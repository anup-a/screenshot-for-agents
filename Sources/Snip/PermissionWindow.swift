import AppKit
import SnipKit

/// First-run setup. One click opens the Screen Recording settings, then a small panel docks under the
/// System Settings window with Snip's icon to drag into the list. Snip relaunches itself once access is granted.
final class PermissionWindow: NSWindow {
    private static var shared: PermissionWindow?

    /// `--onboarding` replays setup even when access is already granted, for demos and testing.
    static let previewing = CommandLine.arguments.contains("--onboarding")

    static func show() {
        let window = shared ?? PermissionWindow()
        shared = window
        window.present(ready: CGPreflightScreenCaptureAccess() && !previewing)
    }

    /// Shown after the relaunch that follows setup, so the user knows it worked.
    static func showReady() {
        let window = shared ?? PermissionWindow()
        shared = window
        window.present(ready: true)
    }

    private let iconView = NSImageView()
    private let heading = NSTextField(labelWithString: "")
    private let body = NSTextField(wrappingLabelWithString: "")
    private let primaryButton = NSButton(title: "", target: nil, action: nil)
    private let secondaryButton = NSButton(title: "", target: nil, action: nil)
    private var helper: DragHelperPanel?

    private init() {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled, .closable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isReleasedWhenClosed = false
        level = .floating

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        heading.font = .systemFont(ofSize: 18, weight: .semibold)
        heading.alignment = .center
        body.textColor = .secondaryLabelColor
        body.alignment = .center

        primaryButton.bezelStyle = .rounded
        primaryButton.controlSize = .large
        primaryButton.keyEquivalent = "\r"
        primaryButton.target = self
        secondaryButton.isBordered = false
        secondaryButton.contentTintColor = .secondaryLabelColor
        secondaryButton.target = self

        let root = NSStackView(views: [iconView, heading, body, primaryButton, secondaryButton])
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = 10
        root.setCustomSpacing(14, after: iconView)
        root.setCustomSpacing(22, after: body)
        root.setCustomSpacing(6, after: primaryButton)
        root.edgeInsets = NSEdgeInsets(top: 34, left: 32, bottom: 18, right: 32)
        root.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: 400),
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72),
            body.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -64),
            primaryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
        ])
        contentView = content
    }

    private func present(ready: Bool) {
        if ready {
            iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 60, weight: .regular).applying(.init(paletteColors: [.white, .systemGreen])))
            heading.stringValue = "Snip is ready"
            body.stringValue = "Press ⌘⇧A anytime to take a screenshot, capture a whole scrolling page, or record your screen."
            primaryButton.title = "Take a Screenshot"
            primaryButton.action = #selector(takeScreenshot)
            secondaryButton.title = "Done"
            secondaryButton.action = #selector(finish)
        } else {
            iconView.image = NSApp.applicationIconImage
            heading.stringValue = "Let Snip see your screen"
            body.stringValue = "macOS asks you to allow Screen Recording for any app that takes screenshots. Snip only looks at your screen when you press ⌘⇧A."
            primaryButton.title = "Allow Screen Recording"
            primaryButton.action = #selector(allow)
            secondaryButton.title = "Not Now"
            secondaryButton.action = #selector(finish)
        }
        NSApp.activate(ignoringOtherApps: true)
        center()
        makeKeyAndOrderFront(nil)
    }

    @objc private func allow() {
        orderOut(nil)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
        helper?.dismiss()
        helper = DragHelperPanel(
            onGranted: { [weak self] in self?.relaunchReady() },
            onSettingsClosed: { [weak self] in
                self?.helper = nil
                self?.present(ready: false)
            })
    }

    /// macOS only applies Screen Recording to a fresh process, so restart and say hello on the other side.
    private func relaunchReady() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = ["--setup-done"]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    @objc private func takeScreenshot() {
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            (NSApp.delegate as? AppDelegate)?.capture()
        }
    }

    @objc private func finish() { close() }
}

/// A small panel that sticks to the bottom of the System Settings window. Its app icon drags into the
/// Screen Recording list, which adds Snip and turns it on in one move.
private final class DragHelperPanel: NSPanel {
    private let onGranted: () -> Void
    private let onSettingsClosed: () -> Void
    private let iconView = DraggableAppIcon()
    private let checkView = NSImageView()
    private let headline = NSTextField(labelWithString: "Drag Snip into the list above")
    private let detail = NSTextField(labelWithString: "Already listed? Just turn on its switch.")
    private let arrow = NSImageView()
    private var timer: Timer?
    private var sawSettings = false
    private var startedAt = Date()
    private var granted = false

    init(onGranted: @escaping () -> Void, onSettingsClosed: @escaping () -> Void) {
        self.onGranted = onGranted
        self.onSettingsClosed = onSettingsClosed
        super.init(contentRect: CGRect(x: 0, y: 0, width: 360, height: 76), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false

        let background = NSVisualEffectView()
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true

        headline.font = .systemFont(ofSize: 13, weight: .semibold)
        detail.font = .systemFont(ofSize: 11.5)
        detail.textColor = .secondaryLabelColor
        let text = NSStackView(views: [headline, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        checkView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 40, weight: .regular).applying(.init(paletteColors: [.white, .systemGreen])))
        checkView.isHidden = true

        arrow.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 18, weight: .semibold))
        arrow.contentTintColor = accentBlue
        arrow.wantsLayer = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [iconView, checkView, text, spacer, arrow])
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 18)
        row.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            checkView.widthAnchor.constraint(equalToConstant: 48),
            checkView.heightAnchor.constraint(equalToConstant: 48),
        ])
        contentView = background

        alphaValue = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
    }

    func dismiss() {
        timer?.invalidate()
        timer = nil
        orderOut(nil)
    }

    private func tick() {
        if granted { return }
        if CGPreflightScreenCaptureAccess() && !PermissionWindow.previewing {
            showGranted()
            return
        }
        guard let settings = Self.settingsWindowFrame() else {
            orderOut(nil)
            // System Settings takes a moment to open; only treat it as closed once we've seen it.
            if sawSettings || Date().timeIntervalSince(startedAt) > 8 {
                dismiss()
                onSettingsClosed()
            }
            return
        }
        sawSettings = true
        setFrameOrigin(origin(docking: settings))
        if !isVisible {
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.2; animator().alphaValue = 1 }
            startArrowBob()
        }
    }

    private func showGranted() {
        granted = true
        iconView.isHidden = true
        checkView.isHidden = false
        arrow.isHidden = true
        headline.stringValue = "Screen Recording is on"
        detail.stringValue = "Restarting Snip…"
        if !isVisible, let settings = Self.settingsWindowFrame() {
            setFrameOrigin(origin(docking: settings))
            alphaValue = 1
            orderFrontRegardless()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.dismiss()
            self?.onGranted()
        }
    }

    /// Below the Settings window if there's room, otherwise beside it, otherwise over its bottom edge.
    private func origin(docking settings: CGRect) -> CGPoint {
        let size = frame.size
        let screen = NSScreen.screens.first { $0.frame.intersects(settings) }?.visibleFrame ?? settings
        let below = CGPoint(x: settings.midX - size.width / 2, y: settings.minY - size.height - 10)
        if below.y >= screen.minY { return below }
        let right = CGPoint(x: settings.maxX + 10, y: settings.minY + 20)
        if right.x + size.width <= screen.maxX { return right }
        let left = CGPoint(x: settings.minX - size.width - 10, y: settings.minY + 20)
        if left.x >= screen.minX { return left }
        return CGPoint(x: settings.midX - size.width / 2, y: settings.minY + 16)
    }

    private func startArrowBob() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let layer = arrow.layer else { return }
        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue = 0
        bob.toValue = 4
        bob.duration = 0.6
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(bob, forKey: "bob")
    }

    /// The frontmost System Settings window, in Cocoa coordinates. Bounds and owner need no permission.
    private static func settingsWindowFrame() -> CGRect? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let mainHeight = NSScreen.screens.first?.frame.height else { return nil }
        for info in windows {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.systempreferences",
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict),
                  bounds.width > 300, bounds.height > 200 else { continue }
            return CGRect(x: bounds.minX, y: mainHeight - bounds.maxY, width: bounds.width, height: bounds.height)
        }
        return nil
    }
}

/// Snip's app icon, draggable as the app bundle so System Settings accepts it as a drop.
private final class DraggableAppIcon: NSView, NSDraggingSource {
    private let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        toolTip = "Drag into the Screen Recording list"
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) { icon.draw(in: bounds) }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func mouseDown(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: Bundle.main.bundleURL as NSURL)
        item.setDraggingFrame(bounds, contents: icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .generic, .link] : []
    }
}
