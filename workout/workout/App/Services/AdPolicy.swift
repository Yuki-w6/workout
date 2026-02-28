import Foundation
import UIKit
import Security

@MainActor
enum AdPolicy {
    
    /// 広告を有効にして良いか（UI表示 / SDK起動の両方で使う）
    static var isAdEnabled: Bool {
        // Xcode Run Arguments の -ads-off/-ads-on を1回だけKeychainへ反映
        applyLaunchArgumentsIfNeeded()
        
        // Keychainの広告OFF（最優先：再インストール後も維持）
        if isDisabledByKeychainFlag { return false }
        
        // 既存：ビルド設定で一括OFF（Info.plist DisableAds）
        if isDisabledByBuildSetting { return false }
        
        // 既存：IDFVで除外（Info.plist AdExcludedDeviceIDs）
        if isExcludedDevice { return false }
        
        return true
    }
    
    static func shouldShowBanner(adUnitID: String?) -> Bool {
        guard isAdEnabled else { return false }
        guard let adUnitID, !adUnitID.isEmpty else { return false }
        return true
    }
    
    // MARK: - ① Keychain 永続フラグ（ads_disabled）
    
    private static let keychainService: String = Bundle.main.bundleIdentifier ?? "app"
    private static let keychainAccount: String = "ads_disabled"
    
    private static var isDisabledByKeychainFlag: Bool {
        KeychainBool.load(service: keychainService, account: keychainAccount) ?? false
    }
    
    /// この端末で広告を無効化/解除（Keychainへ保存）
    static func setAdsDisabledOnThisDevice(_ disabled: Bool) {
        KeychainBool.save(disabled, service: keychainService, account: keychainAccount)
    }
    
    // MARK: - 起動引数（Xcode Scheme > Run > Arguments）
    
    private static var didApplyLaunchArguments = false
    
    /// Xcode Run Arguments の -ads-off / -ads-on を「その起動中に1回だけ」反映してKeychainに保存
    static func applyLaunchArgumentsIfNeeded() {
        guard !didApplyLaunchArguments else { return }
        didApplyLaunchArguments = true
        
        let args = ProcessInfo.processInfo.arguments
        
        // 戻す用も用意しておくと便利
        if args.contains("-ads-on") {
            setAdsDisabledOnThisDevice(false)
        } else if args.contains("-ads-off") {
            setAdsDisabledOnThisDevice(true)
        }
    }
    
    // MARK: - 既存: Build/Info.plist スイッチ
    
    private static var isDisabledByBuildSetting: Bool {
        boolValue(forInfoDictionaryKey: "DisableAds")
    }
    
    // MARK: - 既存: IDFV 除外
    
    private static var isExcludedDevice: Bool {
        guard let currentDeviceID = UIDevice.current.identifierForVendor?.uuidString.lowercased() else {
            return false
        }
        return excludedDeviceIDs.contains(currentDeviceID)
    }
    
    private static var excludedDeviceIDs: Set<String> {
        guard let csv = Bundle.main.object(forInfoDictionaryKey: "AdExcludedDeviceIDs") as? String else {
            return []
        }
        return Set(
            csv
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }
    
    private static func boolValue(forInfoDictionaryKey key: String) -> Bool {
        if let boolValue = Bundle.main.object(forInfoDictionaryKey: key) as? Bool {
            return boolValue
        }
        if let stringValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes":
                return true
            default:
                return false
            }
        }
        return false
    }
}

// MARK: - Keychain bool helper

private enum KeychainBool {
    static func load(service: String, account: String) -> Bool? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        
        return str == "1"
    }
    
    static func save(_ value: Bool, service: String, account: String) {
        let data = Data((value ? "1" : "0").utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            // 端末内のみ（バックアップ/移行に載せない）
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
