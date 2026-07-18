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
                    Text(model.messageText).foregroundStyle(.secondary)
                }
                Spacer()
                Picker(L10n.text(.language, language: model.language), selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
                .help(L10n.text(.language, language: model.language))
                if !model.records.isEmpty || model.isWorking {
                    Button(t(.anotherFolder), action: model.chooseFolder)
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isWorking)
                }
                if model.isWorking {
                    Button(t(.cancel), action: model.cancelScan)
                }
            }

            if model.isWorking {
                ProgressView(value: Double(model.completedCount), total: Double(max(model.totalCount, 1))) {
                    Text(String(
                        format: t(.progressCount),
                        Int64(model.completedCount), Int64(model.totalCount)
                    ))
                }
            }

            if model.records.isEmpty && !model.isWorking {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.tint)
                    VStack(spacing: 6) {
                        Text(t(.dropFolder))
                            .font(.title3.weight(.semibold))
                        Text(t(.orChooseFolder))
                            .foregroundStyle(.secondary)
                    }
                    Button(t(.chooseFolder), action: model.chooseFolder)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Text(t(.sourceSafetyNote))
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
                        TableColumn(t(.confirmColumn)) { $record in
                            Toggle("", isOn: $record.isConfirmed)
                                .labelsHidden()
                                .disabled(!record.extractionSucceeded)
                                .accessibilityLabel("\(t(.confirmColumn)): \(record.originalFilename)")
                        }.width(44)
                        TableColumn(t(.originalFile)) { $record in Text(record.originalFilename) }
                        TableColumn(t(.proposedName)) { $record in
                            Text(record.proposedFilename.isEmpty ? "—" : record.proposedFilename)
                                .foregroundStyle(record.isReadyToRename ? .primary : .secondary)
                                .textSelection(.enabled)
                        }
                        TableColumn(t(.status)) { $record in
                            Label(record.localizedStatus(model.language), systemImage: statusIcon(record))
                                .foregroundStyle(statusColor(record))
                        }
                    }
                    .frame(minWidth: 500)

                    if let index = selectedIndex {
                        RecordDetailView(record: $model.records[index], language: model.language)
                            .frame(minWidth: 340, idealWidth: 400)
                    } else {
                        ContentUnavailableView(
                            t(.selectFile),
                            systemImage: "photo.on.rectangle.angled",
                            description: Text(t(.selectFileDescription))
                        )
                        .frame(minWidth: 340)
                    }
                }

                HStack {
                    Text(t(.outputNote))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if model.canUndo {
                        Button(t(.undoRename), action: confirmUndo)
                    }
                    Button(String(format: t(.renameConfirmed), Int64(model.confirmedCount))) {
                        confirmRename()
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(model.confirmedCount == 0 || model.isWorking)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 580)
        .dropDestination(for: URL.self) { urls, _ in
            guard !model.isWorking else { return false }
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

    private func t(_ key: TextKey) -> String {
        L10n.text(key, language: model.language)
    }

    private func statusIcon(_ record: SlideRecord) -> String {
        if record.status == .renamed || record.status == .restored { return "checkmark.circle.fill" }
        if record.status.isError { return "exclamationmark.triangle.fill" }
        if record.status == .downloadPending { return "icloud.and.arrow.down" }
        if record.qualityAssessment?.needsReview == true { return "exclamationmark.triangle.fill" }
        return record.isConfirmed ? "checkmark.circle" : "questionmark.circle"
    }

    private func statusColor(_ record: SlideRecord) -> Color {
        if record.status.isError { return .red }
        if record.status == .renamed || record.status == .restored { return .green }
        if record.qualityAssessment?.needsReview == true { return .orange }
        if record.isConfirmed { return .green }
        return .secondary
    }

    private func confirmRename() {
        let alert = NSAlert()
        alert.messageText = t(.renameAlertTitle)
        alert.informativeText = String(
            format: t(.renameAlertDescription), Int64(model.confirmedCount)
        )
        alert.addButton(withTitle: t(.renameAction))
        alert.addButton(withTitle: t(.cancelAction))
        if alert.runModal() == .alertFirstButtonReturn { model.applyRename() }
    }

    private func confirmUndo() {
        let alert = NSAlert()
        alert.messageText = t(.undoAlertTitle)
        alert.informativeText = t(.undoAlertDescription)
        alert.addButton(withTitle: t(.undoAction))
        alert.addButton(withTitle: t(.cancelAction))
        if alert.runModal() == .alertFirstButtonReturn { model.undoLastRename() }
    }
}

private struct RecordDetailView: View {
    @Binding var record: SlideRecord
    let language: AppLanguage

    private func t(_ key: TextKey) -> String { L10n.text(key, language: language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ImagePreview(title: t(.label), url: record.labelImageURL, maxHeight: 280, language: language)

                GroupBox(t(.recognitionResult)) {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text(t(.pathologyNumber)).foregroundStyle(.secondary)
                            TextField(t(.pathologyExample), text: $record.pathologyNumber)
                        }
                        GridRow {
                            Text(t(.blockNumber)).foregroundStyle(.secondary)
                            TextField(t(.blockExample), text: $record.blockNumber)
                        }
                        GridRow {
                            Text(t(.stain)).foregroundStyle(.secondary)
                            TextField(t(.stainExample), text: $record.stain)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(t(.resultingName)).font(.caption).foregroundStyle(.secondary)
                    Text(record.proposedFilename.isEmpty ? "—" : record.proposedFilename)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .textSelection(.enabled)
                }

                Toggle(t(.confirmLabelAndName), isOn: $record.isConfirmed)
                    .disabled(!record.extractionSucceeded || record.proposedFilename.isEmpty)

                DisclosureGroup(t(.rawOCR)) {
                    Text(record.rawOCR.isEmpty ? t(.noOCR) : record.rawOCR)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }

                if record.overviewImageURL != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        ImagePreview(
                            title: t(.wsiOverview),
                            url: record.overviewImageURL,
                            maxHeight: 300,
                            language: language
                        )
                        Text(t(.overviewExplanation))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                QualitySummary(assessment: record.qualityAssessment, language: language)

                if record.macroImageURL != nil {
                    ImagePreview(
                        title: t(.macroImage),
                        url: record.macroImageURL,
                        maxHeight: 180,
                        language: language
                    )
                }
            }
            .padding(16)
        }
    }
}

private struct ImagePreview: View {
    let title: String
    let url: URL?
    let maxHeight: CGFloat
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let url, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: maxHeight)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(title)
            } else {
                ContentUnavailableView(L10n.text(.noImage, language: language), systemImage: "photo")
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }
}

private struct QualitySummary: View {
    let assessment: QualityAssessment?
    let language: AppLanguage

    private func t(_ key: TextKey) -> String { L10n.text(key, language: language) }

    var body: some View {
        GroupBox(t(.qualityTitle)) {
            VStack(alignment: .leading, spacing: 10) {
                if let assessment {
                    Label(
                        assessment.needsReview ? t(.qualityReview) : t(.qualityGood),
                        systemImage: assessment.needsReview
                            ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    )
                    .fontWeight(.medium)
                    .foregroundStyle(assessment.needsReview ? .orange : .green)

                    if assessment.needsReview {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(assessment.flags, id: \.self) { flag in
                                Text("• \(flag.localized(language))")
                            }
                        }
                    }

                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                        metricRow(t(.tissueCoverage), assessment.tissueCoverage, percent: true)
                        metricRow(t(.brightness), assessment.brightness)
                        metricRow(t(.contrast), assessment.contrast)
                        metricRow(t(.sharpness), assessment.sharpness)
                    }
                    .font(.caption.monospacedDigit())
                } else {
                    Label(t(.qualityUnavailable), systemImage: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }

                Text(t(.qualityNonDiagnostic))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func metricRow(_ label: String, _ value: Double, percent: Bool = false) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(percent ? String(format: "%.1f%%", value * 100) : String(format: "%.3f", value))
        }
    }
}
