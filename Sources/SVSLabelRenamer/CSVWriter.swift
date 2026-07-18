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

    static func write(_ records: [SlideRecord], to url: URL) throws {
        var rows = ["original_filename,new_filename,pathology_number,block_number,stain,ocr_text,status"]
        rows += records.map {
            [$0.originalFilename, $0.proposedFilename, $0.pathologyNumber,
             $0.blockNumber, $0.stain, $0.rawOCR, $0.status].map(escape).joined(separator: ",")
        }
        try (rows.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
