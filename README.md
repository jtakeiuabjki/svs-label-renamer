# SVS Label Renamer

SVSファイルのラベルを読み取り、安全なファイル名を提案するmacOSアプリです。ラベル画像、macro画像、WSI本体の低倍率全体像をPNGで保存し、変更前後の名前をCSVに記録します。処理はMac内で完結し、日本語／Englishを画面右上で切り替えられます。

> [!IMPORTANT]
> 現在はベータ版（v0.2.0）です。OCR結果と画質警告を確認してから名前を変更してください。本アプリの画質スクリーニングは診断用の品質保証ではありません。

## 主な機能

- フォルダ内の`.svs`ファイルをまとめて読み込み
- Apple VisionによるローカルOCR（画像を外部へ送信しません）
- 病理番号、任意のブロック番号、染色情報からファイル名を提案
- label、macro、低倍率overviewをPNGで出力
- 低倍率overviewを使った、明るさ・コントラスト・組織量・細部量の確認補助
- 変更前後の名前と処理結果をCSVで保存
- 同名ファイルの検出、安全な一括変更、直前の変更の取り消し
- 日本語／English表示、Apple Silicon／Intel Mac対応

命名形式は`病理番号_ブロック番号_染色情報.svs`です（ブロック番号は任意）。

- `K1234 CD163` → `K1234_CD163.svs`
- `K5678 2 CD68` → `K5678_2_CD68.svs`

## 動作環境

- macOS 14 Sonoma以降
- Apple Silicon（M1以降）またはIntel Mac

Python、Homebrew、OpenSlideの追加インストールは不要です。

## ダウンロードと起動

1. [GitHub Releases](https://github.com/jtakeiuabjki/svs-label-renamer/releases)から`SVSLabelRenamer-macOS.zip`をダウンロードします。
2. ZIPを展開し、`SVS Label Renamer.app`をダブルクリックします。インストーラーはなく、アプリは任意の場所から起動できます。

v0.2.0配布ZIPのSHA-256は`1da9c10e12c9de1e0d60a38a16005d40acc8fbcf0b4bb5e27bb0a741dda9ff6d`です。ダウンロード後に確認する場合は、ターミナルで次を実行します。

```bash
shasum -a 256 ~/Downloads/SVSLabelRenamer-macOS.zip
```

この配布版はアドホック署名済みですが、Appleによる公証（notarization）はまだ行っていません。初回起動をmacOSに止められた場合は、一度起動を試したあと、`システム設定` → `プライバシーとセキュリティ` → `このまま開く`を選んでください。詳しくは[Appleの案内](https://support.apple.com/102445)を参照してください。信頼できるGitHub Releaseから取得したファイルだけを開いてください。

## 使い方

1. アプリで「SVSフォルダを選択」を押します。
2. 自動生成されたlabel、macro、overviewとOCR結果を確認します。
3. 必要なら病理番号、ブロック番号、染色情報を修正します。
4. 変更候補に問題がなければ「確認して名前を変更」を押します。

初回利用時は元フォルダのバックアップを推奨します。選択したフォルダ直下の`.svs`だけが対象で、サブフォルダは走査しません。

フォルダ選択直後はPNGとプレビューCSVだけを作成し、SVSの名前は変更しません。明示的に名前変更を実行した場合も、SVSの画像内容には触れず、ファイル名だけを変更します。

## 出力

選択したフォルダ内の`SVS_Label_Renamer_Output`に以下を保存します。

- `<元名>_label.png` — ラベル画像
- `<元名>_macro.png` — ガラススライド全体の写真（SVSに含まれる場合）
- `<元名>_overview.png` — WSI画像ピラミッドから生成した長辺最大2048 pxの低倍率全体像（生成できる場合）
- `rename_preview.csv` — 名前変更前の確認一覧
- `rename_preview_<日時>.csv` — 名前変更実行時点の確認一覧
- `rename_log_<日時>.csv` — 名前変更の結果
- `undo_log_<日時>.csv` — 直前の変更を取り消した結果
- `rename_transaction_<日時>_<ID>.json` — 監査と、失敗時の手動復旧に使える処理記録

## 安全性とプライバシー

- OCRと画質確認はMac内で完結し、画像を外部サービスへ送信しません。
- 同名候補がある場合は名前変更を止めます。
- 0バイトのDropboxプレースホルダーは変更対象にしません。
- 一括変更は一時名を介したtransactionとして処理し、途中で失敗した場合は元の名前へ戻します。
- アプリを閉じる前なら、直前の名前変更を画面上のボタンで取り消せます。

> [!WARNING]
> SVS、label／macro PNG、CSV、transaction JSONには、患者情報、OCR全文、元ファイル名、ローカルパスが含まれる可能性があります。機微情報として安全に保管し、公開Issueへ実データや未加工のスクリーンショットを添付しないでください。選択先がDropboxやiCloud Drive内の場合、生成物は各サービスの設定に従って同期されることがあります。

## WSI全体像と画質スクリーニング

`macro`はガラススライド全体の写真、`overview`はQuPathで低倍率表示したときに近い組織全体像です。overviewを使って、組織領域、明るさ、コントラスト、低倍率での細部量を確認し、見直した方がよい画像に警告を表示します。

警告は名前変更を止めません。また、低倍率全体像だけを使う確認補助であり、顕微鏡倍率での局所的なピント、スキャナー品質、診断適否を保証しません。

## 開発

macOS 14以降とSwift 6が必要です。

```bash
swift test
swift run SVSLabelRenamer
```

開発環境でのSVS抽出には`slidetool`が必要です。単体アプリの作成時には、公式Universal 2版OpenSlideを検証済みハッシュで自動取得して同梱します。

```bash
bash scripts/build_app.sh
```

## License

本体は[MIT License](LICENSE)で公開しています。同梱ライブラリについては[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)を参照してください。

---

## English

SVS Label Renamer is a standalone macOS app that reads slide labels, proposes filenames, exports label/macro/low-magnification WSI overview PNGs, and records rename results in CSV. OCR and quality screening run locally with Apple Vision. Use the control in the upper-right corner to switch between Japanese and English.

> [!IMPORTANT]
> This is a beta release (v0.2.0). Review every OCR result and warning before renaming. Quality screening is a non-diagnostic review aid.

### Requirements and download

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac
- No Python, Homebrew, or separate OpenSlide installation

Download `SVSLabelRenamer-macOS.zip` from [GitHub Releases](https://github.com/jtakeiuabjki/svs-label-renamer/releases), unzip it, and open `SVS Label Renamer.app`. No installer is required.

SHA-256 for the v0.2.0 ZIP: `1da9c10e12c9de1e0d60a38a16005d40acc8fbcf0b4bb5e27bb0a741dda9ff6d`

The current build is ad-hoc signed but not Apple-notarized. If macOS blocks the first launch, try opening the app once, then go to `System Settings` → `Privacy & Security` → `Open Anyway`. See [Apple's guidance](https://support.apple.com/102445), and only open a build obtained from a GitHub Release you trust.

### Basic workflow

1. Select a folder containing `.svs` files.
2. Review the exported label, macro, overview, and OCR fields.
3. Correct the pathology ID, optional block, or stain when needed.
4. Confirm the proposals, then run the rename action.

Back up the source folder before the first batch rename. Only `.svs` files directly inside the selected folder are scanned; subfolders are not scanned. Selecting a folder only creates PNG previews and `rename_preview.csv`. The app does not rename anything until you explicitly confirm. Renaming changes filenames only, not the image data inside the SVS files.

Output is written to `SVS_Label_Renamer_Output` inside the selected folder. The overview is generated from the WSI pyramid with a maximum long edge of 2048 px. It resembles a low-magnification QuPath view, not a full-resolution diagnostic export.

> [!WARNING]
> SVS files, label/macro PNGs, CSV logs, and transaction JSON may contain patient information, raw OCR text, original filenames, or local paths. Store them as sensitive data and never attach real data or unredacted screenshots to a public issue. Outputs inside Dropbox or iCloud Drive may be synchronized according to those services' settings.
