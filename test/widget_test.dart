import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sarasara_studio_01_rev1/app.dart';

void main() {
  testWidgets(
    'SarasaraStudioApp renders the painting screen without crashing',
    (WidgetTester tester) async {
      await tester.pumpWidget(const SarasaraStudioApp());
      await tester.pump();

      // The floating toolbar's undo button is a reliable proxy for "the
      // painting screen mounted successfully" without depending on canvas
      // pixels, which aren't meaningfully assertable in a widget test.
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.redo_rounded), findsOneWidget);
    },
  );
}
