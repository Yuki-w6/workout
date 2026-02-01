import Foundation
import SwiftData

struct PresetExerciseDefinition {
    let id: UUID
    let seedKey: String
    let seedVersion: Int
    let name: String
    let bodyPart: BodyPart
    let defaultWeightUnit: WeightUnit
}

enum PresetSeeder {
    
    static func upsertPresets(using modelContext: ModelContext, presets: [PresetExerciseDefinition]) throws {
        
        // 1) 既存Exerciseをまとめて取得
        let all = try modelContext.fetch(FetchDescriptor<Exercise>())
        
        // 2) インデックス作成
        var bySeedKey: [String: [Exercise]] = [:]
        var byId: [UUID: Exercise] = [:]
        var bySignature: [String: [Exercise]] = [:]
        var byName: [String: [Exercise]] = [:]
        
        for ex in all {
            byId[ex.id] = ex
            if let key = ex.seedKey {
                bySeedKey[key, default: []].append(ex)
            }
            let sig = "\(ex.name)|\(ex.bodyPartRaw)"
            bySignature[sig, default: []].append(ex)
            byName[ex.name, default: []].append(ex)
        }
        
        // 3) Upsert
        for preset in presets {
            let signature = "\(preset.name)|\(preset.bodyPart.rawValue)"
            
            // 候補を探す
            let candidate: Exercise? =
            bySeedKey[preset.seedKey]?.first ??
            byId[preset.id] ??
            bySignature[signature]?.first ??
            byName[preset.name]?.first
            
            if let ex = candidate {
                // 既存をプリセットとして整形（バージョン更新は方針次第）
                if ex.seedVersion < preset.seedVersion {
                    ex.name = preset.name
                    ex.bodyPartRaw = preset.bodyPart.rawValue
                    ex.defaultWeightUnitRaw = preset.defaultWeightUnit.rawValue
                }
                ex.isPreset = true
                ex.seedKey = preset.seedKey
                ex.seedVersion = max(ex.seedVersion, preset.seedVersion)
                ex.presetSortKey = 0
            } else {
                // 新規作成
                let ex = Exercise(
                    id: preset.id,
                    name: preset.name,
                    bodyPart: preset.bodyPart,
                    defaultWeightUnit: preset.defaultWeightUnit,
                    isPreset: true,
                    seedKey: preset.seedKey,
                    seedVersion: preset.seedVersion,
                    isArchived: false
                )
                ex.presetSortKey = 0
                modelContext.insert(ex)
            }
        }
        
        // 4) 重複統合（seedKeyごと）
        try dedupBySeedKey(using: modelContext)
        
        // 5) 保存
        try modelContext.save()
    }
    
    // seedKeyごとに複数存在する場合、1つを「正」として残し、他を統合→アーカイブ
    private static func dedupBySeedKey(using modelContext: ModelContext) throws {
        var desc = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isPreset == true && $0.seedKey != nil }
        )
        let presets = try modelContext.fetch(desc)
        
        let grouped = Dictionary(grouping: presets, by: { $0.seedKey! })
        
        for (_, list) in grouped where list.count > 1 {
            // 正の選び方：記録がある > 非アーカイブ > 名前など（必要に応じて調整）
            let sorted = list.sorted { a, b in
                let aHas = hasAnyRecord(for: a.id, using: modelContext)
                let bHas = hasAnyRecord(for: b.id, using: modelContext)
                if aHas != bHas { return aHas && !bHas }
                if a.isArchived != b.isArchived { return !a.isArchived && b.isArchived }
                return a.id.uuidString < b.id.uuidString
            }
            
            let canonical = sorted[0]
            let dups = sorted.dropFirst()
            
            for dup in dups {
                // RecordHeaderを正に付け替え（関係とスナップショットを寄せる）
                try rebindRecords(from: dup, to: canonical, using: modelContext)
                
                // TemplateSetも寄せる（あれば）
                if let sets = dup.templateSets {
                    for s in sets { s.exercise = canonical }
                }
                
                // dupは安全にアーカイブ（削除は事故りやすい）
                dup.isArchived = true
            }
        }
    }
    
    private static func hasAnyRecord(for exerciseID: UUID, using modelContext: ModelContext) -> Bool {
        var d = FetchDescriptor<RecordHeader>(
            predicate: #Predicate { $0.exerciseIDSnapshot == exerciseID }
        )
        d.fetchLimit = 1
        return ((try? modelContext.fetch(d)) ?? []).isEmpty == false
    }
    
    private static func rebindRecords(from old: Exercise, to new: Exercise, using modelContext: ModelContext) throws {
        // 関係を使わずクエリで拾う（巨大to-manyを触らない）
        let oldID = old.id
        var d = FetchDescriptor<RecordHeader>(
            predicate: #Predicate { $0.exerciseIDSnapshot == oldID }
        )
        let headers = try modelContext.fetch(d)
        
        for h in headers {
            h.exercise = new
            // 今後の検索や集計が新IDで揃うように寄せる（表示はsnapshotに残る）
            h.exerciseIDSnapshot = new.id
        }
    }
}
