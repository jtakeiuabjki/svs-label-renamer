import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case japanese = "ja"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .japanese: "日本語"
        case .english: "English"
        }
    }

    static var preferred: AppLanguage {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ja") == true
            ? .japanese : .english
    }
}

enum TextKey: Sendable {
    case anotherFolder, cancel, dropFolder, orChooseFolder, chooseFolder
    case sourceSafetyNote, confirmColumn, originalFile, proposedName, status
    case selectFile, selectFileDescription, outputNote, undoRename, renameConfirmed
    case label, recognitionResult, pathologyNumber, blockNumber, stain
    case pathologyExample, blockExample, stainExample, resultingName
    case confirmLabelAndName, rawOCR, noOCR, macroImage, wsiOverview
    case noImage, qualityTitle, qualityGood, qualityReview, qualityUnavailable
    case qualityNonDiagnostic, tissueCoverage, brightness, contrast, sharpness
    case renameAlertTitle, renameAlertDescription, renameAction
    case cancelAction, undoAlertTitle, undoAlertDescription, undoAction
    case language, qualityFlagPossibleBlur, qualityFlagTooDark
    case qualityFlagTooBright, qualityFlagLowContrast, qualityFlagLittleTissue
    case overviewExplanation
    case progressCount
}

enum L10n {
    static func text(_ key: TextKey, language: AppLanguage) -> String {
        switch language {
        case .japanese: japanese[key] ?? ""
        case .english: english[key] ?? ""
        }
    }

    private static let japanese: [TextKey: String] = [
        .anotherFolder: "別のフォルダを選択",
        .cancel: "キャンセル",
        .dropFolder: "SVSフォルダをここにドロップ",
        .orChooseFolder: "または、フォルダを選択してください",
        .chooseFolder: "フォルダを選択",
        .sourceSafetyNote: "元のSVSは、確認して名前を変更するまで変更されません",
        .confirmColumn: "確認",
        .originalFile: "元のファイル",
        .proposedName: "変更後",
        .status: "状態",
        .selectFile: "確認するファイルを選択",
        .selectFileDescription: "一覧から1件選ぶと、ラベル・WSI全体像・画質結果を確認できます。",
        .outputNote: "ラベル・macro・WSI全体像のPNGとCSVは出力フォルダへ保存されます。",
        .undoRename: "直前の変更を元に戻す",
        .renameConfirmed: "確認済み%lld件の名前を変更",
        .label: "ラベル",
        .recognitionResult: "読み取り結果",
        .pathologyNumber: "病理番号",
        .blockNumber: "ブロック",
        .stain: "染色",
        .pathologyExample: "例: K1234",
        .blockExample: "任意（例: 2、A）",
        .stainExample: "例: CD163",
        .resultingName: "変更後の名前",
        .confirmLabelAndName: "ラベルと変更後の名前を確認しました",
        .rawOCR: "OCRで読み取った原文",
        .noOCR: "読み取り結果なし",
        .macroImage: "macro（スライド全体）",
        .wsiOverview: "WSI全体像",
        .noImage: "画像なし",
        .qualityTitle: "画質スクリーニング",
        .qualityGood: "低倍率全体像の自動チェックでは警告なし",
        .qualityReview: "画質を確認してください",
        .qualityUnavailable: "画質を判定できませんでした",
        .qualityNonDiagnostic: "自動判定は確認を補助する目安で、診断用の品質保証ではありません。",
        .tissueCoverage: "組織領域",
        .brightness: "明るさ",
        .contrast: "コントラスト",
        .sharpness: "鮮明度",
        .renameAlertTitle: "SVSファイルの名前を変更しますか？",
        .renameAlertDescription: "確認済みの%lld件だけを変更します。処理前後の名前はCSVとtransaction記録に残ります。",
        .renameAction: "名前を変更",
        .cancelAction: "キャンセル",
        .undoAlertTitle: "直前の名前変更を元に戻しますか？",
        .undoAlertDescription: "SVSファイルを、直前の変更前の名前へ戻します。履歴はCSVとtransaction記録に残ります。",
        .undoAction: "元に戻す",
        .language: "言語",
        .qualityFlagPossibleBlur: "低倍率画像の細部が少ないため要確認（ぼけ等の可能性）",
        .qualityFlagTooDark: "暗すぎる可能性",
        .qualityFlagTooBright: "白飛び・明るすぎる可能性",
        .qualityFlagLowContrast: "コントラストが低い可能性",
        .qualityFlagLittleTissue: "組織領域が少ないため判定が不安定",
        .overviewExplanation: "QuPathで低倍率表示したときに近い、SVS本体の組織画像です。",
        .progressCount: "%lld / %lld 件"
    ]

    private static let english: [TextKey: String] = [
        .anotherFolder: "Choose Another Folder",
        .cancel: "Cancel",
        .dropFolder: "Drop an SVS folder here",
        .orChooseFolder: "or choose a folder",
        .chooseFolder: "Choose Folder",
        .sourceSafetyNote: "Original SVS files are unchanged until you confirm and rename them",
        .confirmColumn: "Confirm",
        .originalFile: "Original File",
        .proposedName: "New Name",
        .status: "Status",
        .selectFile: "Select a file to review",
        .selectFileDescription: "Select one row to review its label, WSI overview, and quality results.",
        .outputNote: "Label, macro, WSI overview PNGs, and CSV files are saved in the output folder.",
        .undoRename: "Undo Last Rename",
        .renameConfirmed: "Rename %lld Confirmed",
        .label: "Label",
        .recognitionResult: "Recognized Fields",
        .pathologyNumber: "Pathology ID",
        .blockNumber: "Block",
        .stain: "Stain",
        .pathologyExample: "Example: K1234",
        .blockExample: "Optional (for example 2 or A)",
        .stainExample: "Example: CD163",
        .resultingName: "Resulting Filename",
        .confirmLabelAndName: "I reviewed the label and resulting filename",
        .rawOCR: "Raw OCR Text",
        .noOCR: "No recognized text",
        .macroImage: "Macro (whole glass slide)",
        .wsiOverview: "WSI Overview",
        .noImage: "No Image",
        .qualityTitle: "Image Quality Screening",
        .qualityGood: "No warning in the low-magnification overview check",
        .qualityReview: "Please review image quality",
        .qualityUnavailable: "Image quality could not be assessed",
        .qualityNonDiagnostic: "Automated screening is a review aid, not diagnostic quality assurance.",
        .tissueCoverage: "Tissue area",
        .brightness: "Brightness",
        .contrast: "Contrast",
        .sharpness: "Sharpness",
        .renameAlertTitle: "Rename the SVS files?",
        .renameAlertDescription: "Only the %lld confirmed files will be renamed. Old and new names are recorded in the CSV and transaction log.",
        .renameAction: "Rename",
        .cancelAction: "Cancel",
        .undoAlertTitle: "Undo the last rename?",
        .undoAlertDescription: "The SVS files will be restored to their previous names. The action is recorded in the CSV and transaction log.",
        .undoAction: "Undo",
        .language: "Language",
        .qualityFlagPossibleBlur: "Low overview detail; review for blur or scan issues",
        .qualityFlagTooDark: "Possibly too dark",
        .qualityFlagTooBright: "Possible overexposure or clipping",
        .qualityFlagLowContrast: "Possibly low contrast",
        .qualityFlagLittleTissue: "Too little tissue for a stable assessment",
        .overviewExplanation: "The tissue image from the SVS itself, similar to QuPath at low magnification.",
        .progressCount: "%lld / %lld files"
    ]
}

enum AppMessage: Sendable {
    case chooseFolder
    case cancelling
    case cannotReadFolder(String)
    case analyzing(Int)
    case cancelled(Int, Int)
    case cannotSavePreview(String)
    case complete
    case renamed(Int)
    case renamedButCSVFailed(String)
    case undone(Int)
    case renameFailure(RenameTransactionError)
    case error(String)

    func localized(_ language: AppLanguage) -> String {
        switch (language, self) {
        case (.japanese, .chooseFolder): "SVSファイルが入ったフォルダを選択してください"
        case (.english, .chooseFolder): "Choose a folder containing SVS files"
        case (.japanese, .cancelling): "解析をキャンセルしています…"
        case (.english, .cancelling): "Cancelling analysis…"
        case (.japanese, .cannotReadFolder(let error)): "フォルダを読み取れません: \(error)"
        case (.english, .cannotReadFolder(let error)): "Could not read the folder: \(error)"
        case (.japanese, .analyzing(let count)): "\(count)件を解析しています…"
        case (.english, .analyzing(let count)): "Analyzing \(count) file\(count == 1 ? "" : "s")…"
        case (.japanese, .cancelled(let done, let total)): "解析をキャンセルしました（\(done) / \(total)件）"
        case (.english, .cancelled(let done, let total)): "Analysis cancelled (\(done) / \(total))"
        case (.japanese, .cannotSavePreview(let error)): "プレビューCSVを保存できません: \(error)"
        case (.english, .cannotSavePreview(let error)): "Could not save the preview CSV: \(error)"
        case (.japanese, .complete): "解析完了。内容と画質を確認してから名前を変更してください"
        case (.english, .complete): "Analysis complete. Review the fields and image quality before renaming"
        case (.japanese, .renamed(let count)): "\(count)件の名前を安全に変更しました"
        case (.english, .renamed(let count)): "Safely renamed \(count) file\(count == 1 ? "" : "s")"
        case (.japanese, .renamedButCSVFailed(let error)): "名前は変更しましたが、CSV保存に失敗しました: \(error)"
        case (.english, .renamedButCSVFailed(let error)): "Files were renamed, but the CSV could not be saved: \(error)"
        case (.japanese, .undone(let count)): "直前の\(count)件を元の名前に戻しました"
        case (.english, .undone(let count)): "Restored the previous names for \(count) file\(count == 1 ? "" : "s")"
        case (_, .renameFailure(let error)): error.localized(language)
        case (.japanese, .error(let error)): error
        case (.english, .error(let error)): error
        }
    }
}
