import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var records: [SlideRecord] = []
    @Published var selectedFolder: URL?
    @Published var isWorking = false
    @Published var message = "SVSファイルが入ったフォルダを選択してください"
    @Published var completedCount = 0
    @Published var totalCount = 0
    private var scanTask: Task<Void, Never>?
    private var lastCompletedOperations: [RenameOperation] = []

    var confirmedCount: Int { records.filter(\.isReadyToRename).count }
    var canUndo: Bool { !lastCompletedOperations.isEmpty }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            openFolder(url)
        }
    }

    func openFolder(_ url: URL) {
        var isDirectory: ObjCBool = false
        let folder = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            ? url
            : url.deletingLastPathComponent()
        selectedFolder = folder
        scanTask?.cancel()
        scanTask = Task { await scan(folder) }
    }

    func cancelScan() {
        scanTask?.cancel()
        message = "解析をキャンセルしています…"
    }

    func scan(_ folder: URL) async {
        isWorking = true
        records = []
        lastCompletedOperations = []
        completedCount = 0
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension.lowercased() == "svs" }
             .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            message = "フォルダを読み取れません: \(error.localizedDescription)"
            isWorking = false
            return
        }
        totalCount = files.count
        message = "\(files.count)件を解析しています…"
        let output = folder.appendingPathComponent("SVS_Label_Renamer_Output", isDirectory: true)
        do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        catch { message = error.localizedDescription; isWorking = false; return }

        for file in files {
            if Task.isCancelled { break }
            let record = await SlideProcessor.process(file: file, outputDirectory: output)
            records.append(record)
            completedCount += 1
        }
        if Task.isCancelled {
            message = "解析をキャンセルしました（\(completedCount) / \(totalCount)件）"
            isWorking = false
            return
        }
        do {
            try CSVWriter.write(records, to: output.appendingPathComponent("rename_preview.csv"))
        } catch {
            message = "プレビューCSVを保存できません: \(error.localizedDescription)"
            isWorking = false
            return
        }
        message = "解析完了。内容を確認してから名前を変更してください"
        isWorking = false
    }

    func applyRename() {
        guard let folder = selectedFolder else { return }
        let indexes = records.indices.filter { records[$0].isReadyToRename }
        let operations = indexes.map {
            RenameOperation(
                source: records[$0].sourceURL,
                destination: folder.appendingPathComponent(records[$0].proposedFilename)
            )
        }
        let output = folder.appendingPathComponent("SVS_Label_Renamer_Output", isDirectory: true)
        do {
            let timestamp = RenameTransactionService.timestamp()
            try CSVWriter.write(records, to: output.appendingPathComponent("rename_preview_\(timestamp).csv"))
            _ = try RenameTransactionService().execute(operations, logDirectory: output)
            lastCompletedOperations = operations
            for (offset, index) in indexes.enumerated() {
                records[index].sourceURL = operations[offset].destination
                records[index].status = "変更済み"
                records[index].isConfirmed = false
            }
            do {
                try CSVWriter.write(records, to: output.appendingPathComponent("rename_log_\(timestamp).csv"))
                message = "\(operations.count)件の名前を安全に変更しました"
            } catch {
                message = "名前は変更しましたが、CSV保存に失敗しました: \(error.localizedDescription)"
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func undoLastRename() {
        guard let folder = selectedFolder, !lastCompletedOperations.isEmpty else { return }
        let reversed = lastCompletedOperations.reversed().map {
            RenameOperation(source: $0.destination, destination: $0.source)
        }
        let output = folder.appendingPathComponent("SVS_Label_Renamer_Output", isDirectory: true)
        do {
            _ = try RenameTransactionService().execute(reversed, logDirectory: output)
            for operation in lastCompletedOperations {
                if let index = records.firstIndex(where: { $0.sourceURL == operation.destination }) {
                    records[index].sourceURL = operation.source
                    records[index].status = "元に戻しました"
                    records[index].isConfirmed = false
                }
            }
            let count = lastCompletedOperations.count
            lastCompletedOperations = []
            try CSVWriter.write(
                records,
                to: output.appendingPathComponent("undo_log_\(RenameTransactionService.timestamp()).csv")
            )
            message = "直前の\(count)件を元の名前に戻しました"
        } catch {
            message = error.localizedDescription
        }
    }
}
