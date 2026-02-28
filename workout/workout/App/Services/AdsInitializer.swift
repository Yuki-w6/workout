import GoogleMobileAds
import SwiftUI

@MainActor
final class AdsInitializer: ObservableObject {
    private var hasStartedSDKs = false
    
    /// アプリ起動時などに呼ぶ（何度呼んでも安全）
    func startIfNeeded() {
        // -ads-off/-ads-on をKeychainへ反映（この起動中に1回だけ）
        AdPolicy.applyLaunchArgumentsIfNeeded()
        
        // すでに初期化済みなら何もしない
        guard !hasStartedSDKs else { return }
        
        // 広告OFFならここで止まる（SDK起動もしない＝リクエストもゼロ）
        guard AdPolicy.isAdEnabled else { return }
        
        hasStartedSDKs = true
        MobileAds.shared.start(completionHandler: { _ in })
    }
}
