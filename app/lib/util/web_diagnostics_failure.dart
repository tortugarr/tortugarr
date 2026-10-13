enum WebDiagnosticsFailureReason { cors, mixedContent }

String webDiagnosticsFailureReasonToQuery(WebDiagnosticsFailureReason reason) {
  switch (reason) {
    case WebDiagnosticsFailureReason.cors:
      return 'cors';
    case WebDiagnosticsFailureReason.mixedContent:
      return 'mixed-content';
  }
}

WebDiagnosticsFailureReason? webDiagnosticsFailureReasonFromQuery(
  String? value,
) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'cors':
      return WebDiagnosticsFailureReason.cors;
    case 'mixed-content':
      return WebDiagnosticsFailureReason.mixedContent;
    default:
      return null;
  }
}

WebDiagnosticsFailureReason? inferWebDiagnosticsFailureReason({
  required Uri pageUri,
  required String? targetUrl,
  String? errorType,
  int? statusCode,
  String? message,
}) {
  final targetUri = _parseTargetUri(targetUrl);
  if (targetUri == null) return null;

  final pageScheme = pageUri.scheme.toLowerCase();
  final targetScheme = targetUri.scheme.toLowerCase();

  if (pageScheme == 'https' && targetScheme == 'http') {
    return WebDiagnosticsFailureReason.mixedContent;
  }

  if (statusCode != null) {
    return null;
  }

  final normalizedType = (errorType ?? '').trim().toLowerCase();
  final normalizedMessage = (message ?? '').trim().toLowerCase();
  final looksLikeBrowserBlockedRequest =
      normalizedType == 'connectionerror' ||
      normalizedType == 'unknown' ||
      normalizedMessage.contains('xmlhttprequest error') ||
      normalizedMessage.contains('failed to fetch') ||
      normalizedMessage.contains('connection failed');

  if (!looksLikeBrowserBlockedRequest) {
    return null;
  }

  if (!_isCrossOrigin(pageUri, targetUri)) {
    return null;
  }

  return WebDiagnosticsFailureReason.cors;
}

Uri? _parseTargetUri(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }

  return uri;
}

bool _isCrossOrigin(Uri pageUri, Uri targetUri) {
  final pageScheme = pageUri.scheme.toLowerCase();
  final targetScheme = targetUri.scheme.toLowerCase();
  final pageHost = pageUri.host.toLowerCase();
  final targetHost = targetUri.host.toLowerCase();
  final pagePort = _effectivePort(pageUri);
  final targetPort = _effectivePort(targetUri);

  return pageScheme != targetScheme ||
      pageHost != targetHost ||
      pagePort != targetPort;
}

int _effectivePort(Uri uri) {
  if (uri.hasPort && uri.port > 0) {
    return uri.port;
  }

  switch (uri.scheme.toLowerCase()) {
    case 'https':
      return 443;
    case 'http':
      return 80;
    default:
      return 0;
  }
}
