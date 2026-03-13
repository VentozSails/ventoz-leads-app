import 'dart:io';

Future<List<int>?> readFileBytes(String path) async =>
    File(path).readAsBytes();
