import Foundation

struct SlideProcessor {
    static func process(file: URL, outputDirectory: URL) async -> SlideRecord {
        let worker = Task.detached(priority: .userInitiated) {
            var record = SlideRecord(sourceURL: file)
            do {
                try Task.checkCancellation()
                let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size > 0 else {
                    record.status = .downloadPending
                    return record
                }

                let stem = file.deletingPathExtension().lastPathComponent
                var labelFailure: Error?
                do {
                    let labelURL = outputDirectory.appendingPathComponent(stem + "_label.png")
                    let label = try SVSExtractor.extractPNG(named: "label", from: file, to: labelURL)
                    record.labelImageURL = labelURL
                    record.extractionSucceeded = true
                    let parsed = try OCRService.recognize(label)
                    record.pathologyNumber = parsed.pathology
                    record.blockNumber = parsed.block
                    record.stain = parsed.stain
                    record.rawOCR = parsed.raw
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    labelFailure = error
                }

                do {
                    try Task.checkCancellation()
                    let macroURL = outputDirectory.appendingPathComponent(stem + "_macro.png")
                    try SVSExtractor.extractPNG(named: "macro", from: file, to: macroURL)
                    record.macroImageURL = macroURL
                } catch is CancellationError {
                    throw CancellationError()
                } catch { /* macro is optional */ }

                do {
                    try Task.checkCancellation()
                    let overviewURL = outputDirectory.appendingPathComponent(stem + "_overview.png")
                    let overview = try SVSExtractor.extractOverviewPNG(from: file, to: overviewURL)
                    record.overviewImageURL = overviewURL
                    record.qualityAssessment = ImageQualityAnalyzer.assess(overview)
                } catch is CancellationError {
                    throw CancellationError()
                } catch { /* overview and quality screening are optional */ }

                record.status = labelFailure.map { .failed(ProcessingFailure($0)) } ?? .needsReview
            } catch is CancellationError {
                record.status = .cancelled
            } catch {
                record.status = .failed(ProcessingFailure(error))
            }
            return record
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
