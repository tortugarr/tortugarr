import 'package:flutter/widgets.dart';

/// Invokes [ActivateIntent] on [context] once and reports whether it ran.
///
/// Do not use the return value of [Actions.maybeInvoke] for this: it is the
/// action's result, and many actions (InkWell's among them) return nothing.
/// A null result then looked like "no action", the key event was marked
/// ignored, and the app's default Shortcuts fired ActivateIntent a second
/// time: one OK press on a request card pushed its detail page twice.
KeyEventResult activateFocused(BuildContext context) {
  const intent = ActivateIntent();
  final action = Actions.maybeFind<ActivateIntent>(context, intent: intent);
  if (action == null || !action.isEnabled(intent)) {
    return KeyEventResult.ignored;
  }
  Actions.invoke(context, intent);
  return KeyEventResult.handled;
}
