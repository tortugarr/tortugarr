/// Web has no libretro cores, so there is no buildbot build to point at.
({String dir, String suffix})? currentBuildbotTarget() => null;

/// Web never downloads cores, so the tag only needs to be a stable placeholder.
String currentAbiTag() => 'web';
