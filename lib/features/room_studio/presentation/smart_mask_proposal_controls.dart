import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/smart_mask_proposal_controller.dart';
import '../domain/smart_mask_proposal.dart';

/// Intentionally contributes no controls, semantics, claims or photo access.
class SmartMaskProposalControls extends ConsumerWidget {
  const SmartMaskProposalControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(smartMaskAvailabilityProvider)) {
        SmartMaskAvailability.disabledByEvidence => const SizedBox.shrink(),
      };
}
