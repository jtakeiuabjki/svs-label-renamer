import Foundation
import Testing
@testable import SVSLabelRenamer

@Test @MainActor func switchingFoldersCannotMixResultsFromCancelledScan() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("SVSLabelRenamerScanTests-\(UUID().uuidString)")
    let first = root.appendingPathComponent("first", isDirectory: true)
    let second = root.appendingPathComponent("second", isDirectory: true)
    try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
    try Data([1]).write(to: first.appendingPathComponent("old.svs"))
    try Data([2]).write(to: second.appendingPathComponent("new.svs"))
    defer { try? FileManager.default.removeItem(at: root) }

    let model = AppModel { file, _ in
        let delay: Duration = file.lastPathComponent == "old.svs" ? .milliseconds(180) : .milliseconds(10)
        _ = await Task.detached {
            try? await Task.sleep(for: delay)
        }.value
        return SlideRecord(sourceURL: file)
    }

    model.openFolder(first)
    try await Task.sleep(for: .milliseconds(20))
    model.openFolder(second)
    await model.waitForCurrentScan()
    try await Task.sleep(for: .milliseconds(220))

    #expect(model.selectedFolder == second)
    #expect(model.records.map(\.originalFilename) == ["new.svs"])
    #expect(model.completedCount == 1)
    #expect(model.totalCount == 1)
    #expect(!model.isWorking)
}
