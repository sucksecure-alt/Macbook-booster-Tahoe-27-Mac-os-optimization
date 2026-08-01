import SwiftUI

enum Category: String, CaseIterable {
    case power, ram, ssd, network, ui, background

    var title: String {
        switch self {
        case .power: return "Энергия и CPU"
        case .ram: return "Память"
        case .ssd: return "Диск / SSD"
        case .network: return "Сеть"
        case .ui: return "Отзывчивость"
        case .background: return "Фоновые процессы"
        }
    }
    var icon: String {
        switch self {
        case .power: return "bolt.fill"
        case .ram: return "memorychip"
        case .ssd: return "internaldrive"
        case .network: return "wifi"
        case .ui: return "wand.and.stars"
        case .background: return "gearshape.2.fill"
        }
    }
    var color: Color {
        switch self {
        case .power: return T.boost
        case .ram: return T.cool
        case .ssd: return T.amber
        case .network: return T.lime
        case .ui: return T.violet
        case .background: return T.textDim
        }
    }
    var blurb: String {
        switch self {
        case .power: return "Снимаем лимиты энергосбережения — максимум мощности"
        case .ram: return "Освобождаем память от балласта"
        case .ssd: return "Меньше записей и фоновой долбёжки по диску"
        case .network: return "Быстрее DNS и отклик сети"
        case .ui: return "Мгновенный интерфейс без лишних анимаций"
        case .background: return "Убиваем фоновых пожирателей ресурсов"
        }
    }
}

enum Risk: String {
    case safe = "Безопасно"
    case moderate = "Компромисс"
    case aggressive = "Рискованно"
    var color: Color {
        switch self {
        case .safe: return T.lime
        case .moderate: return T.amber
        case .aggressive: return T.redline
        }
    }
}

struct Tweak: Identifiable {
    let id: String
    let title: String
    let icon: String
    let desc: String
    let category: Category
    let impact: Int
    let risk: Risk
    let needsRoot: Bool
    let isOneShot: Bool
    let applyCmd: String
    let revertCmd: String
    var isApplied: Bool = false
}

struct SystemMetrics {
    var cpu: Double = 0
    var ram: Double = 0
    var disk: Double = 0
    var thermal: Int = 0
    var powerMode: Int = 0
}

struct ProcInfo: Identifiable {
    let id = UUID()
    let name: String
    let pid: Int32
    let cpu: Double
}

enum Tab: String, CaseIterable, Identifiable {
    case dashboard = "Обзор"
    case power = "Энергия"
    case ram = "Память"
    case ssd = "Диск"
    case network = "Сеть"
    case ui = "Интерфейс"
    case background = "Фоновые"
    case benchmark = "Тесты"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .power: return "bolt.fill"
        case .ram: return "memorychip"
        case .ssd: return "internaldrive"
        case .network: return "wifi"
        case .ui: return "wand.and.stars"
        case .background: return "gearshape.2.fill"
        case .benchmark: return "speedometer"
        }
    }
}
