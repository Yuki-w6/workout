import SwiftUI
import SwiftData

struct RecordListView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    @Query(sort: \RecordHeader.date) private var records: [RecordHeader]
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var toastMessage = ""
    @State private var isToastPresented = false
    private let recordListBannerAdUnitID: String? = Bundle.main.object(forInfoDictionaryKey: "RecordListBannerAdUnitID") as? String
    @Environment(\.modelContext) private var modelContext

    private let calendar = Calendar.japaneseLocale

    private var markedDates: Set<Date> {
        Set(records.map { calendar.startOfDay(for: $0.date) })
    }

    private var recordsForSelectedDate: [RecordHeader] {
        records.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    var body: some View {
        NavigationStack {
            Group {
                VStack(spacing: 12) {
                    HStack {
                        Button {
                            shiftMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        Spacer()
                        Text(monthTitle(for: monthStart))
                            .font(.headline)
                        Spacer()
                        Button {
                            shiftMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding(.horizontal)

                    CalendarMonthView(
                        month: monthStart,
                        selectedDate: $selectedDate,
                        markedDates: markedDates
                    )
                    .padding(.horizontal)

                    List {
                        if recordsForSelectedDate.isEmpty {
                            Text("記録はありません")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(recordsForSelectedDate, id: \.id) { record in
                                RecordSection(
                                    record: record,
                                    viewModel: viewModel,
                                    onDelete: deleteDetail(_:in:),
                                    onToast: showToast(_:)
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                .padding(.top, 20)
            }
            .toast(message: toastMessage, isPresented: $isToastPresented)
            .safeAreaInset(edge: .bottom) {
                if let adUnitID = recordListBannerAdUnitID, !adUnitID.isEmpty {
                    BannerAdView(adUnitID: adUnitID)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) {
            isToastPresented = true
        }
    }

    private func deleteDetail(_ detail: RecordSet, in record: RecordHeader) {
        var details = record.sets ?? []
        if let index = details.firstIndex(where: { $0.id == detail.id }) {
            details.remove(at: index)
        }
        modelContext.delete(detail)
        let sorted = details.sorted { $0.setNumber < $1.setNumber }
        if sorted.isEmpty {
            modelContext.delete(record)
        } else {
            for (index, item) in sorted.enumerated() {
                item.setNumber = index + 1
            }
            record.sets = sorted
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }

    private func shiftMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: monthStart) {
            displayedMonth = newMonth
            selectedDate = newMonth
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
}

private struct CalendarMonthView: View {
    let month: Date
    @Binding var selectedDate: Date
    let markedDates: Set<Date>

    private let calendar = Calendar.japaneseLocale

    private var days: [Date?] {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = range.count
        let total = leading + daysInMonth
        return (0..<total).map { index in
            guard index >= leading else { return nil }
            let dayOffset = index - leading
            return calendar.date(byAdding: .day, value: dayOffset, to: firstDay)
        }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        VStack(spacing: 8) {
            let symbols = weekdaySymbols()
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isMarked = markedDates.contains(calendar.startOfDay(for: date))
                        let isToday = calendar.isDateInToday(date)
                        Button {
                            selectedDate = date
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.subheadline)
                                    .foregroundStyle(isToday ? Color.appPink : Color.primary)
                                    .frame(maxWidth: .infinity)
                                Circle()
                                    .fill(isMarked ? Color.appPink : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .padding(6)
                            .background(isSelected ? Color.appPink.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
        }
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let shift = max(calendar.firstWeekday - 1, 0)
        if shift == 0 {
            return symbols
        }
        return Array(symbols[shift...]) + symbols[..<shift]
    }
}

private struct RecordSection: View {
    let record: RecordHeader
    let viewModel: ExerciseListViewModel
    let onDelete: (RecordSet, RecordHeader) -> Void
    let onToast: (String) -> Void

    private var exerciseName: String {
        let name = record.exercise?.name ?? record.exerciseNameSnapshot
        return name.isEmpty ? "種目不明" : name
    }

    private var sortedDetails: [RecordSet] {
        (record.sets ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    var body: some View {
        Section(exerciseName) {
            ForEach(sortedDetails, id: \.id) { detail in
                NavigationLink {
                    ExerciseDetailView(
                        viewModel: viewModel,
                        exerciseID: record.exerciseIDSnapshot,
                        exercise: record.exercise,
                        isNewRecord: false,
                        initialDate: record.date,
                        onSave: { message in
                            onToast(message)
                        }
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("セット\(detail.setNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(detail.weight, specifier: "%.1f") \(detail.weightUnit.rawValue) × \(detail.repetitions)回")
                            .font(.headline)
                        if let memo = detail.memo, !memo.isEmpty {
                            Text(memo)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onDelete(detail, record)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
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
