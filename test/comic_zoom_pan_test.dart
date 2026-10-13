import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The comic reader nests an InteractiveViewer inside a PageView. These cover
/// that pairing rather than the reader screen, which needs an archive open
/// before any of it runs.
Widget _pagedComic({
  required bool zoomed,
  required TransformationController controller,
}) => MaterialApp(
  home: Scaffold(
    body: PageView.builder(
      physics: zoomed ? const NeverScrollableScrollPhysics() : null,
      itemCount: 3,
      itemBuilder: (context, index) => GestureDetector(
        onTapUp: (_) {},
        onDoubleTap: () {},
        child: InteractiveViewer(
          transformationController: controller,
          minScale: 1,
          maxScale: 5,
          child: SizedBox.expand(
            child: ColoredBox(
              color: Colors.blue,
              child: Center(child: Text('page $index')),
            ),
          ),
        ),
      ),
    ),
  ),
);

TransformationController _zoomedTo(double scale) => TransformationController()
  ..value = (Matrix4.identity()..scaleByDouble(scale, scale, scale, 1));

void main() {
  testWidgets('a drag on a zoomed page moves the page and leaves it in place',
      (tester) async {
    final controller = _zoomedTo(2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_pagedComic(zoomed: true, controller: controller));
    await tester.drag(find.byType(PageView), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(
      controller.value.getTranslation().x,
      lessThan(0),
      reason: 'the page moved under the finger',
    );
    expect(find.text('page 0'), findsOneWidget, reason: 'still the same page');
  });

  testWidgets('a page view that keeps its own scrolling swallows the pan',
      (tester) async {
    final controller = _zoomedTo(2);
    addTearDown(controller.dispose);

    // The state this fixes: the PageView takes the drag, so the zoomed page
    // never moves.
    await tester.pumpWidget(_pagedComic(zoomed: false, controller: controller));
    await tester.drag(find.byType(PageView), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(controller.value.getTranslation().x, 0);
  });
}
