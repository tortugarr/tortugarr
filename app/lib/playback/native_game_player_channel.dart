import 'native_game_player.dart';

/// The native libretro session on Android and desktop, where cores are
/// downloaded on demand and loaded through the runner's native game channel.
class NativeGamePlayerChannel extends MethodChannelGamePlayer {
  NativeGamePlayerChannel()
      : super('moonfin/native_game_control', 'moonfin/native_game_events');
}
