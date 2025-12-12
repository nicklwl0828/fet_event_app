// lib/util/download_csv_web.dart
import 'dart:convert';
import 'dart:html' as html;

/// Triggers a browser download of [content] saved as [filename].
/// On web only.
Future<void> downloadCsvFile(String filename, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
