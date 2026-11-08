import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/admin/providers/admin_status_providers.dart';
import 'package:server_core/server_core.dart';

/// 2026-11-08: warnings stop counting once the dashboard was seen; errors and
/// critical alerts only once the alert list was opened.
void main() {
  ActivityLogEntry e(String severity, DateTime date) =>
      ActivityLogEntry(id: '$severity$date', name: 'x', type: 't', date: date, severity: severity);

  test('warnings and errors have their own "seen" time', () {
    final now = DateTime(2026, 11, 8, 12);
    final items = [
      e('Warning', now.subtract(const Duration(hours: 3))),
      e('Warning', now.subtract(const Duration(minutes: 5))),
      e('Error', now.subtract(const Duration(hours: 3))),
      e('Critical', now.subtract(const Duration(days: 2))),
      e('Information', now),
    ];
    final r = countUnseenAlerts(items,
        warningsSince: now.subtract(const Duration(hours: 1)),
        errorsSince: now.subtract(const Duration(days: 7)));
    expect(r.warnings, 1, reason: 'only the warning after the last look');
    expect(r.errors, 2, reason: 'errors stay until the list is opened');
  });
}
