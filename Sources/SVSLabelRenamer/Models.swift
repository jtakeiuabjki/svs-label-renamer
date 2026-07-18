import Foundation

struct SlideRecord: Identifiable, Sendable {
    let id = UUID()
    let originalFilename: String
    var sourceURL: URL
    var pathologyNumber: String
    var blockNumber: String
    var stain: String
    var rawOCR: String
    var labelImageURL: URL?
    var macroImageURL: URL?
    var status: String
    var extractionSucceeded: Bool
    var isConfirmed: Bool

    init(
        sourceURL: URL,
        pathologyNumber: String = "",
        blockNumber: String = "",
        stain: String = "",
        rawOCR: String = "",
        status: String = "要確認",
        extractionSucceeded: Bool = false,
        isConfirmed: Bool = false
    ) {
        self.originalFilename = sourceURL.lastPathComponent
        self.sourceURL = sourceURL
        self.pathologyNumber = pathologyNumber
        self.blockNumber = blockNumber
        self.stain = stain
        self.rawOCR = rawOCR
        self.status = status
        self.extractionSucceeded = extractionSucceeded
        self.isConfirmed = isConfirmed
    }

    var proposedBaseName: String {
        FilenameBuilder.make(pathology: pathologyNumber, block: blockNumber, stain: stain)
    }

    var proposedFilename: String {
        proposedBaseName.isEmpty ? "" : proposedBaseName + ".svs"
    }

    var isReadyToRename: Bool {
        extractionSucceeded && isConfirmed &&
        !FilenameBuilder.clean(pathologyNumber).isEmpty &&
        !FilenameBuilder.clean(stain).isEmpty &&
        !proposedFilename.isEmpty &&
        sourceURL.lastPathComponent != proposedFilename
    }
}

enum FilenameBuilder {
    static func clean(_ value: String) -> String {
        value.uppercased()
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: #"[^A-Z0-9-]+"#, with: "", options: .regularExpression)
    }

    static func make(pathology: String, block: String, stain: String) -> String {
        [pathology, block, stain].map(clean).filter { !$0.isEmpty }.joined(separator: "_")
    }
}
