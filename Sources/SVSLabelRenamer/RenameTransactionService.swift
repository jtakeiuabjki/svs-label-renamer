import Foundation

struct RenameOperation: Codable, Equatable, Sendable {
    let source: URL
    let destination: URL
}

private struct RenameTransaction: Codable {
    let id: UUID
    let createdAt: Date
    var state: String
    let operations: [RenameOperation]
}

enum RenameTransactionError: LocalizedError, Equatable, Sendable {
    case empty
    case duplicateDestination(String)
    case missingSource(String)
    case emptySource(String)
    case destinationExists(String)
    case logFailure(String)
    case moveFailure(String)
    case rollbackFailure(String)

    var errorDescription: String? {
        switch self {
        case .empty: "名前を変更できる確認済みファイルがありません"
        case .duplicateDestination(let name): "変更後の名前が重複しています: \(name)"
        case .missingSource(let name): "元ファイルが見つかりません: \(name)"
        case .emptySource(let name): "ダウンロード未完了のため変更できません: \(name)"
        case .destinationExists(let name): "同名ファイルが既にあります: \(name)"
        case .logFailure(let message): "変更記録を保存できません: \(message)"
        case .moveFailure(let message): "名前変更に失敗しました: \(message)"
        case .rollbackFailure(let message): "復元に失敗しました。transaction記録を確認してください: \(message)"
        }
    }

    func localized(_ language: AppLanguage) -> String {
        switch (language, self) {
        case (.japanese, _): return errorDescription ?? "名前変更に失敗しました"
        case (.english, .empty): return "There are no confirmed files ready to rename"
        case (.english, .duplicateDestination(let name)): return "Duplicate resulting filename: \(name)"
        case (.english, .missingSource(let name)): return "Original file is missing: \(name)"
        case (.english, .emptySource(let name)): return "The file is not fully downloaded: \(name)"
        case (.english, .destinationExists(let name)): return "A file with that name already exists: \(name)"
        case (.english, .logFailure(let detail)): return "Could not save the rename record: \(detail)"
        case (.english, .moveFailure(let detail)): return "Rename failed: \(detail)"
        case (.english, .rollbackFailure(let detail)):
            return "Restore failed. Check the transaction record: \(detail)"
        }
    }
}

struct RenameTransactionService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func execute(_ operations: [RenameOperation], logDirectory: URL) throws -> URL {
        try validate(operations)
        let id = UUID()
        let logURL = logDirectory.appendingPathComponent("rename_transaction_\(Self.timestamp())_\(id.uuidString.prefix(8)).json")
        var transaction = RenameTransaction(id: id, createdAt: Date(), state: "prepared", operations: operations)
        do {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            try write(transaction, to: logURL)
        } catch {
            throw RenameTransactionError.logFailure(error.localizedDescription)
        }

        var staged: [(operation: RenameOperation, temporary: URL)] = []
        var finalized: [(operation: RenameOperation, temporary: URL)] = []
        do {
            for (index, operation) in operations.enumerated() {
                let temporary = operation.source.deletingLastPathComponent()
                    .appendingPathComponent(".svs-label-renamer-\(id.uuidString)-\(index).tmp")
                try fileManager.moveItem(at: operation.source, to: temporary)
                staged.append((operation, temporary))
            }
            for item in staged {
                try fileManager.moveItem(at: item.temporary, to: item.operation.destination)
                finalized.append(item)
            }
            transaction.state = "completed"
            try write(transaction, to: logURL)
            return logURL
        } catch {
            let originalError = error
            do {
                for item in finalized.reversed() where fileManager.fileExists(atPath: item.operation.destination.path) {
                    try fileManager.moveItem(at: item.operation.destination, to: item.operation.source)
                }
                let finalizedSources = Set(finalized.map { $0.operation.source })
                for item in staged.reversed()
                    where !finalizedSources.contains(item.operation.source) && fileManager.fileExists(atPath: item.temporary.path) {
                    try fileManager.moveItem(at: item.temporary, to: item.operation.source)
                }
                transaction.state = "rolled_back"
                try? write(transaction, to: logURL)
                throw RenameTransactionError.moveFailure(originalError.localizedDescription)
            } catch let rollback as RenameTransactionError {
                throw rollback
            } catch {
                transaction.state = "rollback_failed"
                try? write(transaction, to: logURL)
                throw RenameTransactionError.rollbackFailure(error.localizedDescription)
            }
        }
    }

    private func validate(_ operations: [RenameOperation]) throws {
        guard !operations.isEmpty else { throw RenameTransactionError.empty }
        let sourcePaths = Set(operations.map { $0.source.standardizedFileURL.path })
        var destinations = Set<String>()
        for operation in operations {
            let destinationPath = operation.destination.standardizedFileURL.path
            guard destinations.insert(destinationPath).inserted else {
                throw RenameTransactionError.duplicateDestination(operation.destination.lastPathComponent)
            }
            guard fileManager.fileExists(atPath: operation.source.path) else {
                throw RenameTransactionError.missingSource(operation.source.lastPathComponent)
            }
            let attributes = try? fileManager.attributesOfItem(atPath: operation.source.path)
            if (attributes?[.size] as? NSNumber)?.int64Value == 0 {
                throw RenameTransactionError.emptySource(operation.source.lastPathComponent)
            }
            if fileManager.fileExists(atPath: operation.destination.path), !sourcePaths.contains(destinationPath) {
                throw RenameTransactionError.destinationExists(operation.destination.lastPathComponent)
            }
        }
    }

    private func write(_ transaction: RenameTransaction, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(transaction).write(to: url, options: .atomic)
    }

    static func timestamp(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
