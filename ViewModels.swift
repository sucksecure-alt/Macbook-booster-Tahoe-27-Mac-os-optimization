import SwiftUI
import Foundation

@MainActor
final class BoostBrain: ObservableObject {
    @Published var tweaks: [Tweak] = []
    @Published var metrics = SystemMetrics()
    @Published var boostScore: Double = 0
    @Published var tab: Tab = .dashboard
    @Published var isBoosting = false
    @Published var topProcesses: [ProcInfo] = []
    @Published var cpuBench: Double = 0
    @Published var diskWrite: Double = 0
    @Published var diskRead: Double = 0
    @Published var benchRunning = false
    @Published var boostLog: [String] = []

    private var timer: Timer?

    init() {
        tweaks = TweakFactory.all()
        let applied = Set(Persistence.load())
        for i in tweaks.indices where applied.contains(tweaks[i].id) {
            tweaks[i].isApplied = true
        }
    }

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func refresh() {
        Task {
            let m = await Task.detached(priority: .utility) { SystemReader.metrics() }.value
            let procs = await Task.detached(priority: .utility) { SystemReader.topProcesses(limit: 8) }.value
            self.metrics = m
            self.topProcesses = procs
            self.recomputeScore()
        }
    }

    func recomputeScore() {
        let resource = ((100 - metrics.cpu) + (100 - metrics.ram) + (100 - metrics.disk)) / 3
        let persistent = tweaks.filter { !$0.isOneShot }
        let appliedW = persistent.filter(\.isApplied).reduce(0) { $0 + $1.impact }
        let totalW = persistent.reduce(0) { $0 + $1.impact }
        let tweakScore = totalW > 0 ? Double(appliedW) / Double(totalW) * 100 : 0
        boostScore = resource * 0.4 + tweakScore * 0.6
    }

    // MARK: - Применение
    func apply(_ t: Tweak) {
        Task { await applySync(t) }
    }

    @discardableResult
    private func applySync(_ t: Tweak) async -> Bool {
        let code = await Task.detached(priority: .userInitiated) {
            Shell.run(t.applyCmd, root: t.needsRoot).code
        }.value
        if code == 0 {
            if let i = tweaks.firstIndex(where: { $0.id == t.id }) { tweaks[i].isApplied = true }
            if !t.isOneShot { persist() }
            log("✅ \(t.title)")
            recomputeScore()
            return true
        } else {
            log("⚠️ \(t.title) — не применилось")
            return false
        }
    }

    func revert(_ t: Tweak) {
        guard !t.revertCmd.isEmpty else { return }
        Task {
            let code = await Task.detached(priority: .userInitiated) {
                Shell.run(t.revertCmd, root: t.needsRoot).code
            }.value
            if code == 0 {
                if let i = tweaks.firstIndex(where: { $0.id == t.id }) { tweaks[i].isApplied = false }
                persist()
                log("↩️ \(t.title) — отключено")
                recomputeScore()
            }
        }
    }

    func applySection(_ cat: Category) {
        Task {
            for t in tweaks where t.category == cat && !t.isApplied {
                await applySync(t)
            }
        }
    }

    func maxBoost() {
        isBoosting = true
        boostLog = []
        Task {
            log("🚀 Запускаю MAX BOOST...")
            for t in tweaks where !t.isOneShot && t.risk != .aggressive && !t.isApplied {
                await applySync(t)
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            for t in tweaks where t.isOneShot && (t.id == "ram_purge" || t.id == "ssd_snaps" || t.id == "net_dns") {
                await applySync(t)
            }
            log("🏁 MAX BOOST завершён. Boost: \(Int(boostScore))%")
            isBoosting = false
        }
    }

    func restoreAll() {
        Task {
            log("↩️ Возвращаю настройки по умолчанию...")
            for t in tweaks where t.isApplied && !t.isOneShot {
                if !t.revertCmd.isEmpty {
                    let code = await Task.detached(priority: .userInitiated) {
                        Shell.run(t.revertCmd, root: t.needsRoot).code
                    }.value
                    if code == 0, let i = tweaks.firstIndex(where: { $0.id == t.id }) {
                        tweaks[i].isApplied = false
                    }
                }
            }
            persist()
            recomputeScore()
            log("✅ Настройки восстановлены")
        }
    }

    private func persist() {
        Persistence.save(tweaks.filter { $0.isApplied && !$0.isOneShot }.map(\.id))
    }

    private func log(_ s: String) {
        boostLog.insert(s, at: 0)
        if boostLog.count > 12 { boostLog.removeLast() }
    }

    func killProcess(_ pid: Int32) {
        Shell.run("kill -9 \(pid)", root: true)
        refresh()
    }

    // MARK: - Бенчмарки
    func runCPUBench() {
        benchRunning = true
        Task {
            let score = await Task.detached(priority: .userInitiated) {
                let start = Date()
                var x = 0.0
                for i in 0..<3_000_000 { x += sin(Double(i)) * cos(Double(i)) }
                let elapsed = max(0.0001, Date().timeIntervalSince(start))
                return 3_000_000.0 / elapsed / 1_000_000
            }.value
            cpuBench = score
            benchRunning = false
        }
    }

    func runDiskBench() {
        benchRunning = true
        Task {
            let (w, r) = await Task.detached(priority: .userInitiated) {
                let path = "/tmp/od_bench_\(UUID().uuidString).tmp"
                let wOut = Shell.run("dd if=/dev/zero of=\(path) bs=1m count=256 2>&1").out
                let write = Self.parseDD(wOut)
                let rOut = Shell.run("dd if=\(path) of=/dev/null bs=1m 2>&1").out
                let read = Self.parseDD(rOut)
                Shell.run("rm -f \(path)")
                return (write, read)
            }.value
            diskWrite = w
            diskRead = r
            benchRunning = false
        }
    }

    nonisolated static func parseDD(_ out: String) -> Double {
        if let r = out.range(of: #"(\d+) bytes/sec"#, options: .regularExpression) {
            let digits = out[r].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return (Double(digits) ?? 0) / 1_048_576
        }
        return 0
    }

    var statusTitle: String {
        if boostScore >= 80 { return "НА ПИКЕ 🔥" }
        if boostScore >= 55 { return "Разогнан" }
        if boostScore >= 35 { return "Есть запас" }
        return "Задушен энергосбережением"
    }
    var statusDesc: String {
        if boostScore >= 80 { return "Все лимиты сняты, ресурсы свободны." }
        if boostScore >= 55 { return "Хорошая производительность, можно выжать ещё." }
        if boostScore >= 35 { return "Фоновые процессы и энергосбережение съедают мощность." }
        return "Нажми MAX BOOST, чтобы снять ограничения."
    }
}
