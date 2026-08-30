import Foundation
import SwiftUI

// グラフの描画と集計で共有する型。ファイルをまたいで使うため internal にしている。

struct MetricPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    let range: DateInterval?

    init(date: Date, value: Double, range: DateInterval? = nil) {
        self.date = date
        self.value = value
        self.range = range
    }

    var isAverage: Bool {
        range != nil
    }
}

struct MetricPoints {
    let totalLoad: [MetricPoint]
    let estimatedOneRM: [MetricPoint]
    let maxWeight: [MetricPoint]

    var isEmpty: Bool {
        totalLoad.isEmpty && estimatedOneRM.isEmpty && maxWeight.isEmpty
    }

    static let empty = MetricPoints(totalLoad: [], estimatedOneRM: [], maxWeight: [])
}

enum GraphMetric: String, CaseIterable, Identifiable {
    case totalLoad
    case estimatedOneRM
    case maxWeight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .totalLoad:
            return "総負荷量"
        case .estimatedOneRM:
            return "推定1RM"
        case .maxWeight:
            return "最大重量"
        }
    }
}

enum GraphPeriod: String, CaseIterable, Identifiable {
    case oneWeek
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneWeek:
            return "週"
        case .oneMonth:
            return "月"
        case .threeMonths:
            return "3か月"
        case .sixMonths:
            return "6か月"
        case .oneYear:
            return "年"
        }
    }

    func startDate(endingAt endDate: Date, calendar: Calendar) -> Date {
        switch self {
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .oneMonth:
            let anchor = endDate.addingTimeInterval(-1)
            guard let interval = calendar.dateInterval(of: .month, for: anchor) else {
                return endDate
            }
            return interval.start
        case .threeMonths:
            let anchor = endDate.addingTimeInterval(-1)
            guard let interval = calendar.dateInterval(of: .month, for: anchor) else {
                return endDate
            }
            return calendar.date(byAdding: .month, value: -2, to: interval.start) ?? interval.start
        case .sixMonths:
            let anchor = endDate.addingTimeInterval(-1)
            guard let interval = calendar.dateInterval(of: .month, for: anchor) else {
                return endDate
            }
            return calendar.date(byAdding: .month, value: -5, to: interval.start) ?? interval.start
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        }
    }
}

// 同じ定義が各画面にprivateで重複していたため、ここに集約した。
extension Calendar {
    static var japaneseLocale: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }
}
