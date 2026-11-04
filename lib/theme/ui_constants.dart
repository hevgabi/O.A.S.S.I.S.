import 'package:flutter/material.dart';

/// Shared UI values for the Entry, Splash, and Visitor Chat screens.
/// Black and white direction only: no colored accents.
class UiConstants {
  UiConstants._();

  // Colors
  static const Color black = Colors.black;
  static const Color fieldGray = Color(0xFFEEEEEE);
  static const Color bubbleGray = Color(0xFFEEEEEE);
  static const Color buttonGray = Color(0xFFC4C4C4);
  static const Color lightButtonGray = Color(0xFFE0E0E0);
  static const Color borderGray = Color(0xFF666666);
  static const Color mutedText = Colors.black54;

  // Spacing
  static const double screenPadding = 20;
  static const double spaceXs = 5;
  static const double spaceSm = 10;
  static const double spaceMd = 16;
  static const double spaceLg = 26;
  static const double spaceXl = 34;
  static const double dialogSpacing = 24;

  // Text sizes
  static const double headingSize = 38;
  static const double titleSize = 24;
  static const double labelSize = 18;
  static const double bodySize = 17;
  static const double captionSize = 12;

  // Controls
  static const double inputHeight = 58;
  static const double buttonHeight = 58;
  static const double minTapTarget = 48;

  // Borders and radius
  static const double borderWidth = 1.2;
  static const double focusedBorderWidth = 1.5;
  static const double radius = 9;
  static const double bubbleRadius = 13;

  // Layout
  static const double maxFormWidth = 440;
  static const double maxChatWidth = 600;

  static OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Shared text field look for Entry and Visitor Chat.
  static InputDecoration inputDecoration(String hint, {String? errorText}) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 2,
      errorStyle: const TextStyle(
        color: black,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(fontSize: labelSize, color: Colors.black45),
      filled: true,
      fillColor: fieldGray,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: _border(borderGray, borderWidth),
      enabledBorder: _border(borderGray, borderWidth),
      focusedBorder: _border(black, focusedBorderWidth),
      errorBorder: _border(black, focusedBorderWidth),
      focusedErrorBorder: _border(black, focusedBorderWidth),
    );
  }
}
