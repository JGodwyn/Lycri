import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/shared/utils/caps_text_controller.dart';

void main() {
  testWidgets('shows typed text in caps but keeps the typed value', (
    tester,
  ) async {
    final controller = CapsTextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: TextField(controller: controller)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Drag path');
    await tester.pump();

    final shown =
        tester
            .renderObject<RenderEditable>(
              find.descendant(
                of: find.byType(EditableText),
                matching: find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == '_Editable',
                ),
              ),
            )
            .text!
            .toPlainText();

    expect(shown, 'DRAG PATH'); // what the user sees
    expect(controller.text, 'Drag path'); // what gets saved
  });
}
