import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var selectedRecordID: SlideRecord.ID?
    @State private var handledLaunchArgument = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SVS Label Renamer").font(.title2).fontWeight(.semibold)
                    Text(model.message).foregroundStyle(.secondary)
                }
                Spacer()
                if !model.records.isEmpty || model.isWorking {
                    Button("別のフォルダを選択", action: model.chooseFolder)
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isWorking)
                }
                if model.isWorking {
                    Button("キャンセル", action: model.cancelScan)
                }
            }

            if model.isWorking {
                ProgressView(value: Double(model.completedCount), total: Double(max(model.totalCount, 1))) {
                    Text("\(model.completedCount) / \(model.totalCount) 件")
                }
            }

            if model.records.isEmpty && !model.isWorking {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.tint)
                    VStack(spacing: 6) {
                        Text("SVSフォルダをここにドロップ")
                            .font(.title3.weight(.semibold))
                        Text("または、フォルダを選択してください")
                            .foregroundStyle(.secondary)
                    }
                    Button("フォルダを選択", action: model.chooseFolder)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Text("元のSVSは、確認ボタンを押すまで変更されません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                        .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [6]))
                }
            } else {
                HSplitView {
                    Table($model.records, selection: $selectedRecordID) {
                        TableColumn("確認") { $record in
                            Toggle("", isOn: $record.isConfirmed)
                                .labelsHidden()
                                .disabled(!record.extractionSucceeded)
                        }.width(44)
                        TableColumn("元のファイル") { $record in Text(record.originalFilename) }
                        TableColumn("変更後") { $record in
                            Text(record.proposedFilename.isEmpty ? "—" : record.proposedFilename)
                                .foregroundStyle(record.isReadyToRename ? .primary : .secondary)
                                .textSelection(.enabled)
                        }
                        TableColumn("状態") { $record in
                            Label(record.status, systemImage: statusIcon(record))
                                .foregroundStyle(statusColor(record))
                        }
                    }
                    .frame(minWidth: 500)

                    if let index = selectedIndex {
                        RecordDetailView(record: $model.records[index])
                            .frame(minWidth: 340, idealWidth: 400)
                    } else {
                        ContentUnavailableView(
                            "確認するファイルを選択",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("一覧から1件選ぶと、ラベル画像と読み取り結果を確認できます。")
                        )
                        .frame(minWidth: 340)
                    }
                }

                HStack {
                    Text("ラベルPNG・全体PNG・プレビューCSVは出力フォルダへ保存されます。")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if model.canUndo {
                        Button("直前の変更を元に戻す", action: confirmUndo)
                    }
                    Button("確認済み\(model.confirmedCount)件の名前を変更") { confirmRename() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(model.confirmedCount == 0 || model.isWorking)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 580)
        .dropDestination(for: URL.self) { urls, _ in
            guard let first = urls.first else { return false }
            model.openFolder(first)
            return true
        }
        .onChange(of: model.records.count) {
            if selectedRecordID == nil { selectedRecordID = model.records.first?.id }
        }
        .onAppear {
            guard !handledLaunchArgument else { return }
            handledLaunchArgument = true
            guard let path = CommandLine.arguments.dropFirst().first,
                  FileManager.default.fileExists(atPath: path) else { return }
            model.openFolder(URL(fileURLWithPath: path))
        }
    }

    private var selectedIndex: Int? {
        guard let selectedRecordID else { return nil }
        return model.records.firstIndex { $0.id == selectedRecordID }
    }

    private func statusIcon(_ record: SlideRecord) -> String {
        if record.status == "変更済み" { return "checkmark.circle.fill" }
        if record.status.hasPrefix("エラー") { return "exclamationmark.triangle.fill" }
        if record.status == "ダウンロード待ち" { return "icloud.and.arrow.down" }
        return record.isConfirmed ? "checkmark.circle" : "questionmark.circle"
    }

    private func statusColor(_ record: SlideRecord) -> Color {
        if record.status == "変更済み" || record.isConfirmed { return .green }
        if record.status.hasPrefix("エラー") { return .red }
        return .secondary
    }

    private func confirmRename() {
        let alert = NSAlert()
        alert.messageText = "SVSファイルの名前を変更しますか？"
        alert.informativeText = "確認済みの\(model.confirmedCount)件だけを変更します。処理前後の名前はCSVとtransaction記録に残ります。"
        alert.addButton(withTitle: "名前を変更")
        alert.addButton(withTitle: "キャンセル")
        if alert.runModal() == .alertFirstButtonReturn { model.applyRename() }
    }

    private func confirmUndo() {
        let alert = NSAlert()
        alert.messageText = "直前の名前変更を元に戻しますか？"
        alert.informativeText = "SVSファイルを、直前の変更前の名前へ戻します。履歴はCSVとtransaction記録に残ります。"
        alert.addButton(withTitle: "元に戻す")
        alert.addButton(withTitle: "キャンセル")
        if alert.runModal() == .alertFirstButtonReturn { model.undoLastRename() }
    }
}

private struct RecordDetailView: View {
    @Binding var record: SlideRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ImagePreview(title: "ラベル", url: record.labelImageURL)

                GroupBox("読み取り結果") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text("病理番号").foregroundStyle(.secondary)
                            TextField("例: K1234", text: $record.pathologyNumber)
                        }
                        GridRow {
                            Text("ブロック").foregroundStyle(.secondary)
                            TextField("任意（例: 2、A）", text: $record.blockNumber)
                        }
                        GridRow {
                            Text("染色").foregroundStyle(.secondary)
                            TextField("例: CD163", text: $record.stain)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("変更後の名前").font(.caption).foregroundStyle(.secondary)
                    Text(record.proposedFilename.isEmpty ? "—" : record.proposedFilename)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .textSelection(.enabled)
                }

                Toggle("ラベルと変更後の名前を確認しました", isOn: $record.isConfirmed)
                    .disabled(!record.extractionSucceeded || record.proposedFilename.isEmpty)

                DisclosureGroup("OCRで読み取った原文") {
                    Text(record.rawOCR.isEmpty ? "読み取り結果なし" : record.rawOCR)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }

                if record.macroImageURL != nil {
                    ImagePreview(title: "全体画像", url: record.macroImageURL)
                }
            }
            .padding(16)
        }
    }
}

private struct ImagePreview: View {
    let title: String
    let url: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let url, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: title == "ラベル" ? 280 : 180)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(title)
            } else {
                ContentUnavailableView("画像なし", systemImage: "photo")
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }
}
