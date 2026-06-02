import SwiftUI

struct BatchRenameView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var rule = BatchRenameRule()
    @State private var isApplying = false

    private var plan: BatchRenamePlan {
        store.batchRenamePlan(for: rule)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.tr("Batch Rename"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(L10n.tr("Cancel")) {
                    dismiss()
                }
                Button(L10n.tr("Rename")) {
                    apply()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!plan.canApply || isApplying)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text(L10n.tr("Pattern"))
                        .foregroundStyle(.secondary)
                    TextField("", text: $rule.pattern)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
                GridRow {
                    Text(L10n.tr("Start"))
                        .foregroundStyle(.secondary)
                    Stepper(value: $rule.startNumber, in: 0...999_999) {
                        Text("\(rule.startNumber)")
                            .monospacedDigit()
                            .frame(width: 74, alignment: .leading)
                    }
                }
                GridRow {
                    Text(L10n.tr("Digits"))
                        .foregroundStyle(.secondary)
                    Stepper(value: $rule.digitCount, in: 1...8) {
                        Text("\(rule.digitCount)")
                            .monospacedDigit()
                            .frame(width: 74, alignment: .leading)
                    }
                }
                GridRow {
                    Text(L10n.tr("Case"))
                        .foregroundStyle(.secondary)
                    Picker(L10n.tr("Case"), selection: $rule.letterCase) {
                        ForEach(BatchRenameLetterCase.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                GridRow {
                    Text(L10n.tr("Cleanup"))
                        .foregroundStyle(.secondary)
                    Toggle(L10n.tr("Replace spaces with hyphens"), isOn: $rule.replaceWhitespace)
                }
            }

            Text(L10n.tr("Tokens: {index}, {name}, {date}, {time}, {rating}, {camera}, {lens}, {folder}"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !plan.issues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.issues.prefix(4)) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
            }

            Divider()

            Table(plan.entries.prefix(120).map { $0 }) {
                TableColumn(L10n.tr("Current Name")) { entry in
                    Text(entry.sourceURL.lastPathComponent)
                        .lineLimit(1)
                }
                TableColumn(L10n.tr("New Name")) { entry in
                    Text(entry.destinationURL.lastPathComponent)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 260)

            Text(String(format: L10n.tr("Previewing %d files."), plan.entries.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 680, height: 560)
    }

    private func apply() {
        isApplying = true
        Task {
            let success = await store.applyBatchRename(rule: rule)
            await MainActor.run {
                isApplying = false
                if success {
                    dismiss()
                }
            }
        }
    }
}
