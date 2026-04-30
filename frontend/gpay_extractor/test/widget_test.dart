import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gpay_extractor/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GPayExtractorApp());
    await tester.pumpAndSettle();

    // Verify app title is shown
    expect(find.text('GPay Extractor'), findsOneWidget);
  });
}
