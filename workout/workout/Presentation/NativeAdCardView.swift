import SwiftUI
@preconcurrency import GoogleMobileAds
@preconcurrency import UIKit

struct NativeAdCardView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        adView.backgroundColor = UIColor.secondarySystemGroupedBackground
        adView.layer.cornerRadius = 12
        adView.clipsToBounds = true

        let adChoicesView = AdChoicesView()
        adChoicesView.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 8
        iconView.clipsToBounds = true

        let headlineLabel = UILabel()
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        headlineLabel.numberOfLines = 2

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        bodyLabel.textColor = UIColor.secondaryLabel
        bodyLabel.numberOfLines = 2

        let callToActionButton = UIButton(type: .system)
        callToActionButton.translatesAutoresizingMaskIntoConstraints = false
        callToActionButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        callToActionButton.layer.cornerRadius = 6
        callToActionButton.clipsToBounds = true
        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.baseBackgroundColor = UIColor.systemBlue
        buttonConfig.baseForegroundColor = UIColor.white
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        callToActionButton.configuration = buttonConfig

        let textStack = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel, callToActionButton])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .leading

        let contentStack = UIStackView(arrangedSubviews: [iconView, textStack])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.spacing = 12
        contentStack.alignment = .center

        adView.addSubview(contentStack)
        adView.addSubview(adChoicesView)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            contentStack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),
            adChoicesView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 6),
            adChoicesView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -6)
        ])

        adView.headlineView = headlineLabel
        adView.bodyView = bodyLabel
        adView.callToActionView = callToActionButton
        adView.iconView = iconView
        adView.adChoicesView = adChoicesView

        context.coordinator.adView = adView
        context.coordinator.loadAdIfNeeded(adUnitID: adUnitID, rootViewController: rootViewController())

        return adView
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {
        context.coordinator.loadAdIfNeeded(adUnitID: adUnitID, rootViewController: rootViewController())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency AdLoaderDelegate, @preconcurrency NativeAdLoaderDelegate {
        var adLoader: AdLoader?
        weak var adView: NativeAdView?
        private var didLoad = false

        func loadAdIfNeeded(adUnitID: String, rootViewController: UIViewController?) {
            guard !didLoad, let rootViewController else {
                return
            }
            let adTypes: [AdLoaderAdType] = [.native]
            adLoader = AdLoader(
                adUnitID: adUnitID,
                rootViewController: rootViewController,
                adTypes: adTypes,
                options: nil
            )
            adLoader?.delegate = self
            adLoader?.load(Request())
            didLoad = true
        }

        func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
            apply(nativeAd: nativeAd)
        }

        func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
            // Keep the card reserved; avoid spamming reloads on failure.
        }

        @MainActor
        private func apply(nativeAd: NativeAd) {
            guard let adView else {
                return
            }
            nativeAd.rootViewController = adView.window?.rootViewController

            if let headlineLabel = adView.headlineView as? UILabel {
                headlineLabel.text = nativeAd.headline
            }
            if let bodyLabel = adView.bodyView as? UILabel {
                bodyLabel.text = nativeAd.body
                bodyLabel.isHidden = nativeAd.body == nil
            }
            if let callToActionButton = adView.callToActionView as? UIButton {
                callToActionButton.setTitle(nativeAd.callToAction, for: .normal)
                callToActionButton.isHidden = nativeAd.callToAction == nil
            }
            if let iconView = adView.iconView as? UIImageView {
                iconView.image = nativeAd.icon?.image
                iconView.isHidden = nativeAd.icon == nil
            }

            adView.nativeAd = nativeAd
        }
    }
}
