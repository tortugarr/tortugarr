#!/bin/bash
# What must still be Tortugarr after a Moonfin merge. Each line is a check; exit 1 when one fails.
# Step 4 of docs/MOONFIN-UPSTREAM.md (run it after resolving the merge, before the tests).
set -uo pipefail
cd "$(dirname "$0")/.."
FAILED=0
check() { if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; FAILED=$((FAILED + 1)); fi; }

check "own Android id (io.github.tortugarr), not Moonfin's"   "grep -E 'baseAppId\\s*=.*tortugarr' android/app/build.gradle.kts"
check "public build flag kTortugarrPublic"                    "grep -q 'kTortugarrPublic' lib/util/build_flavor.dart"
check "public build skips Firebase"                            "grep -q 'Public build (build-android-tv-public.sh): no server keys, no Firebase' android/app/build.gradle.kts"
check "public build script"                                    "test -x build-android-tv-public.sh"
check "Tortugarr plugin client"                                "test -f lib/data/services/tortugarr/tortugarr_plugin_client.dart"
check "Download Now flow"                                      "test -f lib/ui/widgets/download_now/plugin_download_flow.dart"
check "Tortugarr intro videos"                                 "test -f assets/intro/tortugarr_intro_1080p.mp4 && test -f assets/intro/tortugarr_intro_short_1080p.mp4"
check "intro plays only after its first frame"                 "grep -q 'waitUntilFirstFrameRendered' lib/ui/screens/auth/startup_screen.dart"
check "Tortugarr settings in the side panel"                   "grep -q 'tgNotifyTitle' lib/ui/screens/settings/settings_side_panel.dart && grep -q '_TortugarrAdminScreen' lib/ui/screens/settings/settings_side_panel.dart"
check "Top lists home section"                                 "grep -q 'tortugarrTopLists' lib/preference/preference_constants.dart"
check "Server health card on the admin dashboard"              "grep -q 'TortugarrHealthCard' lib/ui/screens/admin/admin_dashboard_screen.dart"
en=$(grep -c '"tg[A-Z]' lib/l10n/app_en.arb); nb=$(grep -c '"tg[A-Z]' lib/l10n/app_nb.arb)
check "every Tortugarr string also in Norwegian ($nb of $en)" "[ $nb -ge $en ]"
# On a merge commit: Moonfin has no server/, so the merge must leave it exactly as Tortugarr had it.
check "server/ (installer + plugin) untouched by the merge"     "! git rev-parse -q --verify HEAD^2 || git diff --quiet HEAD^1 HEAD -- server"

[ $FAILED -eq 0 ] && echo "all Tortugarr invariants hold" || { echo "$FAILED invariant(s) broken"; exit 1; }
