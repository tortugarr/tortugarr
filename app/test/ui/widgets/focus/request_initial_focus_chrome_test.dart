import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/focus/nav_chrome_focus.dart';
import 'package:moonfin/ui/widgets/focus/request_initial_focus.dart';

/// A sidebar-like chrome scope with one focusable button, registered the way
/// LeftSidebar registers its rail.
class _Chrome extends StatefulWidget {
  final FocusNode button;
  const _Chrome({required this.button});

  @override
  State<_Chrome> createState() => _ChromeState();
}

class _ChromeState extends State<_Chrome> {
  final _scope = FocusScopeNode(debugLabel: 'chrome');

  @override
  void initState() {
    super.initState();
    NavChromeFocus.register(_scope);
  }

  @override
  void dispose() {
    NavChromeFocus.unregister(_scope);
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    node: _scope,
    child: Focus(focusNode: widget.button, child: const SizedBox(width: 10, height: 10)),
  );
}

void main() {
  testWidgets('initial focus skips sidebar chrome when content is focusable', (tester) async {
    final chromeButton = FocusNode(debugLabel: 'profile');
    final content = FocusNode(debugLabel: 'content');
    await tester.pumpWidget(MaterialApp(
      home: RequestInitialFocus(
        child: Column(children: [
          _Chrome(button: chromeButton),
          Focus(focusNode: content, child: const SizedBox(width: 10, height: 10)),
        ]),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(content.hasFocus, isTrue);
    expect(chromeButton.hasFocus, isFalse);
  });

  testWidgets('a late target wins over chrome while the page was loading', (tester) async {
    final chromeButton = FocusNode(debugLabel: 'profile');
    final target = FocusNode(debugLabel: 'overview');
    var loaded = false;
    late StateSetter setOuter;

    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        setOuter = setState;
        return RequestInitialFocus(
          targetNode: loaded ? target : null,
          child: Column(children: [
            _Chrome(button: chromeButton),
            if (loaded) Focus(focusNode: target, child: const SizedBox(width: 10, height: 10)),
          ]),
        );
      }),
    ));
    // Loading: nothing in content yet. Even after retries run out and focus
    // falls back to chrome, the arriving target must take over.
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    setOuter(() => loaded = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(target.hasFocus, isTrue);
    expect(chromeButton.hasFocus, isFalse);
  });

  testWidgets('chrome is still used when a screen has nothing else', (tester) async {
    final chromeButton = FocusNode(debugLabel: 'profile');
    await tester.pumpWidget(MaterialApp(
      home: RequestInitialFocus(child: _Chrome(button: chromeButton)),
    ));
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(chromeButton.hasFocus, isTrue);
  });

  testWidgets('isOnCurrentRoute is false for a route underneath', (tester) async {
    late BuildContext underneath;
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: Builder(builder: (context) {
        underneath = context;
        return const SizedBox();
      }),
    ));
    expect(NavChromeFocus.isOnCurrentRoute(underneath), isTrue);
    navKey.currentState!.push(MaterialPageRoute(builder: (_) => const SizedBox()));
    await tester.pumpAndSettle();
    expect(NavChromeFocus.isOnCurrentRoute(underneath), isFalse);
  });
}
