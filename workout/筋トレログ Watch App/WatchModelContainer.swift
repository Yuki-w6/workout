import Foundation
import SwiftData
import WorkoutShared

enum WatchModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([Exercise.self, ExerciseTemplateSet.self, RecordHeader.self, RecordSet.self])

#if DEBUG && targetEnvironment(simulator)
        // シミュレータにはiCloudアカウントが無くCloudKitコンテナの初期化に失敗するため、
        // App Store用スクリーンショットの撮影ができるようローカルのみのコンテナを使う。
        //
        // 実機ではこのフォールバックを行わない。CloudKitが一時的に利用できないときに
        // ローカル専用ストアで動いてしまうと、その間の記録が同期されず失われるため、
        // 初期化に失敗した場合はエラーを表示して利用者に気づいてもらう。
        let localConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [localConfiguration])
#else
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.mayamayk.workoutlog")
        )
        return try ModelContainer(for: schema, configurations: [cloudConfiguration])
#endif
    }
}
