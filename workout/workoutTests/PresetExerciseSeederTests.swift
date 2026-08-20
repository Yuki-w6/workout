import Foundation
import SwiftData
import Testing
@testable import WorkoutLogJP2026WOD01

/// NSUbiquitousKeyValueStore の代わりにメモリ上で seedKey を保持するテスト用ストア。
private final class InMemorySeededPresetKeyStore: SeededPresetKeyStore {
    private(set) var keys: Set<String>
    private(set) var saveCount = 0

    init(keys: Set<String> = []) {
        self.keys = keys
    }

    func load() -> Set<String> {
        keys
    }

    func save(_ keys: Set<String>) {
        self.keys = keys
        saveCount += 1
    }
}

private func makeDefinitions() -> [PresetExerciseDefinition] {
    [
        PresetExerciseDefinition(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!,
            seedKey: "bench_press",
            seedVersion: 1,
            name: "ベンチプレス",
            bodyPart: .chest,
            defaultWeightUnit: .kg
        ),
        PresetExerciseDefinition(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000a2")!,
            seedKey: "squat",
            seedVersion: 1,
            name: "スクワット",
            bodyPart: .legs,
            defaultWeightUnit: .kg
        )
    ]
}

private func fetchExercises(_ context: ModelContext) throws -> [Exercise] {
    try context.fetch(FetchDescriptor<Exercise>())
}

struct PresetExerciseSeederTests {
    @Test func seedsAllPresetsIntoAnEmptyStore() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let keyStore = InMemorySeededPresetKeyStore()
        let definitions = makeDefinitions()

        let inserted = try PresetExerciseSeeder(
            context: context,
            keyStore: keyStore,
            definitions: definitions
        ).seedIfNeeded()

        #expect(Set(inserted) == ["bench_press", "squat"])

        let exercises = try fetchExercises(context)
        #expect(exercises.count == 2)
        // Watch側は Exercise レコードをそのままクエリするため、実体が isPreset で作られている必要がある。
        #expect(exercises.allSatisfy { $0.isPreset })
        #expect(exercises.allSatisfy { $0.isArchived == false })
        #expect(Set(exercises.map { $0.id }) == Set(definitions.map { $0.id }))
        #expect(keyStore.keys == ["bench_press", "squat"])
    }

    @Test func secondRunDoesNotDuplicate() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let keyStore = InMemorySeededPresetKeyStore()
        let definitions = makeDefinitions()

        try PresetExerciseSeeder(context: context, keyStore: keyStore, definitions: definitions)
            .seedIfNeeded()
        let inserted = try PresetExerciseSeeder(context: context, keyStore: keyStore, definitions: definitions)
            .seedIfNeeded()

        #expect(inserted.isEmpty)
        #expect(try fetchExercises(context).count == 2)
        // 変化が無いときはKVSへの書き込みも発生しない。
        #expect(keyStore.saveCount == 1)
    }

    @Test func doesNotResurrectAnArchivedPreset() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let keyStore = InMemorySeededPresetKeyStore()
        let definitions = makeDefinitions()

        try PresetExerciseSeeder(context: context, keyStore: keyStore, definitions: definitions)
            .seedIfNeeded()

        let repository = SwiftDataExerciseRepository(context: context)
        try repository.archive(definitions[0].id)

        let inserted = try PresetExerciseSeeder(context: context, keyStore: keyStore, definitions: definitions)
            .seedIfNeeded()

        #expect(inserted.isEmpty)
        let exercises = try fetchExercises(context)
        #expect(exercises.count == 2)
        #expect(exercises.first { $0.id == definitions[0].id }?.isArchived == true)
    }

    /// 別デバイスで削除済み、あるいはCloudKitのインポートがまだ終わっていない状況。
    /// ローカルが空でも「シード済み」を根拠に投入してはいけない(重複レコードになる)。
    @Test func doesNotSeedWhenKeyStoreSaysAlreadySeededButStoreIsEmpty() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let keyStore = InMemorySeededPresetKeyStore(keys: ["bench_press", "squat"])

        let inserted = try PresetExerciseSeeder(
            context: context,
            keyStore: keyStore,
            definitions: makeDefinitions()
        ).seedIfNeeded()

        #expect(inserted.isEmpty)
        #expect(try fetchExercises(context).isEmpty)
    }

    /// 旧バージョンでプリセット行をタップ済みのユーザー。
    /// レコードは既にあるので投入せず、KVSの記録だけを追いつかせる。
    @Test func recordsExistingExercisesAsSeededWithoutInserting() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let keyStore = InMemorySeededPresetKeyStore()
        let definitions = makeDefinitions()

        let alreadyTapped = definitions[0]
        context.insert(
            Exercise(
                id: alreadyTapped.id,
                name: alreadyTapped.name,
                bodyPart: alreadyTapped.bodyPart,
                defaultWeightUnit: alreadyTapped.defaultWeightUnit,
                isPreset: true,
                seedKey: alreadyTapped.seedKey,
                seedVersion: alreadyTapped.seedVersion
            )
        )
        try context.save()

        let inserted = try PresetExerciseSeeder(
            context: context,
            keyStore: keyStore,
            definitions: definitions
        ).seedIfNeeded()

        #expect(inserted == ["squat"])
        #expect(try fetchExercises(context).count == 2)
        #expect(keyStore.keys == ["bench_press", "squat"])
    }

    /// 本番の定義もIDが固定されていること(ランダム生成だと冪等キーとして機能しない)。
    @Test func productionDefinitionsHaveStableUniqueKeys() throws {
        let all = PresetExerciseDefinitions.all
        #expect(Set(all.map { $0.id }).count == all.count)
        #expect(Set(all.map { $0.seedKey }).count == all.count)
        // 名前+部位は正規化のシグネチャとして使われる。ここが衝突すると記録の付け替え先が壊れる。
        #expect(Set(all.map { "\($0.name)|\($0.bodyPart.rawValue)" }).count == all.count)
    }
}
