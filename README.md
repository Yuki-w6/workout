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
bash scripts/generate_secrets_xcconfig.sh
```

GitHub Actions では、以下の Repository Secrets を設定してください。

- `BANNER_AD_UNIT_ID`
- `RECORD_LIST_BANNER_AD_UNIT_ID`
- `GRAPH_BANNER_AD_UNIT_ID`

ワークフロー: `.github/workflows/ios-release-build.yml`

GitHub での設定手順:

1. 対象リポジトリを開く
2. `Settings` -> `Secrets and variables` -> `Actions`
3. `New repository secret` から上記 3 つを登録
