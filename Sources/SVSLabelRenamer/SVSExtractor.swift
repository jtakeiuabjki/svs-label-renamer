import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

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
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = tool
            process.arguments = ["assoc", "read", sourceURL.path, name, outputURL.path]
            process.standardError = errorPipe
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                throw ExtractionError.toolFailed(error.localizedDescription)
            }
            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw ExtractionError.toolFailed(message?.isEmpty == false ? message! : "終了コード \(process.terminationStatus)")
            }
            guard let pngData = try? Data(contentsOf: outputURL),
                  let imageSource = CGImageSourceCreateWithData(pngData as CFData, [
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary),
                  let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw ExtractionError.cannotOpen(outputURL)
            }
            return image
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
