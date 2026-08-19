import Foundation
import SwiftData

/// シード済みプリセットの seedKey を永続化するストア。
protocol SeededPresetKeyStore {
    func load() -> Set<String>
    func save(_ keys: Set<String>)
}

/// iCloud Key-Value Store 版。
/// UserDefaults は端末ローカルかつ再インストールで消えるため、2台目のデバイスや
/// 再インストール直後(CloudKitのインポート完了前でローカルが空に見える瞬間)に
/// 同じプリセットを二重投入してしまう。KVSはiCloudアカウント単位で共有されるので防げる。
struct UbiquitousSeededPresetKeyStore: SeededPresetKeyStore {
    private static let storeKey = "seededPresetKeys"

    private let store: NSUbiquitousKeyValueStore

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    func load() -> Set<String> {
        store.synchronize()
        return Set(store.array(forKey: Self.storeKey) as? [String] ?? [])
    }

    func save(_ keys: Set<String>) {
        store.set(keys.sorted(), forKey: Self.storeKey)
        store.synchronize()
    }
}

/// プリセット種目を実体としてストアに投入する。
///
/// Watchはプリセット定義を持たず Exercise レコードをそのままクエリするため、
/// 実体が無いプリセットはCloudKit経由でWatchに届かない。
/// iPhone側で一度もタップされていないプリセットもここで作成しておく。
struct PresetExerciseSeeder {
    private let context: ModelContext
    private let keyStore: SeededPresetKeyStore
    private let definitions: [PresetExerciseDefinition]

    init(
        context: ModelContext,
        keyStore: SeededPresetKeyStore = UbiquitousSeededPresetKeyStore(),
        definitions: [PresetExerciseDefinition] = PresetExerciseDefinitions.all
    ) {
        self.context = context
        self.keyStore = keyStore
        self.definitions = definitions
    }

    /// 投入したプリセットの seedKey を返す。
    @discardableResult
    func seedIfNeeded() throws -> [String] {
        var seededKeys = keyStore.load()
        let originalSeededKeys = seededKeys

        // アーカイブ済みも「存在する」とみなすため、フィルタ無しで取得する。
        let existing = try context.fetch(FetchDescriptor<Exercise>())
        let existingIDs = Set(existing.map(\.id))
        let existingSeedKeys = Set(existing.compactMap(\.seedKey))

        var insertedKeys: [String] = []
        for preset in definitions {
            // 削除(アーカイブ)したプリセットを復活させないため、投入済みは二度と投入しない。
            guard seededKeys.contains(preset.seedKey) == false else { continue }

            // 旧バージョンでタップ済みの種目は、投入せず記録だけ追いつかせる。
            if existingIDs.contains(preset.id) || existingSeedKeys.contains(preset.seedKey) {
                seededKeys.insert(preset.seedKey)
                continue
            }

            context.insert(
                Exercise(
                    id: preset.id,
                    name: preset.name,
                    bodyPart: preset.bodyPart,
                    defaultWeightUnit: preset.defaultWeightUnit,
                    isPreset: true,
                    seedKey: preset.seedKey,
                    seedVersion: preset.seedVersion,
                    isArchived: false
                )
            )
            seededKeys.insert(preset.seedKey)
            insertedKeys.append(preset.seedKey)
        }

        // 保存に失敗したときはKVSを更新せず、次回起動でやり直せるようにする。
        if insertedKeys.isEmpty == false {
            try context.save()
        }
        if seededKeys != originalSeededKeys {
            keyStore.save(seededKeys)
        }
        return insertedKeys
    }
}
