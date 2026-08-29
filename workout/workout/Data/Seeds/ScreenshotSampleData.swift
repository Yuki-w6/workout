import Foundation
import SwiftData

// App Store用スクリーンショットをシミュレータで撮影するためのサンプルデータ。
// 半年ほど使い込んだ状態を再現する。これが無いと、プリセットの種目が並ぶだけで
// 記録が1件も無い画面しか撮れず、グラフも前回重量のサジェストも写らない。
//
// 本番のアプリ配信に影響しないよう、DEBUGビルドかつシミュレータ実行時に、
// 起動引数 -screenshot-data が指定されたときだけ動作する。
enum ScreenshotSampleData {
    /// Xcode Scheme > Run > Arguments に追加して使う。
    static let launchArgument = "-screenshot-data"

#if DEBUG && targetEnvironment(simulator)

    /// 何週ぶんの履歴を作るか。グラフの「6か月」まで埋まる長さにしてある。
    private static let weeks = 26

    /// 撮りたい画面ごとに、今日の記録の有無を出し分ける。
    /// 週3回の分割法として組む。全種目を同じ曜日に置くとカレンダーの点が一列に並び、
    /// 一目で作り物とわかってしまうため、部位ごとに曜日をずらす。
    ///
    /// 曜日は固定せず「今日から何日前か」で決める。撮影日が何曜日でも
    /// 次の2つが必ず成り立つようにするため:
    /// - 脚の日(dayOffsetInWeek = 0)は今日に当たる → 記録一覧とカレンダーが埋まる
    /// - 胸の日(dayOffsetInWeek = 5)は今日に当たらない → 入力画面で
    ///   「前回の重量が最初から入っている」状態を撮れる
    private struct Plan {
        let seedKey: String
        let startWeight: Double
        /// 1週あたりの増加量。実際には下の揺らぎが乗るので、この通りには増えない。
        let weeklyGain: Double
        /// セットごとの回数。要素数がそのままセット数になる。
        let reps: [Int]
        /// その週のトレーニング日を、今日から何日前に置くか。同じ値の種目は同じ日にやる。
        let dayOffsetInWeek: Int
    }

    private static let plans: [Plan] = [
        // 脚の日(今日)
        Plan(seedKey: "squat", startWeight: 50, weeklyGain: 1.6, reps: [10, 8, 8], dayOffsetInWeek: 0),
        Plan(seedKey: "leg_press", startWeight: 70, weeklyGain: 2.0, reps: [12, 10, 10], dayOffsetInWeek: 0),
        // 背中の日(2日前)
        Plan(seedKey: "deadlift", startWeight: 60, weeklyGain: 1.8, reps: [8, 6, 5], dayOffsetInWeek: 2),
        Plan(seedKey: "lat_pulldown", startWeight: 35, weeklyGain: 0.9, reps: [12, 10, 8], dayOffsetInWeek: 2),
        // 胸・肩・腕の日(5日前)。入力画面のサジェスト撮影はこの日の種目で行う。
        Plan(seedKey: "bench_press", startWeight: 40, weeklyGain: 1.2, reps: [10, 8, 6], dayOffsetInWeek: 5),
        Plan(seedKey: "shoulder_press", startWeight: 20, weeklyGain: 0.6, reps: [12, 10, 8], dayOffsetInWeek: 5),
        Plan(seedKey: "arm_curl", startWeight: 10, weeklyGain: 0.4, reps: [15, 12, 10], dayOffsetInWeek: 5)
    ]

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// 記録が1件も無いときだけ投入する。既に記録があれば何もしないので、繰り返し起動しても安全。
    static func seedIfNeeded(in context: ModelContext) throws {
        guard isRequested else {
            return
        }
        let existingRecords = try context.fetch(FetchDescriptor<RecordHeader>())
        guard existingRecords.isEmpty else {
            return
        }

        // 記録を付ける種目だけを実体化すると、実体化済みと未実体化の種目が
        // 別々に並んで一覧の順序が実際のアプリと変わってしまう。全件揃える。
        var exercises = try context.fetch(FetchDescriptor<Exercise>())
        for definition in PresetExerciseDefinitions.all where !exercises.contains(where: { $0.seedKey == definition.seedKey }) {
            exercises.append(makePresetExercise(from: definition, in: context))
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        let today = calendar.startOfDay(for: Date())

        // 撮り直すたびにグラフの形が変わると、撮影済みのカットと揃わなくなる。
        // 乱数は固定シードにして、同じ起動引数からは必ず同じ履歴が出るようにする。
        var noise = SeededGenerator(seed: 20260829)

        for plan in plans {
            guard let exercise = materializedExercise(for: plan.seedKey, existing: exercises, in: context) else {
                continue
            }
            // 古い週から順に作る。SetProgressionPredictorは直近セッションとの差分を見るため、
            // 日付の並びが崩れているとサジェストが不自然になる。
            for weeksAgo in stride(from: weeks, through: 0, by: -1) {
                let daysAgo = weeksAgo * 7 + plan.dayOffsetInWeek
                guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                    continue
                }
                let elapsedWeeks = Double(weeks - weeksAgo)
                // 一本調子に伸ばすとグラフが直線になって作り物に見える。停滞と微減を混ぜる。
                let drift = noise.nextDouble(in: -2.5...2.0)
                let baseWeight = plan.startWeight + plan.weeklyGain * elapsedWeeks + drift
                insertRecord(
                    for: exercise,
                    on: date,
                    baseWeight: baseWeight,
                    reps: plan.reps,
                    in: context
                )
            }
        }

        try context.save()
    }

    /// シミュレータにはiCloudアカウントが無く、PresetExerciseSeeder が使う
    /// NSUbiquitousKeyValueStore が機能しないため、プリセットが実体化されないまま
    /// 「未実体化の候補行」として表示されるだけのことがある。その状態では記録を
    /// 紐付ける先が無いので、必要な種目はここで作る。
    /// idとseedKeyはプリセット定義と同じものを使う。アプリ側の正規化処理が
    /// 同一種目とみなせるようにするため。
    private static func materializedExercise(
        for seedKey: String,
        existing: [Exercise],
        in context: ModelContext
    ) -> Exercise? {
        if let found = existing.first(where: { $0.seedKey == seedKey }) {
            return found
        }
        guard let definition = PresetExerciseDefinitions.all.first(where: { $0.seedKey == seedKey }) else {
            return nil
        }
        return makePresetExercise(from: definition, in: context)
    }

    private static func makePresetExercise(
        from definition: PresetExerciseDefinition,
        in context: ModelContext
    ) -> Exercise {
        let exercise = Exercise(
            id: definition.id,
            name: definition.name,
            bodyPart: definition.bodyPart,
            defaultWeightUnit: definition.defaultWeightUnit,
            isPreset: true,
            seedKey: definition.seedKey,
            seedVersion: definition.seedVersion
        )
        context.insert(exercise)
        return exercise
    }

    private static func insertRecord(
        for exercise: Exercise,
        on date: Date,
        baseWeight: Double,
        reps: [Int],
        in context: ModelContext
    ) {
        let header = RecordHeader(date: date, exercise: exercise)
        context.insert(header)

        let recordSets = reps.enumerated().map { index, repetitions in
            // セットが進むほど重量を落とす、という一般的な組み方に合わせる。
            let weight = roundToPlate(baseWeight - Double(index) * 2.5)
            let recordSet = RecordSet(
                setNumber: index + 1,
                weight: weight,
                weightUnit: exercise.defaultWeightUnit,
                repetitions: repetitions,
                header: header
            )
            context.insert(recordSet)
            return recordSet
        }
        header.sets = recordSets
    }

    /// 実際のプレートで作れない重量が並ぶと見た目に嘘が出るため、2.5kg刻みに丸める。
    private static func roundToPlate(_ weight: Double) -> Double {
        max(2.5, (weight / 2.5).rounded() * 2.5)
    }

    /// 固定シードの線形合同法。撮影のたびに同じ履歴を再現するためだけのもの。
    private struct SeededGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(state >> 11) / Double(UInt64(1) << 53)
            return range.lowerBound + unit * (range.upperBound - range.lowerBound)
        }
    }

#else
    static var isRequested: Bool { false }

    static func seedIfNeeded(in context: ModelContext) throws {}
#endif
}
