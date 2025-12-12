// lib/util/download_csv.dart
// Exports the proper implementation for web vs other platforms.
export 'download_csv_stub.dart'
    if (dart.library.html) 'download_csv_web.dart';
