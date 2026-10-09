import 'package:flutter/material.dart';

/// Single-line text that fades out at the end when it doesn't fit, instead
/// of an ellipsis or a hard clip. The fade (24px, matching [ScrollFadeMask])
/// only appears when the text actually overflows.
///
/// App-wide rule: use this for any single-line text that can overflow.
class FadeText extends StatelessWidget {
  const FadeText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.fadeExtent = 24,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final double fadeExtent;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      data,
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) return text;

        final painter = TextPainter(
          text: TextSpan(
            text: data,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final overflows = painter.width > constraints.maxWidth;
        painter.dispose();
        if (!overflows) return text;

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final f =
                bounds.width <= 0
                    ? 0.0
                    : (fadeExtent / bounds.width).clamp(0.0, 1.0);
            return LinearGradient(
              colors: const [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 1 - f, 1],
            ).createShader(bounds);
          },
          child: text,
        );
      },
    );
  }
}
