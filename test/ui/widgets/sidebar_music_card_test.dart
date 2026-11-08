import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:playback_core/playback_core.dart';
import 'package:server_core/server_core.dart';

import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:moonfin/ui/widgets/left_sidebar.dart';

class _Factory extends Fake implements MediaServerClientFactory {
  @override
  MediaServerClient? getClientIfExists(String id) => null;
}

void main() {
  late PlaybackManager manager;

  setUp(() {
    manager = PlaybackManager();
    GetIt.instance.registerSingleton<PlaybackManager>(manager);
    GetIt.instance.registerSingleton<MediaServerClientFactory>(_Factory());
    manager.queueService.setQueue([
      AggregatedItem(
        id: 'track',
        serverId: 'server',
        rawData: const {'Name': 'Song', 'Type': 'Audio'},
      ),
    ]);
  });

  tearDown(() async {
    manager.dispose();
    await GetIt.instance.reset();
  });

  Color? rowFill(WidgetTester tester) {
    final row = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('Song'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return (row.decoration! as BoxDecoration).color;
  }

  // The rail opens as it takes focus, so the art row is the D-pad's only way
  // from the card to the full player.
  testWidgets('the open card puts its art row between the rail and buttons', (
    tester,
  ) async {
    final railItem = FocusNode(debugLabel: 'rail item');
    addTearDown(railItem.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // As wide as the open rail.
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 260,
              child: Column(
                children: [
                  Focus(
                    focusNode: railItem,
                    child: const SizedBox(height: 40, width: 260),
                  ),
                  const SidebarMusicCard(isExpanded: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    railItem.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(rowFill(tester), isNot(Colors.transparent));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(rowFill(tester), Colors.transparent, reason: 'on a button now');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(rowFill(tester), isNot(Colors.transparent));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(railItem.hasFocus, isTrue);
  });
}
