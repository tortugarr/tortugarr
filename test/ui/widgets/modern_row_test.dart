import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/modern_row.dart';

void main() {
  group('ModernCardExpansion', () {
    test('a focused card grows right away without the dwell', () {
      final expansion = ModernCardExpansion();
      expansion.settle('a', delayExpansion: false);

      expect(
        expansion.isExpanded('a', isFocused: true, isTouch: false, delayExpansion: false),
        isTrue,
      );
      expect(
        expansion.isExpanded('b', isFocused: false, isTouch: false, delayExpansion: false),
        isFalse,
      );
      expansion.dispose();
    });

    test('with the dwell a focused card waits before it grows', () {
      fakeAsync((async) {
        final expansion = ModernCardExpansion();
        bool grown() => expansion.isExpanded(
              'a',
              isFocused: true,
              isTouch: false,
              delayExpansion: true,
            );

        expansion.settle('a', delayExpansion: true);
        expect(grown(), isFalse);

        async.elapse(const Duration(milliseconds: 70));
        expect(grown(), isTrue);
        expansion.dispose();
      });
    });

    test('a card passed during the dwell never grows', () {
      fakeAsync((async) {
        final expansion = ModernCardExpansion();
        expansion.settle('a', delayExpansion: true);
        async.elapse(const Duration(milliseconds: 30));
        expansion.settle('b', delayExpansion: true);
        async.elapse(const Duration(milliseconds: 70));

        expect(expansion.settledKey.value, 'b');
        expansion.dispose();
      });
    });

    test('a hovered card grows without focus', () {
      final expansion = ModernCardExpansion();
      expansion.hoveredKey.value = 'a';

      expect(
        expansion.isExpanded('a', isFocused: false, isTouch: false, delayExpansion: true),
        isTrue,
      );
      expansion.dispose();
    });

    test('touch grows a card on the first tap and opens it on the second', () {
      final expansion = ModernCardExpansion();
      bool grown() => expansion.isExpanded(
            'a',
            isFocused: false,
            isTouch: true,
            delayExpansion: false,
          );

      expect(expansion.tapToOpen('a'), isFalse);
      expect(grown(), isTrue);
      expect(expansion.tapToOpen('a'), isTrue);
      expect(grown(), isFalse);
      expansion.dispose();
    });
  });
}
