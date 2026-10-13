import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'screensaver_controller.dart';
import 'screensaver_view.dart';

class ScreensaverHost extends StatelessWidget {
  const ScreensaverHost({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GetIt.instance<ScreensaverController>();
    return ValueListenableBuilder<bool>(
      valueListenable: controller.visible,
      builder: (context, visible, _) {
        if (!visible) {
          return const SizedBox.shrink();
        }
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => controller.dismiss(),
          child: const ScreensaverView(),
        );
      },
    );
  }
}
