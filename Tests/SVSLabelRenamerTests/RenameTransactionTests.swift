import Foundation
import Testing
@testable import SVSLabelRenamer

@Test func transactionSupportsCyclesWithoutDataLoss() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("RenameTransactionTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let first = root.appendingPathComponent("first.svs")
    let second = root.appendingPathComponent("second.svs")
    try Data("first-content".utf8).write(to: first)
    try Data("second-content".utf8).write(to: second)

    let log = try RenameTransactionService().execute([
        RenameOperation(source: first, destination: second),
        RenameOperation(source: second, destination: first)
    ], logDirectory: root.appendingPathComponent("logs"))

    #expect(try String(contentsOf: first, encoding: .utf8) == "second-content")
    #expect(try String(contentsOf: second, encoding: .utf8) == "first-content")
    #expect(FileManager.default.fileExists(atPath: log.path))
}

@Test func transactionRejectsDuplicateDestinationsBeforeMoving() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("RenameTransactionTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let first = root.appendingPathComponent("first.svs")
    let second = root.appendingPathComponent("second.svs")
    let destination = root.appendingPathComponent("same.svs")
    try Data("first".utf8).write(to: first)
    try Data("second".utf8).write(to: second)

    #expect(throws: RenameTransactionError.self) {
        try RenameTransactionService().execute([
            RenameOperation(source: first, destination: destination),
            RenameOperation(source: second, destination: destination)
        ], logDirectory: root.appendingPathComponent("logs"))
    }
    #expect(FileManager.default.fileExists(atPath: first.path))
    #expect(FileManager.default.fileExists(atPath: second.path))
}

@Test func transactionRejectsZeroBytePlaceholders() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("RenameTransactionTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("placeholder.svs")
    FileManager.default.createFile(atPath: source.path, contents: Data())
    #expect(throws: RenameTransactionError.self) {
        try RenameTransactionService().execute([
            RenameOperation(source: source, destination: root.appendingPathComponent("new.svs"))
        ], logDirectory: root.appendingPathComponent("logs"))
    }
    #expect(FileManager.default.fileExists(atPath: source.path))
}
