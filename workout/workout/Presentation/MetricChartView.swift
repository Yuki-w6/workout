import SwiftUI
import Charts

/// 1つの指標の折れ線グラフ。点のタップ選択と横スクロールを持つ。
///
/// 選択状態(どの点を選んでいるか、カードをどこに置くか)をこのView自身が持つ。
/// 1画面に複数のグラフを並べるため、状態を親に置くと互いに干渉してしまう。
struct MetricChartView: View {
    let title: String
    /// 期間に応じて集計済みの点。集計は呼び出し側で行う。
    let points: [MetricPoint]
    let range: ClosedRange<Date>
    let period: GraphPeriod
    let unitLabel: String

    @State private var selectedPoint: MetricPoint?
    @State private var selectedDate: Date?
    @State private var hasAutoSelectedInitialPoint = false
    @State private var valueLabelSize: CGSize = .zero
    @State private var chartScrollPosition: Date = Date()
    @State private var selectedPointXInSpace: CGFloat?
    @State private var selectionCardFrame: CGRect?
    @State private var selectionCardSize: CGSize = .zero
    @State private var plotFrameInSpace: CGRect?
    @State private var selectionCardSizeTick = 0

    private let calendar = Calendar.japaneseLocale
    private let valueLabelAreaWidth: CGFloat = 320
    private let valueLabelAreaHeight: CGFloat = 56

    var body: some View {
        let xRange = chartRange(for: range)
        let yDomain = yRange(for: points)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ZStack {
                if let point = selectedPoint {
                    GeometryReader { proxy in
                        let containerFrame = proxy.frame(in: .named("GraphViewSpace"))
                        let targetXInSpace = selectedPointXInSpace ?? containerFrame.midX
                        let targetX = targetXInSpace - containerFrame.minX
                        let effectiveCardWidth = selectionCardSize.width > 0
                            ? selectionCardSize.width
                            : (selectionCardFrame?.width ?? 0)
                        let clampedX = cardCenterX(
                            inWidth: proxy.size.width,
                            cardWidth: effectiveCardWidth,
                            targetX: targetX
                        )
                        selectionSummaryView(for: point)
                            .background(
                                GeometryReader { cardProxy in
                                    Color.clear.preference(
                                        key: SummaryCardFrameKey.self,
                                        value: cardProxy.frame(in: .named("GraphViewSpace"))
                                    )
                                }
                            )
                            .background(
                                GeometryReader { sizeProxy in
                                    Color.clear.preference(
                                        key: SummaryCardSizeKey.self,
                                        value: sizeProxy.size
                                    )
                                }
                            )
                            .opacity(isSelectionLayoutReady ? 1 : 0)
                            .position(x: clampedX, y: proxy.size.height / 2)
                    }
                } else if let maxValue = visibleMaxValue(in: xRange, points: points) {
                    VStack(alignment: .leading, spacing: 4) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("最大")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(formattedValue(maxValue))
                                    .font(.system(size: 34, weight: .semibold))
                                Text(unitLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(visiblePeriodLabel(in: xRange))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 80, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .leading)
            Chart {
                RuleMark(x: .value("開始", xRange.lowerBound))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                if shouldShowMonthBoundaries(for: period) {
                    ForEach(monthBoundaryDates(in: xRange), id: \.self) { boundary in
                        RuleMark(x: .value("月境界", boundary))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                PointMark(
                    x: .value("範囲開始", xRange.lowerBound),
                    y: .value("値", yDomain.lowerBound)
                )
                .opacity(0.001)
                PointMark(
                    x: .value("範囲終了", xRange.upperBound),
                    y: .value("値", yDomain.lowerBound)
                )
                .opacity(0.001)
                ForEach(points) { point in
                    let xValue = plotDate(for: point)
                    LineMark(
                        x: .value("日付", xValue),
                        y: .value("値", point.value)
                    )
                    .foregroundStyle(Color.appAccent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Color.appAccent)
                    .symbol(.circle.strokeBorder(lineWidth: 2))
                    .interpolationMethod(.linear)
                }
                if let point = selectedPoint {
                    let xValue = plotDate(for: point)
                    RuleMark(x: .value("日付", xValue))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .zIndex(0)
                    PointMark(
                        x: .value("日付", xValue),
                        y: .value("値", point.value)
                    )
                    .symbolSize(80)
                    .foregroundStyle(Color.appAccent)
                    .zIndex(2)
                }
            }
            .chartXScale(domain: xRange)
            .chartXAxis {
                AxisMarks(values: axisStrideValues(for: period)) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel(axisDateLabel(date, period: period))
                            .offset(y: 2)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: gridlineValues(for: yDomain)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYScale(domain: yDomain)
            .applyIfAvailable { chart in
                chart
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: visibleDomainLength(for: period))
                    .chartScrollPosition(x: $chartScrollPosition)
                    .chartXSelection(value: $selectedDate)
            }
            .onChange(of: selectedDate) { _, newValue in
                guard let date = newValue else {
                    selectedPoint = nil
                    return
                }
                selectedPoint = nearestPoint(to: date, in: points)
            }
            .frame(height: 360)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateSelectionGeometry(proxy: proxy, geometry: geometry, point: selectedPoint)
                        }
                        .onChange(of: selectedPoint) { _, newPoint in
                            updateSelectionGeometry(proxy: proxy, geometry: geometry, point: newPoint)
                        }
                        .onChange(of: chartScrollPosition) { _, _ in
                            updateSelectionGeometry(proxy: proxy, geometry: geometry, point: selectedPoint)
                        }
                        .onChange(of: selectionCardSizeTick) { _, _ in
                            updateSelectionGeometry(proxy: proxy, geometry: geometry, point: selectedPoint)
                        }
                }
            }
        }
        .onPreferenceChange(SummaryCardFrameKey.self) { frame in
            DispatchQueue.main.async {
                selectionCardFrame = frame
            }
        }
        .onPreferenceChange(SummaryCardSizeKey.self) { size in
            DispatchQueue.main.async {
                selectionCardSize = size
                if size != .zero {
                    selectionCardSizeTick += 1
                }
            }
        }
        .onAppear {
            updateChartScrollPosition()
        }
        .onChange(of: points) { _, _ in
            updateSelectedPoint()
            updateChartScrollPosition()
        }
        .onChange(of: period) { _, _ in
            updateSelectedPoint()
            updateChartScrollPosition()
        }
    }

    /// 表示対象の点が入れ替わったときに、選択を持ち越さないようにする。
    private func updateSelectedPoint() {
        selectedPoint = nil
        selectedDate = nil
    }

    private func updateChartScrollPosition() {
        chartScrollPosition = scrollLowerBound(for: period, in: range)
    }

    private func nearestPoint(to date: Date, in points: [MetricPoint]) -> MetricPoint? {
        points.min { lhs, rhs in
            abs(plotDate(for: lhs).timeIntervalSince(date)) < abs(plotDate(for: rhs).timeIntervalSince(date))
        }
    }

    private func updateSelectionGeometry(
        proxy: ChartProxy?,
        geometry: GeometryProxy?,
        point: MetricPoint?
    ) {
        guard let point else {
            return
        }
        guard let proxy, let geometry, let plotFrameAnchor = proxy.plotFrame else {
            return
        }
        let plotFrame = geometry[plotFrameAnchor]
        let chartFrameInSpace = geometry.frame(in: .named("GraphViewSpace"))
        let plotFrameInSpace = CGRect(
            x: chartFrameInSpace.minX + plotFrame.minX,
            y: chartFrameInSpace.minY + plotFrame.minY,
            width: plotFrame.width,
            height: plotFrame.height
        )
        guard let xPosition = proxy.position(forX: plotDate(for: point)) else {
            return
        }
        let rawXInSpace = plotFrameInSpace.minX + xPosition
        let clampedXInSpace = min(max(rawXInSpace, plotFrameInSpace.minX), plotFrameInSpace.maxX)
        DispatchQueue.main.async {
            selectedPointXInSpace = clampedXInSpace
            self.plotFrameInSpace = plotFrameInSpace
        }
    }

    private func cardCenterX(inWidth width: CGFloat, cardWidth: CGFloat, targetX: CGFloat) -> CGFloat {
        guard cardWidth > 0 else {
            return min(max(targetX, 0), width)
        }
        let edgeInset: CGFloat = 12
        let halfWidth = cardWidth / 2
        let minCenter = halfWidth + edgeInset
        let maxCenter = max(width - halfWidth - edgeInset, minCenter)
        return min(max(targetX, minCenter), maxCenter)
    }

    private var isSelectionLayoutReady: Bool {
        selectedPointXInSpace != nil
            && plotFrameInSpace != nil
            && selectionCardFrame != nil
    }

    private func formattedValue(_ value: Double) -> String {
        String(format: "%.2f", value)
    }


    private func visibleDomainLength(for period: GraphPeriod) -> TimeInterval {
        let end = endOfCurrentSection(for: period)
        let start = period.startDate(endingAt: end, calendar: calendar)
        return end.timeIntervalSince(start)
    }

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

    private func axisDateLabel(_ date: Date) -> String {
        axisDateLabel(date, period: period)
    }

    private func axisDateLabel(_ date: Date, period: GraphPeriod) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        switch period {
        case .oneWeek:
            formatter.dateFormat = "E"
        case .oneMonth, .threeMonths:
            formatter.dateFormat = "d日"
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


    private func visiblePeriodLabel(in range: ClosedRange<Date>) -> String {
        let resolvedRange = clampedVisibleRange(in: range)
        let lower = calendar.startOfDay(for: resolvedRange.lowerBound)
        let upperAnchor = resolvedRange.upperBound.addingTimeInterval(-1)
        let upper = endOfDay(for: upperAnchor, fallback: lower)
        return formattedPeriodLabel(lower: lower, upper: upper)
    }

    private func visibleMaxValue(in range: ClosedRange<Date>, points: [MetricPoint]) -> Double? {
        let resolvedRange = clampedVisibleRange(in: range)
        let filtered = points.filter { point in
            let date = plotDate(for: point)
            return date >= resolvedRange.lowerBound && date <= resolvedRange.upperBound
        }
        guard !filtered.isEmpty else {
            return nil
        }
        return filtered.map(\.value).max()
    }

    private func selectionSummaryView(for point: MetricPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if point.isAverage {
                Text("平均")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formattedValue(point.value))
                    .font(.system(size: 30, weight: .semibold))
                Text(unitLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(selectionPeriodLabel(for: point))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func selectionPeriodLabel(for point: MetricPoint) -> String {
        if let range = point.range {
            let lower = calendar.startOfDay(for: range.start)
            let upperAnchor = range.end.addingTimeInterval(-1)
            let upper = endOfDay(for: upperAnchor, fallback: lower)
            if calendar.isDate(lower, inSameDayAs: upper) {
                return formattedSingleDateLabel(lower)
            }
            return formattedPeriodLabel(lower: lower, upper: upper)
        }
        let date = calendar.startOfDay(for: point.date)
        return formattedSingleDateLabel(date)
    }

    private func clampedVisibleRange(in range: ClosedRange<Date>) -> ClosedRange<Date> {
        let length = visibleDomainLength(for: period)
        let maxLower = range.upperBound.addingTimeInterval(-length)
        let clampedLower = min(max(chartScrollPosition, range.lowerBound), maxLower)
        let lower = max(clampedLower, range.lowerBound)
        let upper = min(lower.addingTimeInterval(length), range.upperBound)
        if upper <= lower {
            return range
        }
        return lower...upper
    }

    private func endOfDay(for date: Date, fallback: Date) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: dayStart)?.addingTimeInterval(-1)
            ?? fallback
    }

    private func formattedPeriodLabel(lower: Date, upper: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.dateFormat = "yyyy/MM/dd"
        let start = formatter.string(from: lower)
        let end = formatter.string(from: upper)
        return "\(start) - \(end)"
    }

    private func formattedSingleDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
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


    private func gridlineValues(for domain: ClosedRange<Double>) -> [Double] {
        let lower = domain.lowerBound
        let upper = domain.upperBound
        let span = upper - lower
        guard span > 0 else {
            return [lower]
        }
        let step = span / 3
        let rawTicks = [
            lower,
            lower + step,
            lower + step * 2,
            upper
        ]
        if shouldAlignTensGridlines {
            let aligned = rawTicks.map { roundToTen($0) }
            if alignedAreValid(aligned, lower: lower, upper: upper) {
                return aligned
            }
        }
        return rawTicks
    }

    private func roundUpToTen(_ value: Double) -> Double {
        ceil(value / 10) * 10
    }

    private func roundDownToTen(_ value: Double) -> Double {
        floor(value / 10) * 10
    }

    private func roundToTen(_ value: Double) -> Double {
        (value / 10).rounded() * 10
    }

    private func alignedAreValid(_ values: [Double], lower: Double, upper: Double) -> Bool {
        guard values.count == 4 else {
            return false
        }
        if values.contains(where: { $0 < lower || $0 > upper }) {
            return false
        }
        return values[0] < values[1] && values[1] < values[2] && values[2] < values[3]
    }

    private var shouldAlignTensGridlines: Bool {
        switch period {
        case .threeMonths, .sixMonths, .oneYear:
            return true
        case .oneWeek, .oneMonth:
            return false
        }
    }

    private func chartRange(for range: ClosedRange<Date>) -> ClosedRange<Date> {
        range
    }

    private func shouldShowMonthBoundaries(for period: GraphPeriod) -> Bool {
        switch period {
        case .oneMonth, .threeMonths:
            return true
        case .oneWeek, .sixMonths, .oneYear:
            return false
        }
    }

    private func monthBoundaryDates(in range: ClosedRange<Date>) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: range.lowerBound) else {
            return []
        }
        var dates: [Date] = []
        var current = calendar.date(byAdding: .month, value: 1, to: monthInterval.start) ?? monthInterval.start
        while current < range.upperBound {
            if current > range.lowerBound {
                dates.append(current)
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else {
                break
            }
            current = next
        }
        return dates
    }


    private func scrollLowerBound(for period: GraphPeriod, in range: ClosedRange<Date>) -> Date {
        let length = visibleDomainLength(for: period)
        let lower = range.upperBound.addingTimeInterval(-length)
        return max(lower, range.lowerBound)
    }

    private func valueLabelView(for point: MetricPoint) -> some View {
        Text("\(formattedValue(point.value))\(unitLabel)")
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
#if DEBUG
                    print("GraphView valueLabelSize:", size)
#endif
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

private struct SummaryCardFrameKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

private struct SummaryCardSizeKey: PreferenceKey {
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
