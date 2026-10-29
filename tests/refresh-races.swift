// Appended to Host by ui-smoke.py --races; deterministic delegate-state checks
// use only the disposable fixture. Actual menu tracking is checked by ui-smoke.swift.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let args = CommandLine.arguments
let host = Host(producer: args[1], helper: args[2], interval: 0)
app.delegate = host
let directory = URL(fileURLWithPath: args[1]).deletingLastPathComponent()
var phase = 0
var oldItem: NSMenuItem?
let started = Date()
func require(_ condition: Bool, _ name: String) {
    if !condition { fputs("FAIL: \(name)\n", stderr); exit(1) }
    print("PASS: \(name)")
}
func mark(_ name: String) { try! Data().write(to: directory.appendingPathComponent(name)) }
func history() -> [[String]] {
    guard let data = try? Data(contentsOf: directory.appendingPathComponent("history.json")) else { return [] }
    return try! JSONSerialization.jsonObject(with: data) as! [[String]]
}
let expected = ["literal space", "$(printf unsafe)"]
require(captionFromOutput("Ignored header\n---\nStatus") == "LB", "ignored first line keeps default caption")
require(captionFromOutput("title=PVR\n---\nStatus") == "PVR", "custom caption is parsed")
require(captionFromOutput("title=● Café 🚀\n---\nStatus") == "● Café 🚀", "Unicode and emoji caption is parsed")
require(captionFromOutput("title=\n---\nStatus") == "LB", "empty caption uses default")
require(captionFromOutput("title\n---\nStatus") == "LB", "malformed directive keeps default")
require(captionFromOutput("title=Bad\u{0}Title\n---\nStatus") == "LB", "control characters use default")
require(captionFromOutput("title=" + String(repeating: "x", count: 40) + "\n---\nStatus").count == maximumCaptionLength,
        "long caption is bounded")
let poll = Timer(timeInterval: 0.05, repeats: true) { _ in
    if Date().timeIntervalSince(started) > 25 { fputs("Race check timeout at phase \(phase)\n", stderr); exit(1) }
    switch phase {
    case 0:
        guard !host.busy, host.rows.count == 2 else { return }
        require(host.displayedCaption == "LB" && host.item.button?.title == "LB", "default caption is displayed")
        require(host.stateItem!.isHidden, "idle snapshot has no status row")
        oldItem = host.menu.items.first { $0.title == "Record argv" }!
        var label = host.menu.items.first { $0.title == "Waiting for action" }!
        require((label.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor) == .systemGreen,
                "color without size is rendered")
        require(label.attributedTitle?.attribute(.font, at: 0, effectiveRange: nil) == nil,
                "color does not require an explicit font size")
        // Model a batch becoming idle and gaining a "Run now" action while open.
        let originalRows = host.rows
        host.opened = true
        host.rows = try! parse("Fixture\n---\nIdle | color=orange size=17\nRun now | shell=/bin/echo terminal=false\nRecord argv | shell=/bin/echo terminal=false")
        host.render()
        label = host.menu.items[1]
        require(label.title == "Idle", "status updates while open despite action insertion")
        require((label.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor) == .systemOrange,
                "open status color updates")
        require((label.attributedTitle?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 17,
                "open status size updates")
        require(!host.menu.items.contains { $0 === oldItem } && host.menu.items.contains { $0.title == "Run now" },
                "action insertion appears immediately")
        host.rows = try! parse("Fixture\n---\nPlain status\nRecord argv | shell=/bin/echo terminal=false")
        host.render()
        label = host.menu.items[1]
        require(label.title == "Plain status" && label.attributedTitle == nil, "refresh removes old styling")
        host.rows = try! parse("Fixture\n---\nInserted label\nAnother status")
        host.render()
        label = host.menu.items[1]
        require(label.title == "Inserted label", "label insertion appears immediately")
        host.rows = try! parse("Fixture\n---\nNew section\n---\nOther status")
        host.render()
        label = host.menu.items[1]
        require(label.title == "New section" && host.menu.items.contains { $0.isSeparatorItem }, "separator insertion appears immediately")
        host.rows = originalRows
        host.render()
        label = host.menu.items[1]
        require(label.title == "Waiting for action", "matching status recovers before closing")
        host.menuDidClose(host.menu)
        oldItem = host.menu.items.first { $0.title == "Record argv" }!
        // Exercise the queue bound without launching any synthetic commands.
        host.busy = true
        for i in 0..<host.maximumQueuedActions {
            let entry = NSMenuItem()
            entry.representedObject = MenuCommand(title: "Bound \(i)", argv: ["/bin/echo", String(i)])
            host.action(entry)
        }
        let overflow = NSMenuItem()
        overflow.representedObject = MenuCommand(title: "Overflow", argv: ["/bin/echo", "overflow"])
        host.action(overflow)
        require(host.actions.count == host.maximumQueuedActions && host.stateItem!.title.contains("queue full"),
                "unique action queue is bounded with visible overflow feedback")
        host.actions = []; host.busy = false; host.queueNotice = nil
        host.updateState()
        mark("mode"); mark("delay"); mark("action-delay")
        try! FileManager.default.removeItem(at: directory.appendingPathComponent("producer-started"))
        phase = 1
        host.menuWillOpen(host.menu)
    case 1:
        guard host.opened, host.busy,
              FileManager.default.fileExists(atPath: directory.appendingPathComponent("producer-started").path) else { return }
        require(host.stateItem!.isHidden, "background refresh keeps status row hidden")
        phase = 11
        // Dispatch the bound handler without AppKit automatically closing the menu.
        host.action(oldItem!)
        require(host.actions.count == 1, "click queues behind slow on-open refresh")
        require(!host.stateItem!.isHidden && host.stateItem!.title.contains("queued"), "queued feedback appears while tracking")
        host.action(oldItem!)
        require(host.actions.count == 1 && !oldItem!.isEnabled && oldItem!.title.contains("queued"),
                "duplicate queued click suppressed and item marked queued")
        require(host.stateItem!.action == nil && !host.stateItem!.isEnabled,
                "queued progress label cannot show updated menu")
    case 11:
        guard host.activeCommand != nil else { return }
        require(!host.stateItem!.isHidden && host.stateItem!.title.hasPrefix("Running"), "running action with refreshed snapshot")
        require(host.stateItem!.action == nil && !host.stateItem!.isEnabled,
                "running progress label cannot show updated menu")
        host.action(oldItem!)
        require(host.actions.isEmpty && host.menu.items.contains { $0.title == "Different action" },
                "duplicate running click suppressed and item marked running")
        // Another item instance can come from reopening/rebuilding the menu.
        let duplicate = NSMenuItem()
        duplicate.representedObject = oldItem!.representedObject
        host.action(duplicate)
        require(host.actions.isEmpty, "same running argv cannot be resubmitted from another item")
        // A retained sender must still carry its original command.
        phase = 2
    case 2:
        guard !host.busy, host.actions.isEmpty, host.rows.count == 3 else { return }
        require(host.displayedCaption == "🟢 Fixture" && host.item.button?.title == "🟢 Fixture",
                "successful refresh dynamically updates caption")
        require(host.opened, "refresh and queued action complete while menu stays open")
        require(history() == [expected], "queued action executes exactly once with original argv")
        require(host.stateItem!.isHidden, "completed actions hide progress with fresh snapshot visible")
        require(!host.menu.items.contains { $0 === oldItem } && host.menu.items.contains { $0.title == "Different action" }, "latest actions appear while open")
        require(host.stateItem!.action == nil && !host.stateItem!.isEnabled, "snapshot feedback remains informational")
        phase = 3
        host.action(oldItem!)
    case 3:
        guard !host.busy, host.actions.isEmpty else { return }
        require(history() == [expected, expected], "retained item keeps original command after producer reorders rows")
        phase = 4
        host.menuDidClose(host.menu)
    case 4:
        guard !host.opened else { return }
        require(host.menu.items.contains(where: { $0.title == "Different action" }),
                "closing preserves latest snapshot")
        phase = 41
        host.menuWillOpen(host.menu)
    case 41:
        guard host.opened else { return }
        require(!host.menu.items.contains { $0 === oldItem }, "manual reopening shows latest snapshot")
        phase = 5
        mark("fail"); host.refresh()
    case 5:
        guard !host.busy, host.message.hasPrefix("Failed:") else { return }
        require(host.item.button?.title == "🟢 Fixture", "refresh failure preserves last successful caption")
        require(host.rows.isEmpty, "failure clears current snapshot")
        require(!host.stateItem!.isHidden && host.stateItem!.title.hasPrefix("Failed:"), "failure feedback appears while tracking")
        require(host.menu.items.filter { $0.representedObject is MenuCommand }.allSatisfy { !$0.isEnabled && $0.action == nil },
                "failure disables stale visible actions while tracking")
        host.menuDidClose(host.menu)
        require(!host.stateItem!.isHidden && host.stateItem!.title.hasPrefix("Failed:"),
                "failure feedback remains after closing")
        print("PASS: only two intended fixture commands executed; driver verifies exact invocation history")
        app.terminate(nil)
    default: break
    }
}
RunLoop.main.add(poll, forMode: .common)
RunLoop.main.add(poll, forMode: .eventTracking)
app.run()
