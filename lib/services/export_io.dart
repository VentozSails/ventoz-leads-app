import 'dart:io';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:file_selector_windows/file_selector_windows.dart';

void downloadCsvWeb(String csv, String filename) {
  throw UnsupportedError('Use export_web.dart on web');
}

Future<String?> saveCsvDesktop(String csv, String filename) async {
  final plugin = FileSelectorWindows();
  final location = await plugin.getSavePath(
    acceptedTypeGroups: [
      XTypeGroup(label: 'CSV (puntkomma)', extensions: ['csv']),
      XTypeGroup(label: 'Tekst (tab-gescheiden)', extensions: ['txt']),
    ],
    suggestedName: filename,
  );

  if (location == null) return null;

  String content = csv;
  if (location.endsWith('.txt')) {
    content = csv.replaceAll(';', '\t');
  }

  final file = File(location);
  await file.writeAsString('\uFEFF$content', flush: true);
  return file.path;
}
