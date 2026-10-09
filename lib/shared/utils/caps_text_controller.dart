import 'package:flutter/widgets.dart';

/// A [TextEditingController] that *displays* its text in capitals while
/// keeping the typed value as-is — for text fields set in a Display / Heading
/// / Title style (which are uppercase in the design), e.g. renaming a lyric.
///
/// The stored text (what gets saved) keeps the user's casing.
class CapsTextEditingController extends TextEditingController {
  CapsTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final upper = text.toUpperCase();
    // Fall back to the plain rendering when capitalising would change the
    // length (e.g. "ß" → "SS", which would misplace the cursor) or while an
    // IME is composing (keeps its underline).
    final composing =
        withComposing &&
        value.isComposingRangeValid &&
        !value.composing.isCollapsed;
    if (upper.length != text.length || composing) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(style: style, text: upper);
  }
}
