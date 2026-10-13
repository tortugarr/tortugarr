import 'package:flutter/material.dart';

IconData seekBackIcon(int ms) {
  return switch (ms ~/ 1000) {
    5 => Icons.replay_5_rounded,
    10 => Icons.replay_10_rounded,
    30 => Icons.replay_30_rounded,
    _ => Icons.fast_rewind_rounded,
  };
}

IconData seekForwardIcon(int ms) {
  return switch (ms ~/ 1000) {
    5 => Icons.forward_5_rounded,
    10 => Icons.forward_10_rounded,
    30 => Icons.forward_30_rounded,
    _ => Icons.fast_forward_rounded,
  };
}
