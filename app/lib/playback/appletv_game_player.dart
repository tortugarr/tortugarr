import 'native_game_player.dart';

/// The native libretro session on tvOS, where cores are bundled in the Runner
/// and loaded through the AppleTvGameChannel.
class AppleTvGamePlayer extends MethodChannelGamePlayer {
  AppleTvGamePlayer()
      : super('moonfin/appletv_game_control', 'moonfin/appletv_game_events');
}
