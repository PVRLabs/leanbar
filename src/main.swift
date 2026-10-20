import AppKit

struct Row {
    var text: String
    var fields: [String: String]
}
struct MenuCommand {
    let title: String
    let argv: [String]
}
enum Invalid: Error { case format(String) }

// Deliberately small quoting grammar: whitespace, single/double quotes, backslash.
func tokens(_ value: String) throws -> [String] {
    var result = [String](), word = "", quote: Character?, escape = false
    for c in value {
        if escape { word.append(c); escape = false }
        else if c == "\\" { escape = true }
        else if let q = quote { if c == q { quote = nil } else { word.append(c) } }
        else if c == "\"" || c == "'" { quote = c }
        else if c.isWhitespace { if !word.isEmpty { result.append(word); word = "" } }
        else { word.append(c) }
    }
    guard quote == nil && !escape else { throw Invalid.format("Unclosed quote") }
    if !word.isEmpty { result.append(word) }
    return result
}
func parse(_ text: String) throws -> [Row] {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard lines.count > 2, lines[1] == "---" else { throw Invalid.format("Expected header and separator") }
    return try lines.dropFirst(2).filter { !$0.isEmpty }.map { line in
        let parts = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        var fields = [String: String]()
        if parts.count == 2 {
            for token in try tokens(String(parts[1])) {
                let pair = token.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard pair.count == 2 else { throw Invalid.format("Invalid field") }
                let key = String(pair[0])
                if key.hasPrefix("param") {
                    guard let index = Int(key.dropFirst(5)), index > 0, key == "param\(index)" else {
                        throw Invalid.format("Invalid parameter key: \(key)")
                    }
                } else {
                    guard ["bash", "shell", "terminal", "refresh", "color", "size"].contains(key) else {
                        throw Invalid.format("Unsupported field: \(key)")
                    }
                }
                guard fields[key] == nil else { throw Invalid.format("Duplicate field") }
                fields[key] = String(pair[1])
            }
        }
        if fields["bash"] != nil || fields["shell"] != nil {
            guard fields["terminal"] == "false", !(fields["bash"] != nil && fields["shell"] != nil),
                  (fields["bash"] ?? fields["shell"]!).hasPrefix("/") else {
                throw Invalid.format("Unsupported executable semantics")
            }
            let indexes = fields.keys.filter { $0.hasPrefix("param") }.compactMap { Int($0.dropFirst(5)) }.sorted()
            guard indexes.isEmpty || indexes == Array(1...indexes.count) else { throw Invalid.format("Noncontiguous argv") }
        }
        return Row(text: parts[0].trimmingCharacters(in: .whitespaces), fields: fields)
    }
}

final class Host: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    var rows = [Row](), busy = false, opened = false, pending = false
    var message = "Preparing…"
    var actions = [MenuCommand](), refreshPending = false
    var activeCommand: MenuCommand?
    var queueNotice: String?
    let maximumQueuedActions = 16
    var stateItem: NSMenuItem?
    var timer: Timer?
    let producer: String, helper: String, interval: Double
    init(producer: String, helper: String, interval: Double) {
        self.producer = producer; self.helper = helper; self.interval = interval
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        item.button?.title = "LB"
        menu.autoenablesItems = false
        menu.delegate = self; item.menu = menu
        render(); refresh()
        if interval > 0 { timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() } }
    }
    func menuWillOpen(_ menu: NSMenu) { opened = true; refresh() }
    func menuDidClose(_ menu: NSMenu) {
        opened = false
        if pending { render() }
    }
    func updateState() {
        guard let state = stateItem else { return }
        if let notice = queueNotice {
            state.title = notice
        } else if !actions.isEmpty {
            state.title = "Action queued (\(actions.count))"
        } else if let command = activeCommand {
            state.title = "Running \(command.title)…"
        } else { state.title = message }
        state.isHidden = state.title.isEmpty
        state.action = nil
        state.target = self
        state.isEnabled = false
        for entry in menu.items {
            guard let command = entry.representedObject as? MenuCommand else { continue }
            let suffix: String
            if activeCommand?.argv == command.argv { suffix = " (running…)" }
            else if actions.contains(where: { $0.argv == command.argv }) { suffix = " (queued)" }
            else { suffix = "" }
            let title = command.title + suffix
            let styled = entry.attributedTitle
            let attributes = (styled?.length ?? 0) > 0 ? styled?.attributes(at: 0, effectiveRange: nil) : nil
            entry.title = title
            if let attributes = attributes {
                entry.attributedTitle = NSAttributedString(string: title, attributes: attributes)
            }
            entry.isEnabled = suffix.isEmpty && entry.action != nil
        }
        // Update existing item properties only while tracking, never menu structure.
    }
    func render() {
        guard !opened else { pending = true; updateState(); return }
        pending = false; menu.removeAllItems()
        let state = NSMenuItem(title: message, action: nil, keyEquivalent: "")
        stateItem = state; menu.addItem(state)
        for row in rows {
            if row.text == "---" { menu.addItem(.separator()); continue }
            let executable = row.fields["bash"] ?? row.fields["shell"]
            let entry = NSMenuItem(title: row.text, action: executable != nil ? #selector(action(_:)) : nil, keyEquivalent: "")
            entry.target = self
            entry.isEnabled = executable != nil
            if let executable = executable {
                let count = row.fields.keys.filter { $0.hasPrefix("param") }.count
                let args = count == 0 ? [] : (1...count).map { row.fields["param\($0)"]! }
                entry.representedObject = MenuCommand(title: row.text, argv: [executable] + args)
            }
            var attributes = [NSAttributedString.Key: Any]()
            if let size = Double(row.fields["size"] ?? ""), size.isFinite {
                attributes[.font] = NSFont.systemFont(ofSize: min(24, max(9, size)))
            }
            if let name = row.fields["color"] { attributes[.foregroundColor] = color(name) }
            if !attributes.isEmpty {
                entry.attributedTitle = NSAttributedString(string: row.text, attributes: attributes)
            }
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        let about = NSMenuItem(title: "About LeanBar…", action: #selector(aboutHost), keyEquivalent: "")
        about.target = self; menu.addItem(about)
        let quit = NSMenuItem(title: "Quit LeanBar", action: #selector(quitHost), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        updateState()
    }
    func color(_ name: String?) -> NSColor {
        switch name { case "orange": return .systemOrange; case "gray": return .systemGray
        case "red": return .systemRed; case "green": return .systemGreen; case "blue": return .systemBlue
        default: return .labelColor }
    }
    @objc func quitHost() { NSApp.terminate(nil) }
    @objc func aboutHost() {
        NSWorkspace.shared.open(URL(string: "https://github.com/PVRLabs/leanbar")!)
    }
    func refresh() {
        refreshPending = true
        drain()
    }
    @objc func action(_ sender: NSMenuItem) {
        guard let command = sender.representedObject as? MenuCommand else { return }
        guard activeCommand?.argv != command.argv && !actions.contains(where: { $0.argv == command.argv }) else {
            updateState(); return
        }
        guard actions.count < maximumQueuedActions else {
            queueNotice = "Action queue full — try again after pending actions finish"
            updateState(); return
        }
        queueNotice = nil
        actions.append(command)
        drain()
    }
    func drain() {
        guard !busy else { updateState(); return }
        if !actions.isEmpty {
            let command = actions.removeFirst()
            activeCommand = command
            invoke(command.argv, producerResult: false)
        } else if refreshPending {
            refreshPending = false
            activeCommand = nil
            invoke([producer], producerResult: true)
        } else { activeCommand = nil; updateState() }
    }
    private func invoke(_ argv: [String], producerResult: Bool) {
        busy = true; updateState()
        DispatchQueue.global(qos: .utility).async {
            let p = Process(), pipe = Pipe()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            p.arguments = [self.helper] + argv; p.standardOutput = pipe
            var result: [String: Any] = [:]
            do {
                try p.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
                result = (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            } catch { result = ["error": String(describing: error)] }
            let completed = result
            // Common modes deliver completion even during AppKit menu tracking.
            RunLoop.main.perform(inModes: [.common]) {
                self.busy = false
                self.activeCommand = nil
                self.queueNotice = nil
                if !producerResult { self.refreshPending = true }
                do {
                    guard completed["error"] is NSNull, completed["status"] as? Int == 0 else {
                        throw Invalid.format("\(completed["error"] ?? "helper failed"): \(completed["stderr"] ?? "")")
                    }
                    if producerResult {
                        self.rows = try parse(completed["stdout"] as? String ?? "")
                        self.message = ""
                    } else { self.refreshPending = true }
                } catch {
                    self.rows = []; self.message = "Failed: \(error)"
                    // Existing visible rows must not remain enabled on a failed snapshot.
                    if self.opened {
                        for entry in self.menu.items where entry.representedObject is MenuCommand {
                            entry.action = nil
                            entry.isEnabled = false
                        }
                    }
                }
                self.render()
                self.drain()
            }
        }
    }
}
let args = CommandLine.arguments
if args.count == 2 && args[1] == "--check" {
    do {
        let text = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let rows = try parse(text)
        print("Parsed \(rows.count) rows; \(rows.filter { $0.fields["bash"] != nil || $0.fields["shell"] != nil }.count) actions")
        exit(0)
    } catch { fputs("\(error)\n", stderr); exit(1) }
}
guard (2...3).contains(args.count),
      let interval = Double(args.count == 3 ? args[2] : "0"), interval.isFinite, interval >= 0,
      args[1].hasPrefix("/"), FileManager.default.isExecutableFile(atPath: args[1]),
      let helper = Bundle.main.path(forResource: "invoke", ofType: "py") else {
    fputs("usage: LeanBar /absolute/path/to/producer [INTERVAL_SECONDS]\nRun the executable inside the built LeanBar.app; interval defaults to 0.\n", stderr); exit(2)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let host = Host(producer: args[1], helper: helper, interval: interval)
app.delegate = host
app.run()
