import 'dart:convert';

/// Decodes POS text that may be UTF-8 or legacy Windows-1252.
///
/// Windows terminals and some printers still emit single-byte accents
/// (é = 0xE9, — = 0x97). Valid UTF-8 sequences are kept as-is.
String decodeText(List<int> bytes) {
  if (bytes.isEmpty) return '';
  final out = StringBuffer();
  var i = 0;
  while (i < bytes.length) {
    final byte = bytes[i] & 0xFF;
    if (byte < 0x80) {
      out.writeCharCode(byte);
      i++;
      continue;
    }

    final length = _utf8Length(byte);
    if (length > 1 && i + length <= bytes.length && _isUtf8Sequence(bytes, i, length)) {
      out.write(utf8.decode(bytes.sublist(i, i + length)));
      i += length;
      continue;
    }

    out.writeCharCode(_windows1252[byte] ?? byte);
    i++;
  }
  return out.toString();
}

int _utf8Length(int lead) {
  if (lead >= 0xC2 && lead <= 0xDF) return 2;
  if (lead >= 0xE0 && lead <= 0xEF) return 3;
  if (lead >= 0xF0 && lead <= 0xF4) return 4;
  return 1;
}

bool _isUtf8Sequence(List<int> bytes, int start, int length) {
  for (var j = 1; j < length; j++) {
    if ((bytes[start + j] & 0xC0) != 0x80) return false;
  }
  try {
    utf8.decode(bytes.sublist(start, start + length));
    return true;
  } on FormatException {
    return false;
  }
}

/// Unicode code points for Windows-1252 bytes 0x80–0x9F.
/// Bytes 0xA0–0xFF match Latin-1 and are used as-is.
const Map<int, int> _windows1252 = {
  0x80: 0x20AC,
  0x82: 0x201A,
  0x83: 0x0192,
  0x84: 0x201E,
  0x85: 0x2026,
  0x86: 0x2020,
  0x87: 0x2021,
  0x88: 0x02C6,
  0x89: 0x2030,
  0x8A: 0x0160,
  0x8B: 0x2039,
  0x8C: 0x0152,
  0x8E: 0x017D,
  0x91: 0x2018,
  0x92: 0x2019,
  0x93: 0x201C,
  0x94: 0x201D,
  0x95: 0x2022,
  0x96: 0x2013,
  0x97: 0x2014,
  0x98: 0x02DC,
  0x99: 0x2122,
  0x9A: 0x0161,
  0x9B: 0x203A,
  0x9C: 0x0153,
  0x9E: 0x017E,
  0x9F: 0x0178,
};
