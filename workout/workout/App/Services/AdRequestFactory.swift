import GoogleMobileAds

/// 広告リクエストを組み立てる。すべての広告はここを通す。
///
/// このアプリはApp Tracking Transparencyの許可を求めない。求めない以上、
/// Appleの定義するトラッキング(第三者データと結び付けた広告のターゲティング)を
/// してはならないため、広告を非パーソナライズに固定する。
/// App Store Connectのプライバシー申告で「トラッキングに使用」を「いいえ」に
/// できるのは、この設定が入っていることが前提になる。
enum AdRequestFactory {
    /// SDKの初期化時に一度だけ呼ぶ。
    static func configure() {
        // 同一パブリッシャー内でユーザーを横断的に識別するIDを無効にする。
        // 非パーソナライズ広告と方針を揃えるため。
        MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
    }

    /// 非パーソナライズ広告のリクエストを作る。
    static func makeRequest() -> Request {
        let request = Request()
        let extras = Extras()
        // npa=1 がGoogleに非パーソナライズ広告を要求する指定。
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }
}
