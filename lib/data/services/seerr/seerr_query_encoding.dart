import 'dart:convert';

/// Percent-encodes every byte outside RFC 3986's unreserved set
/// (`A-Z a-z 0-9 - . _ ~`), so a space becomes `%20` rather than `+` and
/// `'`, `(`, `)`, `!` and `*` are escaped as well.
///
/// Seerr validates the raw query string and answers
/// 400 "Parameter 'query' must be url encoded" when any reserved character
/// reaches it unescaped. Dio's queryParameters encoding writes spaces as `+`
/// and Uri.encodeComponent leaves `!'()*` alone, so neither is safe for the
/// search endpoint; build the query string by hand with this instead.
String strictQueryEncode(String value) {
  final out = StringBuffer();
  for (final byte in utf8.encode(value)) {
    final unreserved = (byte >= 0x30 && byte <= 0x39) || // 0-9
        (byte >= 0x41 && byte <= 0x5A) || // A-Z
        (byte >= 0x61 && byte <= 0x7A) || // a-z
        byte == 0x2D || // -
        byte == 0x2E || // .
        byte == 0x5F || // _
        byte == 0x7E; // ~
    if (unreserved) {
      out.writeCharCode(byte);
    } else {
      out.write('%');
      out.write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return out.toString();
}
