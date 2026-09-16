/// Safe numeric parsing for sync payloads (API decimals often arrive as strings).
int syncAsInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is BigInt) return value.toInt();
  return int.tryParse(value.toString().trim()) ??
      double.tryParse(value.toString().trim())?.round() ??
      fallback;
}

int? syncAsIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is BigInt) return value.toInt();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return int.tryParse(text) ?? double.tryParse(text)?.round();
}

double syncAsDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is BigInt) return value.toDouble();
  return double.tryParse(value.toString().trim().replaceAll(',', '.')) ?? fallback;
}

double? syncAsDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is BigInt) return value.toDouble();
  final text = value.toString().trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}
