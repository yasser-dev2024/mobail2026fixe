import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_shop_pro/core/router/app_router.dart';
import 'package:mobile_shop_pro/core/theme/app_theme.dart';

void main() {
  testWidgets('App theme builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Text('ProShop')),
      ),
    );

    expect(find.text('ProShop'), findsOneWidget);
  });

  test('App router starts at splash without an activation gate', () {
    expect(AppRouter.router.routeInformationProvider.value.uri.path, '/splash');
  });
}
