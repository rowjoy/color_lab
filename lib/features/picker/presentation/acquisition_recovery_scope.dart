import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../settings/application/app_preferences_providers.dart';
import '../application/photo_acquisition_controller.dart';

/// Only the normal shell starts recovery, after preferences have committed.
class AcquisitionRecoveryScope extends ConsumerWidget {
  const AcquisitionRecoveryScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed =
        ref.watch(appPreferencesProvider).asData?.value.onboardingCompleted ==
        true;
    if (completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final path = GoRouter.of(context).state.uri.path;
        if (path == '/onboarding' || path == '/welcome' || path == '/startup') {
          return;
        }
        if (ref
                .read(appPreferencesProvider)
                .asData
                ?.value
                .onboardingCompleted ==
            true) {
          unawaited(
            ref.read(photoAcquisitionProvider.notifier).ensureRecovered(),
          );
        }
      });
    }
    return child;
  }
}
