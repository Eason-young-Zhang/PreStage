import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section(L10n.tr("Workspace")) {
                Picker(L10n.tr("Workspace"), selection: Binding(
                    get: { store.activeWorkspacePresetID },
                    set: { store.applyWorkspacePreset(id: $0) }
                )) {
                    ForEach(store.workspacePresets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        store.saveCurrentWorkspaceAsNewPreset()
                    } label: {
                        Label(L10n.tr("Save As"), systemImage: "plus")
                    }

                    Button {
                        store.updateActiveWorkspacePreset()
                    } label: {
                        Label(L10n.tr("Update"), systemImage: "arrow.clockwise")
                    }

                    Button {
                        store.deleteActiveWorkspacePreset()
                    } label: {
                        Label(L10n.tr("Delete"), systemImage: "trash")
                    }
                    .disabled(store.workspacePresets.count <= 1)
                }
            }

            Picker(L10n.tr("Language"), selection: $store.appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .onChange(of: store.appLanguage) { store.scheduleWorkspaceSave() }
            Text(L10n.tr("System dialogs use the selected language after restarting the app."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Section(L10n.tr("Review Environment")) {
                Picker(L10n.tr("Appearance"), selection: $store.panelLayout.appAppearance) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .onChange(of: store.panelLayout.appAppearance) { store.scheduleWorkspaceSave() }

                Picker(L10n.tr("Preview Background"), selection: $store.panelLayout.previewBackground) {
                    ForEach(PreviewBackgroundTone.allCases) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .onChange(of: store.panelLayout.previewBackground) { store.scheduleWorkspaceSave() }

                Picker(L10n.tr("Review Matte"), selection: $store.panelLayout.reviewMatteSize) {
                    ForEach(ReviewMatteSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .onChange(of: store.panelLayout.reviewMatteSize) { store.scheduleWorkspaceSave() }

                Text(L10n.tr("Review matte adds temporary padding around the gallery preview without changing files."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(L10n.tr("Restore source and target paths"), isOn: $store.preservePaths)
                .onChange(of: store.preservePaths) { store.scheduleWorkspaceSave() }

            Section(L10n.tr("Camera Card")) {
                Picker(L10n.tr("When Card Is Inserted"), selection: Binding(
                    get: { store.cameraCardAction },
                    set: { store.setCameraCardAction($0) }
                )) {
                    ForEach(CameraCardAction.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                Text(L10n.tr("Automatic card actions use DCIM when available and never enable subfolder scanning by themselves."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr("Layout")) {
                Slider(
                    value: $store.panelLayout.sidebarWidth,
                    in: PanelLayout.minimumSidebarWidth...PanelLayout.maximumSidebarWidth
                ) {
                    Text(L10n.tr("Sidebar Width"))
                }
                .onChange(of: store.panelLayout) { store.scheduleWorkspaceSave() }

                Slider(value: $store.panelLayout.previewWidth, in: 280...460) {
                    Text(L10n.tr("Inspector Width"))
                }
                .onChange(of: store.panelLayout) { store.scheduleWorkspaceSave() }
            }

            Section(L10n.tr("Cache")) {
                Button {
                    store.clearThumbnailCache()
                } label: {
                    Label(L10n.tr("Clear Thumbnail Cache"), systemImage: "trash")
                }
                Text(L10n.tr("Thumbnail cache helps repeated browsing use less CPU and regenerate fewer previews."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }
}
