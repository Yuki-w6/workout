import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI

@MainActor
final class AdsInitializer: ObservableObject {
    @AppStorage("hasRequestedTrackingAuthorization") private var hasRequested = false
    private var hasStartedAds = false
    
    /// アプリ起動時などに呼ぶ（何度呼んでも安全）
    func startIfNeeded() {
        // すでに広告を開始していたら何もしない
        guard !hasStartedAds else { return }
        
        // まずは「ATTを聞くべきか」を判断して、必要なら聞いてから開始
        requestTrackingAuthorizationIfNeeded()
    }
    
    private func requestTrackingAuthorizationIfNeeded() {
        // すでにATTを“聞いたことがある”なら、広告開始へ
        guard !hasRequested else {
            startMobileAdsIfNeeded()
            return
        }
        
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            
            // notDetermined（未決定）のときだけダイアログを出す
            guard status == .notDetermined else {
                hasRequested = true
                startMobileAdsIfNeeded()
                return
            }

            requestTrackingAuthorizationFromSystem()
        } else {
            // iOS 13以下はATTがないので「聞いた扱い」にして広告開始
            hasRequested = true
            startMobileAdsIfNeeded()
        }
    }
    
    @MainActor
    private func requestTrackingAuthorizationFromSystem() {
        Task { @MainActor in
            _ = await ATTrackingManager.requestTrackingAuthorization()
            self.hasRequested = true
            self.startMobileAdsIfNeeded()
        }
    }
    
    private func startMobileAdsIfNeeded() {
        // 二重起動防止
        guard !hasStartedAds else { return }
        hasStartedAds = true

        MobileAds.shared.start(completionHandler: { _ in })
    }
}
