# SVS Label Renamer

SVSファイルに埋め込まれたラベル画像とmacro画像に加え、WSI本体の低倍率全体像をPNGに書き出し、macOSのローカルOCRで病理番号・ブロック番号・染色情報を読み取るMacアプリです。画面右上で日本語／Englishをすぐに切り替えられます。

命名形式は `病理番号_ブロック番号_染色情報.svs`（ブロック番号は任意）です。

例：`K1234 CD163` → `K1234_CD163.svs`、`K5678 2 CD68` → `K5678_2_CD68.svs`

## 安全性

- OCRはApple Visionを使い、画像を外部へ送信しません。
- フォルダ選択直後はPNGとプレビューCSVだけを作り、元のSVS内容は変更しません。
- SVSの名前は、一覧を確認して「確認して名前を変更」を押すまで変更しません。
- 同名候補がある場合は処理を止めます。
- 0バイトのDropboxプレースホルダーは変更対象にしません。
- 一括変更は一時名を介したtransactionとして処理し、途中失敗時は元名へ戻します。
- アプリを閉じる前なら、直前の名前変更をボタンで元に戻せます。

## WSI全体像と画質スクリーニング

- `macro`はガラススライド全体の写真です。
- `overview`はSVS本体の画像ピラミッドから生成する組織画像です。QuPathで低倍率表示したときに近い全体像を、縦横比を保って長辺最大2048pxで保存します。
- 組織領域、明るさ、コントラスト、低倍率での細部量を自動チェックし、確認した方がよい画像を警告します。
- 警告は名前変更を止めません。ユーザーが画像を確認して判断できます。

> 画質スクリーニングは低倍率全体像を使う確認補助であり、診断用の品質保証や、顕微鏡倍率での局所的なピント保証ではありません。

## 利用方法

GitHub Releasesから `SVSLabelRenamer-macOS.zip` をダウンロードし、展開した
`SVS Label Renamer.app` をダブルクリックします。Python、Homebrew、OpenSlideの
追加インストールは不要です。

## 開発版の実行

macOS 14以降とSwift 6が必要です。

```bash
swift run SVSLabelRenamer
```

開発環境でのSVS抽出には`slidetool`が必要です。単体アプリの作成時には、公式の
Universal 2版OpenSlideを検証済みハッシュで自動取得して同梱します。

```bash
bash scripts/build_app.sh
```

## 出力

選択したフォルダ内の `SVS_Label_Renamer_Output` に以下を保存します。

- `<元名>_label.png`
- `<元名>_macro.png`
- `<元名>_overview.png`
- `rename_preview.csv`
- 名前変更後の `rename_log_<日時>.csv`
- 復元に使える `rename_transaction_<日時>_<ID>.json`

> ラベルには個人情報が含まれる可能性があります。公開Issueへ実データを添付しないでください。

## English

SVS Label Renamer is a standalone macOS app that exports label, glass-slide macro, and low-magnification WSI overview PNGs; recognizes pathology ID, optional block, and stain locally with Apple Vision; proposes safe filenames; and records preview/rename CSV logs. Use the language control in the upper-right corner to switch between Japanese and English immediately.

The overview quality screen is a conservative, non-diagnostic review aid. It can flag gross exposure, contrast, tissue-coverage, or low-detail issues, but it does not certify microscopic focus or scanner quality.
