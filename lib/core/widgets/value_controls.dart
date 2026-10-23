import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';
import 'buttons.dart';

class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.valueLabel,
    this.valueFormatter,
  });
  final String label;
  final double value, min, max;
  final ValueChanged<double>? onChanged;
  final int? divisions;
  final String? valueLabel;
  final String Function(double)? valueFormatter;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(
            valueLabel ??
                valueFormatter?.call(value) ??
                value.toStringAsFixed(2),
            style: AppTypography.mono.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
      Semantics(
        label: label,
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
          semanticFormatterCallback: (v) =>
              valueFormatter?.call(v) ?? v.toStringAsFixed(2),
        ),
      ),
    ],
  );
}

class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.label,
    required this.value,
    this.copyable = true,
    this.onCopied,
  });
  final String label, value;
  final bool copyable;
  final VoidCallback? onCopied;
  @override
  Widget build(BuildContext context) {
    Future<void> copyValue() async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      HapticFeedback.selectionClick();
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('$label copied')));
      onCopied?.call();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: copyable ? copyValue : null,
        borderRadius: BorderRadius.circular(AppRadii.small),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.huge),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        value,
                        style: AppTypography.mono.copyWith(
                          color: context.appColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconCircleButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy $label',
                    onPressed: copyValue,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
