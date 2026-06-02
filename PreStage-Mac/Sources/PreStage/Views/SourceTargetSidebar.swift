import SwiftUI

struct SourceTargetSidebar: View {
    @EnvironmentObject private var store: AppStore
    @State private var sourceDraftBrowserHeight: CGFloat?
    @State private var targetDraftBrowserHeight: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - 28, 1)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    cameraCardsSection

                    SidebarDisclosureSection(
                        title: L10n.tr("Source"),
                        summary: sourceSummary,
                        isExpanded: sectionBinding(\.sourceSectionExpanded, automatic: automaticExpanded(for: .source, height: proxy.size.height))
                    ) {
                        sourceSection(height: proxy.size.height)
                    }

                    SidebarDisclosureSection(
                        title: L10n.tr("Target"),
                        summary: targetSummary,
                        isExpanded: sectionBinding(\.targetSectionExpanded, automatic: automaticExpanded(for: .target, height: proxy.size.height))
                    ) {
                        targetSection(height: proxy.size.height)
                    }

                    SidebarDisclosureSection(
                        title: L10n.tr("Filters"),
                        summary: filtersSummary,
                        isExpanded: sectionBinding(\.filtersSectionExpanded, automatic: automaticExpanded(for: .filters, height: proxy.size.height))
                    ) {
                        filtersSection
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(.regularMaterial)
            .clipped()
        }
        .frame(minWidth: PanelLayout.minimumSidebarWidth)
        .clipped()
    }

    private var cameraCardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SidebarHeader(title: L10n.tr("Camera Cards"), summary: nil)

            if store.cameraVolumes.isEmpty {
                Label(L10n.tr("No cards detected"), systemImage: "sdcard")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(store.cameraVolumes) { volume in
                    Button {
                        store.useCameraVolume(volume)
                    } label: {
                        Label(volume.name, systemImage: volume.hasDCIM ? "camera" : "externaldrive")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                store.refreshVolumes()
            } label: {
                Label(L10n.tr("Refresh Devices"), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func sourceSection(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FolderRow(title: store.sourceURL?.lastPathComponent ?? L10n.tr("Choose source folder"), subtitle: store.sourceURL?.path, systemImage: "folder")
                .contentShape(Rectangle())
                .onTapGesture { store.chooseSourceFolder() }

            sourceScanControls

            NativeFolderBranchPicker(
                branch: store.sourceBranch,
                scale: effectiveScale(for: height),
                placeholder: L10n.tr("Choose a source folder to show subfolders."),
                emptyMessage: L10n.tr("No subfolders"),
                onSelect: { url in store.selectSourceLocation(url) },
                onChooseParent: { url in store.selectSourceFolder(url) }
            )
            .frame(height: store.sourceBranch == nil ? 28 : sourceFolderBrowserHeight)
            .transaction { transaction in transaction.animation = nil }

            FolderBrowserResizeHandle(height: Binding(
                get: { sourceFolderBrowserHeight },
                set: { sourceDraftBrowserHeight = clampedFolderBrowserHeight($0) }
            ), onCommit: {
                setSourceFolderBrowserHeight(sourceFolderBrowserHeight)
                sourceDraftBrowserHeight = nil
            })
            .disabled(store.sourceBranch == nil)

            Button {
                store.chooseSourceFolder()
            } label: {
                Label(L10n.tr("Select Source"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func targetSection(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FolderRow(title: store.targetURL?.lastPathComponent ?? L10n.tr("Choose target folder"), subtitle: store.targetURL?.path, systemImage: "tray.and.arrow.down")
                .contentShape(Rectangle())
                .onTapGesture { store.chooseTargetFolder() }

            NativeFolderBranchPicker(
                branch: store.targetBranch,
                scale: effectiveScale(for: height),
                placeholder: L10n.tr("Choose a target folder to show subfolders."),
                emptyMessage: L10n.tr("No subfolders"),
                onSelect: { url in store.selectTargetLocation(url) },
                onChooseParent: { url in store.selectTargetFolder(url) }
            )
            .frame(height: store.targetBranch == nil ? 28 : targetFolderBrowserHeight)
            .transaction { transaction in transaction.animation = nil }

            FolderBrowserResizeHandle(height: Binding(
                get: { targetFolderBrowserHeight },
                set: { targetDraftBrowserHeight = clampedFolderBrowserHeight($0) }
            ), onCommit: {
                setTargetFolderBrowserHeight(targetFolderBrowserHeight)
                targetDraftBrowserHeight = nil
            })
            .disabled(store.targetBranch == nil)

            HStack(spacing: 8) {
                Button {
                    store.chooseTargetFolder()
                } label: {
                    Label(L10n.tr("Select Target"), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }

                Button {
                    store.createFolderInTarget()
                } label: {
                    Label(L10n.tr("New Folder"), systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)

        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper("\(L10n.tr("Minimum Rating")): \(store.filterState.minimumRating)", value: $store.filterState.minimumRating, in: 0...5)
                .onChange(of: store.filterState) { store.scheduleWorkspaceSave() }

            Picker(L10n.tr("Pick State"), selection: Binding(
                get: { store.filterState.pickState },
                set: { store.filterState.pickState = $0; store.scheduleWorkspaceSave() }
            )) {
                Text(L10n.tr("Any")).tag(Optional<PickState>.none)
                ForEach(PickState.allCases, id: \.self) { state in
                    Text(state.displayName).tag(Optional(state))
                }
            }

            Picker(L10n.tr("Color"), selection: Binding(
                get: { store.filterState.colorLabel },
                set: { store.filterState.colorLabel = $0; store.scheduleWorkspaceSave() }
            )) {
                Text(L10n.tr("Any")).tag(Optional<ColorLabel>.none)
                ForEach(ColorLabel.allCases) { label in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(label.color)
                            .frame(width: 9, height: 9)
                        Text(label.displayName)
                    }
                    .tag(Optional(label))
                }
            }

            Picker(L10n.tr("Camera"), selection: Binding(
                get: { store.filterState.cameraModel },
                set: { store.filterState.cameraModel = $0; store.scheduleWorkspaceSave() }
            )) {
                Text(L10n.tr("Any")).tag(Optional<String>.none)
                ForEach(store.availableCameraModels, id: \.self) { camera in
                    Text(camera).tag(Optional(camera))
                }
            }

            Picker(L10n.tr("Lens"), selection: Binding(
                get: { store.filterState.lensModel },
                set: { store.filterState.lensModel = $0; store.scheduleWorkspaceSave() }
            )) {
                Text(L10n.tr("Any")).tag(Optional<String>.none)
                ForEach(store.availableLensModels, id: \.self) { lens in
                    Text(lens).tag(Optional(lens))
                }
            }

            Toggle(L10n.tr("Start Date"), isOn: Binding(
                get: { store.filterState.startDate != nil },
                set: { enabled in
                    store.filterState.startDate = enabled ? (store.filterState.startDate ?? Date()) : nil
                    store.scheduleWorkspaceSave()
                }
            ))

            if store.filterState.startDate != nil {
                DatePicker("From", selection: Binding(
                    get: { store.filterState.startDate ?? Date() },
                    set: { store.filterState.startDate = $0; store.scheduleWorkspaceSave() }
                ), displayedComponents: .date)
                .labelsHidden()
            }

            Toggle(L10n.tr("End Date"), isOn: Binding(
                get: { store.filterState.endDate != nil },
                set: { enabled in
                    store.filterState.endDate = enabled ? (store.filterState.endDate ?? Date()) : nil
                    store.scheduleWorkspaceSave()
                }
            ))

            if store.filterState.endDate != nil {
                DatePicker("To", selection: Binding(
                    get: { store.filterState.endDate ?? Date() },
                    set: { store.filterState.endDate = $0; store.scheduleWorkspaceSave() }
                ), displayedComponents: .date)
                .labelsHidden()
            }

            Button {
                store.filterState = FilterState()
                store.scheduleWorkspaceSave()
            } label: {
                Label(L10n.tr("Reset Filters"), systemImage: "line.3.horizontal.decrease.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var folderScaleControl: some View {
        Picker(L10n.tr("Folder View"), selection: Binding(
            get: { store.panelLayout.folderBrowserScale },
            set: { scale in
                store.panelLayout.folderBrowserScale = scale
                store.saveWorkspace()
            }
        )) {
            ForEach(FolderBrowserScale.allCases) { scale in
                Text(scale.displayName).tag(scale)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sourceScanControls: some View {
        HStack(alignment: .center, spacing: 12) {
            folderScaleControl

            Spacer(minLength: 4)

            Toggle(isOn: Binding(
                get: { store.includeSourceSubfolders },
                set: { store.setIncludeSourceSubfolders($0) }
            )) {
                Text(L10n.tr("Include Subfolders"))
                    .lineLimit(1)
            }
            .toggleStyle(.checkbox)
            .help(L10n.tr("Scan media in nested folders"))
        }
    }

    private var sourceSummary: String {
        if let sourceSelectionURL = store.sourceSelectionURL {
            return "\(store.sourceURL?.lastPathComponent ?? L10n.tr("Source")) -> \(sourceSelectionURL.lastPathComponent)"
        }
        return store.sourceURL?.lastPathComponent ?? L10n.tr("Not selected")
    }

    private var targetSummary: String {
        if let targetSelectionURL = store.targetSelectionURL {
            return "\(store.targetURL?.lastPathComponent ?? L10n.tr("Target")) -> \(targetSelectionURL.lastPathComponent)"
        }
        return store.targetURL?.lastPathComponent ?? L10n.tr("Not selected")
    }

    private var filtersSummary: String {
        let rating = "\(L10n.tr("Rating")) \(store.filterState.minimumRating)"
        let pick = store.filterState.pickState?.displayName ?? L10n.tr("Any Pick")
        let color = store.filterState.colorLabel?.displayName ?? L10n.tr("Any Color")
        return "\(rating) · \(pick) · \(color)"
    }

    private func sectionBinding(_ keyPath: WritableKeyPath<PanelLayout, Bool?>, automatic: Bool) -> Binding<Bool> {
        Binding(
            get: { store.panelLayout[keyPath: keyPath] ?? automatic },
            set: { isExpanded in
                store.panelLayout[keyPath: keyPath] = isExpanded
                store.saveWorkspace()
            }
        )
    }

    private func automaticExpanded(for section: SidebarSectionKind, height: CGFloat) -> Bool {
        switch section {
        case .source, .target:
            height >= 560
        case .filters:
            height >= 760
        }
    }

    private var sourceFolderBrowserHeight: CGFloat {
        sourceDraftBrowserHeight ?? CGFloat(store.panelLayout.sourceFolderBrowserHeight ?? defaultFolderBrowserHeight)
    }

    private var targetFolderBrowserHeight: CGFloat {
        targetDraftBrowserHeight ?? CGFloat(store.panelLayout.targetFolderBrowserHeight ?? defaultFolderBrowserHeight)
    }

    private var defaultFolderBrowserHeight: Double {
        112
    }

    private func setSourceFolderBrowserHeight(_ height: CGFloat) {
        store.panelLayout.sourceFolderBrowserHeight = Double(clampedFolderBrowserHeight(height))
        store.saveWorkspace()
    }

    private func setTargetFolderBrowserHeight(_ height: CGFloat) {
        store.panelLayout.targetFolderBrowserHeight = Double(clampedFolderBrowserHeight(height))
        store.saveWorkspace()
    }

    private func clampedFolderBrowserHeight(_ height: CGFloat) -> CGFloat {
        min(max(height, 76), 220)
    }

    private func effectiveScale(for height: CGFloat) -> FolderBrowserScale {
        return store.panelLayout.folderBrowserScale
    }
}

private enum SidebarSectionKind {
    case source
    case target
    case filters
}

private struct SidebarDisclosureSection<Content: View>: View {
    let title: String
    let summary: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12, height: 18)

                    SidebarHeader(title: title, summary: summary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.top, 1)
            }
        }
    }
}

private struct SidebarHeader: View {
    let title: String
    let summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FolderBrowserResizeHandle: View {
    @Binding var height: CGFloat
    var onCommit: () -> Void = {}
    @State private var dragStartHeight: CGFloat?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(height: 8)

            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 42, height: 3)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let startHeight = dragStartHeight ?? height
                    dragStartHeight = startHeight
                    height = startHeight + value.translation.height
                }
                .onEnded { _ in
                    dragStartHeight = nil
                    onCommit()
                }
        )
        .help(L10n.tr("Drag to resize the folder browser"))
    }
}

private struct FolderRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
