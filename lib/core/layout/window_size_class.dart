enum WindowSizeClass { compact, medium, expanded, large }

WindowSizeClass windowSizeClassFor(double logicalWidth) {
  if (!logicalWidth.isFinite || logicalWidth < 0) {
    throw ArgumentError.value(
      logicalWidth,
      'logicalWidth',
      'Must be finite and non-negative',
    );
  }
  if (logicalWidth < 600) return WindowSizeClass.compact;
  if (logicalWidth < 840) return WindowSizeClass.medium;
  if (logicalWidth < 1200) return WindowSizeClass.expanded;
  return WindowSizeClass.large;
}

extension WindowSizeClassCapabilities on WindowSizeClass {
  bool get usesNavigationRail => this != WindowSizeClass.compact;

  bool get hasPersistentInspector =>
      this == WindowSizeClass.expanded || this == WindowSizeClass.large;
}
