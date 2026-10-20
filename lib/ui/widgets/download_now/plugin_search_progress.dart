import 'dart:async';

import 'package:flutter/material.dart';

import '../seerr/seerr_tv_controls.dart';
import '../track_selector_dialog.dart' show showStyledPlayerDialog;
import 'package:moonfin/util/app_l10n.dart';

/// The outcome of [showPluginSearchProgress]: the search's value, its error,
/// or neither when the user cancelled.
class PluginSearchOutcome<T> {
  final T? value;
  final Object? error;
  final bool cancelled;
  const PluginSearchOutcome.value(T this.value)
      : error = null,
        cancelled = false;
  const PluginSearchOutcome.error(Object this.error)
      : value = null,
        cancelled = false;
  const PluginSearchOutcome.cancelled()
      : value = null,
        error = null,
        cancelled = true;
}

/// A server search through Radarr/Sonarr can take minutes when an indexer is
/// slow. While it runs this dialog shows how long it has been going and lets
/// the user cancel. Being modal it also keeps a second search from starting
/// and finishing out of order. [start] gets a function that tells the search
/// whether the user cancelled, so its polling can stop.
Future<PluginSearchOutcome<T>> showPluginSearchProgress<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(bool Function() isCancelled) start,
}) async {
  var cancelled = false;
  final future = start(() => cancelled);
  final outcome = await showStyledPlayerDialog<PluginSearchOutcome<T>>(
    context,
    title: title,
    barrierDismissible: false,
    builder: (_) => _SearchProgressBody<T>(future: future),
  );
  if (outcome == null || outcome.cancelled) {
    cancelled = true;
    return const PluginSearchOutcome.cancelled();
  }
  return outcome;
}

class _SearchProgressBody<T> extends StatefulWidget {
  final Future<T> future;
  const _SearchProgressBody({required this.future});

  @override
  State<_SearchProgressBody<T>> createState() => _SearchProgressBodyState<T>();
}

class _SearchProgressBodyState<T> extends State<_SearchProgressBody<T>> {
  final _watch = Stopwatch()..start();
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    widget.future.then(
      (value) => _close(PluginSearchOutcome<T>.value(value)),
      onError: (Object e) => _close(PluginSearchOutcome<T>.error(e)),
    );
  }

  void _close(PluginSearchOutcome<T> outcome) {
    if (mounted) Navigator.of(context).pop(outcome);
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _watch.elapsed.inSeconds;
    final elapsed = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Searching releases… $elapsed',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The server asks every indexer. A slow one (for example behind '
            'Cloudflare) can make this take a few minutes.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          SeerrDialogButton(
            label: appL10n().tgCancel,
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(const PluginSearchOutcome.cancelled()),
          ),
        ],
      ),
    );
  }
}
