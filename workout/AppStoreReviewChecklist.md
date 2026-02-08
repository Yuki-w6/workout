# App Store 審査提出チェックリスト

## 1. ビルド/署名
- Releaseビルドでアーカイブできる
- 署名は配布用 (App Store) のプロビジョニング/証明書
- Capabilities に不要なものが残っていない
- `CFBundleShortVersionString` と `CFBundleVersion` を更新済み

## 2. 権限/プライバシー (Info.plist)
- 利用する権限の Usage Description がすべて揃っている
- 使っていない権限や Background Modes を宣言していない
- ATT を使う場合は `NSUserTrackingUsageDescription` が適切

## 3. プライバシー情報 (App Store Connect)
- データ収集/トラッキングの申告がアプリ実態と一致
- 広告 SDK (例: Google Mobile Ads) の利用を正しく反映
- 必要に応じて「収集しない」を明示

## 4. 審査メタデータ
- アプリ名/サブタイトル/説明文
- スクリーンショット/プレビュー (最新のUI)
- サポートURL/プライバシーポリシーURL
- ログイン必要ならテスト用アカウントと手順
- レビュー用ノート (特別な操作が必要なら詳細)

## 5. 動作確認
- クラッシュ/重大なUI崩れがない
- 主要フローがローカル/オフラインでも破綻しない
- アプリ内課金/購読がある場合は審査用テストの準備
