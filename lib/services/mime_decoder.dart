import 'dart:convert';

class MimeDecoder {
  static MimeResult decode(String rawEmail) {
    final headerEnd = rawEmail.indexOf('\r\n\r\n');
    if (headerEnd < 0) {
      final altEnd = rawEmail.indexOf('\n\n');
      if (altEnd < 0) return MimeResult(headers: {}, textBody: rawEmail, htmlBody: rawEmail);
      final headers = _parseHeaders(rawEmail.substring(0, altEnd));
      final body = rawEmail.substring(altEnd + 2);
      return _decodeBody(headers, body);
    }

    final headers = _parseHeaders(rawEmail.substring(0, headerEnd));
    final body = rawEmail.substring(headerEnd + 4);
    return _decodeBody(headers, body);
  }

  static MimeResult _decodeBody(Map<String, String> headers, String body) {
    final contentType = headers['content-type'] ?? '';
    final encoding = (headers['content-transfer-encoding'] ?? '').toLowerCase().trim();

    if (contentType.contains('multipart/')) {
      return _decodeMultipart(contentType, body);
    }

    final decoded = _applyEncoding(body, encoding);
    final charset = _extractParam(contentType, 'charset') ?? 'utf-8';
    final text = _decodeCharset(decoded, charset);

    if (contentType.contains('text/html')) {
      return MimeResult(headers: headers, htmlBody: text);
    }
    return MimeResult(headers: headers, textBody: text, htmlBody: text);
  }

  static MimeResult _decodeMultipart(String contentType, String body) {
    final boundary = _extractParam(contentType, 'boundary');
    if (boundary == null || boundary.isEmpty) {
      return MimeResult(headers: {}, textBody: body, htmlBody: body);
    }

    final delimiter = '--$boundary';
    final parts = body.split(delimiter);

    String? textBody;
    String? htmlBody;

    for (final part in parts) {
      if (part.trim().isEmpty || part.trim() == '--') continue;

      final partHeaderEnd = part.indexOf('\r\n\r\n');
      final altPartHeaderEnd = part.indexOf('\n\n');
      final effectiveEnd = partHeaderEnd >= 0 ? partHeaderEnd : altPartHeaderEnd;
      if (effectiveEnd < 0) continue;

      final partHeaders = _parseHeaders(part.substring(0, effectiveEnd));
      final partBody = part.substring(effectiveEnd + (partHeaderEnd >= 0 ? 4 : 2));
      final partContentType = partHeaders['content-type'] ?? '';
      final partEncoding = (partHeaders['content-transfer-encoding'] ?? '').toLowerCase().trim();

      if (partContentType.contains('multipart/')) {
        final nested = _decodeMultipart(partContentType, partBody);
        textBody ??= nested.textBody;
        if (nested.htmlBody != null) htmlBody = nested.htmlBody;
        continue;
      }

      final decoded = _applyEncoding(partBody, partEncoding);
      final charset = _extractParam(partContentType, 'charset') ?? 'utf-8';
      final text = _decodeCharset(decoded, charset);

      if (partContentType.contains('text/html')) {
        htmlBody = text;
      } else if (partContentType.contains('text/plain')) {
        textBody ??= text;
      }
    }

    return MimeResult(
      headers: {},
      textBody: textBody,
      htmlBody: htmlBody ?? textBody,
    );
  }

  static String _applyEncoding(String input, String encoding) {
    if (encoding == 'base64') {
      try {
        final cleaned = input.replaceAll(RegExp(r'\s+'), '');
        return utf8.decode(base64.decode(cleaned), allowMalformed: true);
      } catch (_) {
        return input;
      }
    }
    if (encoding == 'quoted-printable') {
      return _decodeQuotedPrintable(input);
    }
    return input;
  }

  static String _decodeQuotedPrintable(String input) {
    var result = input.replaceAll('=\r\n', '').replaceAll('=\n', '');
    result = result.replaceAllMapped(
      RegExp(r'=([0-9A-Fa-f]{2})'),
      (m) {
        final byte = int.parse(m.group(1)!, radix: 16);
        return String.fromCharCode(byte);
      },
    );
    return result;
  }

  static String _decodeCharset(String input, String charset) {
    // Already decoded as UTF-8 in most paths; handle latin1 if needed
    final lower = charset.toLowerCase().replaceAll('-', '');
    if (lower == 'iso88591' || lower == 'latin1') {
      try {
        return latin1.decode(input.codeUnits);
      } catch (_) {}
    }
    return input;
  }

  static Map<String, String> _parseHeaders(String headerBlock) {
    final headers = <String, String>{};
    final lines = headerBlock.split(RegExp(r'\r?\n'));
    String? currentKey;
    final currentValue = StringBuffer();

    for (final line in lines) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        currentValue.write(' ${line.trim()}');
        continue;
      }
      if (currentKey != null) {
        headers[currentKey] = currentValue.toString().trim();
      }
      final colonIdx = line.indexOf(':');
      if (colonIdx > 0) {
        currentKey = line.substring(0, colonIdx).toLowerCase().trim();
        currentValue.clear();
        currentValue.write(line.substring(colonIdx + 1).trim());
      } else {
        currentKey = null;
        currentValue.clear();
      }
    }
    if (currentKey != null) {
      headers[currentKey] = currentValue.toString().trim();
    }
    return headers;
  }

  static String? _extractParam(String headerValue, String param) {
    final pattern = RegExp('$param\\s*=\\s*"?([^";\\s]+)"?', caseSensitive: false);
    final match = pattern.firstMatch(headerValue);
    return match?.group(1);
  }

  static String decodeHeaderValue(String value) {
    return value.replaceAllMapped(
      RegExp(r'=\?([^?]+)\?(B|Q)\?([^?]*)\?=', caseSensitive: false),
      (m) {
        final charset = m.group(1)!.toLowerCase();
        final encoding = m.group(2)!.toUpperCase();
        final encoded = m.group(3)!;

        List<int> bytes;
        if (encoding == 'B') {
          try {
            bytes = base64.decode(encoded);
          } catch (_) {
            return m.group(0)!;
          }
        } else {
          bytes = _decodeQEncoded(encoded);
        }

        if (charset.contains('utf-8') || charset.contains('utf8')) {
          return utf8.decode(bytes, allowMalformed: true);
        } else if (charset.contains('iso-8859') || charset.contains('latin')) {
          return latin1.decode(bytes);
        }
        return utf8.decode(bytes, allowMalformed: true);
      },
    );
  }

  static List<int> _decodeQEncoded(String input) {
    final bytes = <int>[];
    var i = 0;
    while (i < input.length) {
      if (input[i] == '_') {
        bytes.add(32); // space
        i++;
      } else if (input[i] == '=' && i + 2 < input.length) {
        bytes.add(int.parse(input.substring(i + 1, i + 3), radix: 16));
        i += 3;
      } else {
        bytes.add(input.codeUnitAt(i));
        i++;
      }
    }
    return bytes;
  }
}

class MimeResult {
  final Map<String, String> headers;
  final String? textBody;
  final String? htmlBody;

  const MimeResult({
    required this.headers,
    this.textBody,
    this.htmlBody,
  });

  String get bestBody => htmlBody ?? textBody ?? '';
}
