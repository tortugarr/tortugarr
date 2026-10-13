import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/core_input_descriptors.dart';

void main() {
  _spyHunterCases();
  group('CoreInputDescriptors.fromChannelPayload', () {
    test('looks up a description by exact port and id', () {
      final descriptors = CoreInputDescriptors.fromChannelPayload([
        {'port': 0, 'device': 1, 'index': 0, 'id': 0, 'description': 'Fire'},
        {'port': 1, 'device': 1, 'index': 0, 'id': 0, 'description': 'P2 Fire'},
      ]);

      expect(descriptors.describe(0, 0), 'Fire');
      expect(descriptors.describe(1, 0), 'P2 Fire');
    });

    test('falls back to port 0 when the exact port has no descriptor', () {
      final descriptors = CoreInputDescriptors.fromChannelPayload([
        {'port': 0, 'device': 1, 'index': 0, 'id': 0, 'description': 'Fire'},
      ]);

      // Many cores only emit descriptors for port 0 and intend them for
      // every port.
      expect(descriptors.describe(2, 0), 'Fire');
      expect(descriptors.describe(3, 0), 'Fire');
    });

    test('returns null when neither the exact port nor port 0 has it', () {
      final descriptors = CoreInputDescriptors.fromChannelPayload([
        {'port': 0, 'device': 1, 'index': 0, 'id': 0, 'description': 'Fire'},
      ]);

      expect(descriptors.describe(1, 9), isNull);
    });

    test('an empty descriptor payload never falls back to a wrong port', () {
      expect(CoreInputDescriptors.empty.describe(0, 0), isNull);
      expect(
        CoreInputDescriptors.fromChannelPayload([]).describe(0, 0),
        isNull,
      );
      expect(
        CoreInputDescriptors.fromChannelPayload(null).describe(0, 0),
        isNull,
      );
    });

    test('an empty or whitespace-only description yields no suffix', () {
      final descriptors = CoreInputDescriptors.fromChannelPayload([
        {'port': 0, 'device': 1, 'index': 0, 'id': 0, 'description': ''},
        {'port': 0, 'device': 1, 'index': 0, 'id': 1, 'description': '   '},
      ]);

      expect(descriptors.describe(0, 0), isNull);
      expect(descriptors.describe(0, 1), isNull);
    });

    test('malformed entries are dropped without throwing', () {
      final descriptors = CoreInputDescriptors.fromChannelPayload([
        'not a map',
        {'port': -1, 'device': 1, 'index': 0, 'id': 0, 'description': 'Bad'},
        {'device': 1, 'index': 0, 'description': 'Missing id and port'},
        {'port': 0, 'device': 1, 'index': 0, 'id': 5, 'description': 'Good'},
      ]);

      expect(descriptors.describe(0, 5), 'Good');
      expect(descriptors.describe(-1, 0), isNull);
    });

    test('lookup keys on the raw libretro id, ignoring index', () {
      // `index` is not part of the key; `device` is (see the Spy Hunter group
      // below).
      final descriptors = CoreInputDescriptors.fromChannelPayload([
        {'port': 0, 'device': 1, 'index': 3, 'id': 8, 'description': 'Jump'},
      ]);

      expect(descriptors.describe(0, 8), 'Jump');
    });

    test('a later duplicate (port, device, id) entry wins', () {
      final descriptors = CoreInputDescriptors.fromChannelPayload([
        {'port': 0, 'device': 1, 'index': 0, 'id': 0, 'description': 'Old'},
        {'port': 0, 'device': 1, 'index': 0, 'id': 0, 'description': 'New'},
      ]);

      expect(descriptors.describe(0, 0), 'New');
    });
  });
}

// Regression cases taken verbatim from an FBNeo Spy Hunter run on a Shield.
void _spyHunterCases() {
  group('FBNeo Spy Hunter descriptors', () {
    final descriptors = CoreInputDescriptors.fromChannelPayload(const [
      {'port': 0, 'device': 1, 'index': 0, 'id': 2, 'description': 'Coin'},
      {'port': 0, 'device': 1, 'index': 0, 'id': 0, 'description': 'Missiles'},
      {'port': 0, 'device': 1, 'index': 0, 'id': 8, 'description': 'Oil Slick'},
      {'port': 0, 'device': 5, 'index': 0, 'id': 0, 'description': 'Wheel'},
    ]);

    test('a subtype entry does not overwrite the joypad entry', () {
      // Both are (port 0, id 0). Keyed only by (port, id), 'Wheel' won and the
      // button was labelled for a layout the user is not using.
      expect(descriptors.describe(0, 0), 'Missiles');
      expect(descriptors.describe(0, 0, device: 5), 'Wheel');
    });

    test('an unrelated subtype falls back to the joypad description', () {
      expect(descriptors.describe(0, 8, device: 517), 'Oil Slick');
    });

    test('a port with no entries of its own falls back to port 0', () {
      expect(descriptors.describe(2, 2), 'Coin');
    });

    test('an unknown id is still undescribed', () {
      expect(descriptors.describe(0, 15), isNull);
    });
  });
}
