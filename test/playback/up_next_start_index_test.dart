import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/playback/audio_player_screen.dart';
import 'package:playback_core/playback_core.dart';

List<String> _visibleUpNext(QueueService queue) {
  final start = upNextStartIndex(queue.items.length, queue.currentIndex);
  return queue.items.skip(start).cast<String>().toList();
}

QueueService _queueOf(List<String> songs) =>
    QueueService()..setQueue(songs, startIndex: 0);

void main() {
  test('the panel starts on the playing track and drops what has played', () {
    final queue = _queueOf(['a', 'b', 'c', 'd']);
    expect(_visibleUpNext(queue), ['a', 'b', 'c', 'd']);

    queue.next();
    expect(_visibleUpNext(queue), ['b', 'c', 'd']);

    queue.next();
    expect(_visibleUpNext(queue), ['c', 'd']);
  });

  test('stepping back to an earlier track lists it again', () {
    final queue = _queueOf(['a', 'b', 'c']);
    queue.next();
    queue.next();
    expect(_visibleUpNext(queue), ['c']);

    queue.previous();
    expect(_visibleUpNext(queue), ['b', 'c']);

    queue.jumpTo(0);
    expect(_visibleUpNext(queue), ['a', 'b', 'c']);
  });

  test('wrapping with repeat all shows the whole queue again', () {
    final queue = _queueOf(['a', 'b'])..toggleRepeat();
    expect(queue.repeatMode, RepeatMode.repeatAll);
    queue.next();
    expect(_visibleUpNext(queue), ['b']);

    queue.next();
    expect(queue.currentIndex, 0);
    expect(_visibleUpNext(queue), ['a', 'b']);
  });

  test('an empty queue and an unset index stay at the top', () {
    expect(upNextStartIndex(0, -1), 0);
    expect(upNextStartIndex(0, 3), 0);
    expect(upNextStartIndex(4, -1), 0);
  });

  test('an index past the end still leaves one row to show', () {
    expect(upNextStartIndex(3, 9), 2);
  });
}
