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
let poll = Timer(timeInterval: 0.05, repeats: true) { _ in
    if Date().timeIntervalSince(started) > 25 { fputs("Race check timeout at phase \(phase)\n", stderr); exit(1) }
    switch phase {
    case 0:
        guard !host.busy, host.rows.count == 2 else { return }
        require(host.stateItem!.isHidden, "idle snapshot has no status row")
        oldItem = host.menu.items.first { $0.title == "Record argv" }!
        let label = host.menu.items.first { $0.title == "Waiting for action" }!
        require((label.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor) == .systemGreen,
                "color without size is rendered")
        require(label.attributedTitle?.attribute(.font, at: 0, effectiveRange: nil) == nil,
                "color does not require an explicit font size")
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
        require(host.pending && !host.stateItem!.isHidden && host.stateItem!.title.hasPrefix("Running"), "running action with pending snapshot")
        require(host.stateItem!.action == nil && !host.stateItem!.isEnabled,
                "running progress label cannot show updated menu")
        host.action(oldItem!)
        require(host.actions.isEmpty && !oldItem!.isEnabled && oldItem!.title.contains("running"),
                "duplicate running click suppressed and item marked running")
        // Another item instance can come from reopening/rebuilding the menu.
        let duplicate = NSMenuItem()
        duplicate.representedObject = oldItem!.representedObject
        host.action(duplicate)
        require(host.actions.isEmpty, "same running argv cannot be resubmitted from another item")
        // Retain the original entry for the existing snapshot-binding regression.
        phase = 2
    case 2:
        guard !host.busy, host.actions.isEmpty, host.rows.count == 3 else { return }
        require(host.opened, "refresh and queued action complete while menu stays open")
        require(history() == [expected], "queued action executes exactly once with original argv")
        require(host.stateItem!.isHidden, "completed actions hide status while fresh snapshot is pending")
        require(host.menu.items.contains { $0 === oldItem }, "visible snapshot remains stable after row insertion")
        require(host.stateItem!.action == nil && !host.stateItem!.isEnabled, "snapshot feedback remains informational")
        phase = 3
        host.action(oldItem!)
    case 3:
        guard !host.busy, host.actions.isEmpty else { return }
        require(history() == [expected, expected], "old visible item still executes original command after producer reorders rows")
        phase = 4
        host.menuDidClose(host.menu)
    case 4:
        guard !host.opened else { return }
        require(!host.pending && host.menu.items.contains(where: { $0.title == "Different action" }),
                "closing applies latest snapshot")
        phase = 41
        host.menuWillOpen(host.menu)
    case 41:
        guard host.opened else { return }
        require(!host.menu.items.contains { $0 === oldItem }, "manual reopening shows latest snapshot")
        phase = 5
        mark("fail"); host.refresh()
    case 5:
        guard !host.busy, host.message.hasPrefix("Failed:") else { return }
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
