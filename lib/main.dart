import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Datenschutz ─────────────────────────────────────────────────────────────

const String kPrivacyUrl = 'https://stockmonitorch.github.io/fx-calc/privacy.html';

// ─── App-Einstieg ────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const FxCalcApp());
}

// ─── Lokalisierung (aus System-Sprache) ──────────────────────────────────────

bool _isDE() {
  final lang = Platform.localeName.toLowerCase();
  return lang.startsWith('de');
}

String tr(String de, String en) => _isDE() ? de : en;

// ─── Zahlenformat (aus System-Locale) ────────────────────────────────────────

String fmtNum(double v, {int dec = 4}) {
  final f = NumberFormat.decimalPatternDigits(locale: Platform.localeName, decimalDigits: dec);
  return f.format(v);
}

// Wie viele Dezimalstellen braucht ein Ergebnis wirklich?
// Nutzt toStringAsPrecision(10) direkt – ohne Double-Roundtrip, der neues Rauschen einführt.
int _neededDecimals(double v, {int max = 12}) {
  if (v == v.truncateToDouble()) return 0;
  final s = v.toStringAsPrecision(12);
  // Wissenschaftliche Notation (sehr grosse/kleine Zahlen)
  if (s.contains('e') || s.contains('E')) return max;
  final dot = s.indexOf('.');
  if (dot < 0) return 0;
  final dec = s.substring(dot + 1);
  int n = dec.length;
  while (n > 0 && dec[n - 1] == '0') n--;
  return math.min(n, max);
}

// ─── Tausendertrennzeichen für Eingabe ───────────────────────────────────────

String _thousandFmt(String digits) {
  final lang = Platform.localeName.toLowerCase();
  final String sep;
  if (lang.startsWith('de_ch') || lang.startsWith('de_at')) {
    sep = "'";
  } else if (lang.startsWith('de')) {
    sep = '.';
  } else {
    sep = ',';
  }
  final buf = StringBuffer();
  final offset = digits.length % 3;
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (i - offset) % 3 == 0) buf.write(sep);
    buf.write(digits[i]);
  }
  return buf.toString();
}

// Fügt Tausendertrennzeichen in einen Display-String ein (nur Ganzzahl-Teile ≥4 Stellen)
String _addThousands(String s) {
  return s.replaceAllMapped(RegExp(r'\d{4,}'), (m) {
    if (m.start > 0 && s[m.start - 1] == '.') return m.group(0)!;
    return _thousandFmt(m.group(0)!);
  });
}

// ─── Twint QR ────────────────────────────────────────────────────────────────

const String _twintQr175 = "iVBORw0KGgoAAAANSUhEUgAAAK8AAACwCAIAAAD2cKlsAAAHSElEQVR4nO2dUZLjNgxEx6lccvb+93A+nLgVC9NsAbSzqXrvUzIJUoMCCRLA3O73+xfA19fX19cf//UA4Hfifr/f7/fv7++Nvb3gf7nsx3c+YTnyvLmZ17JJ+PXyfnJeZGEbQKANINAGEH+eHzWWpdvtZt76DpPVNJEybPL85XE854dlh+UU/MOyn3y0XorHSME2gEAbQBQrxZOl4fJmKrS9S7Y0Gc7F/8wvH8e34ZrSWDKG6/UDbAMItAGEWyl24ffPue0N35Z95lJ2ic5n7T/FJy+SsA0g0AYQaAOIT+wbdp3uhR0eaZxF5sPwP/PjmXuD7wDbAAJtAOFWil32quFhDqU8+8wPBMt+ziMf3hKFy0fvm8y/JLYBBNoAAm0AUewbehdohtzDDB8uPbpwAc5vF3cdM3vR24/wr4JtAIE2gLi979hrV5RfaCqHi8Lwl+cmubu43dlug20AgTaAQBvgwCMB75iHOUn2a+QuDjMby7aJ3Pm8wln7uSzfhp+xN4UXsA0g0AYQhYfZSHAr2zbiWRrO5KTJcjxXpZQsmzT+BA3XN2mLbQCBNoD4Wxt+/fp1+4fGZvjcdrjv9T+7HQh7PjYJ57KUEs4676fssOy57DBsbsaDbQCBNoBAG0C4O8yGn5NHhE78z+Vgwv1E7vs1LiS9lLLJrhDc9hkBtgEE2gCi8DC9O+SdlqU8792FHubSAQvflpMtW5VNSs6i8ybn79n7c/hZmw+LbQCBNoBAG0Bcrh6apzv6Jo0qO3MP6qV543Zxifcwd6U/5FXozk24w4QItAHE5WiXYfnMsEPf+TLapbHiTE5OvZScYb3VeQILtgEE2gAire3iy1eVhjQ0XI09fCP6cnk39r7/BpAnoXsp+fVenv/+ArYBBNoAAm2AA497reV/QAyvxcrbxZ/uEk2Tq+NfiutJ2dVPe9jDPnOJD7ANINAGEGltl0kZ5gafyeAb0ji+nBSL8VKWJJ1jG0CgDSDQBhBpPsXkQjLPTg+X+fwOc3v5t2HWRjjaPJMlz/4g2gWugTaAGP0no0ldmJLGMhRe4i3b7gqQ8bw1aiacrJkCtgEE2gAijYvctYl9X4z8cJFqnHiWTHK0yyaTqNKrc8E2gEAbQKANcOAR5pDXmc7DNPKHvTG/9OOjRRpN8mH7T7GU4j+pp/GhjGhsAwi0AcSoznTIrvukhutbdjhhmP42cdSHJKsztgEE2gACbQCR1naZ/E8Hz65D6LcOOw9VnXyTMCFz2Xk7sBbbAAJtAJFWD/VHWnn1UN+kccRW9hOOZ1mbc0I+wbBQ6LLzhugXsA0g0AYQb8y8C48Ol+dujYPFSejKrhzDiW/SG0Mjaoa4SPgRtAEE2gBitG+YMMwy+zDbNyIbm4cdsm+Aa6ANcOBxPpVXAWuE6ZU/uBSvZ6Q0xnN1UssgRy8xl1J24h8um18aD7YBBNoAwsU3lEWjGyF7/l+pLEWf3zZqhvTKgXmJ+UMv0Y+2UZqjXcME2wACbQCBNoDYk0/RW5XPbRtFMT15HOKkHudwr9C4w5zUPjNgG0CgDSAu/yejRix5IydumEYXepg5uREOQ06G/vCufEM8TPgRtAEE2gCiyKd4vssj/J+XYOfUgNvtVl6v+Zh/fyNXvvVNyoEtp3B+W06/nKz/UGXzskMvMX+b3HBiG0CgDSBGdaaf+KOx0gvKb0qvvi3Jr16Hp4T+4VLi1SbDdPUXsA0g0AYQaAOI9D8ZPdmeOzA8cJ3sIbYXGF8mmoYjXI52176Kk2n4EbQBDjzOp4b5FL5J3rN/mDcJO2w8bHycfLS7phC+PQ8D2wACbQBxOS4yP6oLH+bhfn48jSrUn4lYbHhAu8JCvRR8CnCgDSDQBhCba7s0Yv4btV2Gu4rJcer2k8rh1qeU2NjGPcA2gEAbQLhol55X5h82mIScbC8c1rhtKpsPV89dlVlfwDaAQBtAuLPIXVlmP/3AdDi8v3/fItVoe2R7Mrv/5dVvgm0AgTaAQBtApB7mkzInv2wS+kvDcD/PWw8Wy34aow33Uo1ve3WDhW0AgTbAgUdA3OfjIvN4vXBg/mdDSinhN/lN5pJMAdsAAm0AgTaASKNdOl13b9Iu+WzhAfAw2mVXbM5kPI2LAj/CM9gGEGgDHAg9zEu9Jf5n3tz3M5GS9xO+3bXs5p6qf3hJEB4m/Au0AYT7T0Y5vla09ykaW+6Gk1LSuLV6q3+UM3GLDNgGEGgDCLQBxOVolyNbsvaGJb0abRtbjXydDisgDKNUPO3RYhtAoA0g9tSZ9jRs+LCCTDiGnHJgpegtLvRw9czr5ryAbQCBNoBAG0B8Yt9QroKT0JUSf2b8VvdsUixm+cthRWr/Fg8TfgRtAJH+r9wG2+1nw9capvI1qq54dvnDu+5CX8A2gEAbQBQrxa7KWaGDUPoCw0Itjd11Ka4RDu/x/TTKnIXiQrANINAGEGgDiDdm3sH/DmwDCLQBBNoAAm0AgTaAQBtA/AU/QTV1p/LkXQAAAABJRU5ErkJggg==";

// ─── Währungs-Konstanten ──────────────────────────────────────────────────────

const List<String> kCurrencies = [
  'USD','CHF','EUR','GBP','JPY','CAD','AUD','CNY',
  'HKD','SEK','NOK','DKK','NZD','SGD','MXN','BRL','INR','KRW','TRY',
  'BTC','ETH','XRP','SOL',
  '─── Edelmetalle & Rohstoffe ───',
  'XAU (Gold/oz)','XAG (Silber/oz)','XPT (Platin/oz)',
  'XPD (Palladium/oz)','XCU (Kupfer/lb)',
];

const String kSeparator = '─── Edelmetalle & Rohstoffe ───';

const Map<String,String> kCrypto = {
  'BTC':'BTC-USD','ETH':'ETH-USD','XRP':'XRP-USD','SOL':'SOL-USD',
};

const Map<String,String> kPrecious = {
  'XAU (Gold/oz)':'GC=F',
  'XAG (Silber/oz)':'SI=F',
  'XPT (Platin/oz)':'PL=F',
  'XPD (Palladium/oz)':'PA=F',
  'XCU (Kupfer/lb)':'HG=F',
};

const List<List<String>> kQuickPairs = [
  ['USD','CHF'],['CHF','USD'],
  ['EUR','CHF'],['CHF','EUR'],
  ['GBP','CHF'],['CHF','GBP'],
  ['EUR','USD'],['USD','EUR'],
  ['EUR','GBP'],['GBP','EUR'],
  ['JPY','CHF'],['CHF','JPY'],
];

// ─── Yahoo Finance API ────────────────────────────────────────────────────────

Future<double?> _yahooRate(String symbol) async {
  final url = Uri.parse(
    'https://query1.finance.yahoo.com/v8/finance/chart/$symbol'
    '?interval=1d&range=1d');
  try {
    final r = await http.get(url, headers: {'User-Agent': 'FXCalc/1.0'})
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body);
    final price = j['chart']['result'][0]['meta']['regularMarketPrice'];
    return (price as num).toDouble();
  } catch (_) {
    return null;
  }
}

Future<(double?, String?)> getRate(String from, String to) async {
  if (from == to) return (1.0, null);
  if (from == kSeparator || to == kSeparator) {
    return (null, tr('Trennzeile wählen', 'Select a currency'));
  }
  try {
    // Edelmetall
    if (kPrecious.containsKey(from)) {
      final usd = await _yahooRate(kPrecious[from]!);
      if (usd == null) return (null, tr('Kurs nicht verfügbar', 'Rate unavailable'));
      if (to == 'USD') return (usd, null);
      final (r2, e) = await getRate('USD', to);
      return r2 != null ? (usd * r2, null) : (null, e);
    }
    if (kPrecious.containsKey(to)) {
      final usd = await _yahooRate(kPrecious[to]!);
      if (usd == null) return (null, tr('Kurs nicht verfügbar', 'Rate unavailable'));
      if (from == 'USD') return (1.0 / usd, null);
      final (r1, e) = await getRate(from, 'USD');
      return r1 != null ? (r1 / usd, null) : (null, e);
    }
    // Krypto
    if (kCrypto.containsKey(from) || kCrypto.containsKey(to)) {
      if (kCrypto.containsKey(from) && to == 'USD') {
        final p = await _yahooRate(kCrypto[from]!);
        return p != null ? (p, null) : (null, tr('Kurs nicht verfügbar', 'Rate unavailable'));
      }
      if (from == 'USD' && kCrypto.containsKey(to)) {
        final p = await _yahooRate(kCrypto[to]!);
        return p != null ? (1.0 / p, null) : (null, tr('Kurs nicht verfügbar', 'Rate unavailable'));
      }
      final (r1, _) = await getRate(from, 'USD');
      final (r2, _) = await getRate('USD', to);
      if (r1 != null && r2 != null) return (r1 * r2, null);
      return (null, tr('Kurs nicht verfügbar', 'Rate unavailable'));
    }
    // Fiat via Yahoo Finance
    final p = await _yahooRate('$from$to=X');
    return p != null ? (p, null) : (null, tr('Kurs nicht verfügbar', 'Rate unavailable'));
  } catch (e) {
    return (null, e.toString());
  }
}

// ─── App ─────────────────────────────────────────────────────────────────────

class FxCalcApp extends StatelessWidget {
  const FxCalcApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FX Calc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2980B9),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A4A6B),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

// ─── Home mit Bottom-Navigation ──────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  // Gemeinsamer Memory-Wert zwischen den Seiten
  double _memValue = 0;
  String _currency = 'CHF';

  void _onMemCalc(double v)     => setState(() => _memValue = v);
  void _onMemCurr(double v)     => setState(() => _memValue = v);
  void _onCurrencyChanged(String c) => setState(() => _currency = c);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPrivacyConsent());
    if (Platform.isAndroid) {
      Future.delayed(const Duration(seconds: 3), _checkForUpdate);
    }
  }

  Future<void> _checkPrivacyConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('privacy_accepted') ?? false;
    if (accepted || !mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PrivacyConsentDialog(),
    );
  }

  Future<void> _checkForUpdate({bool showUpToDate = false}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final r = await http.get(
        Uri.parse('https://api.github.com/repos/StockMonitorCH/fx-calc/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (r.statusCode != 200) {
        if (showUpToDate) _showSnack(tr('Fehler: HTTP ${r.statusCode}', 'Error: HTTP ${r.statusCode}'));
        return;
      }
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String).replaceFirst(RegExp(r'^v'), '');
      if (!_isNewer(tag, current)) {
        if (showUpToDate) _showSnack(tr('App ist aktuell (v$current)', 'App is up to date (v$current)'));
        return;
      }
      final assets = (j['assets'] as List).cast<Map<String, dynamic>>();
      Map<String, dynamic>? apk;
      for (final a in assets) {
        if ((a['name'] as String).endsWith('.apk')) { apk = a; break; }
      }
      if (apk == null) return;
      final url = apk['browser_download_url'] as String;
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(version: tag, downloadUrl: url),
      );
    } catch (e) {
      debugPrint('Update-Check Fehler: $e');
      if (mounted && showUpToDate) _showSnack(tr('Keine Verbindung', 'No connection'));
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  bool _isNewer(String remote, String current) {
    final r = remote.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < math.max(r.length, c.length); i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CalculatorPage(initValue: _memValue, onResult: _onMemCalc),
      CurrencyPage(initAmount: _memValue > 0 ? _memValue : 1, onResult: _onMemCurr, onCurrencyChanged: _onCurrencyChanged),
      SavingsPage(currency: _currency),
      FinancePage(initValue: _memValue, onResult: _onMemCalc),
      InfoPage(onCheckUpdate: () => _checkForUpdate(showUpToDate: true)),
    ];
    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: tr('Rechner', 'Calculator'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.currency_exchange_outlined),
            selectedIcon: const Icon(Icons.currency_exchange),
            label: tr('Währung', 'Currency'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.percent_outlined),
            selectedIcon: const Icon(Icons.percent),
            label: tr('Zins', 'Interest'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_outlined),
            selectedIcon: const Icon(Icons.account_balance),
            label: tr('Finanz', 'Finance'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.info_outline),
            selectedIcon: const Icon(Icons.info),
            label: tr('Info', 'Info'),
          ),
        ],
      ),
    );
  }
}

// ─── Gemeinsames Display-Widget ───────────────────────────────────────────────

class CalcDisplay extends StatefulWidget {
  final String main;
  final String sub;
  final String history;
  final bool pendingOp;
  final bool error;
  final String? rawText;
  final void Function(int charIndex)? onTapChar;

  const CalcDisplay({
    super.key,
    required this.main,
    this.sub = '',
    this.history = '',
    this.pendingOp = false,
    this.error = false,
    this.rawText,
    this.onTapChar,
  });

  @override
  State<CalcDisplay> createState() => _CalcDisplayState();
}

class _CalcDisplayState extends State<CalcDisplay> {
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(CalcDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.main != oldWidget.main) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollCtrl.hasClients) return;
        final cursorIdx = widget.main.indexOf('│');
        final target = (cursorIdx >= 0 && widget.main.length > 1)
            ? (cursorIdx / widget.main.length) * _scrollCtrl.position.maxScrollExtent
            : _scrollCtrl.position.maxScrollExtent;
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTap(TapDownDetails details, double containerWidth) {
    final raw = widget.rawText!;
    if (raw.isEmpty) return;
    final fs = widget.main.length <= 14 ? 36.0 : 26.0;
    final style = TextStyle(fontSize: fs, fontWeight: FontWeight.bold);
    final painter = TextPainter(
      text: TextSpan(text: raw, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout();
    final scrollOffset = _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
    final textWidth = painter.width;
    final textStart = math.max(0.0, containerWidth - textWidth);
    final tapX = (details.localPosition.dx + scrollOffset - textStart).clamp(0.0, textWidth);
    final pos = painter.getPositionForOffset(Offset(tapX, 0));
    widget.onTapChar!(pos.offset);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fs = widget.main.length <= 14 ? 36.0 : 26.0;
    final mainStyle = TextStyle(
        fontSize: fs, fontWeight: FontWeight.bold,
        color: widget.error ? cs.error : cs.primary);

    return SizedBox(
      height: 130,
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        color: cs.primaryContainer.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.history.isNotEmpty)
              Text(widget.history,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                  textAlign: TextAlign.right),
            const Spacer(),
            LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (widget.onTapChar != null && widget.rawText != null)
                    ? (d) => _onTap(d, constraints.maxWidth)
                    : null,
                child: SingleChildScrollView(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: () {
                  final cursorIdx = widget.main.indexOf('│');
                  if (cursorIdx >= 0) {
                    return RichText(
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      text: TextSpan(
                        style: mainStyle,
                        children: [
                          if (cursorIdx > 0)
                            TextSpan(text: widget.main.substring(0, cursorIdx)),
                          TextSpan(
                            text: '│',
                            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w100),
                          ),
                          if (cursorIdx + 1 < widget.main.length)
                            TextSpan(text: widget.main.substring(cursorIdx + 1)),
                        ],
                      ),
                    );
                  } else if (widget.pendingOp && widget.main.isNotEmpty) {
                    return RichText(
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      text: TextSpan(
                        style: mainStyle,
                        children: [
                          TextSpan(text: widget.main.substring(0, widget.main.length - 1)),
                          TextSpan(
                              text: widget.main[widget.main.length - 1],
                              style: TextStyle(color: cs.error)),
                        ],
                      ),
                    );
                  } else {
                    return Text(widget.main, style: mainStyle,
                        textAlign: TextAlign.right, maxLines: 1);
                  }
                }(),
                ),
              ),
              );
            }),
            if (widget.sub.isNotEmpty)
              Text(widget.sub,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                  textAlign: TextAlign.right),
          ],
        ),
      ),
    );
  }
}

// ─── Rechner ─────────────────────────────────────────────────────────────────

class CalculatorPage extends StatefulWidget {
  final double initValue;
  final void Function(double) onResult;
  const CalculatorPage({super.key, required this.initValue, required this.onResult});
  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _expr     = '';
  String _disp     = '';
  String _hist     = '';
  String _histFull = '';
  bool   _eval      = false;
  bool   _pendingOp = false;
  bool   _swapped   = false;
  bool   _hasError  = false;
  bool   _bigKeys   = false;

  String? _repeatOp;
  double? _repeatVal;
  String? _repeatDispOp;
  String? _repeatDispVal;

  String _liveResult = '';
  int _dispCursor = -1; // -1 = Cursor am Ende (Standard)
  Timer? _saveTimer;

  final _histScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final expr = p.getString('calc_expr') ?? '';
    if (expr.isEmpty) {
      if (widget.initValue != 0) setState(() => _setVal(widget.initValue));
      return;
    }
    setState(() {
      _expr        = expr;
      _disp        = p.getString('calc_disp')        ?? '';
      _hist        = p.getString('calc_hist')        ?? '';
      _histFull    = p.getString('calc_hist_full')   ?? '';
      _eval        = p.getBool('calc_eval')          ?? false;
      _swapped     = p.getBool('calc_swapped')       ?? false;
      _bigKeys     = p.getBool('calc_big_keys')      ?? false;
      _liveResult  = p.getString('calc_live_result') ?? '';
      _repeatOp    = p.getString('calc_repeat_op');
      _repeatVal   = p.getDouble('calc_repeat_val');
      _repeatDispOp  = p.getString('calc_repeat_disp_op');
      _repeatDispVal = p.getString('calc_repeat_disp_val');
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('calc_expr',        _expr);
    await p.setString('calc_disp',        _disp);
    await p.setString('calc_hist',        _hist);
    await p.setString('calc_hist_full',   _histFull);
    await p.setBool('calc_eval',          _eval);
    await p.setBool('calc_swapped',       _swapped);
    await p.setBool('calc_big_keys',      _bigKeys);
    await p.setString('calc_live_result', _liveResult);
    if (_repeatOp != null) {
      await p.setString('calc_repeat_op', _repeatOp!);
    } else {
      await p.remove('calc_repeat_op');
    }
    if (_repeatVal != null) {
      await p.setDouble('calc_repeat_val', _repeatVal!);
    } else {
      await p.remove('calc_repeat_val');
    }
    if (_repeatDispOp != null) {
      await p.setString('calc_repeat_disp_op', _repeatDispOp!);
    } else {
      await p.remove('calc_repeat_disp_op');
    }
    if (_repeatDispVal != null) {
      await p.setString('calc_repeat_disp_val', _repeatDispVal!);
    } else {
      await p.remove('calc_repeat_disp_val');
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _savePrefs();
    _histScrollCtrl.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _savePrefs);
  }

  void _setVal(double v) {
    _expr = v.toString();
    _disp = fmtNum(v, dec: 4);
    _eval = true;
    _hist = '';
  }

  String get _filledDisp {
    if (_disp.isEmpty) return '';
    final open = '('.allMatches(_disp).length - ')'.allMatches(_disp).length;
    return open > 0 ? _disp + ')' * open : _disp;
  }

  String get _displayText {
    final filled = _filledDisp;
    if (filled.isEmpty) return '0';
    if (_dispCursor >= 0) {
      final pos = _dispCursor.clamp(0, filled.length);
      return filled.substring(0, pos) + '│' + filled.substring(pos);
    }
    return _addThousands(filled);
  }

  void _onTapDisplay(int charIndex) {
    if (_eval || _disp.isEmpty) return;
    final clamped = charIndex.clamp(0, _disp.length);
    setState(() => _dispCursor = clamped >= _disp.length ? -1 : clamped);
  }

  void _captureRepeat(String evalStr) {
    final m = RegExp(r'([+\-*/])([\d.]+)$').firstMatch(evalStr);
    if (m == null || m.start == 0) { _repeatOp = null; _repeatVal = null; return; }
    _repeatOp = m.group(1);
    _repeatVal = double.tryParse(m.group(2)!);
    if (_repeatVal == null) { _repeatOp = null; return; }
    const opMap = {'+': '＋', '-': '−', '*': '×', '/': '÷'};
    _repeatDispOp = opMap[_repeatOp] ?? _repeatOp;
    _repeatDispVal = fmtNum(_repeatVal!, dec: _neededDecimals(_repeatVal!));
  }

  // Berechnet das Zwischenresultat – gibt neuen Wert zurück.
  // Endet Ausdruck mit Operator, bleibt alter Wert (_liveResult) sichtbar.
  String _calcLiveResult() {
    if (_expr.isEmpty) return '';
    if (!RegExp(r'[+\-*/]').hasMatch(_expr)) return '';
    // Endet mit Operator → alten Wert beibehalten (Ruhe im Display)
    if (RegExp(r'[+\-*/]$').hasMatch(_expr)) return _liveResult;
    try {
      final open = '('.allMatches(_expr).length - ')'.allMatches(_expr).length;
      final evalStr = _expr + ')' * (open > 0 ? open : 0);
      final parser = Parser();
      final exp = parser.parse(evalStr);
      final ctx = ContextModel();
      final result = exp.evaluate(EvaluationType.REAL, ctx) as double;
      if (!result.isFinite) return _liveResult;
      return '= ${fmtNum(result, dec: _neededDecimals(result))}';
    } catch (_) {
      return _liveResult;
    }
  }

  // Leitet _expr aus dem Anzeigestring ab – wird nach jeder Cursor-Edit genutzt
  String _dispToExpr(String disp) => disp
      .replaceAll('√(', 'sqrt(')
      .replaceAll('²', '^2')
      .replaceAll('%', '/100')
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('＋', '+')
      .replaceAll('−', '-');

  int get _effectiveCursor =>
      _dispCursor < 0 ? _disp.length : _dispCursor.clamp(0, _disp.length);
  String get _dispBefore => _disp.substring(0, _effectiveCursor);
  String get _dispAfter  => _disp.substring(_effectiveCursor);

  void _refreshLiveResult() {
    // Nach = zeigt histFull; liveResult bleibt für den Moment nach dem nächsten Op
    if (_eval) return;
    final v = _calcLiveResult();
    if (v != _liveResult) setState(() => _liveResult = v);
  }

  void _btn(String t) {
    bool doEval = false;
    setState(() {
      _hasError = false;
      if (t != '=') _pendingOp = false;

      // ── Cursor-Navigation ──────────────────────────────────────────────────
      if (t == '◀') {
        final pos = _effectiveCursor;
        if (pos > 0) _dispCursor = pos - 1;
        return;
      }
      if (t == '▶') {
        final pos = _effectiveCursor;
        if (pos < _disp.length) {
          final next = pos + 1;
          _dispCursor = next >= _disp.length ? -1 : next;
        }
        return;
      }

      // ── CE ─────────────────────────────────────────────────────────────────
      if (t == 'CE') {
        _expr = ''; _disp = ''; _hist = ''; _histFull = ''; _eval = false;
        _repeatOp = null; _repeatVal = null; _liveResult = '';
        _dispCursor = -1;
        return;
      }

      // ── Backspace ──────────────────────────────────────────────────────────
      if (t == '←') {
        if (_eval) { _expr = ''; _disp = ''; _eval = false; _dispCursor = -1; return; }
        final before = _dispBefore;
        final after  = _dispAfter;
        if (before.isEmpty) return;
        int removeLen;
        if (before.endsWith('√('))     removeLen = 2;
        else if (before.endsWith('²')) removeLen = 1;
        else if (before.endsWith('%')) removeLen = 1;
        else                           removeLen = 1;
        _disp = before.substring(0, before.length - removeLen) + after;
        _expr = _dispToExpr(_disp);
        if (_dispCursor >= 0) _dispCursor = math.max(0, _dispCursor - removeLen);
        return;
      }

      // ── = ──────────────────────────────────────────────────────────────────
      if (t == '=') {
        _dispCursor = -1;
        _pendingOp = false;
        // Hängenden Operator entfernen – verhindert, dass = dauerhaft abbricht
        if (_expr.isNotEmpty && RegExp(r'[+\-*/]$').hasMatch(_expr)) {
          _expr = _expr.substring(0, _expr.length - 1);
          if (_disp.isNotEmpty) _disp = _disp.substring(0, _disp.length - 1);
        }
        if (_eval && _repeatOp != null && _repeatVal != null) {
          final current = double.tryParse(_expr);
          if (current != null) {
            final dispCurrent = fmtNum(current, dec: _neededDecimals(current));
            _expr = '$_expr${_repeatOp!}${_repeatVal!}';
            _disp = '$dispCurrent${_repeatDispOp ?? _repeatOp!}${_repeatDispVal ?? _repeatVal.toString()}';
            _eval = false;
          }
        }
        doEval = true;
        return;
      }

      // ── Nach Ergebnis: löschen oder weitermachen ───────────────────────────
      if (_eval && !['＋','−','×','÷','%','x²'].any((op) => t == op)) {
        _expr = ''; _disp = '';
        _repeatOp = null; _repeatVal = null; _liveResult = '';
        _dispCursor = -1;
      }
      if (_eval) { _histFull = ''; _dispCursor = -1; }
      _eval = false;

      // ── Einfügen an Cursor-Position ────────────────────────────────────────
      final before = _dispBefore;
      final after  = _dispAfter;

      const binOps = {'×', '÷', '＋', '−'};
      final map = {
        '√':  ['sqrt(', '√('],
        'x²': ['^2',    '²'],
        '×':  ['*',     '×'],
        '÷':  ['/',     '÷'],
        '%':  ['/100',  '%'],
        '＋': ['+',     '＋'],
        '−':  ['-',     '−'],
      };

      if (map.containsKey(t)) {
        var newBefore = before;
        if (binOps.contains(t) && newBefore.isNotEmpty &&
            binOps.contains(newBefore[newBefore.length - 1])) {
          newBefore = newBefore.substring(0, newBefore.length - 1);
          if (_dispCursor >= 0) _dispCursor -= 1;
        }
        final dispChars = map[t]![1];
        _disp = newBefore + dispChars + after;
        _expr = _dispToExpr(_disp);
        if (_dispCursor >= 0) _dispCursor += dispChars.length;
      } else if (t == '±') {
        if (_disp.isNotEmpty) { _disp = '-($_disp)'; _expr = _dispToExpr(_disp); }
        else                  { _disp = '-'; _expr = '-'; }
        _dispCursor = -1;
      } else if (t == '(') {
        var dispChars = '(';
        if (before.isNotEmpty && RegExp(r'[0-9)]').hasMatch(before[before.length - 1])) {
          dispChars = '×(';
        }
        _disp = before + dispChars + after;
        _expr = _dispToExpr(_disp);
        if (_dispCursor >= 0) _dispCursor += dispChars.length;
      } else if (t == '.') {
        final lastOp = before.lastIndexOf(RegExp(r'[×÷＋−()]'));
        final cur = lastOp >= 0 ? before.substring(lastOp + 1) : before;
        if (!cur.contains('.')) {
          _disp = before + '.' + after;
          _expr = _dispToExpr(_disp);
          if (_dispCursor >= 0) _dispCursor += 1;
        }
      } else if (t == ')') {
        final open = '('.allMatches(_disp).length - ')'.allMatches(_disp).length;
        if (open > 0) {
          _disp = before + ')' + after;
          _expr = _dispToExpr(_disp);
          if (_dispCursor >= 0) _dispCursor += 1;
        }
      } else {
        // Ziffer
        var dispChars = t;
        if (RegExp(r'^[0-9]$').hasMatch(t) && before.isNotEmpty &&
            before[before.length - 1] == ')') {
          dispChars = '×$t';
        }
        _disp = before + dispChars + after;
        _expr = _dispToExpr(_disp);
        if (_dispCursor >= 0) _dispCursor += dispChars.length;
      }

      // Sicherheits-Clamp
      if (_dispCursor >= _disp.length) _dispCursor = -1;
    });
    if (doEval) _evaluate();
    _refreshLiveResult();
    _scheduleSave();
  }

  void _evaluate() {
    if (_expr.isEmpty) return;

    // Ausdruck endet mit binärem Operator → Operator rot anzeigen, warten
    if (RegExp(r'[+\-*/]$').hasMatch(_expr)) {
      setState(() => _pendingOp = true);
      return;
    }

    final open = '('.allMatches(_expr).length - ')'.allMatches(_expr).length;
    final evalStr = _expr + ')' * (open > 0 ? open : 0);
    final dispStr = _disp + ')' * (open > 0 ? open : 0);
    try {
      final parser = Parser();
      final exp = parser.parse(evalStr);
      final ctx = ContextModel();
      final result = exp.evaluate(EvaluationType.REAL, ctx) as double;
      if (!result.isFinite) {
        setState(() {
          _disp = tr('÷ 0 nicht möglich', '÷ 0 not possible');
          _expr = ''; _eval = false; _pendingOp = false;
          _repeatOp = null; _repeatVal = null; _dispCursor = -1;
        });
        return;
      }
      _captureRepeat(evalStr);
      setState(() {
        final fmtDisp = _addThousands(dispStr);
        _hist = '$fmtDisp =';
        final rs = fmtNum(result, dec: _neededDecimals(result));
        _histFull = '$fmtDisp = $rs';
        _disp = rs;
        _expr = result.toString();
        _eval = true;
        _pendingOp = false;
        _dispCursor = -1;
        widget.onResult(result);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _histScrollCtrl.hasClients &&
            _histScrollCtrl.position.hasContentDimensions) {
          _histScrollCtrl.animateTo(
            _histScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      setState(() { _hasError = true; _pendingOp = false; _dispCursor = -1; });
    }
  }

  Widget _buildBtn(String label, {Color? bg, Color? fg, int flex = 1, double minHeight = 58}) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? cs.surfaceVariant,
            foregroundColor: fg ?? cs.onSurfaceVariant,
            minimumSize: Size(0, _bigKeys ? minHeight * 1.25 : minHeight),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _btn(label),
          child: Text(label,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: (label == '=' || ['＋','−','×','÷'].contains(label))
                      ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final op = cs.primary;
    final eq = cs.error;
    final fn = cs.secondaryContainer;
    final fnFg = cs.onSecondaryContainer;

    return SafeArea(
      child: Column(
        children: [
          CalcDisplay(
            main: _displayText,
            pendingOp: _pendingOp,
            error: _hasError,
            rawText: (!_eval && _disp.isNotEmpty) ? _filledDisp : null,
            onTapChar: _onTapDisplay,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => _bigKeys = !_bigKeys);
                          _scheduleSave();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 4, bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _bigKeys ? cs.primaryContainer : cs.surfaceVariant,
                            border: Border.all(
                              color: _bigKeys ? cs.primary : cs.outline.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(Icons.expand, size: 16,
                              color: _bigKeys ? cs.primary : cs.onSurfaceVariant),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _swapped = !_swapped);
                          _scheduleSave();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 4, bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _swapped ? cs.primaryContainer : cs.surfaceVariant,
                            border: Border.all(
                              color: _swapped ? cs.primary : cs.outline.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(Icons.swap_horiz, size: 16,
                              color: _swapped ? cs.primary : cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  _row(['CE', '←', '(', ')', '%'],
                      bgs: [fn,fn,fn,fn,fn], fgs: [fnFg,fnFg,fnFg,fnFg,fnFg]),
                  _row(['√', 'x²', '7', '8', '9'],
                      bgs: [fn,fn,null,null,null], fgs: [fnFg,fnFg,null,null,null]),
                  _row(['÷', '×', '4', '5', '6'],
                      bgs: [op,op,null,null,null], fgs: [Colors.white, Colors.white,null,null,null]),
                  _row(['−', '＋', '1', '2', '3'],
                      bgs: [op,op,null,null,null], fgs: [Colors.white, Colors.white,null,null,null]),
                  if (!_swapped)
                    Row(children: [
                      _buildBtn('±', bg: fn, fg: fnFg),
                      _buildBtn('.'),
                      _buildBtn('0'),
                      _buildBtn('=', bg: eq, fg: Colors.white, flex: 2),
                    ])
                  else
                    Row(children: [
                      _buildBtn('=', bg: eq, fg: Colors.white, flex: 2),
                      _buildBtn('0'),
                      _buildBtn('.'),
                      _buildBtn('±', bg: fn, fg: fnFg),
                    ]),
                  const Spacer(),
                  SizedBox(
                    height: 70,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: () {
                        final bottomText = _histFull.isNotEmpty ? _histFull : _liveResult;
                        final alpha = _histFull.isNotEmpty ? 0.45 : 0.75;
                        if (bottomText.isEmpty) return const SizedBox.shrink();
                        return LayoutBuilder(builder: (ctx, constraints) {
                          return SingleChildScrollView(
                            controller: _histScrollCtrl,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  bottomText,
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: cs.onSurface.withValues(alpha: alpha),
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          );
                        });
                      }(),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> labels,
      {List<Color?>? bgs, List<Color?>? fgs}) {
    if (_swapped) {
      labels = labels.reversed.toList();
      bgs = bgs?.reversed.toList();
      fgs = fgs?.reversed.toList();
      // Nach dem Umkehren ( und ) wieder in richtiger Reihenfolge halten
      final iOpen  = labels.indexOf('(');
      final iClose = labels.indexOf(')');
      if (iOpen != -1 && iClose != -1 && iOpen > iClose) {
        labels[iOpen] = ')';
        labels[iClose] = '(';
      }
    }
    return Row(
      children: List.generate(labels.length, (i) => _buildBtn(
        labels[i],
        bg: bgs != null ? bgs[i] : null,
        fg: fgs != null ? fgs[i] : null,
      )),
    );
  }
}

// ─── Währungsrechner ─────────────────────────────────────────────────────────

class CurrencyPage extends StatefulWidget {
  final double initAmount;
  final void Function(double) onResult;
  final void Function(String) onCurrencyChanged;
  const CurrencyPage({super.key, required this.initAmount, required this.onResult, required this.onCurrencyChanged});
  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  String _from = 'USD';
  String _to   = 'CHF';
  String _input = '';
  String _result = '';    // formatiertes Ergebnis
  String _rateLine = '';
  String _status = '';
  bool   _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initAmount > 0) {
      _input = widget.initAmount.toString();
    }
  }

  @override
  void didUpdateWidget(CurrencyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initAmount != oldWidget.initAmount && widget.initAmount > 0 && _result.isEmpty) {
      setState(() => _input = widget.initAmount.toString());
    }
  }

  String get _displayText => _input.isEmpty ? '0' : _input;

  void _numBtn(String t) {
    setState(() {
      _result = '';
      if (t == 'CE')  { _input = ''; return; }
      if (t == '←')  { if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1); return; }
      if (t == '±')  { _input = _input.startsWith('-') ? _input.substring(1) : (_input.isEmpty ? _input : '-$_input'); return; }
      if (t == '.')   { if (!_input.contains('.')) _input = '${_input.isEmpty ? "0" : _input}.'; return; }
      if (_input == '0') _input = t; else _input += t;
    });
  }

  Future<void> _convert() async {
    final amt = double.tryParse(_input);
    if (amt == null) { setState(() => _status = tr('Ungültiger Betrag', 'Invalid amount')); return; }
    setState(() { _loading = true; _status = tr('⚡ Lade Kursdaten…', '⚡ Loading rates…'); _rateLine = ''; });
    final (rate, err) = await getRate(_from, _to);
    if (!mounted) return;
    if (rate == null) {
      setState(() { _loading = false; _status = err ?? tr('Fehler', 'Error'); });
      return;
    }
    final converted = amt * rate;
    widget.onResult(converted);
    setState(() {
      _loading = false;
      _result   = fmtNum(converted, dec: converted.abs() < 1 ? 6 : 4);
      _rateLine = '1 $_from = ${fmtNum(rate, dec: 4)} $_to';
      _status   = tr('✓ Kurs aktuell (Yahoo Finance)', '✓ Rate current (Yahoo Finance)');
    });
  }

  void _setTo(String v) {
    _to = v;
    widget.onCurrencyChanged(v);
  }

  void _swap() {
    setState(() { final t = _from; _from = _to; _setTo(t); _result = ''; });
    _convert();
  }

  Widget _numBtnW(String label, {Color? bg, Color? fg, int flex = 1}) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? cs.surfaceVariant,
            foregroundColor: fg ?? cs.onSurfaceVariant,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _numBtn(label),
          child: Text(label, style: const TextStyle(fontSize: 17)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          CalcDisplay(
            main: _result.isNotEmpty ? '$_to  $_result' : _displayText,
            sub: _result.isNotEmpty
                ? '${_displayText} $_from  →  $_to'
                : '$_from  →  $_to',
            history: _rateLine,
          ),
          // Selektoren
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _from,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    items: kCurrencies.map((c) => DropdownMenuItem(
                      value: c,
                      enabled: c != kSeparator,
                      child: Text(c, overflow: TextOverflow.ellipsis, style: TextStyle(
                        fontStyle: c == kSeparator ? FontStyle.italic : null,
                        color: c == kSeparator ? Colors.grey : null,
                        fontSize: 13,
                      )),
                    )).toList(),
                    onChanged: (v) { if (v != null) setState(() { _from = v; _result = ''; }); },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: _swap,
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _to,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    items: kCurrencies.map((c) => DropdownMenuItem(
                      value: c,
                      enabled: c != kSeparator,
                      child: Text(c, overflow: TextOverflow.ellipsis, style: TextStyle(
                        fontStyle: c == kSeparator ? FontStyle.italic : null,
                        color: c == kSeparator ? Colors.grey : null,
                        fontSize: 13,
                      )),
                    )).toList(),
                    onChanged: (v) { if (v != null) setState(() { _setTo(v); _result = ''; }); },
                  ),
                ),
              ],
            ),
          ),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(_status, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.55))),
            ),
          // Ziffernblock
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linke 3 Spalten: Ziffern
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(child: Row(children: [_numBtnW('7'), _numBtnW('8'), _numBtnW('9')])),
                        Expanded(child: Row(children: [_numBtnW('4'), _numBtnW('5'), _numBtnW('6')])),
                        Expanded(child: Row(children: [_numBtnW('1'), _numBtnW('2'), _numBtnW('3')])),
                        Expanded(child: Row(children: [
                          _numBtnW('±', bg: cs.secondaryContainer, fg: cs.onSecondaryContainer),
                          _numBtnW('0'),
                          _numBtnW('.'),
                        ])),
                      ],
                    ),
                  ),
                  // Rechte Spalte: ←, CE, Umrechnen (gross)
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _numBtnW('←', bg: cs.secondaryContainer, fg: cs.onSecondaryContainer),
                        _numBtnW('CE', bg: cs.secondaryContainer, fg: cs.onSecondaryContainer),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.error,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _loading ? null : _convert,
                              child: _loading
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  : const Icon(Icons.currency_exchange, size: 28),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Schnellwahl
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Schnellwahl', 'Quick pairs'),
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: kQuickPairs.map((p) {
                    return ActionChip(
                      label: Text('${p[0]}/${p[1]}', style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() { _from = p[0]; _setTo(p[1]); });
                        _convert();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Zinsrechner / Savings Calculator ────────────────────────────────────────

class SavingsPage extends StatefulWidget {
  final String currency;
  const SavingsPage({super.key, this.currency = 'CHF'});
  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  final _startCtrl    = TextEditingController();
  final _depositCtrl  = TextEditingController();
  final _yearsCtrl    = TextEditingController();
  final _rateCtrl     = TextEditingController();

  bool   _isWithdrawal   = false;
  double _endWithout     = 0;
  double _endWith        = 0;
  double _totalPaid      = 0;
  double _interestGain   = 0;
  double? _yearsToDepletion;

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) {
      _startCtrl.addListener(_onChanged);
      _depositCtrl.addListener(_onChanged);
      _yearsCtrl.addListener(_onChanged);
      _rateCtrl.addListener(_onChanged);
      _calculate();
    });
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _startCtrl.text   = p.getString('savings_start')    ?? '10000';
    _depositCtrl.text = p.getString('savings_deposit')  ?? '1200';
    _yearsCtrl.text   = p.getString('savings_years')    ?? '20';
    _rateCtrl.text    = p.getString('savings_rate')     ?? '5.0';
    if (mounted) setState(() => _isWithdrawal = p.getBool('savings_withdrawal') ?? false);
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('savings_start',      _startCtrl.text);
    await p.setString('savings_deposit',    _depositCtrl.text);
    await p.setString('savings_years',      _yearsCtrl.text);
    await p.setString('savings_rate',       _rateCtrl.text);
    await p.setBool('savings_withdrawal',   _isWithdrawal);
  }

  void _onChanged() { _savePrefs(); _calculate(); }

  @override
  void dispose() {
    _startCtrl.dispose();
    _depositCtrl.dispose();
    _yearsCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  double? _calcYearsToDepletion(double start, double withdrawalPerYear, double rate) {
    if (withdrawalPerYear <= 0 || start <= 0) return null;
    if (rate <= 0) return start / withdrawalPerYear;
    if (rate * start >= withdrawalPerYear) return null;
    final w = -withdrawalPerYear;
    final ratio = w / (rate * start + w);
    if (ratio <= 0) return null;
    return math.log(ratio) / math.log(1 + rate);
  }

  void _calculate() {
    final start    = double.tryParse(_startCtrl.text.replaceAll(',', '.'))   ?? 0;
    final depAmt   = double.tryParse(_depositCtrl.text.replaceAll(',', '.')) ?? 0;
    final deposit  = depAmt * (_isWithdrawal ? -1 : 1);
    final years    = int.tryParse(_yearsCtrl.text)   ?? 0;
    final rate     = (double.tryParse(_rateCtrl.text.replaceAll(',', '.')) ?? 0) / 100;

    if (years <= 0) {
      setState(() { _endWithout = 0; _endWith = 0; _totalPaid = 0; _interestGain = 0; _yearsToDepletion = null; });
      return;
    }

    final factor = math.pow(1 + rate, years).toDouble();
    final without = start * factor;
    final withDep = rate == 0
        ? without + deposit * years
        : without + deposit * (factor - 1) / rate;
    final paid = start + deposit * years;

    setState(() {
      _endWithout       = without;
      _endWith          = withDep;
      _totalPaid        = paid;
      _interestGain     = withDep - paid;
      _yearsToDepletion = _isWithdrawal
          ? _calcYearsToDepletion(start, depAmt, rate)
          : null;
    });
  }

  Widget _field(String label, TextEditingController ctrl, String suffix) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDepletion(double totalYears, ColorScheme cs) {
    final y = totalYears.floor();
    final m = ((totalYears - y) * 12).round();
    final label = m > 0
        ? tr('~$y J. $m M.', '~$y yr $m mo')
        : tr('~$y Jahre', '~$y years');
    return Text(label,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.error));
  }

  String _fmt(double v) {
    final locale = Platform.localeName;
    if (v >= 1000000) return NumberFormat('#,##0.##', locale).format(v / 1000000) + ' Mio.';
    return NumberFormat('#,##0.00', locale).format(v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Zinsrechner', 'Savings Calculator'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _field(tr('Startkapital', 'Initial capital'), _startCtrl, widget.currency),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(tr('Einzahlung', 'Deposit')),
                                icon: const Icon(Icons.add, size: 16),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(tr('Entnahme', 'Withdrawal')),
                                icon: const Icon(Icons.remove, size: 16),
                              ),
                            ],
                            selected: {_isWithdrawal},
                            onSelectionChanged: (s) =>
                                setState(() { _isWithdrawal = s.first; _savePrefs(); _calculate(); }),
                          ),
                          const SizedBox(height: 6),
                          _field(tr('Betrag / Jahr', 'Amount / year'), _depositCtrl, widget.currency),
                        ],
                      ),
                    ),
                    _field(tr('Laufzeit', 'Duration'), _yearsCtrl, tr('Jahre', 'years')),
                    _field(tr('Zinssatz', 'Interest rate'), _rateCtrl, '%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Ergebnis', 'Result'),
                      style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final depAmt = double.tryParse(_depositCtrl.text.replaceAll(',', '.')) ?? 0;
                      final yrs = int.tryParse(_yearsCtrl.text) ?? 0;
                      final depleted = _isWithdrawal && _endWith <= 0 && _yearsToDepletion != null;
                      return Column(
                        children: [
                          // Main result
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                depleted
                                    ? tr('Aufgebraucht nach', 'Depleted after')
                                    : _isWithdrawal
                                        ? tr('Mit Entnahmen', 'With withdrawals')
                                        : tr('Mit Einzahlungen', 'With deposits'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              depleted
                                  ? _buildDepletion(_yearsToDepletion!, cs)
                                  : Text(
                                      '${_fmt(_endWith)} ${widget.currency}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                            ],
                          ),
                          const Divider(height: 20),
                          _resultRow(
                            tr('Nur Zinseszins', 'Only compound interest'),
                            '${_fmt(_endWithout)} ${widget.currency}',
                            cs,
                          ),
                          _resultRow(
                            _isWithdrawal
                                ? tr('− Entnahmen gesamt', '− Total withdrawals')
                                : tr('+ Einzahlungen gesamt', '+ Total deposits'),
                            _isWithdrawal
                                ? '− ${_fmt(depAmt * yrs)} ${widget.currency}'
                                : '+ ${_fmt(depAmt * yrs)} ${widget.currency}',
                            cs,
                          ),
                          const Divider(height: 20),
                          _resultRow(
                            _isWithdrawal
                                ? tr('Entnommen total', 'Total withdrawn')
                                : tr('Eingezahlt total', 'Total paid in'),
                            '${_fmt(_totalPaid)} ${widget.currency}',
                            cs,
                          ),
                          _resultRow(
                            tr('Zinsgewinn total', 'Total interest gain'),
                            '${_fmt(_interestGain)} ${widget.currency}',
                            cs,
                            valueColor: _interestGain >= 0 ? Colors.green.shade700 : Colors.red,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, ColorScheme cs, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer.withValues(alpha: 0.8))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? cs.onPrimaryContainer)),
        ],
      ),
    );
  }
}

// ─── Finanzrechner ────────────────────────────────────────────────────────────

enum _FinMode { tvm, amort, cash, conv, breakeven }
enum _TVMField { n, i, pv, pmt, fv }

class FinancePage extends StatefulWidget {
  final double initValue;
  final void Function(double) onResult;
  const FinancePage({super.key, required this.initValue, required this.onResult});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  _FinMode _mode = _FinMode.tvm;

  // TVM
  final _nCtrl   = TextEditingController();
  final _iCtrl   = TextEditingController();
  final _pvCtrl  = TextEditingController();
  final _pmtCtrl = TextEditingController();
  final _fvCtrl  = TextEditingController();
  bool _bgn = false;
  String _tvmResult = '';
  String _tvmError  = '';

  // Amort
  final _amortFromCtrl = TextEditingController(text: '1');
  final _amortToCtrl   = TextEditingController(text: '1');
  String _amortResult  = '';

  // Cash flows
  final List<TextEditingController> _cfCtrls = [
    TextEditingController(text: '0'),
    TextEditingController(text: '0'),
  ];
  final _npvRateCtrl = TextEditingController();
  String _cashResult = '';
  String _cashError  = '';

  // Conversion
  final _nomCtrl = TextEditingController();
  final _effCtrl = TextEditingController();
  final _mCtrl   = TextEditingController(text: '12');
  String _convResult = '';

  // Break-even
  final _fcCtrl = TextEditingController();
  final _vcCtrl = TextEditingController();
  final _prCtrl = TextEditingController();
  String _beResult = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _nCtrl.text   = p.getString('fin_n')   ?? '';
      _iCtrl.text   = p.getString('fin_i')   ?? '';
      _pvCtrl.text  = p.getString('fin_pv')  ?? '';
      _pmtCtrl.text = p.getString('fin_pmt') ?? '';
      _fvCtrl.text  = p.getString('fin_fv')  ?? '';
      _bgn = p.getBool('fin_bgn') ?? false;
      _amortFromCtrl.text = p.getString('fin_amort_from') ?? '1';
      _amortToCtrl.text   = p.getString('fin_amort_to')   ?? '1';
      _npvRateCtrl.text   = p.getString('fin_npv_rate')   ?? '';
      _nomCtrl.text = p.getString('fin_nom') ?? '';
      _effCtrl.text = p.getString('fin_eff') ?? '';
      _mCtrl.text   = p.getString('fin_m')   ?? '12';
      _fcCtrl.text  = p.getString('fin_fc')  ?? '';
      _vcCtrl.text  = p.getString('fin_vc')  ?? '';
      _prCtrl.text  = p.getString('fin_pr')  ?? '';
      final cfCount = p.getInt('fin_cf_count') ?? 2;
      while (_cfCtrls.length < cfCount) {
        _cfCtrls.add(TextEditingController(text: '0'));
      }
      for (int i = 0; i < _cfCtrls.length; i++) {
        _cfCtrls[i].text = p.getString('fin_cf_$i') ?? '0';
      }
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('fin_n',   _nCtrl.text);
    await p.setString('fin_i',   _iCtrl.text);
    await p.setString('fin_pv',  _pvCtrl.text);
    await p.setString('fin_pmt', _pmtCtrl.text);
    await p.setString('fin_fv',  _fvCtrl.text);
    await p.setBool('fin_bgn', _bgn);
    await p.setString('fin_amort_from', _amortFromCtrl.text);
    await p.setString('fin_amort_to',   _amortToCtrl.text);
    await p.setString('fin_npv_rate',   _npvRateCtrl.text);
    await p.setString('fin_nom', _nomCtrl.text);
    await p.setString('fin_eff', _effCtrl.text);
    await p.setString('fin_m',   _mCtrl.text);
    await p.setString('fin_fc',  _fcCtrl.text);
    await p.setString('fin_vc',  _vcCtrl.text);
    await p.setString('fin_pr',  _prCtrl.text);
    await p.setInt('fin_cf_count', _cfCtrls.length);
    for (int i = 0; i < _cfCtrls.length; i++) {
      await p.setString('fin_cf_$i', _cfCtrls[i].text);
    }
  }

  @override
  void dispose() {
    _nCtrl.dispose(); _iCtrl.dispose(); _pvCtrl.dispose();
    _pmtCtrl.dispose(); _fvCtrl.dispose();
    _amortFromCtrl.dispose(); _amortToCtrl.dispose();
    for (final c in _cfCtrls) c.dispose();
    _npvRateCtrl.dispose();
    _nomCtrl.dispose(); _effCtrl.dispose(); _mCtrl.dispose();
    _fcCtrl.dispose(); _vcCtrl.dispose(); _prCtrl.dispose();
    super.dispose();
  }

  // ── TVM Mathematik ───────────────────────────────────────────────────────────

  // Grundgleichung: PV*(1+r)^n + PMT*f*((1+r)^n-1)/r + FV = 0
  // f = (1+r) für Anfang-Zahlungen (BGN), sonst 1
  double _tvmEq(double n, double r, double pv, double pmt, double fv) {
    if (r.abs() < 1e-12) return pv + pmt * n + fv;
    final x = math.pow(1 + r, n).toDouble();
    final f = _bgn ? (1 + r) : 1.0;
    return pv * x + pmt * f * (x - 1) / r + fv;
  }

  void _solveTVM(_TVMField field) {
    setState(() { _tvmError = ''; _tvmResult = ''; });
    final vals = {
      _TVMField.n:   _parseNum(_nCtrl.text),
      _TVMField.i:   _parseNum(_iCtrl.text),
      _TVMField.pv:  _parseNum(_pvCtrl.text),
      _TVMField.pmt: _parseNum(_pmtCtrl.text),
      _TVMField.fv:  _parseNum(_fvCtrl.text),
    };
    vals.remove(field);
    if (vals.values.any((v) => v == null)) {
      setState(() => _tvmError = tr('Bitte die anderen 4 Felder ausfüllen', 'Please fill the other 4 fields'));
      return;
    }
    final n   = vals[_TVMField.n]!;
    final i   = vals[_TVMField.i];
    final pv  = vals[_TVMField.pv];
    final pmt = vals[_TVMField.pmt];
    final fv  = vals[_TVMField.fv];
    double result;
    try {
      result = switch (field) {
        _TVMField.n   => _solveN(i! / 100, pv!, pmt!, fv!),
        _TVMField.i   => _solveI(n, pv!, pmt!, fv!) * 100,
        _TVMField.pv  => _solvePV(n, i! / 100, pmt!, fv!),
        _TVMField.pmt => _solvePMT(n, i! / 100, pv!, fv!),
        _TVMField.fv  => _solveFV(n, i! / 100, pv!, pmt!),
      };
    } catch (_) {
      setState(() => _tvmError = tr('Keine Lösung gefunden', 'No solution found'));
      return;
    }
    if (!result.isFinite) {
      setState(() => _tvmError = tr('Keine Lösung gefunden', 'No solution found'));
      return;
    }
    final label = switch (field) {
      _TVMField.n   => 'N',
      _TVMField.i   => 'I%',
      _TVMField.pv  => tr('BW', 'PV'),
      _TVMField.pmt => tr('Rate', 'PMT'),
      _TVMField.fv  => tr('EW', 'FV'),
    };
    setState(() {
      _tvmResult = '$label = ${fmtNum(result, dec: _neededDecimals(result))}';
      switch (field) {
        case _TVMField.n:   _nCtrl.text   = _fmtInput(result);
        case _TVMField.i:   _iCtrl.text   = _fmtInput(result);
        case _TVMField.pv:  _pvCtrl.text  = _fmtInput(result);
        case _TVMField.pmt: _pmtCtrl.text = _fmtInput(result);
        case _TVMField.fv:  _fvCtrl.text  = _fmtInput(result);
      }
    });
    widget.onResult(result.abs());
    _savePrefs();
  }

  double _solvePV(double n, double r, double pmt, double fv) {
    if (r.abs() < 1e-12) return -(pmt * n + fv);
    final x = math.pow(1 + r, n).toDouble();
    final f = _bgn ? (1 + r) : 1.0;
    return -(pmt * f * (x - 1) / r + fv) / x;
  }

  double _solveFV(double n, double r, double pv, double pmt) {
    if (r.abs() < 1e-12) return -(pv + pmt * n);
    final x = math.pow(1 + r, n).toDouble();
    final f = _bgn ? (1 + r) : 1.0;
    return -(pv * x + pmt * f * (x - 1) / r);
  }

  double _solvePMT(double n, double r, double pv, double fv) {
    if (r.abs() < 1e-12) { if (n == 0) throw Exception(); return -(pv + fv) / n; }
    final x = math.pow(1 + r, n).toDouble();
    final f = _bgn ? (1 + r) : 1.0;
    return -(pv * x + fv) * r / ((x - 1) * f);
  }

  double _solveN(double r, double pv, double pmt, double fv) {
    if (pmt == 0) {
      if (r.abs() < 1e-12 || fv / pv >= 0) throw Exception();
      return math.log(-fv / pv) / math.log(1 + r);
    }
    if (r.abs() < 1e-12) return -(pv + fv) / pmt;
    final f = _bgn ? (1 + r) : 1.0;
    final num = f * pmt - fv * r;
    final den = f * pmt + pv * r;
    if (num <= 0 || den <= 0) throw Exception();
    return math.log(num / den) / math.log(1 + r);
  }

  double _solveI(double n, double pv, double pmt, double fv) {
    // Newton-Raphson mit numerischer Ableitung
    double r = (pmt != 0) ? 0.1 : math.pow(-fv / pv, 1 / n).toDouble() - 1;
    r = r.clamp(-0.999, 10.0);
    for (int k = 0; k < 200; k++) {
      final fr = _tvmEq(n, r, pv, pmt, fv);
      final eps = math.max(r.abs() * 1e-6, 1e-8);
      final fp = (_tvmEq(n, r + eps, pv, pmt, fv) - _tvmEq(n, r - eps, pv, pmt, fv)) / (2 * eps);
      if (fp.abs() < 1e-15) break;
      final step = (fr / fp).clamp(-0.5, 0.5);
      r = (r - step).clamp(-0.999, 100.0);
      if (step.abs() < 1e-12) break;
    }
    return r;
  }

  // ── Amortisation ─────────────────────────────────────────────────────────────

  void _computeAmort() {
    final n   = _parseNum(_nCtrl.text);
    final i   = _parseNum(_iCtrl.text);
    final pv  = _parseNum(_pvCtrl.text);
    final pmt = _parseNum(_pmtCtrl.text);
    if (n == null || i == null || pv == null || pmt == null) {
      setState(() => _amortResult = tr('TVM-Werte (N, I%, BW, Rate) fehlen', 'TVM values (N, I%, PV, PMT) missing'));
      return;
    }
    final from = math.max(1, int.tryParse(_amortFromCtrl.text) ?? 1);
    final to   = math.min(n.toInt(), int.tryParse(_amortToCtrl.text) ?? 1);
    if (from > to) {
      setState(() => _amortResult = tr('Von > Bis', 'From > To'));
      return;
    }
    final r = i / 100;
    double balance = pv;
    for (int k = 1; k < from; k++) {
      balance = balance * (1 + r) + pmt;
    }
    double totalInt = 0, totalPrin = 0;
    for (int k = from; k <= to; k++) {
      final interest  = balance * r;
      final principal = -(pmt + interest);
      totalInt  += interest;
      totalPrin += principal;
      balance    = balance * (1 + r) + pmt;
    }
    final f = _fmtC;
    setState(() {
      _amortResult =
          '${tr("Zinsen", "Interest")}: ${f(totalInt)}\n'
          '${tr("Tilgung", "Principal")}: ${f(totalPrin)}\n'
          '${tr("Saldo", "Balance")}: ${f(balance)}';
    });
    _savePrefs();
  }

  // ── Cashflow / NPV / IRR ──────────────────────────────────────────────────────

  void _computeNPV() {
    final r = _parseNum(_npvRateCtrl.text);
    if (r == null) {
      setState(() { _cashError = tr('Zinssatz fehlt', 'Rate missing'); _cashResult = ''; });
      return;
    }
    final rate = r / 100;
    double npv = 0;
    for (int i = 0; i < _cfCtrls.length; i++) {
      npv += (_parseNum(_cfCtrls[i].text) ?? 0) / math.pow(1 + rate, i);
    }
    setState(() { _cashError = ''; _cashResult = 'NPV = ${_fmtC(npv)}'; });
    widget.onResult(npv.abs());
    _savePrefs();
  }

  void _computeIRR() {
    final cfs = _cfCtrls.map((c) => _parseNum(c.text) ?? 0.0).toList();
    if (cfs.isEmpty || cfs[0] >= 0) {
      setState(() { _cashError = tr('CF0 muss negativ sein (Investition)', 'CF0 must be negative (investment)'); _cashResult = ''; });
      return;
    }
    double npvAt(double r) {
      double s = 0;
      for (int i = 0; i < cfs.length; i++) s += cfs[i] / math.pow(1 + r, i);
      return s;
    }
    // Bisektionssuche im Bereich [-99%, +1000%]
    double lo = -0.999, hi = 10.0;
    if (npvAt(lo) * npvAt(hi) > 0) {
      setState(() { _cashError = tr('Kein IRR gefunden', 'No IRR found'); _cashResult = ''; });
      return;
    }
    for (int k = 0; k < 100; k++) {
      final mid = (lo + hi) / 2;
      if (npvAt(lo) * npvAt(mid) <= 0) hi = mid; else lo = mid;
      if ((hi - lo) < 1e-10) break;
    }
    final irr = (lo + hi) / 2 * 100;
    setState(() { _cashError = ''; _cashResult = 'IRR = ${fmtNum(irr, dec: 4)} %'; });
    _savePrefs();
  }

  // ── Zinskonversion ────────────────────────────────────────────────────────────

  void _convNomToEff() {
    final nom = _parseNum(_nomCtrl.text);
    final m   = _parseNum(_mCtrl.text);
    if (nom == null || m == null || m == 0) return;
    final eff = (math.pow(1 + nom / 100 / m, m).toDouble() - 1) * 100;
    setState(() { _effCtrl.text = _fmtInput(eff); _convResult = tr('Effektivzins', 'Effective Rate') + ': ${fmtNum(eff, dec: 4)} %'; });
    _savePrefs();
  }

  void _convEffToNom() {
    final eff = _parseNum(_effCtrl.text);
    final m   = _parseNum(_mCtrl.text);
    if (eff == null || m == null || m == 0) return;
    final nom = m * (math.pow(1 + eff / 100, 1 / m) - 1) * 100;
    setState(() { _nomCtrl.text = _fmtInput(nom); _convResult = tr('Nominalzins', 'Nominal Rate') + ': ${fmtNum(nom, dec: 4)} %'; });
    _savePrefs();
  }

  // ── Break-Even ────────────────────────────────────────────────────────────────

  void _computeBreakEven() {
    final fc = _parseNum(_fcCtrl.text);
    final vc = _parseNum(_vcCtrl.text);
    final pr = _parseNum(_prCtrl.text);
    if (fc == null || vc == null || pr == null) return;
    final margin = pr - vc;
    if (margin <= 0) {
      setState(() => _beResult = tr('Preis ≤ Var.kosten → kein Break-Even', 'Price ≤ Var.cost → no break-even'));
      return;
    }
    final bepUnits = fc / margin;
    final bepRev   = bepUnits * pr;
    setState(() {
      _beResult = '${tr("BEP Menge", "BEP Units")}: ${fmtNum(bepUnits, dec: _neededDecimals(bepUnits))}\n'
          '${tr("BEP Umsatz", "BEP Revenue")}: ${_fmtC(bepRev)}\n'
          '${tr("Deckungsbeitrag/Stück", "Contrib. margin/unit")}: ${_fmtC(margin)}';
    });
    widget.onResult(bepRev);
    _savePrefs();
  }

  // ── Hilfsfunktionen ───────────────────────────────────────────────────────────

  double? _parseNum(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.').replaceAll("'", ''));

  String _fmtInput(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    final s = v.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  String _fmtC(double v) => NumberFormat('#,##0.00', Platform.localeName).format(v);

  // ── UI ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          // Modus-Auswahl
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                _modeChip(_FinMode.tvm,       'TVM',                    cs),
                _modeChip(_FinMode.amort,     tr('Amort', 'Amort'),     cs),
                _modeChip(_FinMode.cash,      tr('Cashflow', 'Cash'),   cs),
                _modeChip(_FinMode.conv,      tr('Konv', 'Conv'),       cs),
                _modeChip(_FinMode.breakeven, tr('Break-Even', 'B/E'),  cs),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: switch (_mode) {
                _FinMode.tvm       => _buildTVM(cs),
                _FinMode.amort     => _buildAmort(cs),
                _FinMode.cash      => _buildCash(cs),
                _FinMode.conv      => _buildConv(cs),
                _FinMode.breakeven => _buildBE(cs),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(_FinMode m, String label, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: _mode == m,
      onSelected: (_) => setState(() { _mode = m; }),
    ),
  );

  // TVM-Zeile: Label | Eingabefeld | Lösen-Button
  Widget _tvmRow(String label, String hint, TextEditingController ctrl, _TVMField field, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (_) => _savePrefs(),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 68,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _solveTVM(field),
              child: Text(tr('Lös.', 'Solve'), style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBox(String text, ColorScheme cs) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
    child: Text(text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
        textAlign: TextAlign.center),
  );

  Widget _buildTVM(ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(tr('Zeitwert des Geldes', 'Time Value of Money'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary),
          textAlign: TextAlign.center),
      const SizedBox(height: 6),
      _tvmRow('N',              tr('Perioden', 'Periods'),          _nCtrl,   _TVMField.n,   cs),
      _tvmRow('I%',             tr('Zins/Periode %', 'Rate/Period %'), _iCtrl, _TVMField.i, cs),
      _tvmRow(tr('BW', 'PV'),   tr('Barwert', 'Present Value'),    _pvCtrl,  _TVMField.pv,  cs),
      _tvmRow(tr('Rate', 'PMT'), tr('Zahlung/Periode', 'Payment/Period'), _pmtCtrl, _TVMField.pmt, cs),
      _tvmRow(tr('EW', 'FV'),   tr('Endwert', 'Future Value'),     _fvCtrl,  _TVMField.fv,  cs),
      const SizedBox(height: 8),
      Row(
        children: [
          Text(tr('Zahlung: ', 'Payment: '), style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(tr('Ende', 'End'))),
              ButtonSegment(value: true,  label: Text(tr('Anfang', 'Beg'))),
            ],
            selected: {_bgn},
            onSelectionChanged: (s) { setState(() => _bgn = s.first); _savePrefs(); },
            style: ButtonStyle(
              minimumSize: WidgetStateProperty.all(const Size(60, 32)),
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      if (_tvmResult.isNotEmpty) _resultBox(_tvmResult, cs),
      if (_tvmError.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_tvmError, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
        ),
      const SizedBox(height: 10),
      Text(
        tr(
          '4 Felder ausfüllen → «Lös.» beim gesuchten Feld.\n'
          'Vorzeichen: Eingang positiv, Ausgang negativ.',
          'Fill 4 fields → tap «Solve» on the unknown field.\n'
          'Sign: inflow positive, outflow negative.',
        ),
        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
      ),
    ],
  );

  Widget _buildAmort(ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(tr('Amortisation', 'Amortization'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary),
          textAlign: TextAlign.center),
      Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 10),
        child: Text(tr('Verwendet TVM-Werte (N, I%, BW, Rate)', 'Uses TVM values (N, I%, PV, PMT)'),
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55)),
            textAlign: TextAlign.center),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _amortFromCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Von Periode', 'From Period'),
                border: const OutlineInputBorder(), isDense: true,
              ),
              onChanged: (_) => _savePrefs(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _amortToCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Bis Periode', 'To Period'),
                border: const OutlineInputBorder(), isDense: true,
              ),
              onChanged: (_) => _savePrefs(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: _computeAmort,
        style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
        child: Text(tr('Berechnen', 'Calculate')),
      ),
      if (_amortResult.isNotEmpty) _resultBox(_amortResult, cs),
    ],
  );

  Widget _buildCash(ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(tr('Cashflow – NPV / IRR', 'Cash Flow – NPV / IRR'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      ...List.generate(_cfCtrls.length, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text('CF$i', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary)),
            ),
            Expanded(
              child: TextField(
                controller: _cfCtrls[i],
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: i == 0 ? tr('Investition (neg.)', 'Investment (neg.)') : '0',
                ),
                onChanged: (_) { setState(() {}); _savePrefs(); },
              ),
            ),
            if (i >= 2)
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: cs.error, size: 20),
                onPressed: () { setState(() { _cfCtrls[i].dispose(); _cfCtrls.removeAt(i); }); _savePrefs(); },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      )),
      TextButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: Text(tr('CF hinzufügen', 'Add CF'), style: const TextStyle(fontSize: 13)),
        onPressed: () { setState(() => _cfCtrls.add(TextEditingController(text: '0'))); },
      ),
      const SizedBox(height: 4),
      TextField(
        controller: _npvRateCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: tr('Zinssatz % (für NPV)', 'Rate % (for NPV)'),
          border: const OutlineInputBorder(), isDense: true,
        ),
        onChanged: (_) => _savePrefs(),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _computeNPV,
              style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
              child: const Text('NPV'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _computeIRR,
              style: ElevatedButton.styleFrom(backgroundColor: cs.secondary, foregroundColor: cs.onSecondary),
              child: const Text('IRR'),
            ),
          ),
        ],
      ),
      if (_cashResult.isNotEmpty) _resultBox(_cashResult, cs),
      if (_cashError.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_cashError, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
        ),
    ],
  );

  Widget _buildConv(ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(tr('Zinskonversion', 'Interest Conversion'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextField(
        controller: _mCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: tr('Perioden/Jahr (m)', 'Periods/Year (m)'),
          helperText: tr('12 = monatlich · 4 = vierteljährlich · 1 = jährlich',
                         '12 = monthly · 4 = quarterly · 1 = annual'),
          border: const OutlineInputBorder(), isDense: true,
        ),
        onChanged: (_) => _savePrefs(),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _nomCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: tr('Nominalzins %', 'Nominal Rate %'),
          border: const OutlineInputBorder(), isDense: true,
        ),
        onChanged: (_) => _savePrefs(),
      ),
      const SizedBox(height: 4),
      ElevatedButton(
        onPressed: _convNomToEff,
        style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
        child: Text(tr('→ Effektivzins', '→ Effective Rate')),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _effCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: tr('Effektivzins %', 'Effective Rate %'),
          border: const OutlineInputBorder(), isDense: true,
        ),
        onChanged: (_) => _savePrefs(),
      ),
      const SizedBox(height: 4),
      ElevatedButton(
        onPressed: _convEffToNom,
        style: ElevatedButton.styleFrom(backgroundColor: cs.secondary, foregroundColor: cs.onSecondary),
        child: Text(tr('→ Nominalzins', '→ Nominal Rate')),
      ),
      if (_convResult.isNotEmpty) _resultBox(_convResult, cs),
    ],
  );

  Widget _buildBE(ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(tr('Break-Even', 'Break-Even'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      _beField(tr('Fixkosten', 'Fixed Costs'), _fcCtrl),
      _beField(tr('Variable Kosten/Stück', 'Variable Cost/Unit'), _vcCtrl),
      _beField(tr('Verkaufspreis/Stück', 'Selling Price/Unit'), _prCtrl),
      const SizedBox(height: 4),
      ElevatedButton(
        onPressed: _computeBreakEven,
        style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
        child: Text(tr('Berechnen', 'Calculate')),
      ),
      if (_beResult.isNotEmpty) _resultBox(_beResult, Theme.of(context).colorScheme),
    ],
  );

  Widget _beField(String label, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(), isDense: true,
      ),
      onChanged: (_) => _savePrefs(),
    ),
  );
}

// ─── Privacy-Consent-Dialog ──────────────────────────────────────────────────

class _PrivacyConsentDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Datenschutz', 'Privacy Policy')),
      content: Text(tr(
        'FX Calc speichert keine persönlichen Daten. Wechselkurse werden live '
        'von Yahoo Finance abgerufen.\n\n'
        'Bitte stimme unserer Datenschutzerklärung zu, um die App zu nutzen.',
        'FX Calc does not store personal data. Exchange rates are fetched live '
        'from Yahoo Finance.\n\n'
        'Please accept our privacy policy to use the app.',
      )),
      actions: [
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(kPrivacyUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(tr('Datenschutzerklärung', 'Privacy Policy')),
        ),
        TextButton(
          onPressed: () => SystemNavigator.pop(),
          child: Text(tr('Ablehnen', 'Decline'),
              style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('privacy_accepted', true);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(tr('Akzeptieren', 'Accept')),
        ),
      ],
    );
  }
}

// ─── Update-Dialog ───────────────────────────────────────────────────────────

class _UpdateDialog extends StatelessWidget {
  final String version;
  final String downloadUrl;
  const _UpdateDialog({required this.version, required this.downloadUrl});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Update verfügbar', 'Update available')),
      content: Text(tr(
        'Version $version ist verfügbar.\n\n'
        'Auf «Download» tippen → APK wird im Browser heruntergeladen → '
        'in der Download-Benachrichtigung auf «Öffnen» tippen → Installieren.',
        'Version $version is available.\n\n'
        'Tap «Download» → APK downloads in browser → '
        'tap «Open» in the download notification → Install.',
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Später', 'Later')),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: Text(tr('Download', 'Download')),
          onPressed: () {
            launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ─── Info / Über ─────────────────────────────────────────────────────────────

class InfoPage extends StatefulWidget {
  final VoidCallback? onCheckUpdate;
  const InfoPage({super.key, this.onCheckUpdate});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = 'v${i.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Text('FX Calc',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 2),
            Text(
              tr('Rechner & Währungsrechner', 'Calculator & Currency Converter'),
              style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      tr(
                        'FX Calc ist Teil von Stock Monitor – '
                        'der kostenlosen Portfolio-App für Desktop.',
                        'FX Calc is part of Stock Monitor – '
                        'the free portfolio app for desktop.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('Kursdaten: Yahoo Finance', 'Data source: Yahoo Finance'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.language),
                      label: const Text('www.stock-monitor.ch'),
                      onPressed: () => launchUrl(
                        Uri.parse('https://www.stock-monitor.ch'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    if (widget.onCheckUpdate != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.system_update_outlined),
                        label: Text(tr('Nach Updates suchen', 'Check for updates')),
                        onPressed: widget.onCheckUpdate,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    Text(
                      tr('Stock Monitor unterstützen ❤️', 'Support Stock Monitor ❤️'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        'Kostenlos – jede Spende hilft bei der Weiterentwicklung.',
                        'Free – every donation helps with further development.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    // Twint QR
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_twintQr175),
                        width: 175,
                        height: 176,
                        filterQuality: FilterQuality.none,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('TWINT',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.credit_card),
                      label: const Text('PayPal – paypal.me/StockMonitor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003087),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => launchUrl(
                        Uri.parse('https://paypal.me/StockMonitor'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(kPrivacyUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                tr('Datenschutzerklärung', 'Privacy Policy'),
                style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
              ),
            ),
            Text(_version, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
          ],
        ),
      ),
    );
  }
}
