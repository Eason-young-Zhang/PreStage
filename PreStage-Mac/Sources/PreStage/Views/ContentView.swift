import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isShowingCopySettings = false

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                SourceTargetSidebar()
                    .frame(
                        minWidth: PanelLayout.minimumSidebarWidth,
                        idealWidth: store.panelLayout.sidebarWidth,
                        maxWidth: PanelLayout.maximumSidebarWidth
                    )
                    .clipped()

                MainBrowserView()
                    .frame(minWidth: 680)
                    .layoutPriority(1)
            }
            .toolbar {
                ToolbarItem(id: "copy-share") {
                    HStack(spacing: 10) {
                        ToolbarCapsuleButton(
                            title: L10n.tr("Copy"),
                            systemImage: "doc.on.doc",
                            shortcut: "⌘C",
                            isDisabled: store.targetURL == nil || store.selectedItems.isEmpty,
                            action: store.startCopySelected
                        )

                        Button {
                            isShowingCopySettings.toggle()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 30, height: 30)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .stroke(.separator.opacity(0.35), lineWidth: 0.5)
                                }
                        }
                        .buttonStyle(.plain)
                        .shortcutHelp(L10n.tr("Copy Settings"))
                        .accessibilityLabel(L10n.tr("Copy Settings"))
                        .popover(isPresented: $isShowingCopySettings, arrowEdge: .bottom) {
                            CopySettingsPopover()
                                .environmentObject(store)
                        }

                        ToolbarCapsuleButton(
                            title: L10n.tr("Share"),
                            systemImage: "square.and.arrow.up",
                            shortcut: nil,
                            isDisabled: store.selectedItems.isEmpty,
                            action: store.shareSelectedItems
                        )
                    }
                    .frame(height: 38, alignment: .center)
                    .padding(.horizontal, 4)
                    .background(.quaternary.opacity(0.18), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.separator.opacity(0.32), lineWidth: 0.5)
                    }
                    .fixedSize()
                }

                ToolbarItem(id: "actions") {
                    Menu {
                        Button(L10n.tr("Open")) { store.openSelectedItems() }
                            .disabled(store.selectedItems.isEmpty)
                        Button(L10n.tr("Reveal in Finder")) { store.revealSelectedInFinder() }
                            .disabled(store.selectedItems.isEmpty)
                        Button(L10n.tr("Copy Log")) { store.isShowingCopyLog = true }
                        Button(L10n.tr("Batch Rename Log")) { store.isShowingBatchRenameLog = true }
                        Divider()
                        Button(L10n.tr("Rotate Left")) { store.rotateFocusedItem(clockwise: false) }
                            .disabled(store.selectedItems.isEmpty)
                        Button(L10n.tr("Rotate Right")) { store.rotateFocusedItem(clockwise: true) }
                            .disabled(store.selectedItems.isEmpty)
                        Button(L10n.tr("Flip Horizontal")) { store.flipFocusedItem(horizontal: true) }
                            .disabled(store.selectedItems.isEmpty)
                        Button(L10n.tr("Flip Vertical")) { store.flipFocusedItem(horizontal: false) }
                            .disabled(store.selectedItems.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: Circle())
                    }
                    .shortcutHelp(L10n.tr("More"))
                }

                ToolbarItem(placement: .primaryAction) {
                    TextField(L10n.tr("Search"), text: $store.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            }

            StatusBarView()
                .frame(height: 28)
        }
        .sheet(isPresented: $store.isShowingCopyLog) {
            CopyLogView()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.isShowingBatchRenameLog) {
            BatchRenameLogView()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.isShowingBatchRename) {
            BatchRenameView()
                .environmentObject(store)
        }
        .background {
            BrowserShortcutHandler()
                .environmentObject(store)
            WindowLiveResizeObserver { isLiveResizing in
                store.isWindowLiveResizing = isLiveResizing
            }
        }
    }
}

private struct WindowLiveResizeObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ResizeObserverView {
        let view = ResizeObserverView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: ResizeObserverView, context: Context) {
        nsView.onChange = onChange
        nsView.attachIfPossible()
    }

    final class ResizeObserverView: NSView {
        var onChange: ((Bool) -> Void)?
        private weak var observedWindow: NSWindow?
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attachIfPossible()
        }

        func attachIfPossible() {
            guard observedWindow !== window else { return }
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            observedWindow = window
            guard let window else { return }

            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.willStartLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onChange?(true)
            })
            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didEndLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onChange?(false)
            })
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }
}

private struct CopySettingsPopover: View {
    @EnvironmentObject private var store: AppStore

    private var summary: String {
        [
            store.copyRule.displayName,
            store.copyConflictPolicy.displayName,
            store.copyContentMode.displayName,
            store.copyVerificationMode.displayName
        ].joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                Text(L10n.tr("Copy Settings"))
                    .font(.headline)
            }

            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    Text(L10n.tr("Copy Rule"))
                        .foregroundStyle(.secondary)
                    Picker(L10n.tr("Copy Rule"), selection: $store.copyRule) {
                        ForEach(CopyOrganizationRule.allCases) { rule in
                            Text(rule.displayName).tag(rule)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
                GridRow {
                    Text(L10n.tr("Conflict"))
                        .foregroundStyle(.secondary)
                    Picker(L10n.tr("Conflict"), selection: $store.copyConflictPolicy) {
                        ForEach(CopyConflictPolicy.allCases) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
                GridRow {
                    Text(L10n.tr("Copy Content"))
                        .foregroundStyle(.secondary)
                    Picker(L10n.tr("Copy Content"), selection: $store.copyContentMode) {
                        ForEach(CopyContentMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
                GridRow {
                    Text(L10n.tr("Verify Copy"))
                        .foregroundStyle(.secondary)
                    Picker(L10n.tr("Verify Copy"), selection: $store.copyVerificationMode) {
                        ForEach(CopyVerificationMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }
            .onChange(of: store.copyRule) { store.saveWorkspace() }
            .onChange(of: store.copyConflictPolicy) { store.saveWorkspace() }
            .onChange(of: store.copyContentMode) { store.saveWorkspace() }
            .onChange(of: store.copyVerificationMode) { store.saveWorkspace() }
        }
        .padding(16)
        .frame(width: 330)
    }
}

private struct ToolbarCapsuleButton: View {
    let title: String
    let systemImage: String
    let shortcut: String?
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .frame(height: 30, alignment: .center)
            .padding(.horizontal, 13)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(.separator.opacity(0.35), lineWidth: 0.5)
            }
            .opacity(isDisabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .shortcutHelp(title, shortcut: shortcut)
    }
}
