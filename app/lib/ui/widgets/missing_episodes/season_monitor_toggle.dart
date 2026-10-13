import 'package:flutter/material.dart';

import '../focus/focusable_wrapper.dart';
import 'package:moonfin/util/app_l10n.dart';

/// Asks whether Sonarr should fetch a season's missing episodes now when the
/// user turns its monitoring on. True = fetch now, false = only follow new
/// episodes, null = cancelled.
Future<bool?> confirmSeasonSearch(BuildContext context, int season) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(appL10n().tgMonitorSeasonTitle(season)),
      content: Text(appL10n().tgMonitorSeasonQuestion(season)),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(appL10n().tgNo),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(appL10n().tgYes),
        ),
      ],
    ),
  );
}

/// "Overvåkes" / "Ikke overvåket" with a switch for one season. Off by
/// default: the app never turns monitoring on by itself. Turning it on asks
/// whether to fetch the season's missing episodes now. A failed change shows
/// [onChanged]'s message and flips the switch back.
class SeasonMonitorToggle extends StatefulWidget {
  final int season;
  final bool monitored;

  /// Applies the change; returns null on success or the message to show.
  final Future<String?> Function(bool on, bool searchNow) onChanged;

  /// Small variant under a season card.
  final bool compact;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  const SeasonMonitorToggle({
    super.key,
    required this.season,
    required this.monitored,
    required this.onChanged,
    this.compact = false,
    this.focusNode,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  @override
  State<SeasonMonitorToggle> createState() => _SeasonMonitorToggleState();
}

class _SeasonMonitorToggleState extends State<SeasonMonitorToggle> {
  late bool _value = widget.monitored;
  bool _busy = false;

  @override
  void didUpdateWidget(SeasonMonitorToggle old) {
    super.didUpdateWidget(old);
    if (!_busy && old.monitored != widget.monitored) _value = widget.monitored;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final target = !_value;
    var searchNow = false;
    if (target) {
      final answer = await confirmSeasonSearch(context, widget.season);
      if (answer == null || !mounted) return;
      searchNow = answer;
    }
    setState(() {
      _value = target;
      _busy = true;
    });
    final error = await widget.onChanged(target, searchNow);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error != null) _value = !target;
    });
    if (error != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else if (target && searchNow) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(appL10n().tgSonarrSearchingSeason(widget.season))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _value ? appL10n().tgMonitored : appL10n().tgNotMonitored;
    final small = widget.compact;
    return FocusableWrapper(
      focusNode: widget.focusNode,
      onSelect: _toggle,
      onNavigateUp: widget.onNavigateUp,
      onNavigateDown: widget.onNavigateDown,
      autoScroll: true,
      borderRadius: 16,
      disableScale: true,
      semanticLabel: appL10n().tgSeasonStateLabel(widget.season, label),
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: small ? 4 : 8, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _value ? Icons.visibility : Icons.visibility_off_outlined,
                size: small ? 14 : 18,
                color: _value ? Colors.lightGreenAccent : Colors.white54,
              ),
              SizedBox(width: small ? 4 : 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _value ? Colors.white : Colors.white60,
                    fontSize: small ? 11 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: small ? 2 : 6),
              ExcludeFocus(
                child: Transform.scale(
                  scale: small ? 0.6 : 0.8,
                  child: _busy
                      ? const SizedBox(
                          width: 36,
                          height: 24,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : Switch(
                          value: _value,
                          onChanged: (_) => _toggle(),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
