import CoreGraphics
import Foundation
import Testing
@testable import SVSLabelRenamer

@Test func blankOverviewNeedsReviewForLittleTissue() throws {
    let image = try makeTestImage(width: 64, height: 64) { _, _ in (255, 255, 255) }
    let result = try #require(ImageQualityAnalyzer.assess(image))
    #expect(result.flags.contains(.littleTissue))
}

@Test func blackOverviewIsRecognizedAsTooDark() throws {
    let image = try makeTestImage(width: 64, height: 64) { _, _ in (0, 0, 0) }
    let result = try #require(ImageQualityAnalyzer.assess(image))
    #expect(result.brightness == 0)
    #expect(result.flags.contains(.littleTissue))
    #expect(result.flags.contains(.tooDark))
}

@Test func detailedTissuePatternPassesConservativeScreening() throws {
    let image = try makeTestImage(width: 96, height: 96) { x, y in
        (x / 4 + y / 4).isMultiple(of: 2) ? (75, 45, 95) : (205, 160, 185)
    }
    let result = try #require(ImageQualityAnalyzer.assess(image))
    #expect(result.tissueCoverage > 0.9)
    #expect(!result.flags.contains(.lowOverviewDetail))
    #expect(!result.flags.contains(.tooDark))
    #expect(!result.flags.contains(.tooBright))
}

@Test func smoothTissueGradientFlagsLowOverviewDetail() throws {
    let image = try makeTestImage(width: 128, height: 96) { x, _ in
        let offset = UInt8((Double(x) / 127 * 80).rounded())
        return (90 &+ offset, 55 &+ offset, 110 &+ offset)
    }
    let result = try #require(ImageQualityAnalyzer.assess(image))
    #expect(result.contrast > 0.035)
    #expect(result.flags.contains(.lowOverviewDetail))
}

@Test func languageChangesStatusAndInterfaceText() {
    let record = SlideRecord(sourceURL: URL(fileURLWithPath: "/tmp/example.svs"))
    #expect(record.localizedStatus(.japanese) == "要確認")
    #expect(record.localizedStatus(.english) == "Needs review")
    #expect(L10n.text(.chooseFolder, language: .japanese) == "フォルダを選択")
    #expect(L10n.text(.chooseFolder, language: .english) == "Choose Folder")
    #expect(ProcessingFailure(OCRServiceError.noResult).localized(.english) == "No label text could be recognized")
    #expect(
        RenameTransactionError.destinationExists("same.svs").localized(.english)
            == "A file with that name already exists: same.svs"
    )
}

@Test func csvKeepsStableQualityCodesAcrossLanguages() throws {
    let image = try makeTestImage(width: 32, height: 32) { _, _ in (255, 255, 255) }
    var record = SlideRecord(sourceURL: URL(fileURLWithPath: "/tmp/example.svs"))
    record.qualityAssessment = ImageQualityAnalyzer.assess(image)
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SVSLabelRenamerCSVTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let japaneseURL = directory.appendingPathComponent("ja.csv")
    let englishURL = directory.appendingPathComponent("en.csv")
    try CSVWriter.write([record], to: japaneseURL, language: .japanese)
    try CSVWriter.write([record], to: englishURL, language: .english)
    let japanese = try String(contentsOf: japaneseURL, encoding: .utf8)
    let english = try String(contentsOf: englishURL, encoding: .utf8)
    #expect(japanese.contains("\"quality_review\""))
    #expect(english.contains("\"quality_review\""))
    #expect(japanese.contains("\"little_tissue\""))
    #expect(english.contains("\"little_tissue\""))
    #expect(japanese.contains(ImageQualityAnalyzer.algorithmVersion))
}

private func makeTestImage(
    width: Int,
    height: Int,
    pixel: (Int, Int) -> (UInt8, UInt8, UInt8)
) throws -> CGImage {
    var data = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let index = (y * width + x) * 4
            let (red, green, blue) = pixel(x, y)
            data[index] = red
            data[index + 1] = green
            data[index + 2] = blue
            data[index + 3] = 255
        }
    }
    let provider = try #require(CGDataProvider(data: Data(data) as CFData))
    return try #require(CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ))
}
