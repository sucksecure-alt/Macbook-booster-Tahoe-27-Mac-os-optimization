import Foundation

enum Shell {
    @discardableResult
    static func run(_ cmd: String, root: Bool = false) -> (out: String, code: Int32) {
        let p = Process(); let o = Pipe()
        p.standardOutput = o; p.standardError = Pipe()
        if root {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            let esc = cmd.replacingOccurrences(of: "\\", with: "\\\\")
                         .replacingOccurrences(of: "\"", with: "\\\"")
            p.arguments = ["-e", "do shell script \"\(esc)\" with administrator privileges"]
        } else {
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-c", cmd]
        }
        do {
            try p.run(); p.waitUntilExit()
            let d = o.fileHandleForReading.readDataToEndOfFile()
            return (String(data: d, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "", p.terminationStatus)
        } catch { return ("", 1) }
    }
}

enum SystemReader {
    static func metrics() -> SystemMetrics {
        var m = SystemMetrics()

        let cpuOut = Shell.run("ps -A -o %cpu | awk '{s+=$1} END {print s+0}'").out
        let cores = Double(max(1, ProcessInfo.processInfo.activeProcessorCount))
        m.cpu = min(100, (Double(cpuOut) ?? 0) / cores)

        let vs = Shell.run("vm_stat").out
        var pageSize = 16384.0
        if let r = vs.range(of: #"page size of (\d+)"#, options: .regularExpression) {
            let digits = vs[r].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            pageSize = Double(digits) ?? 16384
        }
        func pages(_ label: String) -> Double {
            guard let r = vs.range(of: label + #":\s+(\d+)"#, options: .regularExpression) else { return 0 }
            let digits = vs[r].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Double(digits) ?? 0
        }
        let usedBytes = (pages("Pages active") + pages("Pages wired down")
                         + pages("Pages occupied by compressor")) * pageSize
        let totalBytes = Double(Shell.run("sysctl -n hw.memsize").out) ?? 1
        m.ram = min(100, usedBytes / totalBytes * 100)

        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let v = try? url.resourceValues(forKeys: [
               .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]),
           let avail = v.volumeAvailableCapacityForImportantUsage,
           let total = v.volumeTotalCapacity, total > 0 {
            m.disk = (Double(total) - Double(avail)) / Double(total) * 100
        }

        m.thermal = ProcessInfo.processInfo.thermalState.rawValue

        let pm = Shell.run("pmset -g | grep -o 'powermode[ ]*[0-9]' | grep -o '[0-9]'").out
        m.powerMode = Int(pm) ?? 0

        return m
    }

    static func topProcesses(limit: Int = 8) -> [ProcInfo] {
        let raw = Shell.run("ps -Arco pid,pcpu,comm | head -\(limit + 1) | tail -\(limit)").out
        var result: [ProcInfo] = []
        for line in raw.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 3, let pid = Int32(parts[0]), let cpu = Double(parts[1]) else { continue }
            let name = (parts[2...] .joined(separator: " ") as NSString).lastPathComponent
            result.append(ProcInfo(name: name, pid: pid, cpu: cpu))
        }
        return result
    }
}

enum TweakFactory {
    static func all() -> [Tweak] {
        [
            // ── ЭНЕРГИЯ ──
            Tweak(id: "pwr_highpower", title: "High Power Mode", icon: "bolt.badge.a",
                  desc: "Максимальная устойчивая мощность (M-Pro/Max). Больше тепла и шума вентиляторов.",
                  category: .power, impact: 3, risk: .moderate, needsRoot: true, isOneShot: false,
                  applyCmd: "pmset -a powermode 2", revertCmd: "pmset -a powermode 0"),
            Tweak(id: "pwr_nosleep", title: "Запретить сон", icon: "moon.slash",
                  desc: "Мак не уснёт под нагрузкой — для долгих задач (рендер, компиляция).",
                  category: .power, impact: 2, risk: .moderate, needsRoot: true, isOneShot: false,
                  applyCmd: "pmset -a disablesleep 1", revertCmd: "pmset -a disablesleep 0"),
            Tweak(id: "pwr_hibern", title: "Отключить гибернацию", icon: "zzz",
                  desc: "Не писать RAM на диск — быстрее пробуждение, меньше износ SSD.",
                  category: .power, impact: 2, risk: .moderate, needsRoot: true, isOneShot: false,
                  applyCmd: "pmset -a hibernatemode 0", revertCmd: "pmset -a hibernatemode 3"),
            Tweak(id: "pwr_powernap", title: "Отключить Power Nap", icon: "moon.zzz",
                  desc: "Никаких фоновых задач во сне.",
                  category: .power, impact: 1, risk: .safe, needsRoot: true, isOneShot: false,
                  applyCmd: "pmset -a powernap 0", revertCmd: "pmset -a powernap 1"),
            Tweak(id: "pwr_standby", title: "Отключить standby", icon: "pause.circle",
                  desc: "Не уходить в глубокий сон.",
                  category: .power, impact: 1, risk: .safe, needsRoot: true, isOneShot: false,
                  applyCmd: "pmset -a standby 0", revertCmd: "pmset -a standby 1"),
            Tweak(id: "pwr_autopoff", title: "Отключить autopoweroff", icon: "power",
                  desc: "Не выключаться после долгого сна.",
                  category: .power, impact: 1, risk: .safe, needsRoot: true, isOneShot: false,
                  applyCmd: "pmset -a autopoweroff 0", revertCmd: "pmset -a autopoweroff 1"),
            Tweak(id: "pwr_proximity", title: "Отключить proximity wake", icon: "wave.3.right",
                  desc: "Не просыпаться от устройств рядом.",
                  category: .power, impact: 1, risk: .safe, needsRoot: true, isOneShot: false,
                  applyCmd: "pmset -a proximitywake 0", revertCmd: "pmset -a proximitywake 1"),
            Tweak(id: "pwr_tcp", title: "Отключить TCP keepalive", icon: "arrow.triangle.2.circlepath",
                  desc: "Меньше сетевой активности во сне.",
                  category: .power, impact: 1, risk: .safe, needsRoot: true, isOneShot: false,
                  applyCmd: "pmset -a tcpkeepalive 0", revertCmd: "pmset -a tcpkeepalive 1"),
            Tweak(id: "pwr_wol", title: "Отключить Wake on LAN", icon: "powerplug",
                  desc: "Не просыпаться по сети.",
                  category: .power, impact: 1, risk: .safe, needsRoot: true, isOneShot: false,
                  applyCmd: "pmset -a womp 0", revertCmd: "pmset -a womp 1"),

            // ── RAM ──
            Tweak(id: "ram_purge", title: "Purge памяти", icon: "clear",
                  desc: "Мгновенно освободить неактивную память и кэши. Разовое действие.",
                  category: .ram, impact: 2, risk: .safe, needsRoot: true, isOneShot: true,
                  applyCmd: "purge", revertCmd: ""),
            Tweak(id: "ram_purge2", title: "Сброс кэшей диска", icon: "externaldrive",
                  desc: "Очистить дисковые кэши ядра (дополнительно к purge).",
                  category: .ram, impact: 1, risk: .safe, needsRoot: true, isOneShot: true,
                  applyCmd: "purge && dscacheutil -flushcache", revertCmd: ""),

            // ── SSD ──
            Tweak(id: "ssd_spotlight", title: "Отключить Spotlight", icon: "magnifyingglass",
                  desc: "Индексация долбит CPU и SSD. Главный источник фоновой нагрузки.",
                  category: .ssd, impact: 3, risk: .moderate, needsRoot: true, isOneShot: false,
                  applyCmd: "mdutil -a -i off", revertCmd: "mdutil -a -i on"),
            Tweak(id: "ssd_tm", title: "Отключить Time Machine", icon: "clock.badge.xmark",
                  desc: "Фоновое бэкапирование грузит диск.",
                  category: .ssd, impact: 2, risk: .moderate, needsRoot: true, isOneShot: false,
                  applyCmd: "tmutil disable", revertCmd: "tmutil enable"),
            Tweak(id: "ssd_snaps", title: "Удалить локальные снапшоты", icon: "trash",
                  desc: "Освободить место и убрать фоновые записи APFS-снапшотов. Разовое.",
                  category: .ssd, impact: 2, risk: .safe, needsRoot: true, isOneShot: true,
                  applyCmd: "tmutil deletelocalsnapshots / 2>/dev/null; echo done", revertCmd: ""),
            Tweak(id: "ssd_dsstore", title: "Не писать .DS_Store на сети", icon: "folder.badge.questionmark",
                  desc: "Меньше лишних записей на сетевых томах.",
                  category: .ssd, impact: 1, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true",
                  revertCmd: "defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool false"),

            // ── СЕТЬ ──
            Tweak(id: "net_dns", title: "Сбросить DNS-кэш", icon: "arrow.clockwise",
                  desc: "Свежий DNS-резолвинг. Разовое.",
                  category: .network, impact: 1, risk: .safe, needsRoot: true, isOneShot: true,
                  applyCmd: "dscacheutil -flushcache && killall -HUP mDNSResponder", revertCmd: ""),
            Tweak(id: "net_arp", title: "Очистить ARP-кэш", icon: "arrow.triangle.branch",
                  desc: "Сброс таблицы ARP. Разовое.",
                  category: .network, impact: 1, risk: .safe, needsRoot: true, isOneShot: true,
                  applyCmd: "arp -ad 2>/dev/null; echo done", revertCmd: ""),
            Tweak(id: "net_ipv6", title: "Отключить IPv6", icon: "globe.badge.chevron.backward",
                  desc: "Быстрее DNS, если провайдер не даёт IPv6.",
                  category: .network, impact: 1, risk: .moderate, needsRoot: true, isOneShot: false,
                  applyCmd: "networksetup -setv6off Wi-Fi", revertCmd: "networksetup -setv6automatic Wi-Fi"),
            Tweak(id: "net_bonjour", title: "Отключить Bonjour", icon: "dot.radiowaves.left.and.right",
                  desc: "Меньше фоновой multicast-активности.",
                  category: .network, impact: 1, risk: .moderate, needsRoot: true, isOneShot: false,
                  applyCmd: "defaults write /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements -bool true",
                  revertCmd: "defaults write /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements -bool false"),

            // ── ИНТЕРФЕЙС ──
            Tweak(id: "ui_transp", title: "Отключить прозрачность", icon: "square.on.square.dashed",
                  desc: "Меньше нагрузка на GPU при отрисовке окон.",
                  category: .ui, impact: 2, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write com.apple.universalaccess reduceTransparency -bool true",
                  revertCmd: "defaults write com.apple.universalaccess reduceTransparency -bool false"),
            Tweak(id: "ui_motion", title: "Уменьшить анимации", icon: "figure.walk",
                  desc: "Отключить эффект движения — интерфейс ощущается быстрее.",
                  category: .ui, impact: 2, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write com.apple.universalaccess reduceMotion -bool true",
                  revertCmd: "defaults write com.apple.universalaccess reduceMotion -bool false"),
            Tweak(id: "ui_dock", title: "Мгновенный Dock", icon: "dock.rectangle",
                  desc: "Без задержек появления/скрытия Dock.",
                  category: .ui, impact: 1, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write com.apple.dock autohide-time-modifier -float 0.1 && defaults write com.apple.dock autohide-delay -float 0 && killall Dock",
                  revertCmd: "defaults delete com.apple.dock autohide-time-modifier; defaults delete com.apple.dock autohide-delay; killall Dock"),
            Tweak(id: "ui_mc", title: "Быстрый Mission Control", icon: "square.on.square",
                  desc: "Мгновенное переключение пространств.",
                  category: .ui, impact: 1, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write com.apple.dock expose-animation-duration -float 0.1 && killall Dock",
                  revertCmd: "defaults delete com.apple.dock expose-animation-duration; killall Dock"),
            Tweak(id: "ui_win", title: "Без анимации окон", icon: "macwindow",
                  desc: "Окна открываются/закрываются мгновенно.",
                  category: .ui, impact: 1, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write -g NSAutomaticWindowAnimationsEnabled -bool false",
                  revertCmd: "defaults write -g NSAutomaticWindowAnimationsEnabled -bool true"),
            Tweak(id: "ui_dash", title: "Отключить Dashboard", icon: "gauge",
                  desc: "Убрать виджеты из памяти.",
                  category: .ui, impact: 1, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write com.apple.dashboard mcx-disabled -bool true && killall Dock",
                  revertCmd: "defaults write com.apple.dashboard mcx-disabled -bool false && killall Dock"),

            // ── ФОНОВЫЕ ──
            Tweak(id: "bg_analytics", title: "Отключить телеметрию", icon: "antenna.radiowaves.left.and.right",
                  desc: "Apple не шлёт диагностику в фоне.",
                  category: .background, impact: 1, risk: .safe, needsRoot: true, isOneShot: false,
                  applyCmd: "defaults write /Library/Application\\ Support/CrashReporter/DiagnosticMessagesHistory AutoSubmit -bool false",
                  revertCmd: "defaults write /Library/Application\\ Support/CrashReporter/DiagnosticMessagesHistory AutoSubmit -bool true"),
            Tweak(id: "bg_siri", title: "Отключить Siri", icon: "mic.slash",
                  desc: "Убрать фоновое прослушивание.",
                  category: .background, impact: 1, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write com.apple.Siri StatusMenuVisible -bool false && defaults write com.apple.Siri UserHasDeclinedEnable -bool true",
                  revertCmd: "defaults write com.apple.Siri StatusMenuVisible -bool true"),
            Tweak(id: "bg_handoff", title: "Отключить Handoff", icon: "hand.raised.slash",
                  desc: "Меньше фоновой активности Continuity.",
                  category: .background, impact: 1, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false",
                  revertCmd: "defaults write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool true"),
            Tweak(id: "bg_update", title: "Отключить автообновления", icon: "arrow.triangle.2.circlepath",
                  desc: "softwareupdate не грузит систему в фоне.",
                  category: .background, impact: 1, risk: .safe, needsRoot: true, isOneShot: false,
                  applyCmd: "defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false",
                  revertCmd: "defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true"),
            Tweak(id: "bg_tips", title: "Отключить подсказки", icon: "lightbulb.slash",
                  desc: "Убрать фоновые Tips-уведомления.",
                  category: .background, impact: 1, risk: .safe, needsRoot: false, isOneShot: false,
                  applyCmd: "defaults write com.apple.tipsd tips-disabled -bool true",
                  revertCmd: "defaults write com.apple.tipsd tips-disabled -bool false"),
        ]
    }
}

enum Persistence {
    static let file = NSHomeDirectory() + "/Library/Application Support/Overdrive/state.json"
    struct State: Codable { var applied: [String] }
    static func save(_ ids: [String]) {
        try? FileManager.default.createDirectory(
            atPath: (file as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(State(applied: ids)) {
            try? data.write(to: URL(fileURLWithPath: file))
        }
    }
    static func load() -> [String] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: file)),
              let s = try? JSONDecoder().decode(State.self, from: data) else { return [] }
        return s.applied
    }
}
