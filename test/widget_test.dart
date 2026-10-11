import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fx_calc/main.dart';

void main() {
  testWidgets('App startet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FxCalcApp());
    expect(find.byType(FxCalcApp), findsOneWidget);
  });
}
