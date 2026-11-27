import 'package:flutter/services.dart';

/// Formats numeric date/time input as users type, including pasted digits.
/// The backend continues receiving the existing YYYY-MM-DD and HH:mm formats.
class NumericDateTimeFormatter extends TextInputFormatter {
  const NumericDateTimeFormatter.date()
      : groups = const [4, 2, 2],
        separator = '-';

  const NumericDateTimeFormatter.time()
      : groups = const [2, 2],
        separator = ':';

  final List<int> groups;
  final String separator;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final maxDigits = groups.fold<int>(0, (sum, length) => sum + length);
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    final buffer = StringBuffer();
    var used = 0;
    for (final group in groups) {
      if (used >= limited.length) break;
      final end = (used + group).clamp(0, limited.length);
      if (used > 0) buffer.write(separator);
      buffer.write(limited.substring(used, end));
      used = end;
    }
    final formatted = buffer.toString();

    final originalOffset =
        newValue.selection.extentOffset.clamp(0, newValue.text.length);
    final digitsToCursor = newValue.text
        .substring(0, originalOffset)
        .replaceAll(RegExp(r'\D'), '')
        .length
        .clamp(0, limited.length);
    var seen = 0;
    var offset = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) seen++;
      if (seen >= digitsToCursor) {
        offset = i + 1;
        break;
      }
    }
    if (digitsToCursor == 0) offset = 0;
    if (offset < formatted.length && formatted[offset] == separator &&
        originalOffset >= newValue.text.length) {
      offset++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
