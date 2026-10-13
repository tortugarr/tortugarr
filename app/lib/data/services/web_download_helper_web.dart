import 'package:web/web.dart' as web;

void triggerBrowserDownload(String url, String fileName) {
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..rel = 'noopener'
    ..target = '_blank';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
