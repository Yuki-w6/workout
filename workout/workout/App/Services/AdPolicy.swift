import Foundation
import UIKit

@MainActor
enum AdPolicy {
    static var isAdEnabled: Bool {
        !isDisabledByBuildSetting && !isExcludedDevice
    }

    static func shouldShowBanner(adUnitID: String?) -> Bool {
        guard isAdEnabled else { return false }
        guard let adUnitID, !adUnitID.isEmpty else { return false }
        return true
    }

    private static var isDisabledByBuildSetting: Bool {
        boolValue(forInfoDictionaryKey: "DisableAds")
    }

    private static var isExcludedDevice: Bool {
        guard
            let currentDeviceID = UIDevice.current.identifierForVendor?.uuidString.lowercased()
        else {
            return false
        }
        return excludedDeviceIDs.contains(currentDeviceID)
    }

    private static var excludedDeviceIDs: Set<String> {
        guard
            let csv = Bundle.main.object(forInfoDictionaryKey: "AdExcludedDeviceIDs") as? String
        else {
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
