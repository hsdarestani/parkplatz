import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/config/design_tokens.dart';
import 'package:freiraum_parking/core/theme/app_theme.dart';

void main() {
  test('light chip theme keeps labels readable on pale surfaces', () {
    final chips = appTheme().chipTheme;

    expect(chips.backgroundColor, T.surfaceRaised);
    expect(chips.disabledColor, T.surfaceRaised);
    expect(chips.selectedColor, T.mintSoft);
    expect(chips.checkmarkColor, T.success);
    expect(chips.labelStyle?.color, T.ink);
  });

  testWidgets('action and filter chips inherit dark readable labels',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: Column(
            children: [
              ActionChip(
                avatar: const Icon(Icons.schedule_rounded),
                label: const Text('2 Std.'),
                onPressed: () {},
              ),
              FilterChip(
                avatar: const Icon(Icons.roofing_rounded),
                label: const Text('Überdacht'),
                selected: false,
                onSelected: (_) {},
              ),
              ChoiceChip(
                avatar: const Icon(Icons.garage_rounded),
                label: const Text('Garage'),
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final context = tester.element(find.text('Überdacht'));
    expect(ChipTheme.of(context).labelStyle.color, T.ink);
    expect(ChipTheme.of(context).backgroundColor, T.surfaceRaised);
    expect(ChipTheme.of(context).selectedColor, T.mintSoft);
  });
}
