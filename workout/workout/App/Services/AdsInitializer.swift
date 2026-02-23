import FirebaseCore
import GoogleMobileAds
import SwiftUI

@MainActor
final class AdsInitializer: ObservableObject {
    private var hasStartedSDKs = false
    
    /// アプリ起動時などに呼ぶ（何度呼んでも安全）
    func startIfNeeded() {
        // すでに初期化済みなら何もしない
        guard !hasStartedSDKs else { return }
        startSDKsIfNeeded()
    }
    
    private func startSDKsIfNeeded() {
        // 二重起動防止
        guard !hasStartedSDKs else { return }
        hasStartedSDKs = true

        FirebaseApp.configure()
        MobileAds.shared.start(completionHandler: { _ in })
    }
}
