#!/usr/bin/env bash
set -euo pipefail

# GoogleService-Info.plist は .gitignore 対象で、CI環境には存在しない。
# AppDelegate が起動時に無条件で FirebaseApp.configure() を呼ぶため、
# ファイルが無いとテスト実行前にアプリがクラッシュする(SIGABRT)。
# 実際のFirebaseプロジェクトに接続する必要はない(ユニットテストはFirebaseを使わない)ため、
# configure() が失敗しない程度のダミー値で生成する。

output_path="workout/GoogleService-Info.plist"

cat > "$output_path" <<'EOC'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>AIzaSyDUMMYDUMMYDUMMYDUMMYDUMMYDUMMYDUM</string>
	<key>GCM_SENDER_ID</key>
	<string>000000000000</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>com.mayama.workoutlog</string>
	<key>PROJECT_ID</key>
	<string>ci-placeholder-project</string>
	<key>STORAGE_BUCKET</key>
	<string>ci-placeholder-project.appspot.com</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<false/>
	<key>IS_APPINVITE_ENABLED</key>
	<false/>
	<key>IS_GCM_ENABLED</key>
	<true/>
	<key>IS_SIGNIN_ENABLED</key>
	<false/>
	<key>GOOGLE_APP_ID</key>
	<string>1:000000000000:ios:0000000000000000000000</string>
</dict>
</plist>
EOC

echo "Generated ${output_path} (placeholder, CI用)"
