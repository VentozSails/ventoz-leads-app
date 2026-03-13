import 'file_reader_stub.dart' if (dart.library.io) 'file_reader_io.dart'
    as impl;

Future<List<int>?> readFileBytes(String path) => impl.readFileBytes(path);
