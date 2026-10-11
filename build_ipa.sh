#!/bin/bash
# FX Calc IPA Build-Skript (App Store / TestFlight)
#
# Archiviert unsigniert und signiert erst beim Export mit "Apple Distribution".
# Grund: Das Team hat keine registrierten iOS-Geräte, daher kann Xcode kein
# Development-Profil erzeugen – ein App-Store-Profil braucht keine Geräte.
set -e
cd "$(dirname "$0")"

# Version aus pubspec.yaml lesen (Single Source of Truth)
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
BUILD=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)
TEAM_ID="42TQXYS8LF"

echo "=== FX Calc v${VERSION}+${BUILD} – IPA Build ==="

if ! command -v flutter &>/dev/null; then
    echo "FEHLER: flutter nicht gefunden."
    exit 1
fi

echo "→ Abhängigkeiten holen..."
flutter pub get


echo "→ Analyse..."
flutter analyze --no-pub --no-fatal-infos

echo "→ Flutter-Release-Build (setzt Version/Build in Xcode)..."
flutter build ios --release --no-codesign

ARCHIVE="build/ios/archive/Runner.xcarchive"
EXPORT_DIR="build/ios/ipa"
EXPORT_OPTS="build/ios/ExportOptions.plist"
rm -rf "$ARCHIVE" "$EXPORT_DIR"

echo "→ Archivieren (unsigniert)..."
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" archive CODE_SIGNING_ALLOWED=NO -quiet

cat > "$EXPORT_OPTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
EOF

echo "→ Exportieren + signieren (Apple Distribution)..."
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_OPTS" -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates -quiet

IPA_SRC="$EXPORT_DIR/FX Calc.ipa"
IPA_DST="fx-calc-${VERSION}.ipa"

if [ -f "$IPA_SRC" ]; then
    cp "$IPA_SRC" "$IPA_DST"
    echo ""
    echo "✓ IPA erstellt: $IPA_DST"
    echo "  Version: ${VERSION} (Build ${BUILD})"
    ls -lh "$IPA_DST"
    echo ""
    echo "Hochladen: Transporter.app öffnen und $IPA_DST hineinziehen → Deliver"
else
    echo "FEHLER: IPA nicht gefunden unter $IPA_SRC"
    exit 1
fi
