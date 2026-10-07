import 'package:server_core/server_core.dart';

class SyncPlayState {
  bool enabled;
  String? groupId;
  String? groupName;
  List<String> participants;
  SyncPlayGroupState groupState;
  List<SyncPlayQueueItem> queue;
  String? currentPlaylistItemId;
  int currentItemIndex;
  SyncPlayRepeatMode repeatMode;
  SyncPlayShuffleMode shuffleMode;
  String? lastUpdateAt;

  SyncPlayState({
    this.enabled = false,
    this.groupId,
    this.groupName,
    this.participants = const [],
    this.groupState = SyncPlayGroupState.idle,
    this.queue = const [],
    this.currentPlaylistItemId,
    this.currentItemIndex = -1,
    this.repeatMode = SyncPlayRepeatMode.repeatNone,
    this.shuffleMode = SyncPlayShuffleMode.sorted,
    this.lastUpdateAt,
  });
}
