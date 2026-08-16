import SwiftUI
import SwiftData
import WorkoutShared

struct RecordInputView: View {
    let exercise: Exercise

    @State private var selectedPage: Int = 0
    @State private var editingSetNumber: Int?

    var body: some View {
        TabView(selection: $selectedPage) {
            RecordEntryPage(exercise: exercise, editingSetNumber: $editingSetNumber)
                .tag(0)
            SavedSetsPage(exercise: exercise) { setNumber in
                editingSetNumber = setNumber
                selectedPage = 0
            }
            .tag(1)
        }
        .tabViewStyle(.page)
        .navigationTitle(exercise.name)
    }
}

/// メインページ: 重さ・回数を入力し、記録して次のセットへ進む。
/// editingSetNumberが指定されている間は、その既存セットの更新モードになる。
private struct RecordEntryPage: View {
    let exercise: Exercise
    @Binding var editingSetNumber: Int?

    @Environment(\.modelContext) private var modelContext
    @Query private var todayHeaders: [RecordHeader]

    @State private var weight: Double
    @State private var reps: Int
    @State private var isSaving = false
    @FocusState private var isWeightFocused: Bool

    init(exercise: Exercise, editingSetNumber: Binding<Int?>) {
        self.exercise = exercise
        self._editingSetNumber = editingSetNumber
        let exerciseID = exercise.id
        let startOfDay = Calendar.japaneseLocale.startOfDay(for: Date())
        _todayHeaders = Query(
            filter: #Predicate<RecordHeader> { $0.exerciseIDSnapshot == exerciseID && $0.date == startOfDay }
        )
        _weight = State(initialValue: Self.defaultInitialWeight(for: exercise.defaultWeightUnit))
        _reps = State(initialValue: 8)
    }

    // 種目に記録が一件も無い場合のフォールバック値。kgは区切りの良い50kg、
    // lbは50kgをそのまま換算した110.23ではなく区切りの良い110lbsにする。
    private static func defaultInitialWeight(for unit: WeightUnit) -> Double {
        switch unit {
        case .kg:
            return 50
        case .lb:
            return 110
        }
    }

    private var todaySets: [RecordSet] {
        (todayHeaders.first?.sets ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    private var nextSetNumber: Int {
        (todaySets.map(\.setNumber).max() ?? 0) + 1
    }

    private var targetSetNumber: Int {
        editingSetNumber ?? nextSetNumber
    }

    private var isEditingExistingSet: Bool {
        editingSetNumber != nil
    }

    // 重さ・回数の数値表示を同じ幅にそろえ、＋／－ボタンが縦に一直線に並ぶようにする。
    private static let valueLabelWidth: CGFloat = 74

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    glassStepButton(systemName: "minus") {
                        weight = max(0, weight - 1)
                    }
                    Text("\(formatted(weight)) \(exercise.defaultWeightUnit.displayName)")
                        .font(.title3)
                        .frame(minWidth: Self.valueLabelWidth)
                        .focusable(true)
                        .focused($isWeightFocused)
                        .digitalCrownRotation(
                            $weight,
                            from: 0,
                            through: 500,
                            by: 0.1,
                            sensitivity: .low,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                    glassStepButton(systemName: "plus") {
                        weight = min(500, weight + 1)
                    }
                }

                HStack(spacing: 16) {
                    glassStepButton(systemName: "minus") {
                        reps = max(1, reps - 1)
                    }
                    Text("\(reps) 回")
                        .font(.title3)
                        .frame(minWidth: Self.valueLabelWidth)
                    glassStepButton(systemName: "plus") {
                        reps = min(50, reps + 1)
                    }
                }
                .padding(.top, 16)

                Button("セット\(targetSetNumber)を\(isEditingExistingSet ? "更新" : "記録")") {
                    saveTargetSet()
                }
                .buttonStyle(.borderedProminent)
                .tint(.actionOrange)
                .padding(.top, 20)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .task(id: targetSetNumber) {
            loadValues(for: targetSetNumber)
        }
        .onAppear {
            isWeightFocused = true
            ensureTodayHeaderExists()
        }
    }

    // その日最初のセットを記録する瞬間だけ、新規RecordHeaderの作成(CloudKit連携込み)で
    // 保存が遅くなることが実機計測で判明した。画面を開いた時点(ユーザーがまだ重さ・回数を
    // 調整している間)で空のヘッダーだけ先に作っておき、記録ボタンを押す瞬間の処理を
    // セット追加だけの軽い処理に減らす。sets が0件のヘッダーは「記録がある」扱いに
    // ならないよう、RecordHeader.hasRecordedSetsを見る箇所を各画面で修正済み。
    private func ensureTodayHeaderExists() {
        guard todayHeaders.first == nil else { return }
        let startOfDay = Calendar.japaneseLocale.startOfDay(for: Date())
        let header = RecordHeader(date: startOfDay, exercise: exercise)
        modelContext.insert(header)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }

    private func loadValues(for setNumber: Int) {
        if let existingSet = todaySets.first(where: { $0.setNumber == setNumber }) {
            weight = existingSet.weight
            reps = existingSet.repetitions
        } else {
            applySuggestion()
        }
    }

    private func applySuggestion() {
        guard let lastSet = todaySets.last else {
            applyFirstSetSuggestion()
            return
        }
        applySubsequentSetSuggestion(after: lastSet)
    }

    private func applyFirstSetSuggestion() {
        let repository = SwiftDataRecordRepository(context: modelContext)
        let history = (try? repository.fetchHeaders(for: exercise.id)) ?? []

        // 予測・平均ではなく、前回そのままの1セット目の重量・回数を初期値にする。
        let lastFirstSet = history
            .sorted { $0.date > $1.date }
            .compactMap { header in
                (header.sets ?? [])
                    .filter { $0.weightUnit == exercise.defaultWeightUnit }
                    .first { $0.setNumber == 1 }
            }
            .first

        if let lastFirstSet {
            weight = lastFirstSet.weight
            reps = lastFirstSet.repetitions
        } else {
            weight = Self.defaultInitialWeight(for: exercise.defaultWeightUnit)
            reps = 8
        }
    }

    private func applySubsequentSetSuggestion(after lastSet: RecordSet) {
        let repository = SwiftDataRecordRepository(context: modelContext)
        let todayHeaderID = todayHeaders.first?.id
        let history = ((try? repository.fetchHeaders(for: exercise.id)) ?? [])
            .filter { $0.id != todayHeaderID }

        let progressionPredictor = SetProgressionPredictor()
        if let prediction = progressionPredictor.predictNextSet(
            todayWeights: todaySets.map(\.weight),
            todayReps: todaySets.map(\.repetitions),
            history: history,
            unit: exercise.defaultWeightUnit
        ) {
            weight = prediction.weight
            reps = prediction.reps
        }
    }

    private func saveTargetSet() {
        // 表示は変えず、連続タップによる二重記録だけを防ぐ。保存中にキューされた
        // 次のタップの実行時にはisSavingがもう false に戻ってしまっているため、
        // 解除を少し遅らせて連続タップ分を確実に無視する。
        guard !isSaving else { return }
        isSaving = true
        performSave()
        editingSetNumber = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isSaving = false
        }
    }

    private func performSave() {
        let startOfDay = Calendar.japaneseLocale.startOfDay(for: Date())
        let header: RecordHeader
        if let existing = todayHeaders.first {
            header = existing
        } else {
            // ensureTodayHeaderExists()が画面表示時に先に作っているはずだが、
            // 何らかの理由で無い場合のフォールバック。
            header = RecordHeader(date: startOfDay, exercise: exercise)
            modelContext.insert(header)
        }

        if let existingSet = todaySets.first(where: { $0.setNumber == targetSetNumber }) {
            existingSet.weight = weight
            existingSet.weightUnit = exercise.defaultWeightUnit
            existingSet.repetitions = reps
        } else {
            let newSet = RecordSet(
                setNumber: targetSetNumber,
                weight: weight,
                weightUnit: exercise.defaultWeightUnit,
                repetitions: reps,
                header: header
            )
            modelContext.insert(newSet)
            header.sets = (header.sets ?? []) + [newSet]
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}

/// リキッドグラス調の円形＋／－ボタン。透明感のあるガラスの枠に白いアイコンを乗せる。
private func glassStepButton(systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            // 見た目の円とタップ判定領域を一致させる。これが無いと円の端をタップした際に
            // 判定領域から外れ、押下アニメーションだけ動いてアクションが発火しないことがある。
            .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .glassEffect(.regular.interactive(), in: Circle())
}

/// 右スワイプで表示するページ: 保存済みセットの一覧。タップすると記録画面(左スワイプの画面)へ
/// 切り替わり、そのセットの更新モードで開く。NavigationLinkでの画面遷移はしないため、
/// 戻るボタンは種目一覧に戻るボタンのまま変わらない。
private struct SavedSetsPage: View {
    let exercise: Exercise
    let onSelectSet: (Int) -> Void

    @Query private var todayHeaders: [RecordHeader]

    init(exercise: Exercise, onSelectSet: @escaping (Int) -> Void) {
        self.exercise = exercise
        self.onSelectSet = onSelectSet
        let exerciseID = exercise.id
        let startOfDay = Calendar.japaneseLocale.startOfDay(for: Date())
        _todayHeaders = Query(
            filter: #Predicate<RecordHeader> { $0.exerciseIDSnapshot == exerciseID && $0.date == startOfDay }
        )
    }

    private var todaySets: [RecordSet] {
        (todayHeaders.first?.sets ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    var body: some View {
        Group {
            if todaySets.isEmpty {
                Text("まだ記録がありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(todaySets) { set in
                    Button("セット\(set.setNumber) ・ \(formatted(set.weight))\(set.weightUnit.displayName) × \(set.repetitions)") {
                        onSelectSet(set.setNumber)
                    }
                }
            }
        }
        .navigationTitle("記録済みセット")
    }
}

extension Color {
    // iOS本体(workoutApp.swift)のアプリカラーと合わせたオレンジ。
    static let actionOrange = Color(red: 0.992, green: 0.294, blue: 0.004)
}

private func formatted(_ value: Double) -> String {
    // Digital Crownは0.1kg刻みで調整できるため、Stepperの2.5kg刻みに合わせた
    // 0.5丸めのままだと微調整した値が表示上消えてしまう。0.1刻みに合わせる。
    let rounded = (value * 10).rounded() / 10
    return rounded.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", rounded)
        : String(format: "%.1f", rounded)
}

extension Calendar {
    // iPhone側(ExerciseDetailView等)と同じ定義。日付の起点計算を完全に一致させ、
    // 同日のRecordHeaderがCloudKit経由で重複せず1件に統合されるようにする。
    fileprivate static var japaneseLocale: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }
}
