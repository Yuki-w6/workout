import SwiftUI
import SwiftData
import Charts

struct GraphView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    @Query(sort: \RecordHeader.date) private var records: [RecordHeader]
    @State private var selectedBodyPart: BodyPart = .chest
    @State private var selectedExerciseId: UUID?
    @State private var selectedPeriod: GraphPeriod = .oneWeek
    @State private var selectedMetric: GraphMetric = .totalLoad
    @State private var selectedMetricPoint: MetricPoint?
    @State private var valueLabelSize: CGSize = .zero
    @State private var chartScrollPosition: Date = Date()
    @AppStorage("lastGraphMetric") private var lastGraphMetricRaw = GraphMetric.totalLoad.rawValue
    private let valueLabelAreaWidth: CGFloat = 320
    private let valueLabelAreaHeight: CGFloat = 56

    private let calendar = Calendar.japaneseLocale
    private let bodyPartOrder: [BodyPart] = [
        .chest,
        .back,
        .legs,
        .shoulders,
        .arms,
        .glutes,
        .core
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    selectorSection
                    graphSection
                }
                .padding()
            }
            .coordinateSpace(name: "GraphViewSpace")
        }
        .onAppear {
            viewModel.load()
            syncExerciseSelection()
            selectedMetric = GraphMetric(rawValue: lastGraphMetricRaw) ?? .totalLoad
            updateSelectedMetricPoint()
            chartScrollPosition = scrollTargetDate(for: selectedPeriod)
        }
        .onChange(of: selectedBodyPart) { _, _ in
            syncExerciseSelection()
        }
        .onChange(of: viewModel.exercises) { _, _ in
            syncExerciseSelection()
        }
        .onChange(of: selectedExerciseId) { _, _ in
            updateSelectedMetricPoint()
        }
        .onChange(of: selectedPeriod) { _, _ in
            updateSelectedMetricPoint()
            chartScrollPosition = chartScrollPosition
        }
        .onChange(of: records.count) { _, _ in
            updateSelectedMetricPoint()
        }
        .onChange(of: selectedMetric) { _, newValue in
            lastGraphMetricRaw = newValue.rawValue
            updateSelectedMetricPoint()
        }
        .onChange(of: selectedMetricPoint) { _, _ in
            valueLabelSize = .zero
        }
    }

    private var selectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    SwiftUI.Menu {
                        ForEach(bodyPartOrder, id: \.self) { bodyPart in
                            Button(bodyPart.displayName) {
                                selectedBodyPart = bodyPart
                            }
                        }
                    } label: {
                        menuLabel(text: selectedBodyPart.displayName)
                    }
                    .tint(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.25))
                    )

                    SwiftUI.Menu {
                        if exercisesForBodyPart.isEmpty {
                            Button("種目がありません") {}
                                .disabled(true)
                        } else {
                            ForEach(exercisesForBodyPart, id: \.id) { exercise in
                                Button(exercise.name) {
                                    selectedExerciseId = exercise.id
                                }
                            }
                        }
                    } label: {
                        menuLabel(text: selectedExerciseLabel)
                    }
                    .tint(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.25))
                    )

                    SwiftUI.Menu {
                        ForEach(GraphMetric.allCases) { metric in
                            Button(metric.title) {
                                selectedMetric = metric
                            }
                        }
                    } label: {
                        menuLabel(text: selectedMetric.title)
                    }
                    .tint(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.25))
                    )
                }
                .padding(.horizontal, 2)
            }

            ZStack {
                Picker("期間", selection: $selectedPeriod) {
                    ForEach(GraphPeriod.allCases) { period in
                        Text(period.title)
                            .tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var graphSection: some View {
        let metrics = metricPoints
        return VStack(alignment: .leading, spacing: 20) {
            if metrics.isEmpty {
                Text("期間内の記録がありません")
                    .foregroundStyle(.secondary)
            } else {
                chartBlock(
                    title: selectedMetric.title,
                    points: points(for: selectedMetric, in: metrics),
                    range: periodRange,
                    selectedPoint: $selectedMetricPoint
                )
            }
        }
    }

    private var exercisesForBodyPart: [Exercise] {
        viewModel.exercises.filter { $0.bodyPart == selectedBodyPart }
    }

    private var selectedExercise: Exercise? {
        exercisesForBodyPart.first { $0.id == selectedExerciseId }
    }

    private var periodRange: ClosedRange<Date> {
        let end = endOfCurrentSection(for: selectedPeriod)
        let start = selectedPeriod.startDate(endingAt: end, calendar: calendar)
        return start...end
    }

    private var metricPoints: MetricPoints {
        guard let exercise = selectedExercise else {
            return .empty
        }
        let range = periodRange
        let filtered = records.filter { record in
            record.exercise.id == exercise.id &&
            record.date >= range.lowerBound &&
            record.date <= range.upperBound
        }
        let grouped = Dictionary(grouping: filtered, by: { record in
            calendar.startOfDay(for: record.date)
        })
        let dates = grouped.keys.sorted()

        var totalLoadPoints: [MetricPoint] = []
        var maxRMPoints: [MetricPoint] = []
        var maxWeightPoints: [MetricPoint] = []

        for date in dates {
            let details = grouped[date]?.flatMap { $0.details } ?? []
            guard !details.isEmpty else {
                continue
            }
            let totalLoad = details.reduce(0.0) { partial, detail in
                partial + detail.weight * Double(detail.repetitions)
            }
            let maxDetail = details.max { lhs, rhs in
                if lhs.weight != rhs.weight {
                    return lhs.weight < rhs.weight
                }
                return lhs.repetitions < rhs.repetitions
            }
            let maxWeight = maxDetail?.weight ?? 0.0
            let reps = Double(maxDetail?.repetitions ?? 0)
            let maxRM = maxWeight * (reps / 40.0) + maxWeight

            totalLoadPoints.append(MetricPoint(date: date, value: totalLoad))
            maxRMPoints.append(MetricPoint(date: date, value: maxRM))
            maxWeightPoints.append(MetricPoint(date: date, value: maxWeight))
        }

        return MetricPoints(
            totalLoad: totalLoadPoints,
            maxRM: maxRMPoints,
            maxWeight: maxWeightPoints
        )
    }

    private func chartBlock(
        title: String,
        points: [MetricPoint],
        range: ClosedRange<Date>,
        selectedPoint: Binding<MetricPoint?>
    ) -> some View {
        let xRange = chartRange(for: range)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ZStack {
                Color.clear
                GeometryReader { proxy in
                    if let point = selectedPoint.wrappedValue {
                        let position = valueLabelPosition(
                            point: point,
                            labelAreaSize: proxy.size,
                            range: chartRange(for: range)
                        )
                        valueLabelView(for: point)
                            .position(x: position.x, y: position.y)
                            .zIndex(1)
                    }
                }
            }
            .frame(height: valueLabelAreaHeight)
            Chart {
                RuleMark(x: .value("開始", xRange.lowerBound))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                ForEach(points) { point in
                    let xValue = plotDate(for: point)
                    LineMark(
                        x: .value("日付", xValue),
                        y: .value("値", point.value)
                    )
                    .foregroundStyle(Color.appPink)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Color.appPink)
                    .symbol(.circle.strokeBorder(lineWidth: 2))
                    .interpolationMethod(.linear)
                }
                if let point = selectedPoint.wrappedValue {
                    let xValue = plotDate(for: point)
                    PointMark(
                        x: .value("日付", xValue),
                        y: .value("値", point.value)
                    )
                    .symbolSize(80)
                    .foregroundStyle(Color.appPink)
                    RuleMark(x: .value("日付", xValue))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                }
            }
            .chartXScale(domain: xRange)
            .chartXAxis {
                AxisMarks(values: axisStrideValues(for: selectedPeriod)) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel(axisDateLabel(date, period: selectedPeriod))
                            .offset(y: -6)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing)
            }
            .chartYScale(domain: yRange(for: points))
            .applyIfAvailable { chart in
                chart
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: visibleDomainLength(for: selectedPeriod))
                    .chartScrollPosition(x: $chartScrollPosition)
            }
            .frame(height: 360)
            .padding(.top, 24)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    ZStack {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        guard let plotFrameAnchor = proxy.plotFrame else {
                                            return
                                        }
                                        let plotFrame = geometry[plotFrameAnchor]
                                        let location = value.location
                                        if !plotFrame.contains(location) {
                                            selectedPoint.wrappedValue = nil
                                            return
                                        }
                                        let locationX = location.x - plotFrame.origin.x
                                        let locationY = location.y - plotFrame.origin.y
                                        guard let date: Date = proxy.value(atX: locationX) else {
                                            return
                                        }
                                        guard let nearest = nearestPoint(to: date, in: points),
                                              let nearestX = proxy.position(forX: nearest.date),
                                              let nearestY = proxy.position(forY: nearest.value)
                                        else {
                                            selectedPoint.wrappedValue = nil
                                            return
                                        }
                                        let distance = hypot(nearestX - locationX, nearestY - locationY)
                                        if distance <= 20 {
                                            selectedPoint.wrappedValue = nearest
                                        } else {
                                            selectedPoint.wrappedValue = nil
                                        }
                                    }
                            )

                    }
                }
            }
        }
    }

    private func syncExerciseSelection() {
        if !exercisesForBodyPart.contains(where: { $0.id == selectedExerciseId }) {
            selectedExerciseId = exercisesForBodyPart.first?.id
        }
    }

    private func nearestPoint(to date: Date, in points: [MetricPoint]) -> MetricPoint? {
        points.min { lhs, rhs in
            abs(plotDate(for: lhs).timeIntervalSince(date)) < abs(plotDate(for: rhs).timeIntervalSince(date))
        }
    }

    private func formattedValue(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func visibleDomainLength(for period: GraphPeriod) -> TimeInterval {
        switch period {
        case .oneWeek:
            return 7 * 24 * 60 * 60
        case .oneMonth:
            return 30 * 24 * 60 * 60
        case .threeMonths:
            return 90 * 24 * 60 * 60
        case .sixMonths:
            return 180 * 24 * 60 * 60
        case .oneYear:
            return 365 * 24 * 60 * 60
        }
    }

    private func scrollTargetDate(for period: GraphPeriod) -> Date {
        endOfCurrentSection(for: period).addingTimeInterval(-visibleDomainLength(for: period) / 2)
    }

    private func endOfCurrentSection(for period: GraphPeriod) -> Date {
        let todayStart = calendar.startOfDay(for: Date())
        switch period {
        case .oneWeek, .oneMonth:
            return calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
        case .threeMonths, .sixMonths:
            return calendar.dateInterval(of: .weekOfYear, for: Date())?.end
                ?? calendar.date(byAdding: .day, value: 7, to: todayStart)
                ?? Date()
        case .oneYear:
            let interval = calendar.dateInterval(of: .month, for: Date())
            return interval?.end ?? Date()
        }
    }

    private func axisDateLabel(_ date: Date) -> String {
        axisDateLabel(date, period: selectedPeriod)
    }

    private func axisDateLabel(_ date: Date, period: GraphPeriod) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        switch period {
        case .oneWeek:
            formatter.dateFormat = "E"
        case .oneMonth, .threeMonths:
            formatter.dateFormat = "d"
        case .sixMonths, .oneYear:
            formatter.dateFormat = "M月"
        }
        return formatter.string(from: date)
    }

    private func axisStrideValues(for period: GraphPeriod) -> AxisMarkValues {
        switch period {
        case .oneWeek:
            return .stride(by: .day)
        case .oneMonth:
            return .stride(by: .day, count: 7)
        case .threeMonths:
            return .stride(by: .day, count: 14)
        case .sixMonths, .oneYear:
            return .stride(by: .month, count: 1)
        }
    }

    private var selectedExerciseLabel: String {
        selectedExercise?.name ?? "種目を選択"
    }

    private func updateSelectedMetricPoint() {
        let metrics = metricPoints
        let points = points(for: selectedMetric, in: metrics)
        guard !points.isEmpty else {
            selectedMetricPoint = nil
            return
        }
        selectedMetricPoint = points.max(by: { selectionDate(for: $0) < selectionDate(for: $1) })
    }

    private func points(for metric: GraphMetric, in metrics: MetricPoints) -> [MetricPoint] {
        let basePoints: [MetricPoint]
        switch metric {
        case .totalLoad:
            basePoints = metrics.totalLoad
        case .maxRM:
            basePoints = metrics.maxRM
        case .maxWeight:
            basePoints = metrics.maxWeight
        }
        return aggregatedPoints(from: basePoints, period: selectedPeriod, anchor: periodRange.lowerBound)
    }

    private func yRange(for points: [MetricPoint]) -> ClosedRange<Double> {
        guard
            let minValue = points.map(\.value).min(),
            let maxValue = points.map(\.value).max()
        else {
            return 0...1
        }
        if minValue == maxValue {
            let padded = max(minValue * 0.2, 1)
            return max(0, minValue - padded)...(maxValue + padded)
        }
        let padding = (maxValue - minValue) * 0.35
        let lower = max(0, minValue - padding)
        let upper = maxValue + padding
        return lower...upper
    }

    private func menuLabel(text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .foregroundStyle(.primary)
            TriangleShape()
                .fill(Color.secondary)
                .frame(width: 8, height: 6)
        }
    }

    private func chartRange(for range: ClosedRange<Date>) -> ClosedRange<Date> {
        range
    }

    private func valueLabelView(for point: MetricPoint) -> some View {
        Text("\(formattedValue(point.value))kg")
            .font(.caption.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(Color(.systemBackground))
                    .shadow(radius: 2)
            )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ValueLabelSizeKey.self, value: proxy.size)
            }
        )
            .onPreferenceChange(ValueLabelSizeKey.self) { size in
                guard size != .zero else {
                    return
                }
                DispatchQueue.main.async {
                    valueLabelSize = size
                    print("GraphView valueLabelSize:", size)
                }
            }
    }

    private func valueLabelPosition(
        point: MetricPoint,
        labelAreaSize: CGSize,
        range: ClosedRange<Date>
    ) -> CGPoint {
        let horizontalPadding: CGFloat = 8
        let verticalPadding: CGFloat = 6
        let halfWidth = valueLabelSize.width / 2
        let halfHeight = valueLabelSize.height / 2
        let resolvedWidth = min(valueLabelAreaWidth, labelAreaSize.width)
        let leftBound = (labelAreaSize.width - resolvedWidth) / 2
        let rightBound = leftBound + resolvedWidth
        let minX = leftBound + halfWidth + horizontalPadding
        let maxX = rightBound - halfWidth - horizontalPadding
        let totalRange = range.upperBound.timeIntervalSince(range.lowerBound)
        let rawPercent = totalRange > 0
            ? plotDate(for: point).timeIntervalSince(range.lowerBound) / totalRange
            : 0
        let xPercent = CGFloat(rawPercent)
        let clampedPercent = min(max(xPercent, 0), 1)
        let targetX = leftBound + (rightBound - leftBound) * clampedPercent
        let clampedX: CGFloat
        if maxX >= minX {
            clampedX = min(max(targetX, minX), maxX)
        } else {
            let fallbackMinX = halfWidth + horizontalPadding
            let fallbackMaxX = labelAreaSize.width - halfWidth - horizontalPadding
            clampedX = min(max(targetX, fallbackMinX), fallbackMaxX)
        }
        let minY = halfHeight + verticalPadding
        let maxY = labelAreaSize.height - halfHeight - verticalPadding
        let fixedYPercent: CGFloat = 0.35
        let targetY = minY + (maxY - minY) * fixedYPercent
        return CGPoint(x: clampedX, y: targetY)
    }

    private func plotDate(for point: MetricPoint) -> Date {
        if let range = point.range {
            let halfInterval = range.duration / 2
            return range.start.addingTimeInterval(halfInterval)
        }
        return calendar.date(byAdding: .hour, value: 12, to: point.date) ?? point.date
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

    private func selectionDate(for point: MetricPoint) -> Date {
        point.range?.end ?? point.date
    }

}

private struct ValueLabelSizeKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct MetricPoint: Identifiable, Equatable {
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

private struct MetricPoints {
    let totalLoad: [MetricPoint]
    let maxRM: [MetricPoint]
    let maxWeight: [MetricPoint]

    var isEmpty: Bool {
        totalLoad.isEmpty && maxRM.isEmpty && maxWeight.isEmpty
    }

    static let empty = MetricPoints(totalLoad: [], maxRM: [], maxWeight: [])
}

private enum GraphMetric: String, CaseIterable, Identifiable {
    case totalLoad
    case maxRM
    case maxWeight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .totalLoad:
            return "総負荷量"
        case .maxRM:
            return "最大RM"
        case .maxWeight:
            return "最大重量"
        }
    }
}

private enum GraphPeriod: String, CaseIterable, Identifiable {
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
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        }
    }
}

private extension Calendar {
    static var japaneseLocale: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private extension View {
    @ViewBuilder
    func applyIfAvailable<V: View>(_ transform: (Self) -> V) -> some View {
        if #available(iOS 17.0, *) {
            transform(self)
        } else {
            self
        }
    }
}
