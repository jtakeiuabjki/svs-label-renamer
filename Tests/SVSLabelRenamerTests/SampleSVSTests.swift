import Foundation
import Testing
@testable import SVSLabelRenamer

@Test func extractsAssociatedImagesFromOptionalSample() async throws {
    guard let path = ProcessInfo.processInfo.environment["SVS_SAMPLE"],
          FileManager.default.fileExists(atPath: path) else { return }
    let source = URL(fileURLWithPath: path)
    let label = try SVSExtractor.associatedImage(named: "label", from: source)
    let macro = try SVSExtractor.associatedImage(named: "macro", from: source)
    #expect(label.width > 0 && label.height > 0)
    #expect(macro.width > 0 && macro.height > 0)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SVSLabelRenamerTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try SVSExtractor.writePNG(label, to: directory.appendingPathComponent("label.png"))
    try SVSExtractor.writePNG(macro, to: directory.appendingPathComponent("macro.png"))
    let parsed = try OCRService.recognize(label)
    #expect(!parsed.raw.isEmpty)
}
