# SVS Label Renamer

SVSファイルに埋め込まれたラベル画像と全体画像（macro）をPNGに書き出し、macOSのローカルOCRで病理番号・ブロック番号・染色情報を読み取るMacアプリです。

命名形式は `病理番号_ブロック番号_染色情報.svs`（ブロック番号は任意）です。

例：`K1234 CD163` → `K1234_CD163.svs`、`K5678 2 CD68` → `K5678_2_CD68.svs`

## 安全性

- OCRはApple Visionを使い、画像を外部へ送信しません。
- フォルダ選択直後はPNGとプレビューCSVだけを作ります。
- SVSの名前は、一覧を確認して「確認して名前を変更」を押すまで変更しません。
- 同名候補がある場合は処理を止めます。
- 0バイトのDropboxプレースホルダーは変更対象にしません。
- 一括変更は一時名を介したtransactionとして処理し、途中失敗時は元名へ戻します。
- アプリを閉じる前なら、直前の名前変更をボタンで元に戻せます。

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
- `rename_preview.csv`
- 名前変更後の `rename_log_<日時>.csv`
- 復元に使える `rename_transaction_<日時>_<ID>.json`

> ラベルには個人情報が含まれる可能性があります。公開Issueへ実データを添付しないでください。
