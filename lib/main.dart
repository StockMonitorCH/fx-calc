import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final locale = Platform.localeName;
  final f = NumberFormat.decimalPatternDigits(
    locale: locale, decimalDigits: dec);
  return f.format(v);
}

// Wie viele Dezimalstellen braucht ein Ergebnis wirklich?
// Rundet auf 10 signifikante Stellen (eliminiert Fließkomma-Rauschen wie 0.30000000004)
int _neededDecimals(double v, {int max = 12}) {
  final rounded = double.parse(v.toStringAsPrecision(12));
  if (rounded == rounded.truncateToDouble()) return 0;
  final s = rounded.toStringAsFixed(max);
  final dot = s.indexOf('.');
  if (dot < 0) return 0;
  final dec = s.substring(dot + 1);
  int n = dec.length;
  while (n > 0 && dec[n - 1] == '0') n--;
  return n;
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
  'XAU (Gold/oz)':'XAUUSD=X',
  'XAG (Silber/oz)':'XAGUSD=X',
  'XPT (Platin/oz)':'XPTUSD=X',
  'XPD (Palladium/oz)':'XPDUSD=X',
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
    if (Platform.isAndroid) {
      Future.delayed(const Duration(seconds: 3), _checkForUpdate);
    }
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

class CalcDisplay extends StatelessWidget {
  final String main;
  final String sub;
  final String history;

  const CalcDisplay({
    super.key,
    required this.main,
    this.sub = '',
    this.history = '',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fs = main.length <= 9 ? 36.0
        : main.length <= 14 ? 26.0
        : main.length <= 20 ? 20.0 : 15.0;

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
            if (history.isNotEmpty)
              Text(history,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                  textAlign: TextAlign.right),
            const Spacer(),
            Text(main,
                style: TextStyle(
                    fontSize: fs,
                    fontWeight: FontWeight.bold,
                    color: cs.primary),
                textAlign: TextAlign.right,
                maxLines: 2),
            if (sub.isNotEmpty)
              Text(sub,
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
  String _histFull = '';   // vollständige Rechnung z.B. "1234 × 5.6 = 6'910.4"
  bool   _eval     = false;

  @override
  void initState() {
    super.initState();
    if (widget.initValue != 0) _setVal(widget.initValue);
  }

  void _setVal(double v) {
    _expr = v.toString();
    _disp = fmtNum(v, dec: 4);
    _eval = true;
    _hist = '';
  }

  String get _displayText {
    final d = _disp.isEmpty ? '0' : _disp;
    final open = '('.allMatches(d).length - ')'.allMatches(d).length;
    return open > 0 ? d + ')' * open : d;
  }

  void _btn(String t) {
    setState(() {
      if (t == 'CE') {
        _expr = ''; _disp = ''; _hist = ''; _histFull = ''; _eval = false; return;
      }
      if (t == '←') {
        if (_eval) { _expr = ''; _disp = ''; _eval = false; return; }
        if (_disp.isNotEmpty) {
          // Multi-char tokens
          if (_disp.endsWith('√(')) { _expr = _expr.substring(0, _expr.length - 5); _disp = _disp.substring(0, _disp.length - 2); }
          else if (_disp.endsWith('²')) { _expr = _expr.substring(0, _expr.length - 3); _disp = _disp.substring(0, _disp.length - 1); }
          else if (_disp.endsWith('%')) { _expr = _expr.substring(0, _expr.length - 4); _disp = _disp.substring(0, _disp.length - 1); }
          else { _expr = _expr.substring(0, _expr.length - 1); _disp = _disp.substring(0, _disp.length - 1); }
        }
        return;
      }
      if (t == '=') { _evaluate(); return; }

      if (_eval && !['＋','−','×','÷','%','²'].any((op) => t == op)) {
        _expr = ''; _disp = '';
      }
      _eval = false;

      final map = {'√': ['sqrt(', '√('], 'x²': ['^2', '²'],
        '×': ['*', '×'], '÷': ['/', '÷'], '%': ['/100', '%'],
        '＋': ['+', '＋'], '−': ['-', '−']};
      if (map.containsKey(t)) {
        const binOps = {'×', '÷', '＋', '−'};
        if (binOps.contains(t) && _disp.isNotEmpty && binOps.contains(_disp[_disp.length - 1])) {
          _expr = _expr.substring(0, _expr.length - 1);
          _disp = _disp.substring(0, _disp.length - 1);
        }
        _expr += map[t]![0]; _disp += map[t]![1];
      } else if (t == '±') {
        if (_expr.isNotEmpty) { _expr = '-($_expr)'; _disp = '-($_disp)'; }
        else { _expr = '-'; _disp = '-'; }
      } else if (t == '(') {
        // 2( → 2*(
        if (_expr.isNotEmpty && RegExp(r'[0-9)]').hasMatch(_expr[_expr.length - 1])) {
          _expr += '*'; _disp += '×';
        }
        _expr += '('; _disp += '(';
      } else if (t == '.') {
        // Zweiten Punkt in derselben Zahl ignorieren
        final lastOp = _disp.lastIndexOf(RegExp(r'[×÷＋−()]'));
        final cur = lastOp >= 0 ? _disp.substring(lastOp + 1) : _disp;
        if (!cur.contains('.')) { _expr += '.'; _disp += '.'; }
      } else {
        _expr += t; _disp += t;
      }
    });
  }

  void _evaluate() {
    if (_expr.isEmpty) return;
    final open = '('.allMatches(_expr).length - ')'.allMatches(_expr).length;
    final evalStr = _expr + ')' * (open > 0 ? open : 0);
    final dispStr = _disp + ')' * (open > 0 ? open : 0);
    try {
      final parser = Parser();
      final exp = parser.parse(evalStr);
      final ctx = ContextModel();
      final result = exp.evaluate(EvaluationType.REAL, ctx) as double;
      if (!result.isFinite) throw Exception();
      setState(() {
        _hist = '$dispStr =';
        final rs = fmtNum(result, dec: _neededDecimals(result));
        _histFull = '$dispStr = $rs';
        _disp = rs;
        _expr = result.toString();
        _eval = true;
        widget.onResult(result);
      });
    } catch (_) {
      setState(() {
        _disp = tr('Fehler', 'Error');
        _expr = ''; _eval = false;
      });
    }
  }

  Widget _buildBtn(String label, {Color? bg, Color? fg, int flex = 1}) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? cs.surfaceVariant,
            foregroundColor: fg ?? cs.onSurfaceVariant,
            minimumSize: const Size(0, 58),
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
          CalcDisplay(main: _displayText),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Column(
                children: [
                  _row(['CE', '←', '(', ')', '%'],
                      bgs: [fn,fn,fn,fn,fn], fgs: [fnFg,fnFg,fnFg,fnFg,fnFg]),
                  _row(['√', 'x²', '7', '8', '9'],
                      bgs: [fn,fn,null,null,null], fgs: [fnFg,fnFg,null,null,null]),
                  _row(['÷', '×', '4', '5', '6'],
                      bgs: [op,op,null,null,null], fgs: [Colors.white, Colors.white,null,null,null]),
                  _row(['−', '＋', '1', '2', '3'],
                      bgs: [op,op,null,null,null], fgs: [Colors.white, Colors.white,null,null,null]),
                  Row(children: [
                    _buildBtn('±', bg: fn, fg: fnFg),
                    _buildBtn('.'),
                    _buildBtn('0'),
                    _buildBtn('=', bg: eq, fg: Colors.white, flex: 2),
                  ]),
                  const Spacer(),
                  if (_disp.isNotEmpty || _histFull.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _histFull.isNotEmpty ? _histFull : _disp,
                        style: TextStyle(
                          fontSize: 22,
                          color: cs.onSurface.withValues(alpha: _histFull.isNotEmpty ? 0.45 : 0.70),
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 3,
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
  final _startCtrl    = TextEditingController(text: '10000');
  final _depositCtrl  = TextEditingController(text: '1200');
  final _yearsCtrl    = TextEditingController(text: '20');
  final _rateCtrl     = TextEditingController(text: '5.0');

  bool   _isWithdrawal   = false;
  double _endWithout     = 0;
  double _endWith        = 0;
  double _totalPaid      = 0;
  double _interestGain   = 0;
  double? _yearsToDepletion;

  @override
  void initState() {
    super.initState();
    _startCtrl.addListener(_calculate);
    _depositCtrl.addListener(_calculate);
    _yearsCtrl.addListener(_calculate);
    _rateCtrl.addListener(_calculate);
    _calculate();
  }

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
                                setState(() { _isWithdrawal = s.first; _calculate(); }),
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
            Text(_version, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
          ],
        ),
      ),
    );
  }
}
