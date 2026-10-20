// Appended to the actual Host source by ui-smoke.py; never compiled into LeanBar.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let args = CommandLine.arguments
let host = Host(producer: args[1], helper: args[2], interval: 0)
app.delegate = host
let fixtureDirectory = URL(fileURLWithPath: args[1]).deletingLastPathComponent()
var phase = 0, cycles = 0
let started = Date()
func require(_ condition: Bool, _ name: String) {
    if !condition { fputs("FAIL: \(name)\n", stderr); exit(1) }
    print("PASS: \(name)")
}
func sample(_ label: String) {
    let p = Process(), pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: "/bin/ps")
    p.arguments = ["-o", "pid=,rss=,time=", "-p", String(ProcessInfo.processInfo.processIdentifier)]
    p.standardOutput = pipe
    do {
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        print("SAMPLE \(label): \(String(data: data, encoding: .utf8) ?? "")")
    } catch { print("Sample unavailable: \(error)") }
}
let poll = Timer(timeInterval: 0.2, repeats: true) { _ in
    if Date().timeIntervalSince(started) > 30 { fputs("Harness timeout\n", stderr); exit(1) }
    guard !host.busy else { return }
    switch phase {
    case 0:
        guard host.rows.count == 2 else { return }
        require(host.rows[0].text == "Waiting for action", "fixture rendered")
        guard let index = host.menu.items.firstIndex(where: { $0.title == "Record argv" }) else {
            require(false, "action exists"); return
        }
        phase = 1
        host.menu.performActionForItem(at: index)
    case 1:
        guard host.rows.first?.text == "Action recorded" else { return }
        require(true, "NSMenu action dispatched and producer refreshed")
        sample("before cycles")
        phase = 2
    case 2:
        phase = 3 // Prevent reentry during menu tracking.
        let close = Timer(timeInterval: 0.1, repeats: false) { _ in host.menu.cancelTracking() }
        RunLoop.main.add(close, forMode: .eventTracking)
        RunLoop.main.add(close, forMode: .common)
        host.item.button?.performClick(nil)
        require(!host.opened, "menu closed safely")
        cycles += 1
        phase = cycles < 12 ? 2 : 4
    case 4:
        require(host.rows.first?.text == "Action recorded", "snapshot preserved after 12 cycles")
        sample("after cycles")
        try! Data().write(to: fixtureDirectory.appendingPathComponent("fail"))
        phase = 5; host.refresh()
    case 5:
        guard host.message.hasPrefix("Failed:") else { return }
        require(host.rows.isEmpty, "producer failure removes old actions")
        try! FileManager.default.removeItem(at: fixtureDirectory.appendingPathComponent("fail"))
        phase = 6; host.refresh()
    case 6:
        require(host.rows.first?.text == "Action recorded", "producer recovers after failure")
        sample("recovered")
        print("Completed 12 actual menu open/close cycles; fixture argv verified by Python driver")
        app.terminate(nil)
    default: break
    }
}
RunLoop.main.add(poll, forMode: .common)
app.run()
