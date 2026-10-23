import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/vision_controller.dart';
import '../domain/vision_session.dart';
import 'vision_plate_view.dart';

const _caveat =
    'Generated patterns for exploration only. This is not a validated screening test or medical diagnosis and cannot rule out a condition.';
const _professional =
    'If you have concerns about your color vision, talk to an eye care professional.';

class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen> {
  final _scroll = ScrollController();
  final _answer = TextEditingController();
  String? _error;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _syncDraft(ref.read(visionSessionProvider).draft);
  }

  void _syncDraft(int? draft) {
    final text = draft?.toString() ?? '';
    if (_answer.text != text) {
      _answer.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/lab');
    }
  }

  void _respond(String plateId, int? answer, {required bool notSure}) {
    final current = ref.read(visionSessionProvider);
    if (current.stage != VisionStage.active ||
        current.currentPlate.id != plateId) {
      return;
    }
    if (!notSure && answer == null) {
      setState(() => _error = 'Enter one digit, or choose Not sure.');
      return;
    }
    final accepted = ref
        .read(visionSessionProvider.notifier)
        .respond(plateId: plateId, answer: answer);
    if (accepted) {
      _answer.clear();
      setState(() => _error = null);
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Future<void> _restart() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        animationStyle: AppMotion.sheetAnimation(context),
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Restart this activity?'),
          content: SizedBox(
            width: AppSpacing.huge * 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your responses and pending digit will be replaced with six new patterns.',
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  key: const ValueKey('confirm-vision-restart'),
                  label: 'Restart activity',
                  icon: Icons.refresh_rounded,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted && confirmed == true) {
        ref.read(visionSessionProvider.notifier).restart();
        FocusManager.instance.primaryFocus?.unfocus();
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(visionSessionProvider, (previous, next) {
      _syncDraft(next.draft);
      if (previous != null &&
          (previous.stage != next.stage ||
              previous.currentIndex != next.currentIndex ||
              !identical(previous.plates, next.plates))) {
        _error = null;
        if (_scroll.hasClients) _scroll.jumpTo(0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
        });
      }
    });
    final session = ref.watch(visionSessionProvider);
    final controller = ref.read(visionSessionProvider.notifier);
    // Both values belong to this displayed plate. Retained callbacks cannot
    // submit a later plate's draft after a response or replacement set.
    final plateId = session.currentPlate.id;
    final draft = session.draft;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision plates'),
        leading: IconCircleButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          onPressed: _back,
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('screen-Vision'),
          controller: _scroll,
          padding: AppSpacing.screenPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session.stage == VisionStage.introduction) ...[
                    const StudioHeading(
                      eyebrow: 'An original color study',
                      title: 'Look for a number.',
                      description:
                          'Explore six untimed, generated dot patterns. Enter one digit you see, or choose Not sure. You can review your responses after the sixth pattern.',
                    ),
                    const Text(
                      'Your responses and pending digit stay only for this app session. Screens and lighting can affect what you see.',
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const Text(_professional),
                    const SizedBox(height: AppSpacing.xxl),
                    PrimaryButton(
                      key: const ValueKey('vision-start'),
                      label: 'Start activity',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: controller.start,
                    ),
                  ] else if (session.stage == VisionStage.active) ...[
                    Text(
                      'Plate ${session.plateNumber} of 6',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Enter the number you see, or choose Not sure. There is no time limit.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    VisionPlateView(
                      key: const ValueKey('vision-plate'),
                      plate: session.currentPlate,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextField(
                      key: const ValueKey('vision-answer'),
                      controller: _answer,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Number you see',
                        counterText: '',
                        errorText: _error,
                        errorMaxLines: 3,
                      ),
                      onChanged: (value) {
                        final current = ref.read(visionSessionProvider);
                        if (current.stage == VisionStage.active &&
                            current.currentPlate.id == plateId) {
                          controller.setDraft(int.tryParse(value));
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      key: const ValueKey('vision-record'),
                      label: 'Record answer',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => _respond(plateId, draft, notSure: false),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      key: const ValueKey('vision-not-sure'),
                      label: 'Not sure',
                      onPressed: () => _respond(plateId, null, notSure: true),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SecondaryButton(
                      key: const ValueKey('vision-restart'),
                      label: 'Restart activity',
                      icon: Icons.refresh_rounded,
                      onPressed: _confirming ? null : _restart,
                    ),
                  ] else
                    _VisionResults(
                      session: session,
                      onTryAgain: controller.restart,
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    _caveat,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisionResults extends StatelessWidget {
  const _VisionResults({required this.session, required this.onTryAgain});
  final VisionSession session;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('vision-results'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Your responses', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.md),
      Text(
        '${session.matchedCount} of 6 pattern matches',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text('Not sure: ${session.notSureCount}'),
      const SizedBox(height: AppSpacing.xl),
      const Text(
        'This summary compares your recorded responses with the generated numbers. It does not assess your eye health or explain why a pattern looked a certain way.',
      ),
      const SizedBox(height: AppSpacing.xl),
      const Text(_professional),
      const SizedBox(height: AppSpacing.xxl),
      for (var i = 0; i < session.responses.length; i++) ...[
        StudioCard(
          key: ValueKey('vision-result-${i + 1}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Plate ${i + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Generated number'),
              Text(
                '${session.responses[i].plate.number}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Your response'),
              Text(
                session.responses[i].answer?.toString() ?? 'Not sure',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        key: const ValueKey('vision-try-again'),
        label: 'Try again',
        icon: Icons.refresh_rounded,
        onPressed: onTryAgain,
      ),
    ],
  );
}
