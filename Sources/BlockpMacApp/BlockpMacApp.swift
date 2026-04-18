import AppKit
import SwiftUI
import BlockpMacCore

@main
final class BlockpMacAppMain: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var stateModel: AppStateModel?

    static func main() {
        let app = NSApplication.shared
        let delegate = BlockpMacAppMain()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager: CoreManager
        do {
            let store = try StateStore.defaultStore()
            manager = CoreManager(store: store)
        } catch {
            let store = StateStore(stateFilePath: "/tmp/blockpmac-app-state.json")
            manager = CoreManager(store: store)
        }

        let model = AppStateModel(manager: manager)
        stateModel = model

        let rootView = ContentView(stateModel: model)
            .frame(minWidth: 380, minHeight: 520)

        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BlockpMac"
        window.center()
        window.contentViewController = hostingController
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        self.window = window

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(stateModel: model)
                .frame(width: 320, height: 500)
        )
        self.popover = popover

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "shield", accessibilityDescription: "BlockpMac")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        self.statusItem = item

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let popover, let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let stateModel else {
            return .terminateNow
        }

        stateModel.refreshState()

        if stateModel.canTerminateApplication {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Cannot Quit During Active Restriction"
        alert.informativeText = stateModel.terminationBlockedMessage
        alert.addButton(withTitle: "OK")
        alert.runModal()
        return .terminateCancel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let stateModel else {
            return true
        }

        stateModel.refreshState()
        if stateModel.canTerminateApplication {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Cannot Close Window During Active Restriction"
        alert.informativeText = stateModel.terminationBlockedMessage
        alert.addButton(withTitle: "OK")
        alert.runModal()
        return false
    }
}
