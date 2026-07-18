import Foundation
import Testing
@testable import SVSLabelRenamer

@Test func cancellingToolProcessTerminatesPromptly() async throws {
    let clock = ContinuousClock()
    let started = clock.now
    let task = Task.detached {
        try SVSExtractor.run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"])
    }
    try await Task.sleep(for: .milliseconds(60))
    task.cancel()
    do {
        _ = try await task.value
        Issue.record("Cancelled tool process unexpectedly succeeded")
    } catch {
        // A terminated child reports a non-zero exit through ExtractionError.
    }
    #expect(started.duration(to: clock.now) < .seconds(2))
}

@Test func extractsAssociatedImagesFromOptionalSample() async throws {
    guard let path = ProcessInfo.processInfo.environment["SVS_SAMPLE"],
          FileManager.default.fileExists(atPath: path) else { return }
    let source = URL(fileURLWithPath: path)
    let attributesBefore = try FileManager.default.attributesOfItem(atPath: source.path)
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
    let overview = try SVSExtractor.extractOverviewPNG(
        from: source,
        to: directory.appendingPathComponent("overview.png")
    )
    #expect(overview.width > 0 && overview.height > 0)
    #expect(max(overview.width, overview.height) <= 2048)
    #expect(ImageQualityAnalyzer.assess(overview) != nil)
    let parsed = try OCRService.recognize(label)
    #expect(!parsed.raw.isEmpty)

    let attributesAfter = try FileManager.default.attributesOfItem(atPath: source.path)
    #expect(attributesBefore[.size] as? NSNumber == attributesAfter[.size] as? NSNumber)
    #expect(attributesBefore[.modificationDate] as? Date == attributesAfter[.modificationDate] as? Date)
}
