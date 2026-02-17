# workout

## Release build secrets

`workout/Config/Secrets.xcconfig` は Git 管理せず、環境変数から生成します。

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
