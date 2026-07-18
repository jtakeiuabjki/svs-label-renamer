import Foundation

enum SlideStatus: Sendable, Equatable {
    case needsReview
    case downloadPending
    case cancelled
    case failed(ProcessingFailure)
    case renamed
    case restored

    var isError: Bool {
        if case .failed = self { return true }
        return false
    }

    var code: String {
        switch self {
        case .needsReview: "needs_review"
        case .downloadPending: "download_pending"
        case .cancelled: "cancelled"
        case .failed: "error"
        case .renamed: "renamed"
        case .restored: "restored"
        }
    }

    func localized(_ language: AppLanguage, isConfirmed: Bool, qualityNeedsReview: Bool) -> String {
        switch (language, self) {
        case (.japanese, .needsReview):
            if qualityNeedsReview { return "画質を要確認" }
            return isConfirmed ? "確認済み" : "要確認"
        case (.english, .needsReview):
            if qualityNeedsReview { return "Review image quality" }
            return isConfirmed ? "Confirmed" : "Needs review"
        case (.japanese, .downloadPending): return "ダウンロード待ち"
        case (.english, .downloadPending): return "Waiting for download"
        case (.japanese, .cancelled): return "キャンセル"
        case (.english, .cancelled): return "Cancelled"
        case (.japanese, .failed(let error)): return "エラー: \(error.localized(.japanese))"
        case (.english, .failed(let error)): return "Error: \(error.localized(.english))"
        case (.japanese, .renamed): return "変更済み"
        case (.english, .renamed): return "Renamed"
        case (.japanese, .restored): return "元に戻しました"
        case (.english, .restored): return "Restored"
        }
    }
}

enum ProcessingFailure: Sendable, Equatable {
    case cannotOpen(String)
    case associatedImageMissing(String)
    case toolUnavailable
    case toolFailed(String)
    case cannotWrite(String)
    case ocrNoResult
    case other(String)

    init(_ error: Error) {
        if let extraction = error as? ExtractionError {
            switch extraction {
            case .cannotOpen(let url): self = .cannotOpen(url.lastPathComponent)
            case .associatedImageMissing(let name): self = .associatedImageMissing(name)
            case .toolUnavailable: self = .toolUnavailable
            case .toolFailed(let detail): self = .toolFailed(detail)
            case .cannotWrite(let url): self = .cannotWrite(url.lastPathComponent)
            }
        } else if error is OCRServiceError {
            self = .ocrNoResult
        } else {
            self = .other(error.localizedDescription)
        }
    }

    func localized(_ language: AppLanguage) -> String {
        switch (language, self) {
        case (.japanese, .cannotOpen(let name)): "SVSを開けません: \(name)"
        case (.english, .cannotOpen(let name)): "Cannot open SVS: \(name)"
        case (.japanese, .associatedImageMissing(let name)): "\(name)画像が見つかりません"
        case (.english, .associatedImageMissing(let name)): "Associated \(name) image is missing"
        case (.japanese, .toolUnavailable): "同梱されたOpenSlideツールが見つかりません"
        case (.english, .toolUnavailable): "The bundled OpenSlide tool is unavailable"
        case (.japanese, .toolFailed(let detail)): "SVSの読み込みに失敗しました: \(detail)"
        case (.english, .toolFailed(let detail)): "Could not read the SVS: \(detail)"
        case (.japanese, .cannotWrite(let name)): "画像を書き出せません: \(name)"
        case (.english, .cannotWrite(let name)): "Could not write the image: \(name)"
        case (.japanese, .ocrNoResult): "ラベルの文字を読み取れませんでした"
        case (.english, .ocrNoResult): "No label text could be recognized"
        case (_, .other(let detail)): detail
        }
    }
}

enum QualityFlag: String, CaseIterable, Sendable {
    case lowOverviewDetail = "low_overview_detail"
    case tooDark = "too_dark"
    case tooBright = "too_bright"
    case lowContrast = "low_contrast"
    case littleTissue = "little_tissue"

    func localized(_ language: AppLanguage) -> String {
        let key: TextKey = switch self {
        case .lowOverviewDetail: .qualityFlagPossibleBlur
        case .tooDark: .qualityFlagTooDark
        case .tooBright: .qualityFlagTooBright
        case .lowContrast: .qualityFlagLowContrast
        case .littleTissue: .qualityFlagLittleTissue
        }
        return L10n.text(key, language: language)
    }
}

struct QualityAssessment: Sendable, Equatable {
    let tissueCoverage: Double
    let brightness: Double
    let contrast: Double
    let sharpness: Double
    let edgeFraction: Double
    let flags: [QualityFlag]

    var needsReview: Bool { !flags.isEmpty }
}

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
    var overviewImageURL: URL?
    var qualityAssessment: QualityAssessment?
    var status: SlideStatus
    var extractionSucceeded: Bool
    var isConfirmed: Bool

    init(
        sourceURL: URL,
        pathologyNumber: String = "",
        blockNumber: String = "",
        stain: String = "",
        rawOCR: String = "",
        status: SlideStatus = .needsReview,
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

    func localizedStatus(_ language: AppLanguage) -> String {
        status.localized(
            language,
            isConfirmed: isConfirmed,
            qualityNeedsReview: qualityAssessment?.needsReview == true
        )
    }

    var statusCode: String {
        guard status == .needsReview else { return status.code }
        if qualityAssessment?.needsReview == true { return "quality_review" }
        return isConfirmed ? "confirmed" : "needs_review"
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
