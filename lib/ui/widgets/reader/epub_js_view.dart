import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../data/services/book_document_service.dart';
import '../../../util/webview_environment.dart';

@immutable
class EpubJsLocation {
  final String cfi;
  final int sectionIndex;

  /// The share of the book before [cfi] on the 1024 character location index,
  /// the same number jellyfin-web saves. Null until the index is built.
  final double? fraction;
  final bool atEnd;
  final int? minutesLeftInSection;

  const EpubJsLocation({
    required this.cfi,
    required this.sectionIndex,
    this.fraction,
    this.atEnd = false,
    this.minutesLeftInSection,
  });

  static EpubJsLocation? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final cfi = raw['cfi'];
    final index = raw['index'];
    final percentage = raw['percentage'];
    final minutes = raw['minutesLeft'];
    if (cfi is! String ||
        !cfi.startsWith('epubcfi(') ||
        index is! int ||
        index < 0) {
      return null;
    }
    return EpubJsLocation(
      cfi: cfi,
      sectionIndex: index,
      fraction: percentage is num && percentage.isFinite
          ? percentage.toDouble().clamp(0.0, 1.0)
          : null,
      atEnd: raw['atEnd'] == true,
      minutesLeftInSection: minutes is int && minutes > 0 ? minutes : null,
    );
  }
}

class EpubJsController {
  InAppWebViewController? _web;

  Future<void> _run(String call) async {
    await _web?.evaluateJavascript(
      source: 'window.__moonfin && __moonfin.$call',
    );
  }

  Future<void> next() => _run('next()');

  Future<void> prev() => _run('prev()');

  Future<void> displaySection(int index) => _run('display($index)');

  Future<String> selectedText() async {
    final text = await _web?.evaluateJavascript(
      source: 'window.__moonfin ? __moonfin.selectedText() : ""',
    );
    return text is String ? text : '';
  }
}

void registerEpubJsLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'epub.js',
    ], await rootBundle.loadString('assets/reader/epubjs-LICENSE.txt'));
    yield LicenseEntryWithLineBreaks([
      'JSZip',
    ], await rootBundle.loadString('assets/reader/jszip-LICENSE.txt'));
  });
}

/// An EPUB rendered by epub.js 0.3.93, the version jellyfin-web 12 ships, so
/// both clients agree on what a saved percentage points at.
class EpubJsView extends StatefulWidget {
  final Uint8List bytes;
  final EpubJsController controller;
  final BookDocumentStyle style;
  final bool scrolled;
  final String? startCfi;
  final double? startFraction;
  final int startSection;
  final ContextMenu? contextMenu;
  final void Function(int sectionCount, bool rtl) onReady;
  final ValueChanged<EpubJsLocation> onRelocated;
  final VoidCallback onToggleChrome;
  final VoidCallback onError;

  const EpubJsView({
    super.key,
    required this.bytes,
    required this.controller,
    required this.style,
    required this.scrolled,
    required this.onReady,
    required this.onRelocated,
    required this.onToggleChrome,
    required this.onError,
    this.startCfi,
    this.startFraction,
    this.startSection = 0,
    this.contextMenu,
  });

  @override
  State<EpubJsView> createState() => _EpubJsViewState();
}

class _EpubJsViewState extends State<EpubJsView> {
  // A made up origin that never resolves, so the page has a real origin for
  // its blob URLs and same origin chapter frames.
  static const _baseUrl = 'https://moonfin-reader.invalid/';
  static const _chunkBytes = 512 * 1024;

  static Future<List<String>>? _host;

  String? _html;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    (_host ??= _loadHost()).then(
      (files) {
        if (mounted) setState(() => _html = _page(files));
      },
      onError: (Object _) {
        _host = null;
        if (mounted) widget.onError();
      },
    );
  }

  @override
  void didUpdateWidget(covariant EpubJsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final style = _styleJson(widget.style);
    if (!mapEquals(_styleJson(oldWidget.style), style)) {
      widget.controller._run('style(${jsonEncode(style)})');
    }
    if (oldWidget.scrolled != widget.scrolled) {
      widget.controller._run('flow(${widget.scrolled})');
    }
  }

  @override
  void dispose() {
    widget.controller._web = null;
    super.dispose();
  }

  static Future<List<String>> _loadHost() => Future.wait([
    for (final name in const [
      'epub_host.html',
      'jszip.min.js',
      'epub.legacy.min.js',
      'epub_host.js',
    ])
      rootBundle.loadString('assets/reader/$name'),
  ]);

  /// The reader page with a nonce made for this view, so no book can know the
  /// one that would let its own scripts run.
  static String _page(List<String> files) {
    final random = math.Random.secure();
    final nonce = base64Url.encode([
      for (var i = 0; i < 18; i++) random.nextInt(256),
    ]);
    final scripts = files
        .skip(1)
        .map((s) => '<script nonce="$nonce">$s</script>')
        .join('\n');
    return files.first
        .replaceFirst('{{nonce}}', nonce)
        .replaceFirst('<!--scripts-->', scripts);
  }

  static Map<String, Object?> _styleJson(BookDocumentStyle s) => {
    'font': s.fontFamilyCss,
    'size': s.fontSizePx,
    'lineHeight': s.lineHeight,
    'margin': s.marginPx,
    'maxWidth': s.maxWidthPx,
    'justify': s.justify,
    'bold': s.bold,
    'bg': s.backgroundCss ?? '#fafafa',
    'fg': s.foregroundCss ?? '#222222',
    'link': s.linkCss ?? '#1b4f9c',
  };

  Object? _onChunk(List<dynamic> args) {
    final offset = args.isNotEmpty ? args.first : null;
    final bytes = widget.bytes;
    if (offset is! int || offset < 0 || offset >= bytes.length) return '';
    final end = math.min(offset + _chunkBytes, bytes.length);
    return base64Encode(Uint8List.sublistView(bytes, offset, end));
  }

  Object? _onMessage(List<dynamic> args) {
    final msg = args.isNotEmpty ? args.first : null;
    if (!mounted || msg is! Map) return null;
    switch (msg['type']) {
      case 'ready':
        final sections = msg['sections'];
        setState(() => _ready = true);
        widget.onReady(
          sections is int && sections > 0 ? sections : 1,
          msg['rtl'] == true,
        );
      case 'relocated':
        final location = EpubJsLocation.tryParse(msg);
        if (location != null) widget.onRelocated(location);
      case 'toggle':
        widget.onToggleChrome();
      case 'error':
        widget.onError();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final html = _html;
    if (html == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final webView = InAppWebView(
      webViewEnvironment: gWebViewEnvironment,
      initialData: InAppWebViewInitialData(
        data: html,
        baseUrl: WebUri(_baseUrl),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        supportZoom: false,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: true,
        allowFileAccess: false,
        allowContentAccess: false,
      ),
      contextMenu: widget.contextMenu,
      onWebViewCreated: (controller) {
        widget.controller._web = controller;
        controller.addJavaScriptHandler(
          handlerName: 'moonfinEpubChunk',
          callback: _onChunk,
        );
        controller.addJavaScriptHandler(
          handlerName: 'moonfinEpub',
          callback: _onMessage,
        );
      },
      onLoadStop: (controller, url) async {
        final open = {
          'size': widget.bytes.length,
          'cfi': widget.startCfi,
          'fraction': widget.startFraction ?? 0,
          'section': widget.startSection,
          'scrolled': widget.scrolled,
          'style': _styleJson(widget.style),
        };
        await controller.evaluateJavascript(
          source: '__moonfin.open(${jsonEncode(open)})',
        );
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url;
        // WebView2 can't take a base URL, so on Windows the page itself loads
        // as about:blank. Chapter frames are sandboxed and can't navigate it.
        final allowed =
            url?.toString() == _baseUrl ||
            const {'about', 'blob', 'data'}.contains(url?.scheme);
        return allowed
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? true) widget.onError();
      },
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        webView,
        if (!_ready) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
