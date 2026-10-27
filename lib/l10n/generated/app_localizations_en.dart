// GENERATED CODE - DO NOT MODIFY BY HAND.

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get roomUsePhoto => 'Use my photo';

  @override
  String get roomTryIllustrated => 'Try an Illustrated Room';

  @override
  String get roomSetupTitle => 'Set up Room photo analysis';

  @override
  String get roomSetupIntro =>
      'Download the optional AI models to find surfaces in your room photo.';

  @override
  String get roomSetupPrivacy =>
      'Your photo stays on this device. Downloading models uses the network but never uploads your photos.';

  @override
  String get roomSetupOffline =>
      'Once verified models are saved, room analysis works offline.';

  @override
  String get roomSetupDownload => 'Download';

  @override
  String get roomSetupLater => 'Later';

  @override
  String get roomSetupContinue => 'Continue';

  @override
  String get roomSetupRetry => 'Retry';

  @override
  String get roomSetupCancelled =>
      'Download paused. Your saved progress is kept; Retry resumes when possible.';

  @override
  String get roomSetupFailure =>
      'Could not download or verify the models. Check your connection, then retry. Your photo is safe.';

  @override
  String get roomSetupStorageFull =>
      'There is not enough storage space. Free some space on this device, then retry. Your photo is safe.';

  @override
  String get roomSetupReady =>
      'Verified models are saved on this device. Continue to choose your photo.';

  @override
  String get roomModelsChecking => 'Checking saved AI models…';

  @override
  String get roomModelsDownloading => 'Downloading AI models…';

  @override
  String get roomModelsVerifying => 'Verifying AI models…';

  @override
  String get roomModelsSurfaces => 'Room surfaces';

  @override
  String get roomModelsDepth => 'Foreground depth protection';

  @override
  String get roomModelsPrivacyOffline =>
      'Your photo stays on this device. Once models are saved, AI works offline.';

  @override
  String get roomModelsEditorOffline =>
      'Room analysis uses the models saved on this device and works offline.';

  @override
  String roomSetupSize(String bytes, String mib) {
    return '$bytes bytes · $mib MiB';
  }

  @override
  String roomModelsProgress(String received, String total, String percent) {
    return '$received / $total MiB · $percent%';
  }

  @override
  String get modelsRemovalError =>
      'Couldn\'t remove all Room models. Some downloaded model files may already have been removed. Refresh storage, then retry removal.';

  @override
  String get modelsRefresh => 'Refresh storage';

  @override
  String get dataPreferences =>
      'Appearance, accessibility, and welcome preferences';

  @override
  String get cancel => 'Cancel';

  @override
  String get settingsAccessibility => 'Accessibility';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsHighContrast => 'High contrast';

  @override
  String get settingsColorLabels => 'Always show color labels';

  @override
  String get settingsPrivacyEntry => 'Privacy';

  @override
  String get settingsDataEntry => 'Manage local data';

  @override
  String get settingsModelsEntry => 'Model storage';

  @override
  String get settingsLicensesEntry => 'Licenses';

  @override
  String get privacyBody =>
      'Photos are processed on this device. Camera and photo access are optional and requested only when you choose those tools. Room photo analysis needs an optional model download; downloading models uses the network but does not upload your photos.';

  @override
  String get privacyLibraries =>
      'Saved colors, palettes, illustrated rooms, and game profiles stay on this device. Game profiles share the same color libraries. Switching or deleting a profile does not delete those libraries.';

  @override
  String get privacyControls =>
      'You control which local data to delete. Exported images and photo acquisition metadata are excluded from these controls. Models can be downloaded again when you choose Room photo analysis.';

  @override
  String get dataIntro =>
      'Select the data to review. Nothing is selected by default. Exported files and photo acquisition metadata are never included.';

  @override
  String get dataSavedColors => 'Saved colors';

  @override
  String get dataSavedPalettes => 'Saved palettes';

  @override
  String get dataIllustratedRooms => 'Illustrated room designs';

  @override
  String get dataGames => 'All game profiles and legacy progress';

  @override
  String get dataModels => 'Downloaded Room models';

  @override
  String get dataRoomProjects => 'Room photo projects';

  @override
  String get dataColoringProjects => 'Coloring projects';

  @override
  String get dataLearningProgress => 'Learning progress';

  @override
  String get dataUnavailable => 'Not available yet';

  @override
  String get dataPreview => 'Review selected data';

  @override
  String get dataReviewTitle => 'Review deletion';

  @override
  String get dataContinue => 'Continue to confirmation';

  @override
  String get dataConfirmTitle => 'Delete selected data?';

  @override
  String get dataConfirmBody =>
      'This cannot be undone. Only the reviewed categories will be deleted. Deleting all game data removes every local player and their progress; you can create a new player afterward.';

  @override
  String get dataDelete => 'Delete reviewed data';

  @override
  String get dataError =>
      'Unable to complete this operation. Your selection is retained. Review the data again before retrying. A storage error during deletion may leave some selected data removed.';

  @override
  String get dataSuccess => 'Selected data deleted.';

  @override
  String get modelsIntro =>
      'Room photo models are optional. Opening this screen does not download them. Removing models cancels any active download. Only model files and partial downloads are removed.';

  @override
  String get modelsRemove => 'Remove downloaded models';

  @override
  String get modelsConfirm => 'Remove Room models?';

  @override
  String get modelsEmpty => 'No downloaded models.';

  @override
  String get modelsError => 'Model storage is unavailable. Try again.';

  @override
  String get modelsRemoved => 'Room models removed.';

  @override
  String dataPreviewSummary(int records, int bytes) {
    return '$records records · approximately $bytes bytes';
  }

  @override
  String dataRoomProjectRevisionSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count room project revisions',
      one: '1 room project revision',
    );
    return '$_temp0';
  }

  @override
  String modelsSummary(int files, int bytes) {
    return '$files model files · $bytes bytes';
  }

  @override
  String get appName => 'TintAtlas';

  @override
  String get storeTitle => 'TintAtlas: Room Visualizer';

  @override
  String get roomStudioReady => 'Room Studio is ready';

  @override
  String get setupCouldNotFinish => 'Setup could not finish';

  @override
  String get downloadingAiModels => 'Downloading AI models…';

  @override
  String get verifyingAiModels => 'Verifying AI models…';

  @override
  String get checkingSavedAiModels => 'Checking saved AI models…';

  @override
  String get roomStudioSetup => 'Room Studio setup';

  @override
  String progressPercent(int percent) {
    return '$percent%';
  }

  @override
  String downloadProgressMib(String received, String total) {
    return '$received / $total MiB';
  }

  @override
  String get setupFailureHelp =>
      'Check your internet connection and available storage, then retry. Verified files are kept.';

  @override
  String get setupDownloadHelp =>
      'First setup downloads about 65.2 MiB. Saved models are checked automatically and work offline.';

  @override
  String get roomPhotosStayOnDevice => 'Your room photos stay on this device.';

  @override
  String get retrySetup => 'Retry setup';

  @override
  String get captureDestination => 'Capture';

  @override
  String get homeDestination => 'Home';

  @override
  String get roomsDestination => 'Rooms';

  @override
  String get learnDestination => 'Learn';

  @override
  String get paletteDestination => 'Palette';

  @override
  String get labDestination => 'Lab';

  @override
  String get roomDestination => 'Room';

  @override
  String get gamesDestination => 'Games';

  @override
  String get gamesCreatePlayerTitle => 'Create your player';

  @override
  String get gamesCreatePlayerBody =>
      'Choose a local name before playing. Your levels, coins, scores, and badges stay with this player on this device.';

  @override
  String get gamesCreatePlayerAction => 'Create Player';

  @override
  String gamesPlayNamedGame(String game) {
    return 'Play $game';
  }

  @override
  String gamesContinueNamedGame(String game) {
    return 'Continue $game';
  }

  @override
  String get gamesPlayGame => 'Play game';

  @override
  String get gamesContinueGame => 'Continue game';

  @override
  String get gamesStartingGame => 'Starting…';

  @override
  String gameReplayLevel(int level) {
    return 'Replay level $level';
  }

  @override
  String gamePlayCurrentLevel(int level) {
    return 'Play current level $level';
  }

  @override
  String gamePlayLevel(int level) {
    return 'Play Level $level';
  }

  @override
  String get gameBadgeEarned => 'Badge earned';

  @override
  String destinationTab(String destination) {
    return '$destination tab';
  }

  @override
  String get appearanceSettings => 'Appearance settings';

  @override
  String get homeEyebrow => 'ROOM-FIRST COLOR';

  @override
  String get homeTitle => 'See your space in a new color.';

  @override
  String get homeDescription =>
      'Try an illustrated room instantly, then explore color learning and games at your own pace.';

  @override
  String get homeSampleTitle => 'Start with a sample room';

  @override
  String get homeSampleBody =>
      'No photo, permission, or AI model download is needed.';

  @override
  String get homeTrySampleRoom => 'Try a living room';

  @override
  String get homeContinueTitle => 'Continue';

  @override
  String get homeContinueEmpty =>
      'Nothing to continue yet. Your next room, lesson, or game will appear here.';

  @override
  String get homeNothingToContinue => 'Nothing to continue yet';

  @override
  String get homeRoomsTitle => 'Rooms';

  @override
  String get homeRoomsBody =>
      'Visualize your own photo or recolor an illustrated room.';

  @override
  String get homeLearnTitle => 'Learn Color';

  @override
  String get homeLearnBody =>
      'Study color through guided tools and practical experiments.';

  @override
  String get homeGamesTitle => 'Color Games';

  @override
  String get homeGamesBody =>
      'Practice, solve, and relax with optional color-focused play.';

  @override
  String get homeMyWorkTitle => 'My Work';

  @override
  String get homeMyWorkBody =>
      'Find your saved colors, palettes, and illustrated designs.';

  @override
  String get learnEyebrow => 'COLOR LEARNING';

  @override
  String get learnTitle => 'Learn color by trying it.';

  @override
  String get learnDescription =>
      'Use real tools to explore perception, relationships, mixing, and practical color choices.';

  @override
  String get learnGuidedTitle => 'Learn with color';

  @override
  String get learnExperimentTitle => 'Experiment';

  @override
  String get learnOpenVision => 'Explore vision plates';

  @override
  String get learnOpenMatching => 'Practice color matching';

  @override
  String get learnOpenCapture => 'Capture a color';

  @override
  String get learnOpenPalette => 'Open saved colors';

  @override
  String get learnOpenLab => 'Open Color Lab';

  @override
  String get learnOpenMixer => 'Mix colors';

  @override
  String get learnOpenFormula => 'Build a color formula';

  @override
  String get learnOpenHarmonies => 'Explore color harmonies';

  @override
  String get learnOpenMyWork => 'Review My Work';

  @override
  String get myWorkEyebrow => 'SAVED ON THIS DEVICE';

  @override
  String get myWorkTitle => 'My Work';

  @override
  String get myWorkDescription =>
      'Your shared color library stays on this installation and is separate from game profiles.';

  @override
  String get myWorkColorsTitle => 'Saved colors';

  @override
  String get myWorkPalettesTitle => 'Saved palettes';

  @override
  String get myWorkRoomDesignsTitle => 'Illustrated room designs';

  @override
  String get myWorkColorsLoading => 'Loading saved colors';

  @override
  String get myWorkPalettesLoading => 'Loading saved palettes';

  @override
  String get myWorkRoomDesignsLoading => 'Loading room designs';

  @override
  String get myWorkLoadingBody =>
      'Your other libraries remain available while this section loads.';

  @override
  String get myWorkColorsError => 'Saved colors couldn\'t be loaded';

  @override
  String get myWorkPalettesError => 'Saved palettes couldn\'t be loaded';

  @override
  String get myWorkRoomDesignsError => 'Room designs couldn\'t be loaded';

  @override
  String get myWorkErrorBody =>
      'This section can be retried without changing your other work.';

  @override
  String get myWorkColorsEmpty => 'No saved colors yet';

  @override
  String get myWorkColorsEmptyBody =>
      'Capture, enter, or explore a color to keep it here.';

  @override
  String get myWorkPalettesEmpty => 'No saved palettes yet';

  @override
  String get myWorkPalettesEmptyBody =>
      'Save a harmony when you find a combination you like.';

  @override
  String get myWorkRoomDesignsEmpty => 'No illustrated designs yet';

  @override
  String get myWorkRoomDesignsEmptyBody =>
      'Recolor an illustrated room and save the design to keep it here.';

  @override
  String get myWorkExploreColors => 'Explore colors';

  @override
  String get myWorkCreatePalette => 'Create a palette';

  @override
  String get myWorkTryRoom => 'Try an illustrated room';

  @override
  String get myWorkUnavailableRoom => 'Room template temporarily unavailable';

  @override
  String get routeUnavailableTitle => 'That page isn\'t available';

  @override
  String get routeUnavailableBody =>
      'Return Home and choose another TintAtlas tool.';

  @override
  String get returnHome => 'Return Home';

  @override
  String get skip => 'Skip';

  @override
  String onboardingStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get back => 'Back';

  @override
  String get tryAgain => 'Try again';

  @override
  String get done => 'Done';

  @override
  String get getStarted => 'Get started';

  @override
  String get next => 'Next';

  @override
  String get onboardingCuriousEyeEyebrow => 'A CURIOUS EYE';

  @override
  String get onboardingCuriousEyeTitle => 'Find your next shade.';

  @override
  String get onboardingCuriousEyeBody =>
      'Explore colors from a camera moment or favorite photo. Try wall colors in Rooms, including illustrated rooms you can use offline.';

  @override
  String get onboardingCuriousEyeNote =>
      'Explore a shade. Discover its name and color codes.';

  @override
  String get onboardingPersonalEyebrow => 'MAKE IT PERSONAL';

  @override
  String get onboardingPersonalTitle => 'A little library of you.';

  @override
  String get onboardingPersonalBody =>
      'Save shades and palettes in My Work. Explore color in Learn and practice with Games. Your libraries are shared across local game profiles.';

  @override
  String get onboardingPersonalNote => 'Your saved colors stay on this device.';

  @override
  String get onboardingControlEyebrow => 'ON YOUR TERMS';

  @override
  String get onboardingControlTitle => 'Your curiosity. Your control.';

  @override
  String get onboardingControlBody =>
      'Photos are processed on this device. Camera and photo permissions are optional. Room photo analysis offers an optional model download when you choose it.';

  @override
  String get onboardingControlNote =>
      'Skip anytime. Replay this tour from Settings. No permission is needed to take this tour.';

  @override
  String get tourFinishError =>
      'We couldn’t finish the tour. Please try again.';

  @override
  String get preferencesLoadErrorTitle => 'We couldn\'t load your preferences';

  @override
  String get preferencesLoadErrorBody =>
      'Your saved colors haven\'t been changed. Please try again.';

  @override
  String get loadingPreferences => 'Loading your preferences…';

  @override
  String get settingsSaveError => 'Couldn\'t save your appearance. Try again.';

  @override
  String get settingsAppearanceTitle => 'Make yourself at home';

  @override
  String get settingsAppearanceSubtitle => 'Choose your canvas.';

  @override
  String get closeSettings => 'Close settings';

  @override
  String get themeFollowSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get savingAppearance => 'Saving appearance…';

  @override
  String get appearanceSavedOnDevice => 'Your choice is saved on this device.';

  @override
  String get settingsOrientationTitle => 'A little orientation';

  @override
  String get settingsOrientationSubtitle =>
      'A fresh look at the basics, whenever you like.';

  @override
  String get replayWelcomeTour => 'Replay welcome tour';

  @override
  String get settingsPrivacyTitle => 'Your colors stay yours';

  @override
  String get settingsPrivacySubtitle =>
      'Photos, saved colors and preferences stay on your device. No account or cloud upload is needed.';

  @override
  String get roomProjectDefaultName => 'My room';

  @override
  String get roomProjectDefaultVariant => 'Original colors';

  @override
  String get roomProjectSaving => 'Saving project…';

  @override
  String get roomProjectSaved => 'Project saved';

  @override
  String get roomProjectSaveFailed =>
      'Project not saved. Your edits are still here. Retry to save them.';

  @override
  String get roomProjectSaveConflict =>
      'Project changed elsewhere. Your edits are still here, but could not be saved. Reopen the project to use its saved version.';

  @override
  String get roomProjectSaveLimit =>
      'This project has reached its storage limit. Your latest edits are still here but are not saved.';

  @override
  String get roomProjectRetrySave => 'Retry save';

  @override
  String get roomManualModeNotice =>
      'Manual mode: automatic masks are unavailable. Mark surfaces to preview colors, or retry analysis.';

  @override
  String get roomEditManually => 'Edit manually';

  @override
  String get roomDiscardPhoto => 'Discard photo';

  @override
  String get roomRetryAnalysis => 'Retry analysis';

  @override
  String get roomAnalysisFailed =>
      'Room analysis could not finish. Try again or choose another photo.';

  @override
  String get roomProjectReplaceUnsaved =>
      'This project has unsaved edits. If you continue and open the new photo, those edits will be discarded. Its last saved version stays on this device.';

  @override
  String get roomProjectsTitle => 'Room projects';

  @override
  String get roomProjectsDescription =>
      'Your editable room photos, masks and colors stay on this device.';

  @override
  String get roomProjectsLoading => 'Loading room projects…';

  @override
  String get roomProjectsEmpty => 'No room projects yet';

  @override
  String get roomProjectsNoneReadable => 'No readable room projects';

  @override
  String get roomProjectsEmptyBody =>
      'Use a room photo to create an editable project, or try an Illustrated Room.';

  @override
  String get roomProjectsError => 'Room projects could not be loaded';

  @override
  String get roomProjectsRetryBody =>
      'Your local files have not been removed. Try loading the library again.';

  @override
  String get roomProjectsCorrupt =>
      'Some projects could not be read. Your other projects are shown, and the unreadable files have been kept.';

  @override
  String get roomProjectsRefresh => 'Refresh projects';

  @override
  String roomProjectUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String roomProjectThumbnail(String name) {
    return 'Photo preview for $name';
  }

  @override
  String roomProjectThumbnailUnavailable(String name) {
    return 'Photo preview unavailable for $name';
  }

  @override
  String get roomProjectRecovered =>
      'Recovered an earlier saved version. Some later changes could not be read. The original files have been kept.';

  @override
  String get roomProjectThumbnailWarning =>
      'The photo preview could not be read. Your editable photo and masks are available.';

  @override
  String get roomProjectOpen => 'Open';

  @override
  String roomProjectOpenLabel(String name) {
    return 'Open $name';
  }

  @override
  String get roomProjectContinue => 'Continue';

  @override
  String roomProjectContinueLabel(String name) {
    return 'Continue $name';
  }

  @override
  String roomProjectMenu(String name) {
    return 'Actions for $name';
  }

  @override
  String get roomProjectRename => 'Rename';

  @override
  String get roomProjectName => 'Project name';

  @override
  String get roomProjectNameInvalid =>
      'Use 1–80 characters, with no control characters.';

  @override
  String get roomProjectDuplicate => 'Duplicate';

  @override
  String roomProjectCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get roomProjectCompare => 'Compare';

  @override
  String get roomProjectCompareUnavailable =>
      'Comparison is not available yet.';

  @override
  String get roomProjectDelete => 'Delete project';

  @override
  String roomProjectDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get roomProjectDeleteBody =>
      'This removes this project’s local working photo, masks and color variants, including any unsaved edits. Images already saved or shared outside the app are not removed. Other projects stay on this device.';

  @override
  String get roomProjectCancel => 'Cancel';

  @override
  String get roomProjectActionBusy =>
      'A project action is in progress. Wait for it to finish, then try again.';

  @override
  String get roomProjectActionUnsaved =>
      'Continue your current project and wait for Project saved, or retry saving its edits, before changing another project. Your visible edits are still here.';

  @override
  String get roomProjectActionConflict =>
      'This project changed since this list was loaded. Refresh the library and review its saved version before trying again. Your current draft has been kept.';

  @override
  String get roomProjectActionUnavailable =>
      'This project is missing or could not be read. Return to the library or try again. Any current draft has been kept.';

  @override
  String get roomProjectActionStorage =>
      'The project action could not be completed. Check available device storage and try again.';

  @override
  String get roomProjectActionLimit =>
      'This project action reached a storage or identifier limit. Refresh the library and try again.';

  @override
  String get roomProjectOpening => 'Opening room project…';

  @override
  String get roomProjectOpenError => 'Room project could not be opened';

  @override
  String get roomProjectWorking => 'Working…';

  @override
  String get roomVariantsTitle => 'Color variants';

  @override
  String get roomVariantCreate => 'Create variant';

  @override
  String get roomVariantRename => 'Rename variant';

  @override
  String get roomVariantDelete => 'Delete variant';

  @override
  String roomVariantDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String roomVariantDeleteConsequence(String name) {
    return 'This removes the “$name” color alternative. The project photo, masks, and other variants remain.';
  }

  @override
  String roomVariantDeleteSelection(String name) {
    return 'The selected variant will switch to “$name”.';
  }

  @override
  String get roomVariantDeleteBaseline =>
      'This is the pinned baseline. Comparison will be cleared.';

  @override
  String get roomVariantDeleteChanged =>
      'The project or variants changed while this confirmation was open. Review the variant and try again.';

  @override
  String get roomVariantPin => 'Pin as baseline';

  @override
  String get roomVariantName => 'Variant name';

  @override
  String get roomVariantApply => 'Apply';

  @override
  String get roomVariantInvalidName =>
      'Use a name with 1–80 characters and no control characters.';

  @override
  String get roomVariantDuplicateName =>
      'Choose a different name. Each variant needs a unique name.';

  @override
  String get roomVariantLimit =>
      'This project already has 32 variants. Delete one before creating another.';

  @override
  String get roomVariantFinal => 'Keep at least one variant in this project.';

  @override
  String get roomVariantUnavailable =>
      'This variant cannot be changed right now. Return to the project and try again.';

  @override
  String get roomComparisonClear => 'Clear comparison';

  @override
  String get roomComparisonNeedVariant =>
      'Create another variant to compare two color choices.';

  @override
  String get roomComparisonSelectOther =>
      'Select a different variant to compare with the pinned baseline.';

  @override
  String get roomComparisonGuide =>
      'Pin a baseline and select another variant to compare. Color edits apply to the selected variant.';

  @override
  String get roomComparisonTitle => 'Compare variants';

  @override
  String get roomComparisonOriginal => 'Original room photo';

  @override
  String get roomComparisonDivider => 'Comparison divider';

  @override
  String get roomComparisonFailed =>
      'Comparison could not update. Your variants are safe.';

  @override
  String get roomComparisonUpdating => 'Updating comparison…';

  @override
  String roomVariantLabel(String letter, String name) {
    return '$letter · $name';
  }

  @override
  String roomVariantSelected(String label) {
    return '$label · Selected';
  }

  @override
  String roomVariantBaseline(String label) {
    return 'Baseline: $label';
  }

  @override
  String roomComparisonActive(String name) {
    return 'Selected: $name';
  }

  @override
  String roomComparisonBaseline(String name) {
    return 'Baseline: $name';
  }

  @override
  String roomComparisonPosition(int percent) {
    return '$percent% selected variant';
  }

  @override
  String aboutAndLicenses(String appName) {
    return 'About $appName & licenses';
  }
}
