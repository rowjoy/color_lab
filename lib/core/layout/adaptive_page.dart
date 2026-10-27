import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'window_size_class.dart';

final class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.child,
    this.inspector,
    this.maxContentWidth = AppLayout.defaultMaxContentWidth,
    this.padding,
    this.scrollable = true,
  }) : assert(maxContentWidth > 0);

  final Widget child;
  final Widget? inspector;
  final double maxContentWidth;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sizeClass = windowSizeClassFor(constraints.maxWidth);
      final pagePadding =
          padding ??
          EdgeInsetsDirectional.fromSTEB(
            switch (sizeClass) {
              WindowSizeClass.compact => AppLayout.compactPagePadding,
              WindowSizeClass.medium => AppLayout.regularPagePadding,
              WindowSizeClass.expanded ||
              WindowSizeClass.large => AppLayout.widePagePadding,
            },
            AppSpacing.xl,
            switch (sizeClass) {
              WindowSizeClass.compact => AppLayout.compactPagePadding,
              WindowSizeClass.medium => AppLayout.regularPagePadding,
              WindowSizeClass.expanded ||
              WindowSizeClass.large => AppLayout.widePagePadding,
            },
            AppSpacing.xxl,
          );
      final layout = _contentFor(sizeClass);
      final content = Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          key: const ValueKey('adaptive-page-content'),
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: SizedBox(width: double.infinity, child: layout),
        ),
      );
      final padded = Padding(padding: pagePadding, child: content);
      final page = scrollable
          ? SingleChildScrollView(
              key: const ValueKey('adaptive-page-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: padded,
            )
          : padded;

      return SafeArea(
        maintainBottomViewPadding: true,
        child: AnimatedPadding(
          key: const ValueKey('adaptive-page-keyboard-inset'),
          duration: AppMotion.duration(context, AppMotion.micro),
          curve: AppMotion.enter,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(width: double.infinity, child: page),
        ),
      );
    },
  );

  Widget _contentFor(WindowSizeClass sizeClass) {
    final side = inspector;
    if (side == null) return child;
    if (!sizeClass.hasPersistentInspector) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          const SizedBox(height: AppLayout.contentGap),
          side,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        const SizedBox(width: AppLayout.contentGap),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.inspectorWidth),
          child: SizedBox(width: double.infinity, child: side),
        ),
      ],
    );
  }
}
