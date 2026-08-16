# workout

## Release build secrets

`workout/Config/Secrets.xcconfig` は Git 管理せず、環境変数から生成します。
`workout/workout/Config/Workout.Release.xcconfig` では `#include "Secrets.xcconfig"` を使用しているため、
`Secrets.xcconfig` が未生成の場合は Release ビルドが即時失敗します。

ローカル生成:

```bash
cd workout
BANNER_AD_UNIT_ID='ca-app-pub-xxx/xxx' \
RECORD_LIST_BANNER_AD_UNIT_ID='ca-app-pub-xxx/xxx' \
GRAPH_BANNER_AD_UNIT_ID='ca-app-pub-xxx/xxx' \
DISABLE_ADS='NO' \
AD_EXCLUDED_DEVICE_IDS='XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX,YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY' \
bash scripts/generate_secrets_xcconfig.sh
```

GitHub Actions では、以下の Repository Secrets を設定してください。

- `BANNER_AD_UNIT_ID`
- `RECORD_LIST_BANNER_AD_UNIT_ID`
- `GRAPH_BANNER_AD_UNIT_ID`
- `DISABLE_ADS` (任意, `YES` で全広告無効)
- `AD_EXCLUDED_DEVICE_IDS` (任意, `identifierForVendor` をカンマ区切り)

ワークフロー: `.github/workflows/ios-release-build.yml`

GitHub での設定手順:

1. 対象リポジトリを開く
2. `Settings` -> `Secrets and variables` -> `Actions`
3. `New repository secret` から上記 3 つを登録

## Xcode Cloud (TestFlight / App Store 配信)

ブランチ運用:

- `develop` ブランチへのマージ -> TestFlight (Internal Testing) へ自動配信
- `main` ブランチへのマージ -> App Store Connect へアップロードまで自動化(審査への提出は手動)

Xcode Cloud のワークフロー自体はリポジトリ内のファイルではなく Xcode / App Store Connect 側で管理されるため、以下の手順で手動設定が必要です。

`Product > Xcode Cloud > Manage Workflows` から、ワークフローを2つ作成する:

### ワークフロー1: `develop` -> TestFlight

- Start Condition: Branch Changes、対象ブランチ = `develop`
- Actions: Archive
- Post-Actions: `TestFlight (Internal Testing)` を追加

### ワークフロー2: `main` -> App Store Connect へアップロード

- Start Condition: Branch Changes、対象ブランチ = `main`
- Actions: Archive
- Post-Actions: `App Store Connect` を追加(`TestFlight` ではなくこちら。審査への自動提出はしない)
  - 将来的に審査提出まで自動化したい場合は、Post-Actions に `Submit to App Store Review` を追加する

両ワークフローとも、`BANNER_AD_UNIT_ID` 等の環境変数を Xcode Cloud の Environment Variables(Secret指定)に、上記 GitHub Actions Secrets と同じ値で登録すること。`ci_scripts/ci_post_clone.sh` / `ci_pre_xcodebuild.sh` がこれらの値から `Secrets.xcconfig` を自動生成する。

### 注意事項

Watch アプリの Bundle ID(`com.mayama.workoutlog.watchkitapp`)が Apple Developer Portal / App Store Connect に未登録の場合、Xcode Cloud のアーカイブが失敗する。一度 Xcode で実機ビルド(自動署名)を通し、App ID が登録されることを確認してからワークフローを実行すること。
