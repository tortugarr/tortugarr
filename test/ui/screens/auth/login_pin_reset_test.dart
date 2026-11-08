import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/ui/screens/auth/login_screen.dart';
import 'package:moonfin/util/pin_code_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PinCodeUtil pin;
  late int prompts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    pin = PinCodeUtil(store, 'user');
    await pin.setPin('1234');
    prompts = 0;
  });

  Future<bool> Function(VoidCallback) answer({bool pinCorrect = false}) =>
      (onForgotPin) async {
        prompts++;
        if (!pinCorrect) onForgotPin();
        return pinCorrect;
      };

  test('a password sign in from Forgot PIN clears the PIN unasked', () async {
    final passed = await passesPinCheckAfterSignIn(
      pinUtil: pin,
      forgotPin: true,
      canResetPin: true,
      askForPin: answer(),
    );

    expect(passed, isTrue);
    expect(prompts, 0);
    expect(pin.isPinEnabled, isFalse);
  });

  test('Forgot PIN after a password sign in clears the PIN', () async {
    final passed = await passesPinCheckAfterSignIn(
      pinUtil: pin,
      forgotPin: false,
      canResetPin: true,
      askForPin: answer(),
    );

    expect(passed, isTrue);
    expect(prompts, 1);
    expect(pin.isPinEnabled, isFalse);
  });

  test('a sign in without a password still needs the PIN', () async {
    final passed = await passesPinCheckAfterSignIn(
      pinUtil: pin,
      forgotPin: true,
      canResetPin: false,
      askForPin: answer(),
    );

    expect(passed, isFalse);
    expect(prompts, 1);
    expect(pin.isPinEnabled, isTrue);
  });

  test('the right PIN passes and keeps it', () async {
    final passed = await passesPinCheckAfterSignIn(
      pinUtil: pin,
      forgotPin: false,
      canResetPin: true,
      askForPin: answer(pinCorrect: true),
    );

    expect(passed, isTrue);
    expect(pin.isPinEnabled, isTrue);
  });

  test('a PIN the reset could not clear still holds the user out', () async {
    final passed = await passesPinCheckAfterSignIn(
      pinUtil: pin,
      forgotPin: true,
      canResetPin: true,
      askForPin: answer(),
      resetPin: () async => false,
    );

    expect(passed, isFalse);
    expect(pin.isPinEnabled, isTrue);
  });

  test('a PIN the reset cleared lets the user in', () async {
    final passed = await passesPinCheckAfterSignIn(
      pinUtil: pin,
      forgotPin: true,
      canResetPin: true,
      askForPin: answer(),
      resetPin: () async => true,
    );

    expect(passed, isTrue);
  });
}
