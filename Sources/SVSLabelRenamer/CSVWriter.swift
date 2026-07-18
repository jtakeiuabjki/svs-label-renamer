import Foundation

enum CSVWriter {
    static func escape(_ value: String) -> String {
        let safe: String
        if let first = value.first, "=+-@".contains(first) {
            safe = "'" + value
        } else {
            safe = value
        }
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func write(
        _ records: [SlideRecord],
        to url: URL,
        language: AppLanguage = .japanese
    ) throws {
        var rows = [
            "original_filename,new_filename,pathology_number,block_number,stain,ocr_text," +
            "status,status_label,label_png,macro_png,overview_png," +
            "quality_status,quality_label,quality_flags,quality_flags_label," +
            "tissue_coverage,brightness,contrast,sharpness,edge_fraction,quality_algorithm"
        ]
        rows += records.map {
            let assessment = $0.qualityAssessment
            let qualityStatus: String
            if let assessment {
                if assessment.flags == [.littleTissue] {
                    qualityStatus = "insufficient_tissue"
                } else {
                    qualityStatus = assessment.needsReview ? "review" : "no_warning"
                }
            } else {
                qualityStatus = "unavailable"
            }
            let qualityLabel: String
            if qualityStatus == "unavailable" {
                qualityLabel = L10n.text(.qualityUnavailable, language: language)
            } else if qualityStatus == "no_warning" {
                qualityLabel = L10n.text(.qualityGood, language: language)
            } else {
                qualityLabel = L10n.text(.qualityReview, language: language)
            }
            let flagCodes = assessment?.flags.map(\.rawValue).joined(separator: ";") ?? ""
            let flagLabels = assessment?.flags.map { $0.localized(language) }.joined(separator: "; ") ?? ""
            let metric: (Double?) -> String = { value in
                value.map { String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? ""
            }
            return [$0.originalFilename, $0.proposedFilename, $0.pathologyNumber,
             $0.blockNumber, $0.stain, $0.rawOCR, $0.statusCode, $0.localizedStatus(language),
             $0.labelImageURL?.lastPathComponent ?? "",
             $0.macroImageURL?.lastPathComponent ?? "",
             $0.overviewImageURL?.lastPathComponent ?? "",
             qualityStatus, qualityLabel, flagCodes, flagLabels,
             metric(assessment?.tissueCoverage), metric(assessment?.brightness),
             metric(assessment?.contrast), metric(assessment?.sharpness),
             metric(assessment?.edgeFraction),
             assessment == nil ? "" : ImageQualityAnalyzer.algorithmVersion]
                .map(escape).joined(separator: ",")
        }
        try (rows.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
