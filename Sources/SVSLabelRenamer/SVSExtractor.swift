import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.withLock { storage.append(data) }
    }

    var data: Data { lock.withLock { storage } }
}

enum ExtractionError: LocalizedError {
    case cannotOpen(URL)
    case associatedImageMissing(String)
    case toolUnavailable
    case toolFailed(String)
    case cannotWrite(URL)

    var errorDescription: String? {
        switch self {
        case .cannotOpen(let url): "SVSを開けません: \(url.lastPathComponent)"
        case .associatedImageMissing(let name): "\(name)画像が見つかりません"
        case .toolUnavailable: "同梱されたOpenSlideツールが見つかりません"
        case .toolFailed(let message): "SVSの読み込みに失敗しました: \(message)"
        case .cannotWrite(let url): "画像を書き出せません: \(url.lastPathComponent)"
        }
    }
}

struct SVSExtractor {
    static func associatedImage(named name: String, from url: URL) throws -> CGImage {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("svs-label-renamer-\(UUID().uuidString)-\(name).png")
        defer { try? FileManager.default.removeItem(at: temporary) }
        return try extractPNG(named: name, from: url, to: temporary)
    }

    @discardableResult
    static func extractPNG(named name: String, from sourceURL: URL, to outputURL: URL) throws -> CGImage {
        if let tool = slideToolURL() {
            _ = try run(tool, arguments: ["assoc", "read", sourceURL.path, name, outputURL.path])
            return try loadPNG(outputURL)
        }

        // ImageIO can read some TIFF variants without OpenSlide. Keep this fallback
        // for simpler fixtures and future vendor formats exposed as multi-image TIFF.
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ExtractionError.cannotOpen(sourceURL)
        }
        for index in 0..<CGImageSourceGetCount(source) {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let tiff = properties?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            let description = (tiff?[kCGImagePropertyTIFFImageDescription] as? String)?.lowercased() ?? ""
            if description.contains(name.lowercased()),
               let image = CGImageSourceCreateImageAtIndex(source, index, nil) {
                try writePNG(image, to: outputURL)
                return image
            }
        }
        throw slideToolURL() == nil ? ExtractionError.toolUnavailable : ExtractionError.associatedImageMissing(name)
    }

    /// Writes a low-magnification image of the tissue stored in the WSI itself.
    /// This differs from `macro`, which is a camera photograph of the glass slide.
    /// The coarsest OpenSlide level that still supports a 2048-pixel overview is
    /// preferred; an embedded thumbnail is the safe fallback for unusual pyramids.
    @discardableResult
    static func extractOverviewPNG(from sourceURL: URL, to outputURL: URL) throws -> CGImage {
        guard let tool = slideToolURL() else {
            let thumbnail = try extractPNG(named: "thumbnail", from: sourceURL, to: outputURL)
            return try resizeOverviewIfNeeded(thumbnail, at: outputURL)
        }

        if let level = try? overviewLevel(from: sourceURL, using: tool),
           level.width <= 4096,
           level.height <= 4096,
           level.width * level.height <= 16_000_000 {
            do {
                _ = try run(tool, arguments: [
                    "region", "read", sourceURL.path, "0", "0", String(level.index),
                    String(level.width), String(level.height), outputURL.path
                ])
                return try resizeOverviewIfNeeded(try loadPNG(outputURL), at: outputURL)
            } catch {
                try? FileManager.default.removeItem(at: outputURL)
                // Continue to the embedded thumbnail. Some vendor slides expose
                // pyramid metadata but cannot render their final level.
            }
        }

        let thumbnail = try extractPNG(named: "thumbnail", from: sourceURL, to: outputURL)
        return try resizeOverviewIfNeeded(thumbnail, at: outputURL)
    }

    private struct PyramidLevel {
        let index: Int
        let width: Int
        let height: Int
    }

    private static func overviewLevel(from sourceURL: URL, using tool: URL) throws -> PyramidLevel {
        let output = try run(tool, arguments: ["prop", "list", sourceURL.path])
        guard let text = String(data: output, encoding: .utf8) else {
            throw ExtractionError.cannotOpen(sourceURL)
        }
        var properties: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator])
            var value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("'") && value.hasSuffix("'") {
                value.removeFirst()
                value.removeLast()
            }
            properties[key] = value
        }
        guard let countText = properties["openslide.level-count"],
              let count = Int(countText), count > 0 else {
            throw ExtractionError.associatedImageMissing("overview")
        }
        var levels: [PyramidLevel] = []
        for index in 0..<count {
            if let widthText = properties["openslide.level[\(index)].width"],
               let heightText = properties["openslide.level[\(index)].height"],
               let width = Int(widthText), let height = Int(heightText),
               width > 0, height > 0 {
                levels.append(PyramidLevel(index: index, width: width, height: height))
            }
        }
        let safe = levels.filter {
            $0.width <= 4096 && $0.height <= 4096 && $0.width * $0.height <= 16_000_000
        }
        let target = 2048
        let largeEnough = safe.filter { max($0.width, $0.height) >= target }
        if let level = largeEnough.min(by: {
            max($0.width, $0.height) < max($1.width, $1.height)
        }) {
            return level
        }
        if let level = safe.max(by: {
            max($0.width, $0.height) < max($1.width, $1.height)
        }) {
            return level
        }
        throw ExtractionError.associatedImageMissing("overview")
    }

    private static func slideToolURL() -> URL? {
        let manager = FileManager.default
        if let path = ProcessInfo.processInfo.environment["SLIDETOOL_PATH"],
           manager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/slidetool")
        if manager.isExecutableFile(atPath: bundled.path) { return bundled }
        let homebrew = URL(fileURLWithPath: "/opt/homebrew/bin/slidetool")
        if manager.isExecutableFile(atPath: homebrew.path) { return homebrew }
        return nil
    }

    static func run(_ tool: URL, arguments: [String]) throws -> Data {
        let process = Process()
        let combinedPipe = Pipe()
        process.executableURL = tool
        process.arguments = arguments
        process.standardOutput = combinedPipe
        process.standardError = combinedPipe
        let buffer = LockedDataBuffer()
        let readHandle = combinedPipe.fileHandleForReading
        readHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { buffer.append(data) }
        }
        do {
            try process.run()
        } catch {
            readHandle.readabilityHandler = nil
            throw ExtractionError.toolFailed(error.localizedDescription)
        }
        var sentTermination = false
        while process.isRunning {
            if Task.isCancelled && !sentTermination {
                process.terminate()
                sentTermination = true
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        process.waitUntilExit()
        readHandle.readabilityHandler = nil
        buffer.append(readHandle.readDataToEndOfFile())
        let output = buffer.data
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            let message = String(data: output, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ExtractionError.toolFailed(
                message?.isEmpty == false ? message! : "終了コード \(process.terminationStatus)"
            )
        }
        return output
    }

    private static func loadPNG(_ url: URL) throws -> CGImage {
        guard let pngData = try? Data(contentsOf: url),
              let imageSource = CGImageSourceCreateWithData(pngData as CFData, [
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ExtractionError.cannotOpen(url)
        }
        return image
    }

    private static func resizeOverviewIfNeeded(_ image: CGImage, at outputURL: URL) throws -> CGImage {
        let maximumDimension = 2048
        let sourceMaximum = max(image.width, image.height)
        guard sourceMaximum > maximumDimension else { return image }
        let scale = Double(maximumDimension) / Double(sourceMaximum)
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ExtractionError.cannotWrite(outputURL) }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let resized = context.makeImage() else { throw ExtractionError.cannotWrite(outputURL) }
        try writePNG(resized, to: outputURL)
        return resized
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { throw ExtractionError.cannotWrite(url) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ExtractionError.cannotWrite(url)
        }
    }
}
