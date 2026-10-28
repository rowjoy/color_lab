import 'package:flutter/widgets.dart';

/// Owns one UI export request. Revocation is permanent, so a background/resume
/// round trip cannot revive work that has not reached the native handoff.
final class IllustratedRoomExportRequest with WidgetsBindingObserver {
  IllustratedRoomExportRequest({required bool Function() ownsRequest})
    : _ownsRequest = ownsRequest,
      _binding = WidgetsBinding.instance {
    _revoked =
        _binding.lifecycleState != null &&
        _binding.lifecycleState != AppLifecycleState.resumed;
    _binding.addObserver(this);
  }

  final bool Function() _ownsRequest;
  final WidgetsBinding _binding;
  bool _revoked = false;

  bool get isCurrent {
    if (!_revoked && !_ownsRequest()) _revoked = true;
    return !_revoked;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _revoked = true;
  }

  void dispose() {
    _revoked = true;
    _binding.removeObserver(this);
  }
}
