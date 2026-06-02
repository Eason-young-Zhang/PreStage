import AppKit
import Quartz
import SwiftUI

struct NativeMediaPreviewView: NSViewRepresentable {
    let item: MediaItem?
    let previewURL: URL?
    let preloadURL: URL?
    let preloadKey: String?
    let backgroundColor: NSColor

    func makeNSView(context: Context) -> PreviewContainerView {
        PreviewContainerView()
    }

    func updateNSView(_ nsView: PreviewContainerView, context: Context) {
        nsView.previewBackgroundColor = backgroundColor
        nsView.update(with: item, previewURL: previewURL, preloadURL: preloadURL, preloadKey: preloadKey)
    }
}

final class PreviewContainerView: NSView {
    private let firstQuickLookView = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
    private let secondQuickLookView = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
    private var frontQuickLookView: QLPreviewView!
    private var backQuickLookView: QLPreviewView!
    private var currentPreviewKey: String?
    private var backPreviewKey: String?
    private var desiredPreviewKey: String?
    private var transitionGeneration = 0
    private let transitionDelay: TimeInterval = 0.11
    private let transitionDuration: TimeInterval = 0.13
    var previewBackgroundColor: NSColor = .textBackgroundColor {
        didSet { applyBackgroundColor() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(with item: MediaItem?, previewURL: URL?, preloadURL: URL?, preloadKey: String?) {
        guard let item, let previewURL else {
            transitionGeneration += 1
            currentPreviewKey = nil
            backPreviewKey = nil
            desiredPreviewKey = nil
            firstQuickLookView.previewItem = nil
            secondQuickLookView.previewItem = nil
            firstQuickLookView.alphaValue = 0
            secondQuickLookView.alphaValue = 0
            firstQuickLookView.setAccessibilityHidden(true)
            secondQuickLookView.setAccessibilityHidden(true)
            setAccessibilityChildren([])
            return
        }

        let previewKey = "\(item.thumbnailCacheKey)|\(previewURL.path)"
        desiredPreviewKey = previewKey
        guard previewKey != currentPreviewKey else {
            frontQuickLookView.alphaValue = 1
            preload(url: preloadURL, key: preloadKey, excluding: previewKey)
            return
        }

        guard currentPreviewKey != nil else {
            showInitialPreview(url: previewURL, key: previewKey, preloadURL: preloadURL, preloadKey: preloadKey)
            return
        }

        transition(to: previewURL, key: previewKey, preloadURL: preloadURL, preloadKey: preloadKey)
    }

    private func setup() {
        wantsLayer = true
        applyBackgroundColor()

        frontQuickLookView = firstQuickLookView
        backQuickLookView = secondQuickLookView
        configure(firstQuickLookView)
        configure(secondQuickLookView)
        firstQuickLookView.alphaValue = 0
        secondQuickLookView.alphaValue = 0
        firstQuickLookView.setAccessibilityHidden(true)
        secondQuickLookView.setAccessibilityHidden(true)
        setAccessibilityChildren([])

        addSubview(firstQuickLookView)
        addSubview(secondQuickLookView)

        NSLayoutConstraint.activate([
            firstQuickLookView.topAnchor.constraint(equalTo: topAnchor),
            firstQuickLookView.leadingAnchor.constraint(equalTo: leadingAnchor),
            firstQuickLookView.trailingAnchor.constraint(equalTo: trailingAnchor),
            firstQuickLookView.bottomAnchor.constraint(equalTo: bottomAnchor),
            secondQuickLookView.topAnchor.constraint(equalTo: topAnchor),
            secondQuickLookView.leadingAnchor.constraint(equalTo: leadingAnchor),
            secondQuickLookView.trailingAnchor.constraint(equalTo: trailingAnchor),
            secondQuickLookView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configure(_ quickLookView: QLPreviewView) {
        quickLookView.translatesAutoresizingMaskIntoConstraints = false
        quickLookView.autostarts = true
        quickLookView.shouldCloseWithWindow = false
        quickLookView.wantsLayer = true
        quickLookView.layer?.backgroundColor = previewBackgroundColor.cgColor
    }

    private func applyBackgroundColor() {
        wantsLayer = true
        layer?.backgroundColor = previewBackgroundColor.cgColor
        firstQuickLookView.layer?.backgroundColor = previewBackgroundColor.cgColor
        secondQuickLookView.layer?.backgroundColor = previewBackgroundColor.cgColor
    }

    private func transition(to url: URL, key: String, preloadURL: URL?, preloadKey: String?) {
        transitionGeneration += 1
        let generation = transitionGeneration
        let isPreloaded = backPreviewKey == key
        if backPreviewKey != key {
            load(url: url, into: backQuickLookView)
            backPreviewKey = key
        }

        backQuickLookView.alphaValue = 0
        addSubview(backQuickLookView, positioned: .above, relativeTo: frontQuickLookView)

        let delay = isPreloaded ? 0.015 : transitionDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self,
                  generation == self.transitionGeneration,
                  self.desiredPreviewKey == key else {
                return
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = self.transitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.frontQuickLookView.animator().alphaValue = 0
                self.backQuickLookView.animator().alphaValue = 1
            } completionHandler: {
                guard generation == self.transitionGeneration,
                      self.desiredPreviewKey == key else {
                    return
                }
                let oldFront = self.frontQuickLookView
                let oldCurrentKey = self.currentPreviewKey
                self.frontQuickLookView = self.backQuickLookView
                self.backQuickLookView = oldFront
                self.currentPreviewKey = key
                self.backPreviewKey = oldCurrentKey
                self.frontQuickLookView.alphaValue = 1
                self.backQuickLookView.alphaValue = 0
                self.updateAccessibilityVisibility()
                self.preload(url: preloadURL, key: preloadKey, excluding: key)
            }
        }
    }

    private func showInitialPreview(url: URL, key: String, preloadURL: URL?, preloadKey: String?) {
        transitionGeneration += 1
        load(url: url, into: frontQuickLookView)
        currentPreviewKey = key
        frontQuickLookView.alphaValue = 1
        backQuickLookView.alphaValue = 0
        backPreviewKey = nil
        updateAccessibilityVisibility()
        preload(url: preloadURL, key: preloadKey, excluding: key)
    }

    private func preload(url: URL?, key: String?, excluding currentKey: String) {
        guard let url, let key else { return }
        guard key != currentKey, key != backPreviewKey else { return }
        load(url: url, into: backQuickLookView)
        backPreviewKey = key
        backQuickLookView.alphaValue = 0
        backQuickLookView.setAccessibilityHidden(true)
    }

    private func load(url: URL, into quickLookView: QLPreviewView) {
        quickLookView.previewItem = url as NSURL
        quickLookView.refreshPreviewItem()
    }

    private func updateAccessibilityVisibility() {
        frontQuickLookView.setAccessibilityHidden(false)
        backQuickLookView.setAccessibilityHidden(true)
        setAccessibilityChildren([frontQuickLookView as Any])
    }
}
