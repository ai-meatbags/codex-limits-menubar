import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var snapshotLoader: SnapshotLoader?
    private let refreshQueue = DispatchQueue(label: "local.codex.limits.refresh", qos: .utility)
    private var lastSnapshot: MenubarSnapshot?
    private var lastSuccessfulSnapshot: MenubarSnapshot?
    private var lastRefreshError: String?
    private var isRefreshing = false
    private var logFilePath = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            snapshotLoader = try SnapshotLoader()
            logFilePath = snapshotLoader?.logFilePath ?? ""
        } catch {
            snapshotLoader = nil
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItemButton()
        let initialSnapshot = startupSnapshot()
        apply(snapshot: initialSnapshot, isRefreshing: true)
        requestRefresh()

        let pollSeconds = snapshotLoader?.pollSeconds ?? 60
        timer = Timer.scheduledTimer(
            timeInterval: pollSeconds,
            target: self,
            selector: #selector(refreshSnapshot(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    @objc func refreshSnapshot(_ sender: Any?) {
        requestRefresh()
    }

    @objc func openUsagePage(_ sender: Any?) {
        guard let url = URL(string: "https://chatgpt.com/codex/settings/usage") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc func openLogs(_ sender: Any?) {
        guard !logFilePath.isEmpty else {
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: logFilePath))
    }

    @objc func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    private func buildMenu(snapshot: MenubarSnapshot, isRefreshing: Bool) -> NSMenu {
        let menu = NSMenu(title: "Codex Limits")
        menu.addItem(disabledItem(snapshot.accountLabel))

        if snapshot.ok {
            if let usageBarsItem = MenuPreviewFactory.usageBarsItem(snapshot: snapshot) {
                menu.addItem(usageBarsItem)
            }
        } else {
            menu.addItem(.separator())
            menu.addItem(disabledItem(snapshot.errorMessage ?? "Unknown error"))
        }

        if snapshot.ok || lastRefreshError != nil || isRefreshing {
            menu.addItem(.separator())
        }
        if let lastRefreshError, snapshot.ok {
            menu.addItem(disabledItem("Last refresh failed: \(lastRefreshError)"))
        }
        if isRefreshing {
            menu.addItem(disabledItem("Refreshing…"))
        }
        menu.addItem(.separator())
        menu.addItem(actionItem(isRefreshing ? "Refresh in progress…" : "Refresh now", action: #selector(refreshSnapshot(_:)), enabled: !isRefreshing))
        menu.addItem(actionItem("Open usage page", action: #selector(openUsagePage(_:))))
        menu.addItem(actionItem("Open logs", action: #selector(openLogs(_:)), enabled: !logFilePath.isEmpty))
        menu.addItem(actionItem("Quit", action: #selector(quit(_:))))
        return menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, action: Selector, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        return item
    }

    private func requestRefresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        apply(snapshot: lastSnapshot ?? startupSnapshot(), isRefreshing: true)

        refreshQueue.async { [weak self] in
            guard let self else {
                return
            }

            let snapshot = self.snapshotLoader?.load() ?? self.fallbackSnapshot()
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.handleRefreshResult(snapshot)
            }
        }
    }

    private func apply(snapshot: MenubarSnapshot, isRefreshing: Bool) {
        if snapshot.ok {
            lastSuccessfulSnapshot = snapshot
        }
        lastSnapshot = snapshot
        statusItem?.button?.title = snapshot.title
        statusItem?.menu = buildMenu(snapshot: snapshot, isRefreshing: isRefreshing)
    }

    private func configureStatusItemButton() {
        guard let button = statusItem?.button else {
            return
        }

        button.image = statusItemImage()
        button.imagePosition = .imageLeading
    }

    private func statusItemImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Limits")
        image?.isTemplate = true
        return image
    }

    private func handleRefreshResult(_ snapshot: MenubarSnapshot) {
        if snapshot.ok {
            lastRefreshError = nil
            apply(snapshot: snapshot, isRefreshing: false)
            return
        }

        lastRefreshError = snapshot.errorMessage
        apply(snapshot: lastSuccessfulSnapshot ?? snapshot, isRefreshing: false)
    }

    private func startupSnapshot() -> MenubarSnapshot {
        MenubarSnapshot(
            ok: false,
            title: "…",
            subtitle: "Refreshing limits",
            errorMessage: nil,
            accountLabel: "Loading Codex limits",
            buckets: [],
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func fallbackSnapshot() -> MenubarSnapshot {
        MenubarSnapshot(
            ok: false,
            title: "—",
            subtitle: "Codex limits unavailable",
            errorMessage: "Swift app failed to initialize snapshot loader",
            accountLabel: "Check bundled runtime config",
            buckets: [],
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
