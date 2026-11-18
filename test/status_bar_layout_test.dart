import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/features/shell/status_bar.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  testWidgets('status bar right group is pinned to the far right', (t) async {
    final state = AppState();
    addTearDown(state.dispose);
    for (final w in [1000.0, 1470.0]) {
      await t.binding.setSurfaceSize(Size(w, 200));
      await t.pumpWidget(MaterialApp(
        home: PalScope(
          pal: DarkPal,
          child: Scaffold(
            body: Column(children: [const Spacer(), StatusBar(state: state)]),
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 100));
      final right = t.getTopRight(find.text('commands')).dx;
      expect(right, closeTo(w - 10, 1), reason: 'width $w');
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
