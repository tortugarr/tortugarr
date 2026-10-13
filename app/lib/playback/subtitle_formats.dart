/// Maps a server-reported subtitle codec to a canonical token used for BOTH the
/// offline subtitle file extension and the codec passed to the player backend.
///
/// Keeping a single mapping shared by the download and offline-playback paths
/// guarantees the file written at download time and the file looked up at
/// playback time agree. The token also feeds the media3 backend, which needs it
/// to pick a MIME type for sideloaded subtitles (mpv autodetects, but a correct
/// extension is still preferable).
String canonicalSubtitleCodec(String? codec) {
  switch ((codec ?? '').trim().toLowerCase()) {
    case 'ass':
    case 'ssa':
      return 'ass';
    case 'vtt':
    case 'webvtt':
      return 'vtt';
    case 'ttml':
      return 'ttml';
    case 'subrip':
    case 'srt':
    case 'mov_text':
    default:
      return 'srt';
  }
}
