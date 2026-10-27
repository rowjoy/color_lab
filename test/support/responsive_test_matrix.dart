import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef ResponsiveTestCase = ({String name, Size size});

const foundationResponsiveCases = <ResponsiveTestCase>[
  (name: 'compact portrait', size: Size(320, 568)),
  (name: 'compact landscape', size: Size(568, 320)),
  (name: 'medium portrait', size: Size(800, 1280)),
  (name: 'large landscape', size: Size(1280, 800)),
];

void configureFoundationTestView(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  EdgeInsets safePadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  bool reducedMotion = false,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    left: safePadding.left,
    top: safePadding.top,
    right: safePadding.right,
    bottom: safePadding.bottom,
  );
  tester.view.viewPadding = FakeViewPadding(
    left: safePadding.left,
    top: safePadding.top,
    right: safePadding.right,
    bottom: safePadding.bottom,
  );
  tester.view.viewInsets = FakeViewPadding(
    left: viewInsets.left,
    top: viewInsets.top,
    right: viewInsets.right,
    bottom: viewInsets.bottom,
  );
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reducedMotion);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
}
