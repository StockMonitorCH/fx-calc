%global debug_package %{nil}
%global dist %{nil}

Name:           fx-calc
Version:        1.0.0
Release:        1
Summary:        Rechner & Währungsrechner mit Zinsrechner
License:        Proprietary
URL:            https://www.stock-monitor.ch
Source0:        fx-calc-%{version}.tar.gz
BuildArch:      x86_64

Requires:       python3

%description
FX Calc – Rechner, Währungsrechner und Zinsrechner.
Teil von Stock Monitor (https://www.stock-monitor.ch).

%prep
%setup -q

%build
# Pure Python – kein Kompilieren nötig

%install
install -d %{buildroot}/opt/fx-calc/app
install -d %{buildroot}/opt/fx-calc/wheels
install -d %{buildroot}/usr/bin
install -d %{buildroot}/usr/share/applications
install -d %{buildroot}/usr/share/icons/hicolor/256x256/apps

install -m 0644 app/currency_converter.py %{buildroot}/opt/fx-calc/app/currency_converter.py

for f in wheels/*; do
    install -m 0644 "$f" %{buildroot}/opt/fx-calc/wheels/
done

install -m 0755 fx-calc.sh      %{buildroot}/usr/bin/fx-calc
install -m 0644 fx-calc.desktop %{buildroot}/usr/share/applications/fx-calc.desktop
install -m 0644 fx-calc-256.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/fx-calc.png

%post
exec 2>/dev/null

LIBDIR=/opt/fx-calc/lib
WHEELDIR=/opt/fx-calc/wheels
rm -rf "$LIBDIR"
mkdir -p "$LIBDIR"

PYTHON=""
for py in python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$py" &>/dev/null; then
        ok=$("$py" -c "import sys; print(sys.version_info >= (3,10))" 2>/dev/null)
        if [ "$ok" = "True" ]; then PYTHON="$py"; break; fi
    fi
done
[ -z "$PYTHON" ] && exit 0

echo "$PYTHON" > /opt/fx-calc/python_bin

if ! "$PYTHON" -c "import PyQt6" >/dev/null 2>&1; then
    if command -v dnf &>/dev/null; then
        dnf install -y python3-pyqt6 >/dev/null 2>&1 || true
    elif command -v zypper &>/dev/null; then
        zypper install -y python3-PyQt6 >/dev/null 2>&1 || true
    fi
fi
if ! "$PYTHON" -c "import PyQt6" >/dev/null 2>&1; then
    "$PYTHON" -m pip install --quiet PyQt6 >/dev/null 2>&1 || true
fi

PIP="$PYTHON -m pip install --quiet --target $LIBDIR --no-index --find-links $WHEELDIR --no-deps"

$PIP yfinance multitasking frozendict requests urllib3 certifi \
    charset-normalizer idna beautifulsoup4 soupsieve websockets \
    curl-cffi platformdirs python-dateutil pytz tzdata six \
    typing-extensions packaging setuptools protobuf >/dev/null 2>&1 || true

PYVER=$("$PYTHON" -c "import sys; print('cp%d%d' % sys.version_info[:2])" 2>/dev/null)
for pkg in numpy pandas; do
    WHL=$(ls "$WHEELDIR"/${pkg}-*-${PYVER}-*.whl 2>/dev/null | head -1)
    if [ -n "$WHL" ]; then
        "$PYTHON" -m pip install --quiet --target "$LIBDIR" --no-deps "$WHL" >/dev/null 2>&1 || true
    fi
done

echo "1.0.0" > /opt/fx-calc/lib/.fx-version
gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

%preun
if [ $1 -eq 0 ]; then
    rm -rf /opt/fx-calc/lib /opt/fx-calc/python_bin 2>/dev/null || true
fi

%postun
if [ $1 -eq 0 ]; then
    rm -rf /opt/fx-calc 2>/dev/null || true
fi
gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

%files
/opt/fx-calc/app/currency_converter.py
/opt/fx-calc/wheels/
/usr/bin/fx-calc
/usr/share/applications/fx-calc.desktop
/usr/share/icons/hicolor/256x256/apps/fx-calc.png

%changelog
* Sun May 04 2026 StockMonitor <info@stock-monitor.ch> - 1.0.0-1
- Initiales Release
