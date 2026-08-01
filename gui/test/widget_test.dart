import 'package:flutter_test/flutter_test.dart';

import 'package:id3_tagger_gui/main.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla principal',
      (WidgetTester tester) async {
    await tester.pumpWidget(const IdTaggerApp());

    expect(find.text('ID3 Tagger'), findsWidgets);
    expect(find.text('Etiquetar'), findsOneWidget);
  });
}
