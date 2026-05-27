import 'package:flutter/material.dart';

class CommonTag extends StatelessWidget {
  const CommonTag({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    this.fontSize = 10,
    this.horizontalPadding = 8,
    this.verticalPadding = 3,
    this.letterSpacing = 0.4,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}
