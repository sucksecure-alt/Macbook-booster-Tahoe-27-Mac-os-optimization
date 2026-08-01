import SwiftUI

// MARK: - Тахометр
struct Needle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct Tachometer: View {
    let score: Double

    var body: some View {
        ZStack {
            ForEach(0..<28, id: \.self) { i in
                let angle = 225.0 + Double(i) / 27.0 * 270.0
                Rectangle()
                    .fill(i >= 23 ? T.redline.opacity(0.85) : T.textDim.opacity(0.35))
                    .frame(width: 2, height: i % 3 == 0 ? 13 : 7)
                    .offset(y: -100)
                    .rotationEffect(.degrees(angle))
            }
            Circle().trim(from: 0, to: 0.75)
                .stroke(T.carbonLite, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0.75 * 0.85, to: 0.75)
                .stroke(T.redline.opacity(0.45), style: StrokeStyle(lineWidth: 15))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: 0.75 * score / 100)
                .stroke(
                    AngularGradient(colors: [T.cool, T.boost, T.redline],
                                    center: .center,
                                    startAngle: .degrees(135),
                                    endAngle: .degrees(405)),
                    style: StrokeStyle(lineWidth: 15, lineCap: .round))
                .rotationEffect(.degrees(135))
                .shadow(color: T.boost.opacity(0.6), radius: 10)
                .animation(.spring(duration: 0.9, bounce: 0.2), value: score)

            ZStack {
                Needle().fill(T.textHi).frame(width: 5, height: 88).offset(y: -42)
            }
            .frame(width: 250, height: 250)
            .rotationEffect(.degrees(225 + score / 100 * 270))
            .animation(.spring(duration: 0.9, bounce: 0.2), value: score)

            Circle().fill(T.carbonLite).frame(width: 24)
            Circle().fill(T.boost).frame(width: 11)
                .shadow(color: T.boost.opacity(0.8), radius: 6)

            VStack(spacing: 1) {
                Text("\(Int(score))")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(T.textHi).monospacedDigit()
                Text("BOOST %")
                    .font(.system(size: 10, weight: .bold)).tracking(3)
                    .foregroundStyle(T.boost)
            }
            .offset(y: 62)
        }
        .frame(width: 250, height: 250)
    }
}

// MARK: - Чип метрики
struct MetricChip: View {
    let icon: String; let label: String; let value: String
    let percent: Double; let color: Color

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 5)
                Circle().trim(from: 0, to: min(1, percent / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.6), value: percent)
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(color)
            }
            .frame(width: 50, height: 50)
            Text(value).font(.caption.bold()).foregroundStyle(T.textHi).monospacedDigit()
            Text(label).font(.system(size: 9)).foregroundStyle(T.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(T.carbonLite, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Обзор
struct DashboardView: View {
    @ObservedObject var brain: BoostBrain

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                HStack(spacing: 44) {
                    Tachometer(score: brain.boostScore)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(brain.statusTitle)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(T.textHi)
                        Text(brain.statusDesc)
                            .font(.subheadline).foregroundStyle(T.textDim)
                            .frame(maxWidth: 320, alignment: .leading)

                        Button {
                            brain.maxBoost()
                        } label: {
                            HStack(spacing: 8) {
                                if brain.isBoosting {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "bolt.fill")
                                }
                                Text(brain.isBoosting ? "РАЗГОН..." : "MAX BOOST")
                                    .font(.title3.bold())
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 30).padding(.vertical, 14)
                            .background(T.boostGradient, in: RoundedRectangle(cornerRadius: 14))
                            .shadow(color: T.boost.opacity(0.5), radius: 14, y: 4)
                        }
                        .buttonStyle(PressStyle())
                        .disabled(brain.isBoosting)

                        Button {
                            brain.restoreAll()
                        } label: {
                            Label("Сбросить всё по умолчанию", systemImage: "arrow.uturn.backward")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(T.textDim)
                    }
                }
                .padding(.top, 24)

                HStack(spacing: 12) {
                    MetricChip(icon: "cpu", label: "CPU", value: "\(Int(brain.metrics.cpu))%",
                               percent: brain.metrics.cpu, color: T.boost)
                    MetricChip(icon: "memorychip", label: "RAM", value: "\(Int(brain.metrics.ram))%",
                               percent: brain.metrics.ram, color: T.cool)
                    MetricChip(icon: "internaldrive", label: "Диск", value: "\(Int(brain.metrics.disk))%",
                               percent: brain.metrics.disk, color: T.amber)
                    MetricChip(icon: "thermometer.medium", label: "Термал",
                               value: thermalLabel, percent: Double(brain.metrics.thermal) / 3 * 100,
                               color: thermalColor)
                    MetricChip(icon: "bolt.badge.a", label: "Power",
                               value: brain.metrics.powerMode == 2 ? "HIGH" : "\(brain.metrics.powerMode)",
                               percent: brain.metrics.powerMode == 2 ? 100 : Double(brain.metrics.powerMode) / 2 * 100,
                               color: brain.metrics.powerMode == 2 ? T.redline : T.textDim)
                }

                // Топ процессов
                VStack(alignment: .leading, spacing: 10) {
                    Text("ТОП ПОЖИРАТЕЛИ CPU")
                        .font(.caption.bold()).tracking(1).foregroundStyle(T.textDim)
                    ForEach(brain.topProcesses) { p in
                        HStack {
                            Text(p.name).font(.caption).foregroundStyle(T.textHi).lineLimit(1)
                            Spacer()
                            Text(String(format: "%.0f%%", p.cpu))
                                .font(.caption.bold()).monospacedDigit()
                                .foregroundStyle(p.cpu > 50 ? T.redline : p.cpu > 20 ? T.amber : T.textDim)
                            Button {
                                brain.killProcess(p.pid)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(T.redline.opacity(0.6))
                            }
                            .buttonStyle(.plain).help("Завершить")
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(T.carbonLite, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .mfPanel()

                // Лог
                if !brain.boostLog.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ЖУРНАЛ").font(.caption.bold()).tracking(1).foregroundStyle(T.textDim)
                        ForEach(brain.boostLog, id: \.self) { line in
                            Text(line).font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(T.textDim)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mfPanel()
                }

                Text("Честно: железо Apple Silicon нельзя разогнать. Бустер снимает лимиты энергосбережения, убивает фоновую нагрузку и освобождает ресурсы — так система работает на своём реальном пике.")
                    .font(.caption2).foregroundStyle(T.textDim)
                    .frame(maxWidth: 640)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .background(T.bgGradient)
    }

    var thermalLabel: String {
        ["Норма", "Тепло", "Жарко", "Крит"][min(3, brain.metrics.thermal)]
    }
    var thermalColor: Color {
        brain.metrics.thermal >= 2 ? T.redline : brain.metrics.thermal == 1 ? T.amber : T.lime
    }
}

// MARK: - Панель твика
struct TweakRow: View {
    @Binding var tweak: Tweak
    @ObservedObject var brain: BoostBrain

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tweak.icon)
                .foregroundStyle(tweak.category.color)
                .frame(width: 38, height: 38)
                .background(tweak.category.color.opacity(tweak.isApplied ? 0.22 : 0.08),
                            in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(tweak.title).font(.body.weight(.medium)).foregroundStyle(T.textHi)
                    ImpactDots(count: tweak.impact)
                    RiskBadge(risk: tweak.risk)
                    if tweak.needsRoot {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(T.amber)
                    }
                }
                Text(tweak.desc).font(.caption).foregroundStyle(T.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            if tweak.isOneShot {
                Button("Запустить") { brain.apply(tweak) }
                    .buttonStyle(.bordered).controlSize(.small)
                    .tint(tweak.category.color)
            } else {
                Toggle("", isOn: Binding(
                    get: { tweak.isApplied },
                    set: { on in on ? brain.apply(tweak) : brain.revert(tweak) }
                ))
                .labelsHidden().toggleStyle(.switch)
                .tint(tweak.category.color)
            }
        }
        .padding(14)
        .background(T.carbonLite.opacity(tweak.isApplied ? 1 : 0.55),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(tweak.isApplied ? tweak.category.color.opacity(0.45) : .white.opacity(0.05),
                    lineWidth: 1))
    }
}

// MARK: - Страница подсистемы
struct SubsystemView: View {
    @ObservedObject var brain: BoostBrain
    let category: Category

    var body: some View {
        let items = brain.tweaks.filter { $0.category == category }
        let appliedCount = items.filter(\.isApplied).count

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: category.icon)
                        .font(.title2).foregroundStyle(category.color)
                        .frame(width: 52, height: 52)
                        .background(category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title).font(.title2.bold()).foregroundStyle(T.textHi)
                        Text(category.blurb).font(.caption).foregroundStyle(T.textDim)
                    }
                    Spacer()
                    Button {
                        brain.applySection(category)
                    } label: {
                        Label("Включить всё", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.bordered).tint(category.color)
                    .disabled(appliedCount == items.count)
                }

                Text("Активно: \(appliedCount) из \(items.count)")
                    .font(.caption).foregroundStyle(T.textDim)

                ForEach(items) { t in
                    if let idx = brain.tweaks.firstIndex(where: { $0.id == t.id }) {
                        TweakRow(tweak: $brain.tweaks[idx], brain: brain)
                    }
                }
            }
            .padding(24)
        }
        .background(T.bgGradient)
    }
}

// MARK: - Бенчмарки
struct BenchmarkView: View {
    @ObservedObject var brain: BoostBrain

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("ТЕСТЫ ПРОИЗВОДИТЕЛЬНОСТИ")
                    .font(.title2.bold()).foregroundStyle(T.textHi)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    BenchCard(icon: "cpu", title: "CPU", color: T.boost,
                              value: brain.cpuBench > 0 ? String(format: "%.1f", brain.cpuBench) : "—",
                              unit: "Mops", running: brain.benchRunning) {
                        brain.runCPUBench()
                    }
                    BenchCard(icon: "arrow.down.doc", title: "SSD запись", color: T.amber,
                              value: brain.diskWrite > 0 ? String(format: "%.0f", brain.diskWrite) : "—",
                              unit: "MB/s", running: brain.benchRunning) {
                        brain.runDiskBench()
                    }
                    BenchCard(icon: "arrow.up.doc", title: "SSD чтение", color: T.cool,
                              value: brain.diskRead > 0 ? String(format: "%.0f", brain.diskRead) : "—",
                              unit: "MB/s", running: brain.benchRunning) {
                        brain.runDiskBench()
                    }
                }

                Text("Запусти тест ДО буста и ПОСЛЕ, чтобы увидеть разницу. Сырые цифры CPU/SSD ограничены железом — бустер освобождает ресурсы, чтобы они были доступны целиком.")
                    .font(.caption2).foregroundStyle(T.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
        .background(T.bgGradient)
    }
}

struct BenchCard: View {
    let icon: String; let title: String; let color: Color
    let value: String; let unit: String; let running: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(T.textDim)
            Text(value)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(T.textHi).monospacedDigit()
            Text(unit).font(.caption2).foregroundStyle(T.textDim)
            Button(running ? "Тест..." : "Запустить") { action() }
                .buttonStyle(.bordered).tint(color).disabled(running)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(T.carbonLite, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(color.opacity(0.25), lineWidth: 1))
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

extension View {
    func mfPanel() -> some View {
        self.padding(16)
            .background(T.carbonLite.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.05), lineWidth: 1))
    }
}
