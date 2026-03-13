import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadCsvWeb(String csv, String filename) {
  final bom = '\uFEFF';
  final bytes = utf8.encode('$bom$csv');
  final jsArray = bytes.toJS;
  final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

Future<String?> saveCsvDesktop(String csv, String filename) async {
  throw UnsupportedError('Use export_io.dart on desktop');
}
