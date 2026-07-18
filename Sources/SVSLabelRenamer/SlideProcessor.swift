import Foundation

struct SlideProcessor {
    static func process(file: URL, outputDirectory: URL) async -> SlideRecord {
        await Task.detached(priority: .userInitiated) {
            var record = SlideRecord(sourceURL: file)
            do {
                try Task.checkCancellation()
                let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size > 0 else {
                    record.status = "ダウンロード待ち"
                    return record
                }

                let stem = file.deletingPathExtension().lastPathComponent
                let labelURL = outputDirectory.appendingPathComponent(stem + "_label.png")
                let label = try SVSExtractor.extractPNG(named: "label", from: file, to: labelURL)
                let parsed = try OCRService.recognize(label)
                record.pathologyNumber = parsed.pathology
                record.blockNumber = parsed.block
                record.stain = parsed.stain
                record.rawOCR = parsed.raw
                record.labelImageURL = labelURL
                record.extractionSucceeded = true
                record.status = "要確認"

                do {
                    try Task.checkCancellation()
                    let macroURL = outputDirectory.appendingPathComponent(stem + "_macro.png")
                    try SVSExtractor.extractPNG(named: "macro", from: file, to: macroURL)
                    record.macroImageURL = macroURL
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    record.status = "要確認（全体画像なし）"
                }
            } catch is CancellationError {
                record.status = "キャンセル"
            } catch {
                record.status = "エラー: \(error.localizedDescription)"
            }
            return record
        }.value
    }
}
