#!/bin/bash
# FX Calc Launcher
APP_VERSION="1.0.0"

show_dialog() {
    local type="$1" title="$2" msg="$3"
    if command -v zenity &>/dev/null; then
        zenity --"$type" --title="$title" --text="$msg" --no-wrap 2>/dev/null
    elif command -v kdialog &>/dev/null; then
        kdialog --title "$title" --"$type" "$msg" 2>/dev/null
    else
        echo "$msg" >&2
    fi
}

run_as_root() {
    local label="$1" scriptfile="$2"
    chmod +x "$scriptfile"
    if command -v zenity &>/dev/null; then
        zenity --progress --title="FX Calc" \
               --text="$label" \
               --pulsate --no-cancel 2>/dev/null &
        ZENITY_PID=$!
        pkexec bash "$scriptfile"
        PKEXEC_RC=$?
        kill "$ZENITY_PID" 2>/dev/null
        wait "$ZENITY_PID" 2>/dev/null
        return $PKEXEC_RC
    else
        pkexec bash "$scriptfile"
    fi
}

find_python() {
    local py ok
    for py in python3.13 python3.12 python3.11 python3.10 python3; do
        if command -v "$py" &>/dev/null; then
            ok=$("$py" -c "import sys; print(sys.version_info>=(3,10))" 2>/dev/null)
            if [ "$ok" = "True" ]; then echo "$py"; return 0; fi
        fi
    done
    return 1
}

PYTHON=""
[ -f /opt/fx-calc/python_bin ] && PYTHON=$(cat /opt/fx-calc/python_bin)
command -v "$PYTHON" &>/dev/null || PYTHON=""
[ -z "$PYTHON" ] && PYTHON=$(find_python)

if [ -z "$PYTHON" ]; then
    show_dialog error "FX Calc – Fehler" "Python 3.10 oder neuer wird benötigt."
    exit 1
fi

# ── PyQt6 prüfen ──────────────────────────────────────────────────────────────
if ! "$PYTHON" -c "import PyQt6" 2>/dev/null; then
    show_dialog question "FX Calc – Einmalige Einrichtung" \
"FX Calc benötigt PyQt6, das auf Ihrem System noch fehlt.

Soll es jetzt automatisch installiert werden?
(Erfordert einmalig Ihr Passwort)"
    [ $? -ne 0 ] && exit 1

    PYQT_SETUP=$(mktemp /tmp/fx-pyqt-XXXXXX.sh)
    cat > "$PYQT_SETUP" << SCRIPT
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
add-apt-repository -y universe >/dev/null 2>&1 || true
apt-get update -qq >/dev/null 2>&1 || true
apt-get install -y python3-pyqt6 >/dev/null 2>&1 || true
if ! $PYTHON -c "import PyQt6" >/dev/null 2>&1; then
    apt-get install -y python3-pip >/dev/null 2>&1 || true
    $PYTHON -m pip install PyQt6 --break-system-packages >/dev/null 2>&1 || \
    $PYTHON -m pip install PyQt6 >/dev/null 2>&1 || true
fi
SCRIPT
    run_as_root "PyQt6 wird installiert…" "$PYQT_SETUP"
    rm -f "$PYQT_SETUP"

    if ! "$PYTHON" -c "import PyQt6" 2>/dev/null; then
        show_dialog error "FX Calc – Einrichtung fehlgeschlagen" \
"PyQt6 konnte nicht installiert werden.
Bitte kontaktieren Sie: https://www.stock-monitor.ch"
        exit 1
    fi
fi

# ── Abhängigkeiten einrichten (einmalig) ─────────────────────────────────────
LIB_VERSION=$(cat /opt/fx-calc/lib/.fx-version 2>/dev/null)
if [ -z "$(ls -A /opt/fx-calc/lib 2>/dev/null)" ] || [ "$LIB_VERSION" != "$APP_VERSION" ]; then
    PYBIN="$PYTHON"
    WHEEL_SETUP=$(mktemp /tmp/fx-wheels-XXXXXX.sh)
    cat > "$WHEEL_SETUP" << SCRIPT
#!/bin/bash
LIBDIR=/opt/fx-calc/lib
WHEELDIR=/opt/fx-calc/wheels
rm -rf "\$LIBDIR"/*
mkdir -p "\$LIBDIR"
echo "$PYBIN" > /opt/fx-calc/python_bin
PIP_VER=\$($PYBIN -m pip --version 2>/dev/null | awk '{print \$2}')
MAJOR=\$(echo "\$PIP_VER" | cut -d. -f1)
MINOR=\$(echo "\$PIP_VER" | cut -d. -f2)
if [ "\${MAJOR:-0}" -gt 22 ] || { [ "\${MAJOR:-0}" -eq 22 ] && [ "\${MINOR:-0}" -ge 3 ]; }; then
    BSP="--break-system-packages"
else
    BSP=""
fi
PIP="$PYBIN -m pip install --quiet --target \$LIBDIR --no-index --find-links \$WHEELDIR --no-deps \$BSP"
\$PIP yfinance multitasking frozendict requests urllib3 certifi \
    charset-normalizer idna beautifulsoup4 soupsieve websockets \
    curl-cffi platformdirs python-dateutil pytz tzdata six \
    typing-extensions packaging setuptools protobuf >/dev/null 2>&1 || true
PYVER=\$($PYBIN -c "import sys; print('cp%d%d' % sys.version_info[:2])" 2>/dev/null)
for pkg in numpy pandas; do
    WHL=\$(ls "\$WHEELDIR"/\${pkg}-*-\${PYVER}-*.whl 2>/dev/null | head -1)
    if [ -n "\$WHL" ]; then
        $PYBIN -m pip install --quiet --target \$LIBDIR --no-deps \$BSP "\$WHL" >/dev/null 2>&1 || true
    fi
done
echo "$APP_VERSION" > /opt/fx-calc/lib/.fx-version
SCRIPT
    run_as_root "Bibliotheken werden eingerichtet…" "$WHEEL_SETUP"
    rm -f "$WHEEL_SETUP"
fi

echo "$PYTHON" > /opt/fx-calc/python_bin 2>/dev/null || true

# ── Starten ───────────────────────────────────────────────────────────────────
export PYTHONPATH="/opt/fx-calc/lib:${PYTHONPATH}"
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$FORCE_X11" ]; then
    export QT_QPA_PLATFORM="wayland;xcb"
else
    export QT_QPA_PLATFORM="xcb"
fi
export QT_ENABLE_HIGHDPI_SCALING=1

"$PYTHON" /opt/fx-calc/app/currency_converter.py "$@"
