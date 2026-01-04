import SwiftUI
import SwiftData
import Charts

struct GraphView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    @Query(sort: \RecordHeader.date) private var records: [RecordHeader]
    @State private var selectedBodyPart: BodyPart = .chest
    @State private var selectedExerciseId: UUID?
    @State private var selectedPeriod: GraphPeriod = .threeMonths
    @State private var selectedTotalLoadPoint: MetricPoint?
    @State private var selectedMaxRMPoint: MetricPoint?
    @State private var selectedMaxWeightPoint: MetricPoint?
    @State private var tooltipSize: CGSize = .zero

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
        }
        .onAppear {
            viewModel.load()
            syncExerciseSelection()
        }
        .onChange(of: selectedBodyPart) { _, _ in
            syncExerciseSelection()
        }
        .onChange(of: viewModel.exercises) { _, _ in
            syncExerciseSelection()
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
                }
                .padding(.horizontal, 2)
            }

            Picker("期間", selection: $selectedPeriod) {
                ForEach(GraphPeriod.allCases) { period in
                    Text(period.title)
                        .tag(period)
                }
            }
            .pickerStyle(.segmented)
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
                    title: "総負荷量",
                    points: metrics.totalLoad,
                    range: periodRange,
                    selectedPoint: $selectedTotalLoadPoint
                )
                chartBlock(
                    title: "最大RM",
                    points: metrics.maxRM,
                    range: periodRange,
                    selectedPoint: $selectedMaxRMPoint
                )
                chartBlock(
                    title: "最大重量",
                    points: metrics.maxWeight,
                    range: periodRange,
                    selectedPoint: $selectedMaxWeightPoint
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
        let end = Date()
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("日付", point.date),
                        y: .value("値", point.value)
                    )
                    PointMark(
                        x: .value("日付", point.date),
                        y: .value("値", point.value)
                    )
                }
                if let point = selectedPoint.wrappedValue {
                    RuleMark(x: .value("日付", point.date))
                        .foregroundStyle(.secondary)
                }
            }
            .chartXScale(domain: chartRange(for: range))
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel(axisDateLabel(date))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
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

                        if let point = selectedPoint.wrappedValue,
                           let xPos = proxy.position(forX: point.date),
                           let yPos = proxy.position(forY: point.value),
                           let plotFrameAnchor = proxy.plotFrame {
                            let plotFrame = geometry[plotFrameAnchor]
                            let position = tooltipPosition(
                                xPos: xPos,
                                yPos: yPos,
                                plotFrame: plotFrame
                            )
                            tooltipView(for: point)
                                .position(x: position.x, y: position.y)
                                .zIndex(1)
                        }
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
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private func formattedValue(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func axisDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private var selectedExerciseLabel: String {
        selectedExercise?.name ?? "種目を選択"
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
        let paddingDays = 3
        let start = calendar.date(byAdding: .day, value: -paddingDays, to: range.lowerBound) ?? range.lowerBound
        let end = calendar.date(byAdding: .day, value: paddingDays, to: range.upperBound) ?? range.upperBound
        return start...end
    }

    private func tooltipView(for point: MetricPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate(point.date))
                .font(.caption)
            Text("値(kg): \(formattedValue(point.value))")
                .font(.caption)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .shadow(radius: 2)
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: TooltipSizeKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(TooltipSizeKey.self) { size in
            guard size != .zero else {
                return
            }
            DispatchQueue.main.async {
                tooltipSize = size
            }
        }
    }

    private func tooltipPosition(
        xPos: CGFloat,
        yPos: CGFloat,
        plotFrame: CGRect
    ) -> CGPoint {
        let rawX = xPos + plotFrame.minX
        let rawY = yPos + plotFrame.minY - 28
        let paddedHalfWidth = tooltipSize.width / 2 + 6
        let paddedHalfHeight = tooltipSize.height / 2 + 6
        let minX = plotFrame.minX + paddedHalfWidth
        let maxX = plotFrame.maxX - paddedHalfWidth
        let minY = plotFrame.minY + paddedHalfHeight
        let maxY = plotFrame.maxY - paddedHalfHeight
        var adjustedY = rawY
        if adjustedY - paddedHalfHeight < plotFrame.minY {
            adjustedY = yPos + plotFrame.minY + 28
        }
        adjustedY = min(max(adjustedY, minY), maxY)
        let clampedX = min(max(rawX, minX), maxX)
        return CGPoint(x: clampedX, y: adjustedY)
    }
}

private struct MetricPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
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

private enum GraphPeriod: String, CaseIterable, Identifiable {
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneMonth:
            return "1ヶ月"
        case .threeMonths:
            return "3ヶ月"
        case .sixMonths:
            return "6ヶ月"
        case .oneYear:
            return "1年"
        }
    }

    func startDate(endingAt endDate: Date, calendar: Calendar) -> Date {
        switch self {
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

private struct TooltipSizeKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
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
