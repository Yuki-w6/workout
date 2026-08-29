@preconcurrency import Foundation
import CoreData
import SwiftData
import UIKit

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let exerciseRepository: ExerciseRepository

    private var observers: [NSObjectProtocol] = []
    private var normalizeTask: Task<Void, Never>?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // 正規化はmainContextで行を削除する。repositoryが別コンテキストだと、
        // UIが握っているインスタンスだけが取り残されて無効化アクセスで落ちるため、同じコンテキストを使う。
        exerciseRepository = SwiftDataExerciseRepository(context: modelContainer.mainContext)
        observeStoreChanges()
    }

    deinit {
        normalizeTask?.cancel()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // CloudKitのインポートは起動処理より後に届く。起動時の1回だけ正規化しても、
    // インポート後に現れた同一IDの重複は掃除されないまま残ってしまう
    // (iPhoneはViewModel側のdedupeByIDで畳んで表示するため気付けず、Watchでだけ重複が見える)。
    // リモート変更とフォアグラウンド復帰のたびに正規化をやり直す。
    private func observeStoreChanges() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .NSPersistentStoreRemoteChange,
            UIApplication.didBecomeActiveNotification
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.scheduleNormalization()
                }
            }
        }
    }

    private func scheduleNormalization() {
        // 同期中は変更通知が連続で届くため、最後の1回にまとめる。
        normalizeTask?.cancel()
        normalizeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard Task.isCancelled == false, let self else { return }
            do {
                let changed = try Self.normalizePresetExercisesIfNeeded(context: self.modelContainer.mainContext)
                if changed {
                    NotificationCenter.default.post(name: .exercisesDidNormalize, object: nil)
                }
            } catch {
                // 中途半端な変更をUI用のmainContextに残さない。次の通知で再試行する。
                self.modelContainer.mainContext.rollback()
            }
        }
    }

    static func make(useCloud: Bool) async throws -> (container: AppContainer, warningMessage: String?) {
        let schema = Schema([Exercise.self, ExerciseTemplateSet.self, RecordHeader.self, RecordSet.self])
        let configuration: ModelConfiguration
        if useCloud {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.mayamayk.workoutlog")
            )
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        let modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        let container = AppContainer(modelContainer: modelContainer)
        // 種目の初期設定はbest-effort。ここで失敗しても既存の記録には触れないので、
        // 起動そのものを止めてしまうと記録にアクセスできなくなる方が損害が大きい。
        var warningMessage: String?
        do {
            try PresetExerciseSeeder(context: modelContainer.mainContext).seedIfNeeded()
            _ = try normalizePresetExercisesIfNeeded(context: modelContainer.mainContext)
            // スクリーンショット撮影用。種目が揃ってからでないと記録を紐付けられないので、
            // プリセットの初期設定より後に置く。
            try ScreenshotSampleData.seedIfNeeded(in: modelContainer.mainContext)
        } catch {
            modelContainer.mainContext.rollback()
            warningMessage = "種目の初期設定に失敗しました。次回起動時に再試行します。"
        }
        return (container, warningMessage)
    }

    /// 変更があった場合にtrueを返す。
    @discardableResult
    static func normalizePresetExercisesIfNeeded(context: ModelContext) throws -> Bool {
        var exercises = try context.fetch(FetchDescriptor<Exercise>())
        guard exercises.isEmpty == false else { return false }
        var didChangeAnything = false

        var records = try context.fetch(FetchDescriptor<RecordHeader>())
        var changed = false

        func updateRecordSnapshots(from oldID: UUID, to exercise: Exercise, source: Exercise? = nil) {
            for header in records {
                let idMatch = header.exerciseIDSnapshot == oldID
                let sourceMatch = source.map { header.exercise === $0 } ?? false
                guard idMatch || sourceMatch else { continue }
                header.exercise = exercise
                header.exerciseIDSnapshot = exercise.id
                header.exerciseNameSnapshot = exercise.name
                header.bodyPartRawSnapshot = exercise.bodyPartRaw
                header.defaultWeightUnitRawSnapshot = exercise.defaultWeightUnitRaw
                changed = true
            }
        }

        func moveTemplates(from source: Exercise, to target: Exercise) {
            guard let templates = source.templateSets else { return }
            for template in templates {
                template.exercise = target
                changed = true
            }
        }

        // まずは同一IDの重複を解消（並び順で参照が揺れないようにする）
        let groupedByID = Dictionary(grouping: exercises, by: { $0.id })
        for (_, group) in groupedByID where group.count > 1 {
            let canonical = group.first { $0.isPreset || $0.seedKey != nil } ?? group[0]
            // 残す1件はフェッチ順で決まるため、アーカイブ状態を明示的にマージしないと
            // 未アーカイブ側が勝った瞬間に削除が巻き戻る。削除を優先する。
            let isArchivedInGroup = group.contains { $0.isArchived }
            if canonical.isArchived != isArchivedInGroup {
                canonical.isArchived = isArchivedInGroup
                changed = true
            }
            for exercise in group where exercise !== canonical {
                if canonical.isPreset == false && (exercise.isPreset || exercise.seedKey != nil) {
                    canonical.isPreset = exercise.isPreset
                    canonical.seedKey = exercise.seedKey
                    canonical.seedVersion = exercise.seedVersion
                    canonical.presetSortKey = exercise.presetSortKey
                    changed = true
                }
                updateRecordSnapshots(from: exercise.id, to: canonical, source: exercise)
                moveTemplates(from: exercise, to: canonical)
                context.delete(exercise)
                changed = true
            }
        }

        if changed {
            try context.save()
            didChangeAnything = true
            exercises = try context.fetch(FetchDescriptor<Exercise>())
            records = try context.fetch(FetchDescriptor<RecordHeader>())
            changed = false
        }

        // 直前の重複解消で一意になっているはずだが、CloudKitのインポートは
        // save()とfetch()の間にも割り込む。uniqueKeysWithValuesは重複キーで実行時トラップするため、
        // 取りこぼしがあってもクラッシュしないよう先勝ちで畳む(canonicalの選び方と同じ)。
        var exerciseByID: [UUID: Exercise] = Dictionary(
            exercises.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for preset in PresetExerciseDefinitions.all {
            let matches = exercises.filter {
                $0.id == preset.id || $0.seedKey == preset.seedKey
            }
            guard matches.isEmpty == false else { continue }

            let canonical: Exercise
            if let existing = exerciseByID[preset.id] {
                canonical = existing
            } else {
                let created = Exercise(
                    id: preset.id,
                    name: preset.name,
                    bodyPart: preset.bodyPart,
                    defaultWeightUnit: preset.defaultWeightUnit,
                    isPreset: true,
                    seedKey: preset.seedKey,
                    seedVersion: preset.seedVersion,
                    isArchived: matches.contains { $0.isArchived }
                )
                context.insert(created)
                exerciseByID[preset.id] = created
                canonical = created
                changed = true
            }

            // allSatisfyだと「1件でも未アーカイブなら復活」に倒れ、削除が取り消される。
            let shouldBeArchived = matches.contains { $0.isArchived }
            // name / bodyPart / defaultWeightUnit はユーザーが編集できるフィールドなので上書きしない。
            // 正規化はリモート変更のたびに走るため、上書きすると改名や単位変更が数秒で巻き戻る。
            if canonical.isPreset == false ||
                canonical.seedKey != preset.seedKey ||
                canonical.seedVersion != preset.seedVersion ||
                canonical.presetSortKey != 0 ||
                canonical.isArchived != shouldBeArchived {
                canonical.isPreset = true
                canonical.seedKey = preset.seedKey
                canonical.seedVersion = preset.seedVersion
                canonical.presetSortKey = 0
                canonical.isArchived = shouldBeArchived
                changed = true
            }

            for exercise in matches where exercise.id != canonical.id {
                updateRecordSnapshots(from: exercise.id, to: canonical, source: exercise)
                moveTemplates(from: exercise, to: canonical)
                context.delete(exercise)
                changed = true
            }
        }

        // レコードの参照先が間違っている場合の修正（プリセット同士の誤結合だけ直す）
        // 定義が一意であることは PresetExerciseSeederTests で担保する。
        // 万一重複してもここで起動時クラッシュにはしない。
        let presetBySignature: [String: PresetExerciseDefinition] = Dictionary(
            PresetExerciseDefinitions.all.map {
                ("\($0.name)|\($0.bodyPart.rawValue)", $0)
            },
            uniquingKeysWith: { first, _ in first }
        )
        for header in records {
            guard let linked = header.exercise, linked.isPreset else { continue }
            let signature = "\(header.exerciseNameSnapshot)|\(header.bodyPartRawSnapshot)"
            guard let preset = presetBySignature[signature] else { continue }
            guard preset.id != header.exerciseIDSnapshot else { continue }
            if let target = exerciseByID[preset.id] {
                header.exercise = target
                header.exerciseIDSnapshot = target.id
                changed = true
            }
        }

        if changed {
            try context.save()
            didChangeAnything = true
        }

        return didChangeAnything
    }
}

extension Notification.Name {
    /// 正規化で種目に変更が入ったことを通知する。
    /// 画面はこれを受けて再読込しないと、削除済みインスタンスを掴み続けて無効化アクセスで落ちる。
    static let exercisesDidNormalize = Notification.Name("exercisesDidNormalize")
}
