import '../../../l10n/l10n.dart';

extension LearningCopyResolver on AppLocalizations {
  String learningCopy(String key) => switch (key) {
    'learningStepPredictTitle' => learningStepPredictTitle,
    'learningStepManipulateTitle' => learningStepManipulateTitle,
    'learningStepObserveTitle' => learningStepObserveTitle,
    'learningStepExplainTitle' => learningStepExplainTitle,
    'learningStepApplyTitle' => learningStepApplyTitle,
    'learningStepCheckTitle' => learningStepCheckTitle,
    'learningNonVisualInstruction' => learningNonVisualInstruction,
    'learningGlossaryHsl' => learningGlossaryHsl,
    'learningGlossaryHsv' => learningGlossaryHsv,
    'learningGlossaryRgb' => learningGlossaryRgb,
    'learningGlossaryHex' => learningGlossaryHex,
    'learningGlossaryLab' => learningGlossaryLab,
    'learningGlossaryCmyk' => learningGlossaryCmyk,
    'learningGlossaryDeltaE' => learningGlossaryDeltaE,
    'learningGlossaryHue' => learningGlossaryHue,
    'learningGlossarySaturation' => learningGlossarySaturation,
    'learningGlossaryLightnessValue' => learningGlossaryLightnessValue,
    'learningGlossaryDigitalInterpolation' =>
      learningGlossaryDigitalInterpolation,
    'learningGlossaryHarmony' => learningGlossaryHarmony,
    'learningLessonCoordinatesTitle' => learningLessonCoordinatesTitle,
    'learningLessonCoordinatesSummary' => learningLessonCoordinatesSummary,
    'learningCoordinatesPredictInstruction' =>
      learningCoordinatesPredictInstruction,
    'learningCoordinatesManipulateInstruction' =>
      learningCoordinatesManipulateInstruction,
    'learningCoordinatesObserveInstruction' =>
      learningCoordinatesObserveInstruction,
    'learningCoordinatesExplainInstruction' =>
      learningCoordinatesExplainInstruction,
    'learningCoordinatesApplyInstruction' =>
      learningCoordinatesApplyInstruction,
    'learningCoordinatesCheckInstruction' =>
      learningCoordinatesCheckInstruction,
    'learningCoordinatesManipulateNonVisual' =>
      learningCoordinatesManipulateNonVisual,
    'learningCoordinatesQ1Prompt' => learningCoordinatesQ1Prompt,
    'learningCoordinatesQ1ALabel' => learningCoordinatesQ1ALabel,
    'learningCoordinatesQ1BLabel' => learningCoordinatesQ1BLabel,
    'learningCoordinatesQ1AExplanation' => learningCoordinatesQ1AExplanation,
    'learningCoordinatesQ1BExplanation' => learningCoordinatesQ1BExplanation,
    'learningCoordinatesQ2Prompt' => learningCoordinatesQ2Prompt,
    'learningCoordinatesQ2ALabel' => learningCoordinatesQ2ALabel,
    'learningCoordinatesQ2BLabel' => learningCoordinatesQ2BLabel,
    'learningCoordinatesQ2AExplanation' => learningCoordinatesQ2AExplanation,
    'learningCoordinatesQ2BExplanation' => learningCoordinatesQ2BExplanation,
    'learningLessonHueTitle' => learningLessonHueTitle,
    'learningLessonHueSummary' => learningLessonHueSummary,
    'learningHuePredictInstruction' => learningHuePredictInstruction,
    'learningHueManipulateInstruction' => learningHueManipulateInstruction,
    'learningHueObserveInstruction' => learningHueObserveInstruction,
    'learningHueExplainInstruction' => learningHueExplainInstruction,
    'learningHueApplyInstruction' => learningHueApplyInstruction,
    'learningHueCheckInstruction' => learningHueCheckInstruction,
    'learningHueManipulateNonVisual' => learningHueManipulateNonVisual,
    'learningHueQ1Prompt' => learningHueQ1Prompt,
    'learningHueQ1ALabel' => learningHueQ1ALabel,
    'learningHueQ1BLabel' => learningHueQ1BLabel,
    'learningHueQ1AExplanation' => learningHueQ1AExplanation,
    'learningHueQ1BExplanation' => learningHueQ1BExplanation,
    'learningHueQ2Prompt' => learningHueQ2Prompt,
    'learningHueQ2ALabel' => learningHueQ2ALabel,
    'learningHueQ2BLabel' => learningHueQ2BLabel,
    'learningHueQ2AExplanation' => learningHueQ2AExplanation,
    'learningHueQ2BExplanation' => learningHueQ2BExplanation,
    'learningLessonSaturationTitle' => learningLessonSaturationTitle,
    'learningLessonSaturationSummary' => learningLessonSaturationSummary,
    'learningSaturationPredictInstruction' =>
      learningSaturationPredictInstruction,
    'learningSaturationManipulateInstruction' =>
      learningSaturationManipulateInstruction,
    'learningSaturationObserveInstruction' =>
      learningSaturationObserveInstruction,
    'learningSaturationExplainInstruction' =>
      learningSaturationExplainInstruction,
    'learningSaturationApplyInstruction' => learningSaturationApplyInstruction,
    'learningSaturationCheckInstruction' => learningSaturationCheckInstruction,
    'learningSaturationManipulateNonVisual' =>
      learningSaturationManipulateNonVisual,
    'learningSaturationQ1Prompt' => learningSaturationQ1Prompt,
    'learningSaturationQ1ALabel' => learningSaturationQ1ALabel,
    'learningSaturationQ1BLabel' => learningSaturationQ1BLabel,
    'learningSaturationQ1AExplanation' => learningSaturationQ1AExplanation,
    'learningSaturationQ1BExplanation' => learningSaturationQ1BExplanation,
    'learningSaturationQ2Prompt' => learningSaturationQ2Prompt,
    'learningSaturationQ2ALabel' => learningSaturationQ2ALabel,
    'learningSaturationQ2BLabel' => learningSaturationQ2BLabel,
    'learningSaturationQ2AExplanation' => learningSaturationQ2AExplanation,
    'learningSaturationQ2BExplanation' => learningSaturationQ2BExplanation,
    'learningLessonLightnessValueTitle' => learningLessonLightnessValueTitle,
    'learningLessonLightnessValueSummary' =>
      learningLessonLightnessValueSummary,
    'learningLightnessValuePredictInstruction' =>
      learningLightnessValuePredictInstruction,
    'learningLightnessValueManipulateInstruction' =>
      learningLightnessValueManipulateInstruction,
    'learningLightnessValueObserveInstruction' =>
      learningLightnessValueObserveInstruction,
    'learningLightnessValueExplainInstruction' =>
      learningLightnessValueExplainInstruction,
    'learningLightnessValueApplyInstruction' =>
      learningLightnessValueApplyInstruction,
    'learningLightnessValueCheckInstruction' =>
      learningLightnessValueCheckInstruction,
    'learningLightnessValueManipulateNonVisual' =>
      learningLightnessValueManipulateNonVisual,
    'learningLightnessValueQ1Prompt' => learningLightnessValueQ1Prompt,
    'learningLightnessValueQ1ALabel' => learningLightnessValueQ1ALabel,
    'learningLightnessValueQ1BLabel' => learningLightnessValueQ1BLabel,
    'learningLightnessValueQ1AExplanation' =>
      learningLightnessValueQ1AExplanation,
    'learningLightnessValueQ1BExplanation' =>
      learningLightnessValueQ1BExplanation,
    'learningLightnessValueQ2Prompt' => learningLightnessValueQ2Prompt,
    'learningLightnessValueQ2ALabel' => learningLightnessValueQ2ALabel,
    'learningLightnessValueQ2BLabel' => learningLightnessValueQ2BLabel,
    'learningLightnessValueQ2AExplanation' =>
      learningLightnessValueQ2AExplanation,
    'learningLightnessValueQ2BExplanation' =>
      learningLightnessValueQ2BExplanation,
    'learningLessonDigitalMixingTitle' => learningLessonDigitalMixingTitle,
    'learningLessonDigitalMixingSummary' => learningLessonDigitalMixingSummary,
    'learningDigitalMixingPredictInstruction' =>
      learningDigitalMixingPredictInstruction,
    'learningDigitalMixingManipulateInstruction' =>
      learningDigitalMixingManipulateInstruction,
    'learningDigitalMixingObserveInstruction' =>
      learningDigitalMixingObserveInstruction,
    'learningDigitalMixingExplainInstruction' =>
      learningDigitalMixingExplainInstruction,
    'learningDigitalMixingApplyInstruction' =>
      learningDigitalMixingApplyInstruction,
    'learningDigitalMixingCheckInstruction' =>
      learningDigitalMixingCheckInstruction,
    'learningDigitalMixingManipulateNonVisual' =>
      learningDigitalMixingManipulateNonVisual,
    'learningDigitalMixingQ1Prompt' => learningDigitalMixingQ1Prompt,
    'learningDigitalMixingQ1ALabel' => learningDigitalMixingQ1ALabel,
    'learningDigitalMixingQ1BLabel' => learningDigitalMixingQ1BLabel,
    'learningDigitalMixingQ1AExplanation' =>
      learningDigitalMixingQ1AExplanation,
    'learningDigitalMixingQ1BExplanation' =>
      learningDigitalMixingQ1BExplanation,
    'learningDigitalMixingQ2Prompt' => learningDigitalMixingQ2Prompt,
    'learningDigitalMixingQ2ALabel' => learningDigitalMixingQ2ALabel,
    'learningDigitalMixingQ2BLabel' => learningDigitalMixingQ2BLabel,
    'learningDigitalMixingQ2AExplanation' =>
      learningDigitalMixingQ2AExplanation,
    'learningDigitalMixingQ2BExplanation' =>
      learningDigitalMixingQ2BExplanation,
    'learningLessonPaletteRelationshipsTitle' =>
      learningLessonPaletteRelationshipsTitle,
    'learningLessonPaletteRelationshipsSummary' =>
      learningLessonPaletteRelationshipsSummary,
    'learningPaletteRelationshipsPredictInstruction' =>
      learningPaletteRelationshipsPredictInstruction,
    'learningPaletteRelationshipsManipulateInstruction' =>
      learningPaletteRelationshipsManipulateInstruction,
    'learningPaletteRelationshipsObserveInstruction' =>
      learningPaletteRelationshipsObserveInstruction,
    'learningPaletteRelationshipsExplainInstruction' =>
      learningPaletteRelationshipsExplainInstruction,
    'learningPaletteRelationshipsApplyInstruction' =>
      learningPaletteRelationshipsApplyInstruction,
    'learningPaletteRelationshipsCheckInstruction' =>
      learningPaletteRelationshipsCheckInstruction,
    'learningPaletteRelationshipsManipulateNonVisual' =>
      learningPaletteRelationshipsManipulateNonVisual,
    'learningPaletteRelationshipsQ1Prompt' =>
      learningPaletteRelationshipsQ1Prompt,
    'learningPaletteRelationshipsQ1ALabel' =>
      learningPaletteRelationshipsQ1ALabel,
    'learningPaletteRelationshipsQ1BLabel' =>
      learningPaletteRelationshipsQ1BLabel,
    'learningPaletteRelationshipsQ1AExplanation' =>
      learningPaletteRelationshipsQ1AExplanation,
    'learningPaletteRelationshipsQ1BExplanation' =>
      learningPaletteRelationshipsQ1BExplanation,
    'learningPaletteRelationshipsQ2Prompt' =>
      learningPaletteRelationshipsQ2Prompt,
    'learningPaletteRelationshipsQ2ALabel' =>
      learningPaletteRelationshipsQ2ALabel,
    'learningPaletteRelationshipsQ2BLabel' =>
      learningPaletteRelationshipsQ2BLabel,
    'learningPaletteRelationshipsQ2AExplanation' =>
      learningPaletteRelationshipsQ2AExplanation,
    'learningPaletteRelationshipsQ2BExplanation' =>
      learningPaletteRelationshipsQ2BExplanation,
    _ => throw ArgumentError.value(key, 'key', 'Unknown learning copy key'),
  };
}
