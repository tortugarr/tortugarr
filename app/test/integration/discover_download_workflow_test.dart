/// Runs the discover → download → refresh workflow suite in the Flutter Tester.
///
/// The suite itself lives at `integration_test/discover_download_workflow_test.dart`,
/// which is where the feature plan puts it. That directory is reserved by the
/// tool: `flutter test integration_test/<file>` refuses to run without a
/// connected device, because everything under it is assumed to need
/// `package:integration_test` and a real embedder
/// (`_shouldRunAsIntegrationTests` in `flutter_tools/lib/src/commands/test.dart`).
///
/// The suite needs neither — it drives widgets against mocked repositories, so
/// the desktop tester is the right place for it, and running it there keeps it
/// in the default `flutter test` sweep instead of leaving it to a device job
/// nobody runs. This file is the seam that allows both:
///
/// ```
/// flutter test test/integration/discover_download_workflow_test.dart
/// ```
library;

import '../../integration_test/discover_download_workflow_test.dart' as suite;

void main() => suite.main();
