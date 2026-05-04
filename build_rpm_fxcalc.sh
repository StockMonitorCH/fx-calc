#!/bin/bash
# FX Calc RPM Build-Skript
set -e
cd "$(dirname "$0")"

VERSION="1.0.0"
PKG="fx-calc-${VERSION}"
RPMBUILD="$HOME/rpmbuild"
SRCDIR_BASE="$(dirname "$0")"
SM_SOURCES="$SRCDIR_BASE/../fp/sources"

echo "=== FX Calc ${VERSION} – RPM Build ==="

if ! command -v rpmbuild &>/dev/null; then
    echo "FEHLER: rpmbuild nicht gefunden. sudo dnf install rpm-build"
    exit 1
fi

mkdir -p "$RPMBUILD"/{SOURCES,SPECS,BUILD,RPMS,SRPMS}

echo "→ Erstelle Quell-Tarball..."
TMPDIR=$(mktemp -d)
SRCDIR="$TMPDIR/$PKG"
mkdir -p "$SRCDIR/app" "$SRCDIR/wheels"

install -m 0644 currency_converter.py "$SRCDIR/app/"
install -m 0755 fx-calc.sh            "$SRCDIR/"
install -m 0644 fx-calc.desktop       "$SRCDIR/"
install -m 0644 fx-calc-256.png       "$SRCDIR/"

# Wheels: nur yfinance und seine Abhängigkeiten
echo "→ Kopiere Wheels..."
NEEDED="yfinance multitasking frozendict requests urllib3 certifi \
        charset_normalizer idna beautifulsoup4 soupsieve websockets \
        curl_cffi platformdirs python_dateutil pytz tzdata six \
        typing_extensions packaging setuptools protobuf numpy pandas wheel"
COUNT=0
for pattern in $NEEDED; do
    for whl in "$SM_SOURCES"/${pattern}-*.whl "$SM_SOURCES"/${pattern}-*.tar.gz; do
        [ -f "$whl" ] || continue
        cp "$whl" "$SRCDIR/wheels/"
        COUNT=$((COUNT+1))
    done
done
echo "   $COUNT Pakete eingebettet"

tar -czf "$RPMBUILD/SOURCES/${PKG}.tar.gz" -C "$TMPDIR" "$PKG"
rm -rf "$TMPDIR"

cp fx-calc.spec "$RPMBUILD/SPECS/"
rm -f "$RPMBUILD/RPMS/x86_64/fx-calc-${VERSION}"*.rpm

echo "→ Baue RPM..."
rpmbuild -ba "$RPMBUILD/SPECS/fx-calc.spec" \
    --define "_topdir $RPMBUILD" 2>&1 | grep -v "^Processing\|^Executing\|^Checking" || true

RPM_FILE=$(find "$RPMBUILD/RPMS" -name "fx-calc-${VERSION}*.rpm" | head -1)
if [ -n "$RPM_FILE" ]; then
    OUTDIR="$(dirname "$0")"
    CLEAN="fx-calc-${VERSION}.x86_64.rpm"
    cp "$RPM_FILE" "$OUTDIR/$CLEAN"
    echo ""
    echo "=== Fertig! ==="
    echo "RPM: $OUTDIR/$CLEAN"
else
    echo "FEHLER: RPM nicht erstellt."
    exit 1
fi
