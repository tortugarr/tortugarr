import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/system_ui.dart';

class _Immersive extends StatefulWidget {
  const _Immersive({required this.immersive});

  final bool immersive;

  @override
  State<_Immersive> createState() => _ImmersiveState();
}

class _ImmersiveState extends State<_Immersive> with ImmersiveSystemUi {
  @override
  void initState() {
    super.initState();
    setImmersive(widget.immersive);
  }

  @override
  void didUpdateWidget(_Immersive oldWidget) {
    super.didUpdateWidget(oldWidget);
    setImmersive(widget.immersive);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  late List<SystemUiMode> applied;

  setUp(() {
    SystemUi.reset();
    applied = [];
    SystemUi.apply = (mode) async => applied.add(mode);
  });

  tearDown(SystemUi.reset);

  test('the bars are hidden while any claim is held', () {
    final a = Object();
    final b = Object();
    SystemUi.hold(a);
    SystemUi.hold(b);
    SystemUi.release(a);
    expect(SystemUi.immersive, isTrue);
    expect(applied.last, SystemUiMode.immersiveSticky);

    SystemUi.release(b);
    expect(SystemUi.immersive, isFalse);
    expect(applied.last, SystemUiMode.edgeToEdge);
  });

  test('holding again re-applies, releasing again does nothing', () {
    final owner = Object();
    SystemUi.hold(owner);
    SystemUi.hold(owner);
    expect(applied, hasLength(2));

    SystemUi.release(owner);
    SystemUi.release(owner);
    expect(applied, hasLength(3));
    expect(SystemUi.immersive, isFalse);
  });

  testWidgets('removing a screen releases its claim without it asking', (
    tester,
  ) async {
    await tester.pumpWidget(const _Immersive(immersive: true));
    expect(SystemUi.immersive, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(SystemUi.immersive, isFalse);
    expect(applied.last, SystemUiMode.edgeToEdge);
  });

  testWidgets('a screen can turn its claim on and off while it lives', (
    tester,
  ) async {
    await tester.pumpWidget(const _Immersive(immersive: false));
    expect(SystemUi.immersive, isFalse);

    await tester.pumpWidget(const _Immersive(immersive: true));
    expect(SystemUi.immersive, isTrue);

    await tester.pumpWidget(const _Immersive(immersive: false));
    expect(SystemUi.immersive, isFalse);
  });

  testWidgets('resuming applies the current mode again', (tester) async {
    SystemUi.install();
    applied.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(applied, [SystemUiMode.edgeToEdge]);

    SystemUi.hold(Object());
    applied.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(applied, [SystemUiMode.immersiveSticky]);
  });

  // The claim model only holds if this stays the only caller.
  test('nothing outside SystemUi sets the mode directly', () {
    final callers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('setEnabledSystemUIMode'))
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toList();
    expect(callers, ['lib/util/system_ui.dart']);
  });
}
