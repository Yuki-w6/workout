import SwiftData
import SwiftUI

@MainActor
final class AppSeeder: ObservableObject {
    // seed済みバージョン（将来プリセット追加したら version を上げて再seedできる）
    @AppStorage("presetSeedVersion") private var presetSeedVersion: Int = 0
    
    // 現在のseedバージョン（プリセット定義を増やしたらこの数字を上げる）
    private let currentSeedVersion: Int = 1
    
    func runIfNeeded(modelContainer: ModelContainer) {
        // すでに最新バージョンまで seed 済みなら何もしない
        guard presetSeedVersion < currentSeedVersion else { return }
        
        do {
            // SwiftData: mainContext を使う（App側からでも触れる）
            let context = modelContainer.mainContext
            
            try PresetSeeder.upsertPresets(
                using: context,
                presets: PresetExerciseDefinitions.all
            )
            
            // seed 成功 → バージョン更新
            presetSeedVersion = currentSeedVersion
            print("✅ preset seed done. version:", currentSeedVersion)
        } catch {
            // 失敗してもアプリは起動させたいので、ここではログだけ
            print("❌ preset seed error:", error)
        }
    }
}
