// lib/util/download_csv_stub.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

/// Fallback for non-web platforms: write CSV to system temp directory
/// and show the path via returned string (or a snackbar). This avoids
/// adding extra packages and compiles everywhere.
Future<void> downloadCsvFile(String filename, String content) async {
  // Create a safe filename
  final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  try {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/$safeName');

    // Write using UTF-8 with BOM so Excel (Windows) recognizes encoding
    final bom = [0xEF, 0xBB, 0xBF];
    final encoded = <int>[]..addAll(bom)..addAll(utf8.encode(content));
    await file.writeAsBytes(encoded, flush: true);

    // We can't access BuildContext here to show a SnackBar.
    // Caller should notify user (e.g. "Saved to ${file.path}").
    // For convenience you can print the path:
    // ignore: avoid_print
    print('CSV saved to ${file.path}');
  } catch (e) {
    // ignore: avoid_print
    print('Failed to save CSV locally: $e');
    rethrow;
  }
}
