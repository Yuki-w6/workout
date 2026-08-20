import Foundation
import SwiftData
import Testing
@testable import WorkoutLogJP2026WOD01

/// CloudKitのインポートで同じ `id` の Exercise が二重に入った状態を再現し、
/// 正規化が実体を1件に畳めることを確認する。
/// (iPhoneのUIは dedupeByID で畳んで表示するため重複に気付けず、Watchでだけ二重に見える)
@MainActor
struct AppContainerNormalizationTests {
    private func insertPresetDuplicate(
        _ preset: PresetExerciseDefinition,
        into context: ModelContext
    ) -> Exercise {
        let exercise = Exercise(
            id: preset.id,
            name: preset.name,
            bodyPart: preset.bodyPart,
            defaultWeightUnit: preset.defaultWeightUnit,
            isPreset: true,
            seedKey: preset.seedKey,
            seedVersion: preset.seedVersion
        )
        context.insert(exercise)
        return exercise
    }

    @Test func collapsesDuplicatePresetsSharingTheSameID() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let preset = PresetExerciseDefinitions.all[0]

        _ = insertPresetDuplicate(preset, into: context)
        _ = insertPresetDuplicate(preset, into: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 2)

        try AppContainer.normalizePresetExercisesIfNeeded(context: context)

        let remaining = try context.fetch(FetchDescriptor<Exercise>())
        #expect(remaining.count == 1)
        #expect(remaining[0].id == preset.id)
        #expect(remaining[0].isPreset)
    }

    /// 重複のうち片方に記録がぶら下がっていても、記録は残った側に付け替えられること。
    @Test func movesRecordsToTheSurvivingDuplicate() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let preset = PresetExerciseDefinitions.all[0]

        _ = insertPresetDuplicate(preset, into: context)
        let second = insertPresetDuplicate(preset, into: context)

        let header = RecordHeader(date: Date(), exercise: second)
        context.insert(header)
        let set = RecordSet(setNumber: 1, weight: 60, weightUnit: .kg, repetitions: 5, header: header)
        context.insert(set)
        header.sets = [set]
        try context.save()

        try AppContainer.normalizePresetExercisesIfNeeded(context: context)

        let remaining = try context.fetch(FetchDescriptor<Exercise>())
        #expect(remaining.count == 1)

        let headers = try context.fetch(FetchDescriptor<RecordHeader>())
        #expect(headers.count == 1)
        #expect(headers[0].exerciseIDSnapshot == preset.id)
        #expect(headers[0].exercise?.id == remaining[0].id)
        // 記録が生き残った側に付いていないと、この種目は「記録あり」と判定されず削除できてしまう。
        #expect(headers[0].hasRecordedSets)
    }

    /// 同期が繰り返されて3件以上に増えた場合も1件に畳めること。
    @Test func collapsesMoreThanTwoCopies() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let first = PresetExerciseDefinitions.all[0]
        let second = PresetExerciseDefinitions.all[1]

        for _ in 0..<3 {
            _ = insertPresetDuplicate(first, into: context)
        }
        for _ in 0..<2 {
            _ = insertPresetDuplicate(second, into: context)
        }
        try context.save()

        try AppContainer.normalizePresetExercisesIfNeeded(context: context)

        let remaining = try context.fetch(FetchDescriptor<Exercise>())
        #expect(remaining.count == 2)
        #expect(Set(remaining.map { $0.id }) == [first.id, second.id])
    }

    /// 重複が無いときは何も壊さないこと。
    @Test func keepsStoreIntactWhenThereAreNoDuplicates() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        try PresetExerciseSeeder(context: context, keyStore: NoopKeyStore()).seedIfNeeded()

        try AppContainer.normalizePresetExercisesIfNeeded(context: context)

        let remaining = try context.fetch(FetchDescriptor<Exercise>())
        #expect(remaining.count == PresetExerciseDefinitions.all.count)
        #expect(Set(remaining.map { $0.id }).count == remaining.count)
    }
}

private final class NoopKeyStore: SeededPresetKeyStore {
    private var keys: Set<String> = []
    func load() -> Set<String> { keys }
    func save(_ keys: Set<String>) { self.keys = keys }
}
