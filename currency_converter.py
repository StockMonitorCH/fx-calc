#!/usr/bin/env python3
"""
Rechner & Währungsrechner  –  Desktop App (Portrait-Layout)
Display oben, Modus-Tabs darunter, Ziffernblock in beiden Modi.
Benötigt: pip install PyQt6 yfinance
"""

import sys, math, locale, base64, re, os
import yfinance as yf
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QComboBox, QPushButton, QStackedWidget,
    QDialog, QGridLayout, QSizePolicy, QFrame, QDoubleSpinBox, QScrollArea
)
from PyQt6.QtGui import QFont, QPalette, QPixmap, QDesktopServices, QIcon, QPainter, QColor, QBrush
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QUrl, QByteArray, QSettings

APP_VERSION = "1.0.0"

# ─── QR-Code (Twint) – direkt eingebettet, kein Stock Monitor nötig ──────────

TWINT_QR_B64 = "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"

# Vorberechnete 175×176 Version (kein Runtime-Scaling nötig)
TWINT_QR_175 = "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"

# ─── Währungs-Konstanten ──────────────────────────────────────────────────────

CURRENCIES = [
    'USD', 'CHF', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CNY',
    'HKD', 'SEK', 'NOK', 'DKK', 'NZD', 'SGD', 'MXN', 'BRL',
    'INR', 'KRW', 'TRY',
    'BTC', 'ETH', 'XRP', 'SOL',
    '─── Edelmetalle & Rohstoffe ───',
    'XAU (Gold/oz)', 'XAG (Silber/oz)', 'XPT (Platin/oz)',
    'XPD (Palladium/oz)', 'XCU (Kupfer/lb)',
]
SEPARATOR   = '─── Edelmetalle & Rohstoffe ───'
CRYPTO_MAP  = {'BTC':'BTC-USD','ETH':'ETH-USD','XRP':'XRP-USD','SOL':'SOL-USD'}
PRECIOUS_MAP = {
    'XAU (Gold/oz)':      ('XAUUSD=X','GC=F'),
    'XAG (Silber/oz)':    ('XAGUSD=X','SI=F'),
    'XPT (Platin/oz)':    ('XPTUSD=X','PL=F'),
    'XPD (Palladium/oz)': ('XPDUSD=X','PA=F'),
    'XCU (Kupfer/lb)':    ('HG=F',    'HG=F'),
}

QUICK_PAIRS = [
    ('USD','CHF'), ('CHF','USD'),
    ('EUR','CHF'), ('CHF','EUR'),
    ('GBP','CHF'), ('CHF','GBP'),
    ('EUR','USD'), ('USD','EUR'),
    ('EUR','GBP'), ('GBP','EUR'),
    ('JPY','CHF'), ('CHF','JPY'),
]

# ─── Sprache ──────────────────────────────────────────────────────────────────

def _detect_lang():
    try:
        lc = (locale.getdefaultlocale()[0] or 'en').lower()
        return 'DE' if lc.startswith('de') else 'EN'
    except Exception:
        return 'EN'

STRINGS = {
    'DE': {
        'title':       'Rechner & Währungsrechner',
        'tab_calc':    '🔢  Rechner',
        'tab_curr':    '💱  Währung',
        'btn_convert': 'Umrechnen',
        'btn_swap':    '⇄',
        'hint':        'Yahoo Finance  •  15 min Verzögerung',
        'loading':     '⚡ Lade…',
        'ready':       '✓ Aktuell',
        'err_rate':    '❌ Kurs nicht verfügbar',
        'err_amount':  '❌ Ungültig',
        'err_sep':     'Bitte Währung wählen',
        'quick_label': 'Schnellwahl',
        'rate_fmt':    '1 {f} = {r} {t}',
        'info_title':  'ℹ️  Über diese App',
        'info_app':    ('<b>Rechner &amp; Währungsrechner</b> ist Teil von '
                        '<b>Stock Monitor</b> –<br>der kostenlosen Portfolio-App.'
                        '<br><br>🌐 <a href="https://www.stock-monitor.ch">'
                        'www.stock-monitor.ch</a>'),
        'info_donate': '<b>Stock Monitor unterstützen ❤️</b><br>'
                       'Kostenlos – jede Spende hilft bei der Weiterentwicklung.',
        'twint_cap':   'TWINT',
        'btn_paypal':  '💳  PayPal  –  paypal.me/StockMonitor',
        'btn_close':   '✖  Schließen',
        'calc_div0':   'Div. durch 0',
        'calc_err':    'Fehler',
        'tab_sav':     '📈  Zins',
        'sav_title':   'Zinsrechner',
        'sav_start':   'Startkapital',
        'sav_deposit': 'Einzahlung / Jahr',
        'sav_years':   'Laufzeit (Jahre)',
        'sav_rate':    'Zinssatz (%)',
        'sav_with':    'Mit Einzahlungen',
        'sav_without': 'Nur Zinseszins',
        'sav_total':   'Eingezahlt total',
        'sav_gain':    'Zinsgewinn total',
        'sav_dep_sum': '+ Einzahlungen gesamt',
        'sav_chf':     'CHF',
        'sav_years_u': 'Jahre',
    },
    'EN': {
        'title':       'Calculator & Currency Converter',
        'tab_calc':    '🔢  Calculator',
        'tab_curr':    '💱  Currency',
        'btn_convert': 'Convert',
        'btn_swap':    '⇄',
        'hint':        'Yahoo Finance  •  15 min delay',
        'loading':     '⚡ Loading…',
        'ready':       '✓ Current',
        'err_rate':    '❌ Rate unavailable',
        'err_amount':  '❌ Invalid',
        'err_sep':     'Please select a currency',
        'quick_label': 'Quick pairs',
        'rate_fmt':    '1 {f} = {r} {t}',
        'info_title':  'ℹ️  About this App',
        'info_app':    ('<b>Calculator &amp; Currency Converter</b> is part of '
                        '<b>Stock Monitor</b> –<br>the free portfolio app.'
                        '<br><br>🌐 <a href="https://www.stock-monitor.ch">'
                        'www.stock-monitor.ch</a>'),
        'info_donate': '<b>Support Stock Monitor ❤️</b><br>'
                       'Free app – every donation helps development.',
        'twint_cap':   'TWINT',
        'btn_paypal':  '💳  PayPal  –  paypal.me/StockMonitor',
        'btn_close':   '✖  Close',
        'calc_div0':   'Div. by 0',
        'calc_err':    'Error',
        'tab_sav':     '📈  Interest',
        'sav_title':   'Savings Calculator',
        'sav_start':   'Initial capital',
        'sav_deposit': 'Deposit / year',
        'sav_years':   'Duration (years)',
        'sav_rate':    'Interest rate (%)',
        'sav_with':    'With deposits',
        'sav_without': 'Only compound int.',
        'sav_total':   'Total paid in',
        'sav_gain':    'Total interest gain',
        'sav_dep_sum': '+ Total deposits',
        'sav_chf':     'CHF',
        'sav_years_u': 'years',
    },
}

_lang = _detect_lang()

def TR(key, **kw):
    s = STRINGS[_lang].get(key, key)
    return s.format(**kw) if kw else s

# ─── Zahlenformat ─────────────────────────────────────────────────────────────

NUM_FORMATS = ['CH', 'DE', 'US']
_nfi = 0   # Index

def _fmt(v: float, dec: int = 4) -> str:
    s = f"{abs(v):,.{dec}f}"
    fmt = NUM_FORMATS[_nfi]
    if fmt == 'CH': s = s.replace(',', "'")
    elif fmt == 'DE': s = s.replace(',','X').replace('.',',').replace('X','.')
    return f"-{s}" if v < 0 else s

# ─── Yahoo-Worker ─────────────────────────────────────────────────────────────

class ConvertWorker(QThread):
    done = pyqtSignal(float, str)

    def __init__(self, fc, tc):
        super().__init__()
        self.fc, self.tc = fc, tc

    def run(self):
        r, e = self._rate(self.fc, self.tc)
        self.done.emit(r if r is not None else -1.0, e or "")

    def _precious_usd(self, key):
        for sym in PRECIOUS_MAP[key]:
            try:
                p = yf.Ticker(sym).fast_info.last_price
                if p and float(p) > 0: return float(p)
            except Exception: pass
        return None

    def _rate(self, f, t):
        if f == t: return 1.0, None
        if f == SEPARATOR or t == SEPARATOR: return None, TR('err_sep')
        try:
            if f in PRECIOUS_MAP:
                u = self._precious_usd(f)
                if u is None: return None, TR('err_rate')
                if t == 'USD': return u, None
                r2, e = self._rate('USD', t); return (u*r2, e) if r2 else (None, e)
            if t in PRECIOUS_MAP:
                u = self._precious_usd(t)
                if u is None: return None, TR('err_rate')
                if f == 'USD': return 1/u, None
                r1, e = self._rate(f, 'USD'); return (r1/u, e) if r1 else (None, e)
            if f in CRYPTO_MAP and t == 'USD':
                tk = yf.Ticker(CRYPTO_MAP[f])
                p = tk.fast_info.get('lastPrice') or tk.info.get('regularMarketPrice')
                return float(p), None
            if f == 'USD' and t in CRYPTO_MAP:
                tk = yf.Ticker(CRYPTO_MAP[t])
                p = tk.fast_info.get('lastPrice') or tk.info.get('regularMarketPrice')
                return 1/float(p), None
            if f in CRYPTO_MAP:
                r1,_ = self._rate(f,'USD'); r2,_ = self._rate('USD',t); return r1*r2, None
            if t in CRYPTO_MAP:
                r1,_ = self._rate(f,'USD'); r2,_ = self._rate('USD',t); return r1*r2, None
            tk = yf.Ticker(f"{f}{t}=X")
            r = tk.fast_info.get('lastPrice') or tk.info.get('regularMarketPrice')
            return float(r), None
        except Exception as e:
            return None, str(e)

# ─── Info-Dialog ──────────────────────────────────────────────────────────────

class InfoDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle(TR('info_title'))
        self.setFixedSize(420, 460)
        lay = QVBoxLayout(self)
        lay.setSpacing(10)
        lay.setContentsMargins(20, 16, 20, 16)

        app_lbl = QLabel(TR('info_app'))
        app_lbl.setOpenExternalLinks(True)
        app_lbl.setWordWrap(True)
        app_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        app_lbl.setStyleSheet("font-size:12px; padding:6px;")
        lay.addWidget(app_lbl)

        sep = QFrame(); sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet("color:#aaa;"); lay.addWidget(sep)

        don_lbl = QLabel(TR('info_donate'))
        don_lbl.setWordWrap(True)
        don_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        don_lbl.setStyleSheet("font-size:11px;")
        lay.addWidget(don_lbl)

        # Twint QR – vorberechnet auf 175×176, kein Scaling zur Laufzeit
        try:
            px = QPixmap()
            px.loadFromData(QByteArray(base64.b64decode(TWINT_QR_175)))
            qr_lbl = QLabel()
            qr_lbl.setFixedSize(175, 176)
            qr_lbl.setPixmap(px)
            qr_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            cap = QLabel(f"<b>{TR('twint_cap')}</b>")
            cap.setAlignment(Qt.AlignmentFlag.AlignCenter)
            cap.setStyleSheet("font-size:11px;")
            col = QVBoxLayout()
            col.setSpacing(2)
            col.addWidget(qr_lbl)
            col.addWidget(cap)
            row = QHBoxLayout()
            row.setAlignment(Qt.AlignmentFlag.AlignCenter)
            row.addLayout(col)
            lay.addLayout(row)
        except Exception as e:
            print("QR Fehler:", e)

        pp = QPushButton(TR('btn_paypal'))
        pp.setMinimumHeight(34)
        pp.setStyleSheet("background:#003087; color:white; font-weight:bold; "
                         "border-radius:6px; padding:4px;")
        pp.clicked.connect(lambda: QDesktopServices.openUrl(
            QUrl("https://paypal.me/StockMonitor")))
        lay.addWidget(pp)

        cl = QPushButton(TR('btn_close'))
        cl.setMinimumHeight(30)
        cl.clicked.connect(self.close)
        lay.addWidget(cl)

# ─── App-Icon ─────────────────────────────────────────────────────────────────

def _make_app_icon() -> QIcon:
    icon = QIcon()
    for sz in [16, 24, 32, 48, 64, 128, 256]:
        px = QPixmap(sz, sz)
        px.fill(Qt.GlobalColor.transparent)
        p = QPainter(px)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setPen(Qt.PenStyle.NoPen)

        m   = max(1, sz // 16)
        rad = max(2, sz // 7)

        # Gehäuse (blau)
        p.setBrush(QBrush(QColor("#2471a3")))
        p.drawRoundedRect(m, m, sz - 2*m, sz - 2*m, rad, rad)

        # Display-Streifen (dunkelblau)
        dh = max(3, sz * 22 // 100)
        dm = max(2, sz *  9 // 100)
        p.setBrush(QBrush(QColor("#1a5276")))
        p.drawRoundedRect(dm, dm, sz - 2*dm, dh, max(1, sz // 20), max(1, sz // 20))

        # Tasten-Raster (3 Zeilen × 4 Spalten) – ab 24 px sichtbar
        if sz >= 24:
            gap = max(1, sz // 20)
            top = dm + dh + gap
            bw  = (sz - 2*dm - 3*gap) // 4
            bh  = (sz - top - dm  - 2*gap) // 3
            for row in range(3):
                for col in range(4):
                    x = dm + col * (bw + gap)
                    y = top + row * (bh + gap)
                    # = -Taste orange, Rest hellblau
                    col_eq = (row == 2 and col == 3)
                    p.setBrush(QBrush(QColor("#e67e22" if col_eq else "#aed6f1")))
                    p.drawRoundedRect(x, y, bw, bh, max(1, sz // 32), max(1, sz // 32))

        p.end()
        icon.addPixmap(px)
    return icon

# ─── Haupt-Fenster ────────────────────────────────────────────────────────────

class MainWindow(QMainWindow):

    def __init__(self):
        super().__init__()
        self._dark      = QApplication.palette().color(
            QPalette.ColorRole.Window).lightness() < 128
        self._worker    = None

        # Rechner-Zustand
        self._c_expr  = ""
        self._c_disp  = ""
        self._c_eval  = False
        self._c_hist  = ""

        # Einstellungen laden (vor _build_ui, damit _nfi/_lang stimmen)
        self._settings = QSettings("StockMonitor", "FxCalc")
        global _nfi, _lang
        _nfi  = int(self._settings.value("num_format",    _nfi))
        _lang = self._settings.value("language",           _lang)

        # Währungs-Zustand
        self._w_input = ""
        self._w_from  = self._settings.value("currency_from", 'USD')
        self._w_to    = self._settings.value("currency_to",   'CHF')
        self._w_rate  = None

        self._build_ui()
        self.from_combo.setCurrentText(self._w_from)
        self.to_combo.setCurrentText(self._w_to)
        tab = int(self._settings.value("active_tab", 0))
        self._switch(tab)
        self._do_convert()

    # ── UI ───────────────────────────────────────────────────────────────────

    def _build_ui(self):
        self.setWindowTitle(TR('title'))
        self.setFixedSize(420, 720)

        root = QWidget()
        self.setCentralWidget(root)
        vlay = QVBoxLayout(root)
        vlay.setSpacing(0)
        vlay.setContentsMargins(0, 0, 0, 0)

        # ── Top-Bar ──────────────────────────────────────────────────────────
        top = QWidget()
        top.setFixedHeight(38)
        tlay = QHBoxLayout(top)
        tlay.setContentsMargins(8, 4, 8, 4)
        tlay.setSpacing(6)

        self.info_btn = QPushButton("ℹ")
        self.info_btn.setFixedSize(30, 28)
        self.info_btn.setStyleSheet("font-size:14px; font-weight:bold;")
        self.info_btn.clicked.connect(self._show_info)
        tlay.addWidget(self.info_btn)

        tlay.addStretch()

        self.title_lbl = QLabel(TR('title'))
        self.title_lbl.setFont(QFont("Arial", 10, QFont.Weight.Bold))
        tlay.addWidget(self.title_lbl)

        tlay.addStretch()

        self.fmt_btn = QPushButton(NUM_FORMATS[_nfi])
        self.fmt_btn.setFixedSize(34, 28)
        self.fmt_btn.setStyleSheet("font-size:9px; font-weight:bold;")
        self.fmt_btn.setToolTip("Zahlenformat: CH → DE → US")
        self.fmt_btn.clicked.connect(self._toggle_fmt)
        tlay.addWidget(self.fmt_btn)

        self.lang_btn = QPushButton(_lang)
        self.lang_btn.setFixedSize(30, 28)
        self.lang_btn.setStyleSheet("font-size:9px; font-weight:bold;")
        self.lang_btn.clicked.connect(self._toggle_lang)
        tlay.addWidget(self.lang_btn)

        vlay.addWidget(top)

        # ── Display ──────────────────────────────────────────────────────────
        disp_bg = "#0d2a3d" if self._dark else "#eaf4fb"
        disp_fg = "#7fc8f0" if self._dark else "#1a5276"
        disp_sub = "#5599bb" if self._dark else "#5d8aa8"
        disp_hist = "#446688" if self._dark else "#8aabca"

        disp_widget = QWidget()
        disp_widget.setFixedHeight(140)
        disp_widget.setStyleSheet(f"background:{disp_bg};")
        dlay = QVBoxLayout(disp_widget)
        dlay.setContentsMargins(14, 6, 14, 6)
        dlay.setSpacing(0)

        self.hist_lbl = QLabel("")
        self.hist_lbl.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignTop)
        self.hist_lbl.setStyleSheet(f"font-size:11px; color:{disp_hist}; background:transparent;")
        self.hist_lbl.setMinimumHeight(18)
        dlay.addWidget(self.hist_lbl)

        dlay.addStretch()

        self.main_lbl = QLabel("0")
        self.main_lbl.setFont(QFont("Arial", 36, QFont.Weight.Bold))
        self.main_lbl.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignBottom)
        self.main_lbl.setWordWrap(True)
        self.main_lbl.setStyleSheet(f"color:{disp_fg}; background:transparent;")
        dlay.addWidget(self.main_lbl)

        self.sub_lbl = QLabel("")
        self.sub_lbl.setAlignment(Qt.AlignmentFlag.AlignRight)
        self.sub_lbl.setStyleSheet(f"font-size:11px; color:{disp_sub}; background:transparent;")
        self.sub_lbl.setMinimumHeight(16)
        dlay.addWidget(self.sub_lbl)

        vlay.addWidget(disp_widget)

        # Trennlinie
        vlay.addWidget(self._hline())

        # ── Tabs ──────────────────────────────────────────────────────────────
        tab_bar = QWidget()
        tab_bar.setFixedHeight(40)
        tbar_lay = QHBoxLayout(tab_bar)
        tbar_lay.setSpacing(0)
        tbar_lay.setContentsMargins(0, 0, 0, 0)

        self.tab_calc = QPushButton(TR('tab_calc'))
        self.tab_curr = QPushButton(TR('tab_curr'))
        self.tab_sav  = QPushButton(TR('tab_sav'))
        for btn in (self.tab_calc, self.tab_curr, self.tab_sav):
            btn.setCheckable(True)
            btn.setFixedHeight(40)
            btn.setFont(QFont("Arial", 11, QFont.Weight.Bold))
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            tbar_lay.addWidget(btn)

        vlay.addWidget(tab_bar)
        vlay.addWidget(self._hline())

        # ── Stacked Widget ────────────────────────────────────────────────────
        self.stack = QStackedWidget()
        self.stack.addWidget(self._build_calc_page())
        self.stack.addWidget(self._build_curr_page())
        self.stack.addWidget(self._build_savings_page())
        vlay.addWidget(self.stack)

        self.tab_calc.clicked.connect(lambda: self._switch(0))
        self.tab_curr.clicked.connect(lambda: self._switch(1))
        self.tab_sav.clicked.connect(lambda:  self._switch(2))

    def _hline(self):
        f = QFrame(); f.setFrameShape(QFrame.Shape.HLine)
        f.setFixedHeight(1)
        f.setStyleSheet("background:#ccc;" if not self._dark else "background:#1e4060;")
        return f

    # ── Display setzen ────────────────────────────────────────────────────────

    def _set_display(self, main: str, sub: str = "", hist: str = ""):
        fs = 36 if len(main) <= 9 else (26 if len(main) <= 14 else (18 if len(main) <= 20 else 13))
        self.main_lbl.setFont(QFont("Arial", fs, QFont.Weight.Bold))
        self.main_lbl.setText(main)
        self.sub_lbl.setText(sub)
        self.hist_lbl.setText(hist)

    # ── Rechner-Seite ─────────────────────────────────────────────────────────

    def _build_calc_page(self):
        page = QWidget()
        lay = QVBoxLayout(page)
        lay.setSpacing(5)
        lay.setContentsMargins(8, 8, 8, 8)

        grid = QGridLayout()
        grid.setSpacing(6)

        # row, col, colspan, text, style
        buttons = [
            (0,0,1,"CE","func"),  (0,1,1,"←","func"),
            (0,2,1,"(","func"),   (0,3,1,")","func"),
            (0,4,1,"%","func"),
            (1,0,1,"√","func"),   (1,1,1,"x²","func"),
            (1,2,1,"7","num"),    (1,3,1,"8","num"),    (1,4,1,"9","num"),
            (2,0,1,"÷","op"),     (2,1,1,"×","op"),
            (2,2,1,"4","num"),    (2,3,1,"5","num"),    (2,4,1,"6","num"),
            (3,0,1,"−","op"),     (3,1,1,"+","op"),
            (3,2,1,"1","num"),    (3,3,1,"2","num"),    (3,4,1,"3","num"),
            (4,0,1,"±","func"),   (4,1,1,".","num"),
            (4,2,1,"0","num"),    (4,3,2,"=","eq"),
        ]

        for (r,c,span,txt,sty) in buttons:
            btn = QPushButton(txt)
            btn.setMinimumHeight(60)
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
            btn.setFont(QFont("Arial", 15, QFont.Weight.Bold if sty in ("eq","op") else QFont.Weight.Normal))
            btn.setStyleSheet(self._btn_css(sty))
            btn.clicked.connect(lambda _, t=txt: self._calc_btn(t))
            grid.addWidget(btn, r, c, 1, span)

        lay.addLayout(grid)
        return page

    def _btn_css(self, sty: str) -> str:
        r = "border-radius:10px; padding:2px;"
        if self._dark:
            m = {"num":"background:#1e3a4f;color:#c8e6f5;",
                 "op": "background:#1a4a6b;color:#7fc8f0;font-weight:bold;",
                 "func":"background:#1c2d3a;color:#8899aa;",
                 "eq": "background:#c0590e;color:white;font-weight:bold;"}
        else:
            m = {"num":"background:#d6eaf8;color:#1a5276;",
                 "op": "background:#2980b9;color:white;font-weight:bold;",
                 "func":"background:#bdc3c7;color:#2c3e50;",
                 "eq": "background:#e67e22;color:white;font-weight:bold;"}
        return r + m.get(sty, "")

    # ── Währungs-Seite ────────────────────────────────────────────────────────

    def _build_curr_page(self):
        page = QWidget()
        lay = QVBoxLayout(page)
        lay.setSpacing(5)
        lay.setContentsMargins(8, 6, 8, 6)

        # Selektoren + Kurs
        sel_row = QHBoxLayout()
        self.from_combo = QComboBox()
        self.to_combo   = QComboBox()
        for cb in (self.from_combo, self.to_combo):
            cb.addItems(CURRENCIES)
            cb.setMinimumHeight(36)
            cb.setFont(QFont("Arial", 13))
        self.from_combo.setCurrentText(self._w_from)
        self.to_combo.setCurrentText(self._w_to)

        self.swap_btn = QPushButton(TR('btn_swap'))
        self.swap_btn.setFixedSize(40, 36)
        self.swap_btn.setFont(QFont("Arial", 14))
        self.swap_btn.clicked.connect(self._do_swap)

        sel_row.addWidget(self.from_combo)
        sel_row.addWidget(self.swap_btn)
        sel_row.addWidget(self.to_combo)
        lay.addLayout(sel_row)

        self.rate_lbl = QLabel("")
        self.rate_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.rate_lbl.setStyleSheet("font-size:11px; color:gray;")
        lay.addWidget(self.rate_lbl)

        self.status_lbl = QLabel(TR('hint'))
        self.status_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.status_lbl.setStyleSheet("font-size:10px; color:gray;")
        lay.addWidget(self.status_lbl)

        lay.addWidget(self._hline())

        # ── Ziffernblock (für Betrag-Eingabe) ─────────────────────────────
        num_grid = QGridLayout()
        num_grid.setSpacing(6)

        num_buttons = [
            (0,0,"7","num"),  (0,1,"8","num"),  (0,2,"9","num"),  (0,3,"←","func"),
            (1,0,"4","num"),  (1,1,"5","num"),  (1,2,"6","num"),  (1,3,"CE","func"),
            (2,0,"1","num"),  (2,1,"2","num"),  (2,2,"3","num"),  (2,3,None,None),
            (3,0,"±","func"), (3,1,"0","num"),  (3,2,".","num"),  (3,3,None,None),
        ]

        # Umrechnen-Button (rechts, 2 Zeilen hoch)
        conv_btn = QPushButton(TR('btn_convert'))
        conv_btn.setMinimumHeight(100)
        conv_btn.setFont(QFont("Arial", 12, QFont.Weight.Bold))
        conv_btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        conv_btn.setStyleSheet(self._btn_css("eq"))
        conv_btn.clicked.connect(self._do_convert)
        num_grid.addWidget(conv_btn, 2, 3, 2, 1)
        self.conv_btn = conv_btn

        for (r, c, txt, sty) in num_buttons:
            if txt is None: continue
            btn = QPushButton(txt)
            btn.setMinimumHeight(48)
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
            btn.setFont(QFont("Arial", 14))
            btn.setStyleSheet(self._btn_css(sty))
            btn.clicked.connect(lambda _, t=txt: self._curr_num_btn(t))
            num_grid.addWidget(btn, r, c)

        lay.addLayout(num_grid)
        lay.addWidget(self._hline())

        # ── Schnellwahl ───────────────────────────────────────────────────
        self.quick_lbl = QLabel(TR('quick_label'))
        self.quick_lbl.setStyleSheet("font-size:10px; color:gray;")
        lay.addWidget(self.quick_lbl)

        qg = QGridLayout()
        qg.setSpacing(4)
        for i, (f, t) in enumerate(QUICK_PAIRS):
            btn = QPushButton(f"{f}/{t}")
            btn.setMinimumHeight(28)
            btn.setFont(QFont("Arial", 10))
            btn.setStyleSheet(self._btn_css("num"))
            btn.clicked.connect(lambda _, ff=f, tt=t: self._quick_pair(ff, tt))
            qg.addWidget(btn, i // 4, i % 4)
        lay.addLayout(qg)

        return page

    # ── Zinsrechner-Seite ─────────────────────────────────────────────────────

    def _build_savings_page(self):
        page = QWidget()
        outer = QVBoxLayout(page)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        inner = QWidget()
        lay = QVBoxLayout(inner)
        lay.setSpacing(10)
        lay.setContentsMargins(12, 12, 12, 12)
        scroll.setWidget(inner)
        outer.addWidget(scroll)

        # Titel
        title = QLabel(TR('sav_title'))
        title.setFont(QFont("Arial", 15, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(title)
        self._sav_title_lbl = title

        # Eingabe-Hilfsfunktion
        def _spin(label_key, default, decimals, max_val, suffix):
            row = QWidget()
            hl = QHBoxLayout(row)
            hl.setContentsMargins(0, 0, 0, 0)
            lbl = QLabel(TR(label_key))
            lbl.setFont(QFont("Arial", 11))
            lbl.setFixedWidth(150)
            sp = QDoubleSpinBox()
            sp.setDecimals(decimals)
            sp.setMaximum(max_val)
            sp.setValue(default)
            sp.setSuffix(f"  {suffix}")
            sp.setFont(QFont("Arial", 12))
            sp.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            sp.setFixedHeight(36)
            hl.addWidget(lbl)
            hl.addWidget(sp)
            lay.addWidget(row)
            return lbl, sp

        self._sav_key_start,   self._sav_start   = _spin('sav_start',   10000, 0, 10_000_000, self._w_to)
        self._sav_key_deposit, self._sav_deposit = _spin('sav_deposit',  1200, 0, 10_000_000, self._w_to)
        self._sav_key_years,   self._sav_years   = _spin('sav_years',      20, 0,         100, TR('sav_years_u'))
        self._sav_key_rate,    self._sav_rate    = _spin('sav_rate',       5.0, 2,          50, '%')

        lay.addWidget(self._hline())

        # Ergebnis-Labels
        def _row_label(text_key, bold=False, big=False, color=None):
            row = QWidget()
            hl = QHBoxLayout(row)
            hl.setContentsMargins(0, 0, 0, 0)
            lbl_k = QLabel(TR(text_key))
            lbl_k.setFont(QFont("Arial", 11 if not big else 13, QFont.Weight.Bold if bold else QFont.Weight.Normal))
            lbl_v = QLabel("–")
            lbl_v.setFont(QFont("Arial", 11 if not big else 14, QFont.Weight.Bold if bold else QFont.Weight.Normal))
            lbl_v.setAlignment(Qt.AlignmentFlag.AlignRight)
            if color:
                lbl_v.setStyleSheet(f"color:{color};")
            hl.addWidget(lbl_k)
            hl.addWidget(lbl_v)
            lay.addWidget(row)
            return lbl_k, lbl_v

        self._sav_key_with,    self._sav_lbl_with    = _row_label('sav_with',    bold=True, big=True)
        self._sav_key_without, self._sav_lbl_without = _row_label('sav_without')
        self._sav_key_dep_sum, self._sav_lbl_dep_sum = _row_label('sav_dep_sum')
        lay.addWidget(self._hline())
        self._sav_key_total,   self._sav_lbl_total   = _row_label('sav_total')
        self._sav_key_gain,    self._sav_lbl_gain    = _row_label('sav_gain',    color="#27ae60")

        lay.addStretch()

        # Berechnung auslösen bei jeder Änderung
        for sp in (self._sav_start, self._sav_deposit, self._sav_years, self._sav_rate):
            sp.valueChanged.connect(self._sav_calc)
        self._sav_calc()

        return page

    def _sav_calc(self):
        start   = self._sav_start.value()
        deposit = self._sav_deposit.value()
        years   = int(self._sav_years.value())
        rate    = self._sav_rate.value() / 100.0

        if years <= 0:
            for lbl in (self._sav_lbl_with, self._sav_lbl_without,
                        self._sav_lbl_dep_sum, self._sav_lbl_total, self._sav_lbl_gain):
                lbl.setText("–")
            return

        factor  = (1 + rate) ** years
        without = start * factor
        withDep = (without + deposit * (factor - 1) / rate) if rate != 0 else (without + deposit * years)
        total   = start + deposit * years
        gain    = withDep - total
        dep_sum = deposit * years

        def f(v):
            if abs(v) >= 1_000_000:
                return f"{_fmt(v / 1_000_000, 3)} Mio. {self._w_to}"
            return f"{_fmt(v, 0)} {self._w_to}"

        self._sav_lbl_with.setText(f(withDep))
        self._sav_lbl_without.setText(f(without))
        self._sav_lbl_dep_sum.setText(f"+ {f(dep_sum)}")
        self._sav_lbl_total.setText(f(total))
        self._sav_lbl_gain.setText(f(gain))

    # ── Umschalten ────────────────────────────────────────────────────────────

    def _switch(self, idx: int):
        old = self.stack.currentIndex()
        if old != idx:
            # Wert transferieren
            if idx == 1:   # Rechner → Währung
                try:
                    v = float(self._c_expr) if self._c_expr else 0.0
                    self._w_input = str(abs(v)) if v != 0 else ""
                    self._update_curr_display()
                except Exception:
                    pass
            else:           # Währung → Rechner
                try:
                    val_str = self._w_input or "0"
                    self._c_expr = val_str
                    self._c_disp = _fmt(float(val_str), 4)
                    self._c_eval = True
                    self._c_hist = ""
                    self._set_display(self._c_disp)
                except Exception:
                    pass

        self.stack.setCurrentIndex(idx)
        self.tab_calc.setChecked(idx == 0)
        self.tab_curr.setChecked(idx == 1)
        self.tab_sav.setChecked(idx == 2)
        act = ("background:#2980b9;color:white;" if not self._dark
               else "background:#1a4a6b;color:#7fc8f0;")
        ina = ("background:#d6eaf8;color:#1a5276;" if not self._dark
               else "background:#0d2a3d;color:#5588aa;")
        self.tab_calc.setStyleSheet(act if idx == 0 else ina)
        self.tab_curr.setStyleSheet(act if idx == 1 else ina)
        self.tab_sav.setStyleSheet(act if idx == 2 else ina)
        self._save_settings()

    def _quick_pair(self, f, t):
        self.from_combo.setCurrentText(f)
        self.to_combo.setCurrentText(t)
        self._do_convert()

    # ── Rechner-Logik ─────────────────────────────────────────────────────────

    def _calc_btn(self, t: str):
        if t == "CE":
            self._c_expr = ""; self._c_disp = ""; self._c_eval = False; self._c_hist = ""
            self._set_display("0"); return
        if t == "←":
            if self._c_eval:
                self._c_expr = ""; self._c_disp = ""; self._c_eval = False
                self._set_display("0"); return
            self._c_disp = self._c_disp[:-1]
            for tok, l in [("math.sqrt(",10),("**2",3),("/100",4)]:
                if self._c_expr.endswith(tok): self._c_expr = self._c_expr[:-l]; break
            else:
                self._c_expr = self._c_expr[:-1]
            self._update_calc_display(); return
        if t == "=":
            self._calc_eval(); return

        if self._c_eval and t not in ('+','−','×','÷','%','x²'):
            self._c_expr = ""; self._c_disp = ""
        self._c_eval = False

        mp = {"√":("math.sqrt(","√("),"x²":("**2","²"),"×":("*","×"),
              "÷":("/","÷"),"%":("/100","%"),"−":("-","−")}
        if t in mp:
            self._c_expr += mp[t][0]; self._c_disp += mp[t][1]
        elif t == "±":
            if self._c_expr:
                self._c_expr = f"-({self._c_expr})"; self._c_disp = f"-({self._c_disp})"
            else:
                self._c_expr = "-"; self._c_disp = "-"
        elif t == "(":
            # 2( → 2*(
            if self._c_expr and (self._c_expr[-1].isdigit() or self._c_expr[-1] == ")"):
                self._c_expr += "*"; self._c_disp += "×"
            self._c_expr += "("; self._c_disp += "("
        else:
            # Führende Null entfernen: "05" → "5" (verhindert Python-Eval-Fehler)
            if t.isdigit() and self._c_expr:
                last = self._c_expr[-1]
                if last == '0':
                    prev = self._c_expr[-2] if len(self._c_expr) > 1 else ''
                    if len(self._c_expr) == 1 or prev in '+-*/(,':
                        self._c_expr = self._c_expr[:-1]
                        self._c_disp = self._c_disp[:-1]
            self._c_expr += t; self._c_disp += t

        self._update_calc_display()

    def _update_calc_display(self):
        d = self._c_disp or "0"
        op = d.count('(') - d.count(')')
        if op > 0: d = d + ')' * op
        self._set_display(d, hist=self._c_hist)

    def _calc_eval(self):
        if not self._c_expr: return
        op = self._c_expr.count('(') - self._c_expr.count(')')
        ev = self._c_expr + ')' * max(op,0)
        dv = self._c_disp  + ')' * max(op,0)
        ev = re.sub(r'(?<![.\d])0+(\d)', r'\1', ev)
        try:
            res = float(eval(ev, {"__builtins__":{}}, {"math":math}))
            if not math.isfinite(res): raise ZeroDivisionError
            rs = (_fmt(float(int(res)), 0) if res == int(res) and abs(res) < 1e15
                  else _fmt(res, 8).rstrip('0').rstrip("." if NUM_FORMATS[_nfi] != 'DE' else ","))
            self._c_hist = dv + " ="
            self._c_expr = str(res); self._c_disp = rs; self._c_eval = True
            self._set_display(rs, hist=self._c_hist)
        except ZeroDivisionError:
            self._set_display(TR('calc_div0'))
            self._c_expr = ""; self._c_disp = ""; self._c_eval = False
        except Exception:
            self._set_display(TR('calc_err'))
            self._c_expr = ""; self._c_disp = ""; self._c_eval = False

    # ── Tastatur ─────────────────────────────────────────────────────────────

    def keyPressEvent(self, ev):
        k = ev.key(); t = ev.text()
        if self.stack.currentIndex() == 0:
            km = {Qt.Key.Key_Return:"=", Qt.Key.Key_Enter:"=",
                  Qt.Key.Key_Backspace:"←", Qt.Key.Key_Escape:"CE",
                  Qt.Key.Key_Asterisk:"×", Qt.Key.Key_Slash:"÷",
                  Qt.Key.Key_Percent:"%",
                  Qt.Key.Key_ParenLeft:"(", Qt.Key.Key_ParenRight:")",
                  Qt.Key.Key_Period:".", Qt.Key.Key_Comma:"."}
            if k in km: self._calc_btn(km[k]); return
            if t in '0123456789': self._calc_btn(t); return
            if t == '+': self._calc_btn('+'); return
            if t == '-': self._calc_btn('−'); return
            if t == '*': self._calc_btn('×'); return
            if t == '/': self._calc_btn('÷'); return
        else:
            km = {Qt.Key.Key_Return:"=", Qt.Key.Key_Enter:"=",
                  Qt.Key.Key_Backspace:"←", Qt.Key.Key_Escape:"CE",
                  Qt.Key.Key_Period:".", Qt.Key.Key_Comma:"."}
            if k in km:
                if km[k] == "=": self._do_convert()
                else: self._curr_num_btn(km[k]); return
            if t in '0123456789': self._curr_num_btn(t); return
        super().keyPressEvent(ev)

    # ── Währungs-Ziffernblock ─────────────────────────────────────────────────

    def _curr_num_btn(self, t: str):
        s = self._w_input
        if t == "CE":
            self._w_input = ""
        elif t == "←":
            self._w_input = s[:-1]
        elif t == "±":
            self._w_input = s[1:] if s.startswith('-') else ('-'+s if s else s)
        elif t == ".":
            if '.' not in s: self._w_input = (s or "0") + "."
        else:
            if s == "0": self._w_input = t
            else: self._w_input = s + t
        self._update_curr_display()

    def _update_curr_display(self):
        txt = self._w_input or "0"
        self._set_display(txt, sub=f"{self._w_from} → {self._w_to}", hist="")

    # ── Währungs-Umrechnung ───────────────────────────────────────────────────

    def _refresh_sav_currency(self):
        self._sav_start.setSuffix(f"  {self._w_to}")
        self._sav_deposit.setSuffix(f"  {self._w_to}")
        self._sav_calc()

    def _do_convert(self):
        self._w_from = self.from_combo.currentText()
        self._w_to   = self.to_combo.currentText()
        self._save_settings()
        self._refresh_sav_currency()
        try:
            amt = float(self._w_input or "1")
        except ValueError:
            self._set_display(TR('err_amount')); return

        self.status_lbl.setText(TR('loading'))
        self.rate_lbl.setText("")
        self.conv_btn.setEnabled(False)
        self._w_amt = amt

        self._worker = ConvertWorker(self._w_from, self._w_to)
        self._worker.done.connect(self._on_done)
        self._worker.start()

    def _on_done(self, rate: float, err: str):
        self.conv_btn.setEnabled(True)
        if rate < 0:
            self.status_lbl.setText(err or TR('err_rate'))
            self._set_display(TR('err_rate')); return

        self._w_rate = rate
        converted = self._w_amt * rate
        dec = 6 if abs(converted) < 1 else 4
        self._set_display(
            f"{self._w_to}  {_fmt(converted, dec)}",
            sub=f"{_fmt(self._w_amt, 4)} {self._w_from}",
        )
        self.rate_lbl.setText(TR('rate_fmt', f=self._w_from, r=_fmt(rate,4), t=self._w_to))
        self.status_lbl.setText(TR('ready'))
        # Memory für Übertrag
        self._c_expr = str(converted); self._c_disp = _fmt(converted, dec); self._c_eval = True

    def _do_swap(self):
        f, t = self.from_combo.currentText(), self.to_combo.currentText()
        self.from_combo.setCurrentText(t); self.to_combo.setCurrentText(f)
        self._do_convert()

    # ── Zahlenformat / Sprache ────────────────────────────────────────────────

    def _toggle_fmt(self):
        global _nfi
        _nfi = (_nfi + 1) % len(NUM_FORMATS)
        self.fmt_btn.setText(NUM_FORMATS[_nfi])
        self._save_settings()
        self._sav_calc()

    def _toggle_lang(self):
        global _lang
        _lang = 'EN' if _lang == 'DE' else 'DE'
        self.lang_btn.setText(_lang)
        self._apply_lang()
        self._save_settings()

    def _apply_lang(self):
        self.setWindowTitle(TR('title'))
        self.title_lbl.setText(TR('title'))
        self.tab_calc.setText(TR('tab_calc'))
        self.tab_curr.setText(TR('tab_curr'))
        self.tab_sav.setText(TR('tab_sav'))
        self.swap_btn.setText(TR('btn_swap'))
        self.conv_btn.setText(TR('btn_convert'))
        self.quick_lbl.setText(TR('quick_label'))
        self.status_lbl.setText(TR('hint'))
        # Zinsrechner-Labels
        self._sav_title_lbl.setText(TR('sav_title'))
        self._sav_key_start.setText(TR('sav_start'))
        self._sav_key_deposit.setText(TR('sav_deposit'))
        self._sav_key_years.setText(TR('sav_years'))
        self._sav_key_rate.setText(TR('sav_rate'))
        self._sav_key_with.setText(TR('sav_with'))
        self._sav_key_without.setText(TR('sav_without'))
        self._sav_key_dep_sum.setText(TR('sav_dep_sum'))
        self._sav_key_total.setText(TR('sav_total'))
        self._sav_key_gain.setText(TR('sav_gain'))
        self._sav_start.setSuffix(f"  {self._w_to}")
        self._sav_deposit.setSuffix(f"  {self._w_to}")
        self._sav_years.setSuffix(f"  {TR('sav_years_u')}")
        self._sav_calc()

    def _save_settings(self):
        self._settings.setValue("num_format",    _nfi)
        self._settings.setValue("language",      _lang)
        self._settings.setValue("currency_from", self._w_from)
        self._settings.setValue("currency_to",   self._w_to)
        self._settings.setValue("active_tab",    self.stack.currentIndex())

    def closeEvent(self, ev):
        self._save_settings()
        super().closeEvent(ev)

    def _show_info(self):
        InfoDialog(self).exec()

# ─── Start ────────────────────────────────────────────────────────────────────

def _get_ico_path():
    candidates = []
    if hasattr(sys, '_MEIPASS'):
        candidates.append(os.path.join(sys._MEIPASS, 'fx-calc.ico'))
    candidates.append(os.path.join(os.path.dirname(sys.executable), 'fx-calc.ico'))
    try:
        candidates.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fx-calc.ico'))
    except Exception:
        pass
    candidates.append('fx-calc.ico')
    for p in candidates:
        if os.path.exists(p):
            return p
    return None

def main():
    if sys.platform == 'win32':
        try:
            import ctypes
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
                "StockMonitor.FxCalc.1")
        except Exception:
            pass

    app = QApplication(sys.argv)
    app.setApplicationName("Rechner & Währungsrechner")
    app.setApplicationVersion(APP_VERSION)
    app.setStyle('Fusion')

    _ico_path = _get_ico_path() if sys.platform == 'win32' else None
    _icon = QIcon(_ico_path) if _ico_path else _make_app_icon()
    app.setWindowIcon(_icon)

    win = MainWindow()
    win.setWindowIcon(_icon)
    scr = QApplication.primaryScreen().availableGeometry()
    win.move(scr.x() + (scr.width()-win.width())//2,
             scr.y() + int(scr.height()*0.05))
    win.show()
    sys.exit(app.exec())

if __name__ == '__main__':
    main()
