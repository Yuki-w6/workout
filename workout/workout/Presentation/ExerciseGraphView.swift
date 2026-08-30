import SwiftUI
import SwiftData
import Charts

/// 1種目ぶんのグラフをまとめて出す画面。
/// 指標のセレクターは持たず、最大重量 → 推定1RM → 総負荷量 の順に並べる。
/// 期間だけは画面上部に1つ置き、3つのグラフに共通で効かせる。
struct ExerciseGraphView: View {
    let exercise: Exercise

    @Query(sort: \RecordHeader.date) private var records: [RecordHeader]
    /// 期間は前回選んだものを覚える。初回は3か月。
    /// 週だと点が数個しか並ばず伸びが読み取れず、年だと直近の変化が潰れるため。
    @AppStorage("lastGraphPeriod") private var lastGraphPeriodRaw = GraphPeriod.threeMonths.rawValue

    private let calendar = Calendar.japaneseLocale
    private let graphBannerAdUnitID: String? = Bundle.main.object(forInfoDictionaryKey: "GraphBannerAdUnitID") as? String

    /// 並べる順。ユーザーが最初に見たいものから並べる。
    private let metricsInOrder: [GraphMetric] = [.maxWeight, .estimatedOneRM, .totalLoad]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Picker("期間", selection: periodSelection) {
                    ForEach(GraphPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                let metrics = metricPoints
                if metrics.isEmpty {
                    Text("期間内の記録がありません")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(metricsInOrder) { metric in
                        MetricChartView(
                            title: metric.title,
                            points: points(for: metric, in: metrics),
                            range: chartDataRange,
                            period: selectedPeriod,
                            unitLabel: displayUnitLabel
                        )
                    }
                }
            }
            .padding()
        }
        .coordinateSpace(name: "GraphViewSpace")
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if AdPolicy.shouldShowBanner(adUnitID: graphBannerAdUnitID), let adUnitID = graphBannerAdUnitID {
                BannerAdView(adUnitID: adUnitID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var selectedPeriod: GraphPeriod {
        GraphPeriod(rawValue: lastGraphPeriodRaw) ?? .threeMonths
    }

    private var periodSelection: Binding<GraphPeriod> {
        Binding(
            get: { selectedPeriod },
            set: { lastGraphPeriodRaw = $0.rawValue }
        )
    }

    private var displayUnitLabel: String {
        exercise.defaultWeightUnit.rawValue
    }

    private func points(for metric: GraphMetric, in metrics: MetricPoints) -> [MetricPoint] {
        let basePoints: [MetricPoint]
        switch metric {
        case .totalLoad:
            basePoints = metrics.totalLoad
        case .estimatedOneRM:
            basePoints = metrics.estimatedOneRM
        case .maxWeight:
            basePoints = metrics.maxWeight
        }
        return aggregatedPoints(from: basePoints, period: selectedPeriod, anchor: chartDataRange.lowerBound)
    }

    private var periodRange: ClosedRange<Date> {
        let end = endOfCurrentSection(for: selectedPeriod)
        let start = selectedPeriod.startDate(endingAt: end, calendar: calendar)
        return start...end
    }

    private var chartDataRange: ClosedRange<Date> {
        guard let recordRange = recordRange else {
            return periodRange
        }
        let lower = min(recordRange.lowerBound, periodRange.lowerBound)
        let upper = max(recordRange.upperBound, periodRange.upperBound)
        return lower...upper
    }


    private var recordRange: ClosedRange<Date>? {
        let dates = records
            .filter { $0.exerciseIDSnapshot == exercise.id && $0.hasRecordedSets }
            .map { calendar.startOfDay(for: $0.date) }
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            return nil
        }
        let end = calendar.date(byAdding: .day, value: 1, to: maxDate) ?? maxDate
        return minDate...end
    }


    private var metricPoints: MetricPoints {
        let unit = exercise.defaultWeightUnit
        let filtered = records.filter { record in
            record.exerciseIDSnapshot == exercise.id
        }
        let grouped = Dictionary(grouping: filtered, by: { record in
            calendar.startOfDay(for: record.date)
        })
        let dates = grouped.keys.sorted()

        var totalLoadPoints: [MetricPoint] = []
        var estimatedOneRMPoints: [MetricPoint] = []
        var maxWeightPoints: [MetricPoint] = []

        for date in dates {
            let details = grouped[date]?.flatMap { $0.sets ?? [] } ?? []
            guard !details.isEmpty else {
                continue
            }
            let totalLoad = details.reduce(0.0) { partial, detail in
                let weight = convertedWeight(detail.weight, from: detail.weightUnit, to: unit)
                return partial + weight * Double(detail.repetitions)
            }
            let maxDetail = details.max { lhs, rhs in
                let lhsWeight = convertedWeight(lhs.weight, from: lhs.weightUnit, to: unit)
                let rhsWeight = convertedWeight(rhs.weight, from: rhs.weightUnit, to: unit)
                if lhsWeight != rhsWeight {
                    return lhsWeight < rhsWeight
                }
                return lhs.repetitions < rhs.repetitions
            }
            let maxWeight = maxDetail.map { detail in
                convertedWeight(detail.weight, from: detail.weightUnit, to: unit)
            } ?? 0.0
            // ⚠️ その日で最も重いセットから推定する。回数の多い軽いセットのほうが
            // 高い推定値になる場合があるが、既存の挙動を変えないためこのまま。
            let reps = maxDetail?.repetitions ?? 0
            let estimatedOneRM = OneRepMaxEstimator().estimate(weight: maxWeight, repetitions: reps)

            totalLoadPoints.append(MetricPoint(date: date, value: totalLoad))
            estimatedOneRMPoints.append(MetricPoint(date: date, value: estimatedOneRM))
            maxWeightPoints.append(MetricPoint(date: date, value: maxWeight))
        }

        return MetricPoints(
            totalLoad: totalLoadPoints,
            estimatedOneRM: estimatedOneRMPoints,
            maxWeight: maxWeightPoints
        )
    }


    /// 期間の終端。MetricChartView側と同じ区切り方をする必要がある。
    /// ここがずれると、集計に使う範囲とグラフの表示範囲が食い違う。
    private func endOfCurrentSection(for period: GraphPeriod) -> Date {
        let todayStart = calendar.startOfDay(for: Date())
        switch period {
        case .oneWeek:
            return calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
        case .oneMonth, .threeMonths, .sixMonths:
            return calendar.dateInterval(of: .month, for: Date())?.end ?? Date()
        case .oneYear:
            let interval = calendar.dateInterval(of: .month, for: Date())
            return interval?.end ?? Date()
        }
    }

    private func convertedWeight(_ weight: Double, from: WeightUnit, to: WeightUnit) -> Double {
        guard from != to else {
            return weight
        }
        let poundsPerKilogram = 2.20462
        if from == .kg && to == .lb {
            return weight * poundsPerKilogram
        }
        return weight / poundsPerKilogram
    }


    private func aggregatedPoints(from points: [MetricPoint], period: GraphPeriod, anchor: Date) -> [MetricPoint] {
        switch period {
        case .threeMonths, .sixMonths:
            return averagePointsByDays(points, days: 7, anchor: anchor)
        case .oneYear:
            return averagePoints(points, by: .month)
        case .oneWeek, .oneMonth:
            return points
        }
    }

    private func averagePoints(_ points: [MetricPoint], by component: Calendar.Component) -> [MetricPoint] {
        let grouped = Dictionary(grouping: points) { point in
            calendar.dateInterval(of: component, for: point.date)
        }
        let intervals = grouped.keys.compactMap { $0 }.sorted { $0.start < $1.start }
        return intervals.compactMap { interval in
            guard let bucket = grouped[interval], !bucket.isEmpty else {
                return nil
            }
            let total = bucket.reduce(0.0) { $0 + $1.value }
            let average = total / Double(bucket.count)
            return MetricPoint(date: interval.start, value: average, range: interval)
        }
    }

    private func averagePointsByDays(_ points: [MetricPoint], days: Int, anchor: Date) -> [MetricPoint] {
        guard days > 0 else {
            return points
        }
        let anchorStart = calendar.startOfDay(for: anchor)
        let grouped = Dictionary(grouping: points) { point -> Date? in
            let dayDiff = calendar.dateComponents([.day], from: anchorStart, to: point.date).day ?? 0
            let bucketIndex = dayDiff / days
            return calendar.date(byAdding: .day, value: bucketIndex * days, to: anchorStart)
        }
        let bucketStarts = grouped.keys.compactMap { $0 }.sorted()
        return bucketStarts.compactMap { bucketStart in
            guard let bucket = grouped[bucketStart], !bucket.isEmpty else {
                return nil
            }
            let total = bucket.reduce(0.0) { $0 + $1.value }
            let average = total / Double(bucket.count)
            let end = calendar.date(byAdding: .day, value: days, to: bucketStart) ?? bucketStart
            let range = DateInterval(start: bucketStart, end: end)
            return MetricPoint(date: bucketStart, value: average, range: range)
        }
    }

}
