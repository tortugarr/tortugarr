import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/navigation_layout.dart';

void main() {
  final home = Object(), seerr = Object(), details = Object();
  void homeMenu() {}
  void homeAvatar() {}
  void seerrMenu() {}
  void seerrAvatar() {}
  void detailsMenu() {}
  void detailsAvatar() {}

  setUp(() {
    for (final o in [home, seerr, details]) {
      NavigationLayout.releaseChromeFocus(o);
    }
    NavigationLayout.claimChromeFocus(home, homeMenu, homeAvatar);
    NavigationLayout.claimChromeFocus(seerr, seerrMenu, seerrAvatar);
    NavigationLayout.claimChromeFocus(details, detailsMenu, detailsAvatar);
  });

  test('the newest menu owns the bridge', () {
    expect(NavigationLayout.focusNavbarNotifier.value, detailsMenu);
  });

  test('pages torn down out of order still hand the bridge back to Home (2026-11-12)', () {
    // A delete that goes Home removes Seerr before the details page.
    NavigationLayout.releaseChromeFocus(seerr);
    expect(NavigationLayout.focusNavbarNotifier.value, detailsMenu);
    NavigationLayout.releaseChromeFocus(details);
    expect(NavigationLayout.focusNavbarNotifier.value, homeMenu);
    expect(NavigationLayout.focusNavbarAvatarNotifier.value, homeAvatar);
  });

  test('in order works too', () {
    NavigationLayout.releaseChromeFocus(details);
    expect(NavigationLayout.focusNavbarNotifier.value, seerrMenu);
    NavigationLayout.releaseChromeFocus(seerr);
    expect(NavigationLayout.focusNavbarNotifier.value, homeMenu);
  });

  test('a route on top again claims the bridge back', () {
    NavigationLayout.claimChromeFocus(home, homeMenu, homeAvatar);
    expect(NavigationLayout.focusNavbarNotifier.value, homeMenu);
    NavigationLayout.releaseChromeFocus(details);
    expect(NavigationLayout.focusNavbarNotifier.value, homeMenu);
  });
}
