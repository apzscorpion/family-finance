import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_finance/main.dart';

void main() {
  testWidgets('App launches and shows navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(const FamilyFinanceApp());
    await tester.pumpAndSettle();

    // The main navigation bar should be visible
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
