import Foundation
import SwiftData
import WorkoutShared

// App Store用スクリーンショットをシミュレータで撮影するためのサンプルデータ。
// シミュレータにはiCloudアカウントが無くiPhoneからの同期も行われないため、
// このシードが無いと種目が1件も無い空の画面しか撮影できない。
//
// 本番のアプリ配信に影響しないよう、DEBUGビルドかつシミュレータ実行時のみ動作する。
enum WatchSampleData {
#if DEBUG && targetEnvironment(simulator)
    /// 種目が1件も無いときだけサンプルの種目と記録を投入する。
    /// 既にデータがある場合は何もしないため、繰り返し呼び出しても安全。
    static func seedIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard existing.isEmpty else { return }

        let definitions: [(name: String, bodyPart: BodyPart)] = [
            ("ベンチプレス", .chest),
            ("チェストプレス", .chest),
            ("デットリフト", .back),
            ("ラットプルダウン", .back),
            ("スクワット", .legs),
            ("レッグプレス", .legs),
            ("ショルダープレス", .shoulders),
            ("アームカール", .arms)
        ]

        let exercises = definitions.map { definition in
            let exercise = Exercise(
                name: definition.name,
                bodyPart: definition.bodyPart,
                defaultWeightUnit: .kg
            )
            context.insert(exercise)
            return exercise
        }

        // 記録済みセットの一覧や、次のセットの重量サジェストが自然に見えるよう、
        // 代表的な種目に当日の記録を入れておく。
        seedTodayRecord(for: exercises[0], sets: [(60, 10), (65, 8), (70, 6)], in: context)
        seedTodayRecord(for: exercises[4], sets: [(80, 10), (90, 8)], in: context)

        try? context.save()
    }

    private static func seedTodayRecord(
        for exercise: Exercise,
        sets: [(weight: Double, reps: Int)],
        in context: ModelContext
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        let header = RecordHeader(date: calendar.startOfDay(for: Date()), exercise: exercise)
        context.insert(header)

        let recordSets = sets.enumerated().map { index, set in
            let recordSet = RecordSet(
                setNumber: index + 1,
                weight: set.weight,
                weightUnit: exercise.defaultWeightUnit,
                repetitions: set.reps,
                header: header
            )
            context.insert(recordSet)
            return recordSet
        }
        header.sets = recordSets
    }
#else
    static func seedIfNeeded(in context: ModelContext) {}
#endif
}
