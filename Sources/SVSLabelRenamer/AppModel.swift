import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var records: [SlideRecord] = []
    @Published var selectedFolder: URL?
    @Published var isWorking = false
    @Published private(set) var message: AppMessage = .chooseFolder
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.languageDefaultsKey) }
    }
    @Published var completedCount = 0
    @Published var totalCount = 0
    private var scanTask: Task<Void, Never>?
    private var activeScanID: UUID?
    private var lastCompletedOperations: [RenameOperation] = []
    private let processSlide: @Sendable (URL, URL) async -> SlideRecord
    private static let languageDefaultsKey = "appLanguage"

    init(
        processSlide: @escaping @Sendable (URL, URL) async -> SlideRecord = { file, output in
            await SlideProcessor.process(file: file, outputDirectory: output)
        }
    ) {
        self.processSlide = processSlide
        if let saved = UserDefaults.standard.string(forKey: Self.languageDefaultsKey),
           let language = AppLanguage(rawValue: saved) {
            self.language = language
        } else {
            self.language = .preferred
        }
    }

    var confirmedCount: Int { records.filter(\.isReadyToRename).count }
    var canUndo: Bool { !lastCompletedOperations.isEmpty }
    var messageText: String { message.localized(language) }

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
        let scanID = UUID()
        activeScanID = scanID
        scanTask = Task { await scan(folder, scanID: scanID) }
    }

    func cancelScan() {
        scanTask?.cancel()
        message = .cancelling
    }

    private func scan(_ folder: URL, scanID: UUID) async {
        guard activeScanID == scanID else { return }
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
            guard activeScanID == scanID else { return }
            message = .cannotReadFolder(error.localizedDescription)
            isWorking = false
            return
        }
        totalCount = files.count
        message = .analyzing(files.count)
        let output = folder.appendingPathComponent("SVS_Label_Renamer_Output", isDirectory: true)
        do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        catch {
            guard activeScanID == scanID else { return }
            message = .error(error.localizedDescription)
            isWorking = false
            return
        }

        var scannedRecords: [SlideRecord] = []
        for file in files {
            if Task.isCancelled || activeScanID != scanID { break }
            let record = await processSlide(file, output)
            guard activeScanID == scanID else { return }
            if Task.isCancelled { break }
            scannedRecords.append(record)
            records = scannedRecords
            completedCount = scannedRecords.count
        }
        guard activeScanID == scanID else { return }
        if Task.isCancelled {
            message = .cancelled(completedCount, totalCount)
            isWorking = false
            return
        }
        do {
            try CSVWriter.write(
                records,
                to: output.appendingPathComponent("rename_preview.csv"),
                language: language
            )
        } catch {
            guard activeScanID == scanID else { return }
            message = .cannotSavePreview(error.localizedDescription)
            isWorking = false
            return
        }
        message = .complete
        isWorking = false
    }

    func waitForCurrentScan() async {
        let task = scanTask
        await task?.value
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
            try CSVWriter.write(
                records,
                to: output.appendingPathComponent("rename_preview_\(timestamp).csv"),
                language: language
            )
            _ = try RenameTransactionService().execute(operations, logDirectory: output)
            lastCompletedOperations = operations
            for (offset, index) in indexes.enumerated() {
                records[index].sourceURL = operations[offset].destination
                records[index].status = .renamed
                records[index].isConfirmed = false
            }
            do {
                try CSVWriter.write(
                    records,
                    to: output.appendingPathComponent("rename_log_\(timestamp).csv"),
                    language: language
                )
                message = .renamed(operations.count)
            } catch {
                message = .renamedButCSVFailed(error.localizedDescription)
            }
        } catch let error as RenameTransactionError {
            message = .renameFailure(error)
        } catch {
            message = .error(error.localizedDescription)
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
                    records[index].status = .restored
                    records[index].isConfirmed = false
                }
            }
            let count = lastCompletedOperations.count
            lastCompletedOperations = []
            try CSVWriter.write(
                records,
                to: output.appendingPathComponent("undo_log_\(RenameTransactionService.timestamp()).csv"),
                language: language
            )
            message = .undone(count)
        } catch let error as RenameTransactionError {
            message = .renameFailure(error)
        } catch {
            message = .error(error.localizedDescription)
        }
    }
}
