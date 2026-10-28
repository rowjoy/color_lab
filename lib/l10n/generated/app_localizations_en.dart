// GENERATED CODE - DO NOT MODIFY BY HAND.

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get roomCompare => 'Compare';

  @override
  String get roomComparePin => 'Pin current colors as A';

  @override
  String get roomCompareA => 'A · Pinned colors';

  @override
  String get roomCompareCurrent => 'Current colors';

  @override
  String get roomCompareOriginal => 'Original · Last saved colors';

  @override
  String get roomCompareGrayscale => 'Black & white preview';

  @override
  String roomCompareVariant(String name) {
    return 'B · $name';
  }

  @override
  String get roomCompareHint =>
      'Comparisons preserve your edits. Original shows your last saved colors, or black & white for a new design.';

  @override
  String get roomExportArtwork => 'Room PNG · 2400 × 1600';

  @override
  String get roomExportPaletteCard => 'Palette card · 1200 px wide';

  @override
  String get roomExportDisplayed =>
      'Exports the view shown now. The palette card is available for colored views.';

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
  String get roomDraftUnavailable =>
      'A draft from a newer app version can’t be opened yet. It is kept safely on this device.';

  @override
  String get roomEditFlow => 'Choose a Look → Change a Surface → Save';

  @override
  String get roomChooseLook => 'Choose a Look';

  @override
  String get roomChangeSurface => 'Change a Surface';

  @override
  String get roomApplyCompleteLook => 'Apply Complete Look';

  @override
  String get roomLookPreview => 'Preview — apply to change your room';

  @override
  String get roomSave => 'Save';

  @override
  String get roomUpdate => 'Update';

  @override
  String get roomSaveCopy => 'Save a Copy';

  @override
  String get roomMyDesigns => 'My Designs';

  @override
  String get roomMyPalettes => 'My Palettes';

  @override
  String get roomUndo => 'Undo';

  @override
  String get roomRedo => 'Redo';

  @override
  String get roomSaving => 'Saving…';

  @override
  String get roomSaved => 'Saved';

  @override
  String get roomDraftFailed =>
      'Draft could not be saved. Your changes are still here.';

  @override
  String get roomRetry => 'Retry';

  @override
  String get roomCustomColor => 'Custom color';

  @override
  String get roomClose => 'Close';

  @override
  String get roomNoPalettes => 'No saved palettes yet.';

  @override
  String get roomPalettesFailed => 'Could not load your palettes.';

  @override
  String get roomLoading => 'Loading…';

  @override
  String get roomWallBack => 'Back wall';

  @override
  String get roomWallSide => 'Side wall';

  @override
  String get roomWallAccent => 'Accent wall';

  @override
  String get roomDesk => 'Desk';

  @override
  String get roomChair => 'Chair';

  @override
  String get roomShelves => 'Shelves';

  @override
  String get roomConsole => 'Console';

  @override
  String get roomSofa => 'Sofa';

  @override
  String get roomAccentChair => 'Accent chair';

  @override
  String get roomCoffeeTable => 'Coffee table';

  @override
  String get roomWardrobe => 'Wardrobe';

  @override
  String get roomBedsideTableLeft => 'Left bedside table';

  @override
  String get roomBedsideTableRight => 'Right bedside table';

  @override
  String get roomBed => 'Bed';

  @override
  String get roomSideboard => 'Sideboard';

  @override
  String get roomChairBackLeft => 'Back left chair';

  @override
  String get roomChairBackRight => 'Back right chair';

  @override
  String get roomChairFrontLeft => 'Front left chair';

  @override
  String get roomChairFrontRight => 'Front right chair';

  @override
  String get roomDiningTable => 'Dining table';

  @override
  String get roomCabinetUpperLeft => 'Upper left cabinets';

  @override
  String get roomCabinetLowerLeft => 'Lower left cabinets';

  @override
  String get roomCabinetUpperRight => 'Upper right cabinets';

  @override
  String get roomCabinetLowerRight => 'Lower right cabinets';

  @override
  String get roomIsland => 'Island';

  @override
  String get roomVanity => 'Vanity';

  @override
  String get roomStorage => 'Storage';

  @override
  String get roomWalls => 'All Walls';

  @override
  String get roomCeiling => 'Ceiling';

  @override
  String get roomFloor => 'Floor';

  @override
  String get roomFurniture => 'Furniture';

  @override
  String roomSelectedSurface(String name) {
    return 'Selected: $name';
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

  @override
  String get roomExportLimits =>
      'Display calibration, camera processing, lighting, wall texture, paint finish, surrounding colors, and variation in real paint can change how colors appear. Previews guide exploration and are not calibrated matches for buying paint.';

  @override
  String roomExportResolution(int width, int height) {
    return 'PNG · $width × $height pixels. Exported at the processed working resolution.';
  }

  @override
  String roomExportSelected(String name) {
    return 'Export selected variant: $name';
  }

  @override
  String get roomExportEffects =>
      'Save image adds an external image to Photos or Gallery. Share opens the system sheet. Neither action saves the editable project.';

  @override
  String get roomExportUnsaved =>
      'This project has unsaved edits. Exporting an image does not save those edits.';

  @override
  String roomExportTitle(String appName) {
    return '$appName room preview';
  }

  @override
  String get roomExportSave => 'Save image';

  @override
  String get roomExportShare => 'Share PNG';

  @override
  String get roomExportSaving => 'Preparing image…';

  @override
  String get roomExportSaved => 'Image added to Photos or Gallery.';

  @override
  String get roomExportShared => 'The share sheet completed.';

  @override
  String get roomExportDismissed => 'Share sheet dismissed.';

  @override
  String get roomExportUnavailable =>
      'The sharing result could not be determined.';

  @override
  String get roomExportAccess =>
      'Photo access is off. Allow access in Settings, then try saving again.';

  @override
  String get roomExportCapacity =>
      'Storage is full. Free some space, then retry Save image. Check Photos or Gallery first; an image may already have been added.';

  @override
  String get roomExportSaveFailed =>
      'Could not confirm the image was saved. Check Photos or Gallery before retrying; an image may already have been added.';

  @override
  String get roomExportShareFailed => 'Could not share the PNG. Try again.';

  @override
  String get roomExportInvalid =>
      'This preview could not be verified for export. Your photo and edits are safe. Retry the preview.';

  @override
  String get roomExportInterrupted =>
      'Export was interrupted. Return to the current preview and try again.';

  @override
  String get roomOpenSettings => 'Open Settings';

  @override
  String get roomTryAgain => 'Try again';

  @override
  String get roomChoosePhoto => 'Choose photo';

  @override
  String get roomChooseSupported => 'Choose another supported image';

  @override
  String get roomChooseSmaller => 'Choose a smaller image';

  @override
  String get roomRetryPreview => 'Retry preview';

  @override
  String get roomRetrySaveImage => 'Retry Save image';

  @override
  String get roomRetryShare => 'Retry Share';

  @override
  String get roomPhotoPermission =>
      'Photo access is off. Allow access in Settings to continue.';

  @override
  String get roomCameraUnavailable =>
      'A camera is unavailable. Choose a photo from this device.';

  @override
  String get roomPickerUnavailable =>
      'The photo picker is unavailable. Try again.';

  @override
  String get roomPhotoUnsupported =>
      'This format is not supported. Choose a JPEG, PNG, GIF, WebP, BMP, or TIFF image.';

  @override
  String get roomPhotoInvalid =>
      'This image could not be read. Choose another supported image.';

  @override
  String get roomPhotoTooLarge =>
      'This image is too large to process. Choose a smaller image.';

  @override
  String get roomPhotoPreparation =>
      'This photo could not be prepared. Choose another supported image.';

  @override
  String get roomPhotoStorage =>
      'The photo request could not be stored. Your prepared photo is kept when available. Retry the storage action.';

  @override
  String get roomRetryPhotoStorage => 'Retry photo storage';

  @override
  String get roomModelUnavailable =>
      'Automatic masks need model setup. Your photo is kept; set up the models or edit manually.';

  @override
  String get roomModelIncompatible =>
      'The installed models could not analyze this photo. Your photo is kept; retry model setup or edit manually.';

  @override
  String get roomAnalysisInvalid =>
      'Automatic analysis returned unusable masks. Your photo is kept; retry analysis or edit manually.';

  @override
  String get roomModelSetupAction => 'Set up models';

  @override
  String get roomPreviewFailed =>
      'Preview could not update. Your photo and masks are safe.';

  @override
  String get roomRestoreTitle => 'Restore AI masks?';

  @override
  String get roomRestoreMessage =>
      'Your manual changes will be replaced by the original automatic masks. This clears the undo history.';

  @override
  String get roomRestoreAction => 'Restore';

  @override
  String get roomReplaceTitle => 'Replace room photo?';

  @override
  String get roomReplaceMessage =>
      'After a new photo is analyzed successfully, it replaces these masks and their undo history. Your current masks stay available if you cancel or analysis fails.';

  @override
  String get roomDialogCancel => 'Cancel';

  @override
  String get illustratedPaletteSoftLinenName => 'Soft Linen';

  @override
  String get illustratedPaletteSoftLinenDescription =>
      'Soft neutrals with a deeper warm accent.';

  @override
  String get illustratedPaletteQuietSageName => 'Quiet Sage';

  @override
  String get illustratedPaletteQuietSageDescription =>
      'Muted greens with a gentle neutral contrast.';

  @override
  String get illustratedPaletteAirySlateName => 'Airy Slate';

  @override
  String get illustratedPaletteAirySlateDescription =>
      'Pale cool tones with a deeper blue-gray accent.';

  @override
  String get illustratedPaletteClayAndCreamName => 'Clay and Cream';

  @override
  String get illustratedPaletteClayAndCreamDescription =>
      'Cream and earthy tones with a dark brown accent.';

  @override
  String get illustratedPaletteMistAndInkName => 'Mist and Ink';

  @override
  String get illustratedPaletteMistAndInkDescription =>
      'Light gray and blue tones with a dark ink accent.';

  @override
  String get illustratedPaletteSunwashedOliveName => 'Sunwashed Olive';

  @override
  String get illustratedPaletteSunwashedOliveDescription =>
      'Warm yellow and olive tones with a deep green accent.';

  @override
  String get illustratedPaletteGuideTitle => 'Why these looks?';

  @override
  String get illustratedPaletteGuideClose => 'Close palette guide';

  @override
  String get illustratedPaletteGuideIntro =>
      'Original color combinations for exploring your room. Each palette supplies wall, ceiling, floor and furniture colors.';

  @override
  String get illustratedPalettePreviewLimit =>
      'This is a non-calibrated display preview. Screen calibration, lighting, surface texture, paint finish and surrounding colors can change appearance. Compare physical samples in your room before buying paint.';

  @override
  String get illustratedPaletteRecommended => 'Starting look';

  @override
  String illustratedPaletteRecommendedLabel(String name) {
    return '$name, Starting look';
  }

  @override
  String get learningStepPredictTitle => 'Predict';

  @override
  String get learningStepManipulateTitle => 'Manipulate';

  @override
  String get learningStepObserveTitle => 'Observe';

  @override
  String get learningStepExplainTitle => 'Explain';

  @override
  String get learningStepApplyTitle => 'Apply';

  @override
  String get learningStepCheckTitle => 'Check';

  @override
  String get learningNonVisualInstruction =>
      'Use the labeled names, values, and controls; seeing a color difference is not required.';

  @override
  String get learningRetryHint => 'Try again as often as you like.';

  @override
  String get learningGlossaryHsl =>
      'HSL: hue angle, saturation, and lightness coordinates for an RGB color.';

  @override
  String get learningGlossaryHsv =>
      'HSV: hue, saturation, and value; value is the brightest RGB channel.';

  @override
  String get learningGlossaryRgb =>
      'RGB: encoded red, green, and blue display channels.';

  @override
  String get learningGlossaryHex =>
      'HEX: a compact written form of encoded RGB channel values.';

  @override
  String get learningGlossaryLab =>
      'CIELAB: lightness and opponent-color coordinates computed here from sRGB.';

  @override
  String get learningGlossaryCmyk =>
      'CMYK: a simplified digital conversion here, not a press or ink profile.';

  @override
  String get learningGlossaryDeltaE =>
      'Delta-E: points of computed color difference, not diagnostic accuracy or a calibrated purchase match.';

  @override
  String get learningGlossaryHue =>
      'Hue: a circular color-family angle; neutrals can have no visible hue.';

  @override
  String get learningGlossarySaturation =>
      'Saturation: colorfulness relative to a gray at the same model coordinates.';

  @override
  String get learningGlossaryLightnessValue =>
      'Lightness and value use different model definitions and are not interchangeable.';

  @override
  String get learningGlossaryDigitalInterpolation =>
      'Digital interpolation averages numerical color coordinates; it does not simulate material pigments.';

  @override
  String get learningGlossaryHarmony =>
      'Harmony: a repeatable hue relationship, not a guarantee that a palette is beautiful.';

  @override
  String get learningLessonCoordinatesTitle =>
      'Color coordinates: several views of one color';

  @override
  String get learningLessonCoordinatesSummary =>
      'Read one display color through HSL, RGB/HEX, LAB, and simplified CMYK coordinates.';

  @override
  String get learningCoordinatesPredictInstruction =>
      'Predict which coordinates will change when you adjust one visible color.';

  @override
  String get learningCoordinatesManipulateInstruction =>
      'Adjust hue, saturation, and lightness while reading the labeled HSL, RGB/HEX, LAB, and CMYK values.';

  @override
  String get learningCoordinatesObserveInstruction =>
      'Compare the numbers. Delta-E points describe a computed difference; they do not diagnose vision or guarantee a physical match.';

  @override
  String get learningCoordinatesExplainInstruction =>
      'RGB and HEX encode display channels; LAB and simplified CMYK describe the same digital color through different models.';

  @override
  String get learningCoordinatesApplyInstruction =>
      'Save a labeled color experiment. A generated formula is not a paint recipe, and a screen preview is not a purchase match.';

  @override
  String get learningCoordinatesCheckInstruction =>
      'Answer both questions, read each explanation, and retry freely.';

  @override
  String get learningCoordinatesManipulateNonVisual =>
      'Enter or adjust the labeled HSL values and read every resulting coordinate as text.';

  @override
  String get learningCoordinatesQ1Prompt => 'What does a HEX color encode?';

  @override
  String get learningCoordinatesQ1ALabel => 'Encoded RGB display channels';

  @override
  String get learningCoordinatesQ1BLabel => 'A physical paint formula';

  @override
  String get learningCoordinatesQ1AExplanation =>
      'Correct. HEX writes encoded red, green, and blue channel values.';

  @override
  String get learningCoordinatesQ1BExplanation =>
      'Not quite. HEX describes display channels, not material ingredients.';

  @override
  String get learningCoordinatesQ2Prompt =>
      'What do Delta-E points prove here?';

  @override
  String get learningCoordinatesQ2ALabel =>
      'They certify exact paint and vision accuracy';

  @override
  String get learningCoordinatesQ2BLabel =>
      'They describe a computed difference between color coordinates';

  @override
  String get learningCoordinatesQ2AExplanation =>
      'Not quite. The number is not a diagnosis, calibration certificate, or purchase guarantee.';

  @override
  String get learningCoordinatesQ2BExplanation =>
      'Correct. Delta-E is a model-based distance that needs context.';

  @override
  String get learningLessonHueTitle => 'Hue: the color-family angle';

  @override
  String get learningLessonHueSummary =>
      'Change the circular hue coordinate while names and numbers keep the activity usable without color-only cues.';

  @override
  String get learningHuePredictInstruction =>
      'Predict the named color family after moving the hue angle.';

  @override
  String get learningHueManipulateInstruction =>
      'Adjust hue by slider, keyboard, or number and read its degree value and color-family label.';

  @override
  String get learningHueObserveInstruction =>
      'Notice that the angle wraps around at 360 degrees and a neutral may show no visible hue.';

  @override
  String get learningHueExplainInstruction =>
      'Hue is a circular coordinate; it is not a measure of brightness or saturation.';

  @override
  String get learningHueApplyInstruction =>
      'Choose a hue for a labeled design intention and save the exact value.';

  @override
  String get learningHueCheckInstruction =>
      'Answer both questions, read each explanation, and retry freely.';

  @override
  String get learningHueManipulateNonVisual =>
      'Use the degree value and color-family label; no subtle visual comparison is required.';

  @override
  String get learningHueQ1Prompt => 'What happens after hue reaches 360°?';

  @override
  String get learningHueQ1ALabel => 'It wraps to 0° on the color circle';

  @override
  String get learningHueQ1BLabel => 'It becomes maximum brightness';

  @override
  String get learningHueQ1AExplanation =>
      'Correct. Hue is circular, so 360° and 0° meet.';

  @override
  String get learningHueQ1BExplanation =>
      'Not quite. Hue angle does not set brightness.';

  @override
  String get learningHueQ2Prompt => 'What does hue mainly identify?';

  @override
  String get learningHueQ2ALabel => 'How light a color is';

  @override
  String get learningHueQ2BLabel => 'Its position around a color-family circle';

  @override
  String get learningHueQ2AExplanation =>
      'Not quite. Lightness is a separate coordinate.';

  @override
  String get learningHueQ2BExplanation =>
      'Correct. Hue identifies a circular family position.';

  @override
  String get learningLessonSaturationTitle => 'Saturation: color versus gray';

  @override
  String get learningLessonSaturationSummary =>
      'Explore saturation with labeled values while keeping hue and lightness separate.';

  @override
  String get learningSaturationPredictInstruction =>
      'Predict whether lowering saturation moves the color toward a gray.';

  @override
  String get learningSaturationManipulateInstruction =>
      'Adjust saturation with a labeled percentage while hue and lightness stay fixed.';

  @override
  String get learningSaturationObserveInstruction =>
      'Read the same hue and lightness beside a changing saturation value.';

  @override
  String get learningSaturationExplainInstruction =>
      'In HSL, saturation describes distance from a gray at that lightness; it is not brightness.';

  @override
  String get learningSaturationApplyInstruction =>
      'Choose a saturation for a muted or vivid intention and record the percentage.';

  @override
  String get learningSaturationCheckInstruction =>
      'Answer both questions, read each explanation, and retry freely.';

  @override
  String get learningSaturationManipulateNonVisual =>
      'Use the saturation percentage and muted/vivid text labels instead of judging intensity by sight.';

  @override
  String get learningSaturationQ1Prompt =>
      'At 0% HSL saturation, what remains visible?';

  @override
  String get learningSaturationQ1ALabel => 'The most vivid form of the hue';

  @override
  String get learningSaturationQ1BLabel => 'A gray determined by lightness';

  @override
  String get learningSaturationQ1AExplanation =>
      'Not quite. Maximum vividness is not 0%.';

  @override
  String get learningSaturationQ1BExplanation =>
      'Correct. Zero saturation removes visible hue in HSL.';

  @override
  String get learningSaturationQ2Prompt => 'Does saturation mean brightness?';

  @override
  String get learningSaturationQ2ALabel => 'Yes, they are the same coordinate';

  @override
  String get learningSaturationQ2BLabel =>
      'No, lightness/value describe different model dimensions';

  @override
  String get learningSaturationQ2AExplanation =>
      'Not quite. Saturation and brightness-like coordinates are separate.';

  @override
  String get learningSaturationQ2BExplanation =>
      'Correct. The model keeps saturation separate from lightness or value.';

  @override
  String get learningLessonLightnessValueTitle =>
      'Lightness and value: two different scales';

  @override
  String get learningLessonLightnessValueSummary =>
      'Compare HSL lightness with HSV value without treating the terms as interchangeable.';

  @override
  String get learningLightnessValuePredictInstruction =>
      'Predict how an HSL lightness change affects the labeled RGB result.';

  @override
  String get learningLightnessValueManipulateInstruction =>
      'Adjust HSL lightness and read both HSL lightness and computed HSV value.';

  @override
  String get learningLightnessValueObserveInstruction =>
      'Notice that HSL lightness and HSV value can show different numbers for one RGB color.';

  @override
  String get learningLightnessValueExplainInstruction =>
      'HSL lightness averages channel extremes; HSV value uses the brightest channel.';

  @override
  String get learningLightnessValueApplyInstruction =>
      'Record a lightness choice and its separate value reading for a design note.';

  @override
  String get learningLightnessValueCheckInstruction =>
      'Answer both questions, read each explanation, and retry freely.';

  @override
  String get learningLightnessValueManipulateNonVisual =>
      'Compare the printed HSL lightness and HSV value percentages rather than relying on appearance.';

  @override
  String get learningLightnessValueQ1Prompt =>
      'Are HSL lightness and HSV value interchangeable?';

  @override
  String get learningLightnessValueQ1ALabel =>
      'No; their model definitions differ';

  @override
  String get learningLightnessValueQ1BLabel =>
      'Yes; they always have the same number';

  @override
  String get learningLightnessValueQ1AExplanation =>
      'Correct. They can describe one RGB color with different numbers.';

  @override
  String get learningLightnessValueQ1BExplanation =>
      'Not quite. The models calculate these coordinates differently.';

  @override
  String get learningLightnessValueQ2Prompt => 'What does HSV value use?';

  @override
  String get learningLightnessValueQ2ALabel =>
      'The average of the lightest and darkest channel';

  @override
  String get learningLightnessValueQ2BLabel => 'The brightest RGB channel';

  @override
  String get learningLightnessValueQ2AExplanation =>
      'Not quite. That resembles the HSL lightness calculation.';

  @override
  String get learningLightnessValueQ2BExplanation =>
      'Correct. HSV value is based on the maximum RGB channel.';

  @override
  String get learningLessonDigitalMixingTitle =>
      'Digital mixing: average coordinates';

  @override
  String get learningLessonDigitalMixingSummary =>
      'Mix weighted RGB or LAB values while keeping the result distinct from real pigment behavior.';

  @override
  String get learningDigitalMixingPredictInstruction =>
      'Predict which weighted input will pull the numerical result closer.';

  @override
  String get learningDigitalMixingManipulateInstruction =>
      'Change labeled color stops, weights, and RGB/LAB interpolation mode.';

  @override
  String get learningDigitalMixingObserveInstruction =>
      'Read normalized percentages and the resulting HEX value for each digital method.';

  @override
  String get learningDigitalMixingExplainInstruction =>
      'Digital RGB/LAB interpolation is not pigment mixing; paint, ink, light, texture, and profiles can behave differently.';

  @override
  String get learningDigitalMixingApplyInstruction =>
      'Save the exact stops, weights, mode, result, and an observation in the notebook.';

  @override
  String get learningDigitalMixingCheckInstruction =>
      'Answer both questions, read each explanation, and retry freely.';

  @override
  String get learningDigitalMixingManipulateNonVisual =>
      'Use stop names, HEX values, weights, normalized percentages, and the result text.';

  @override
  String get learningDigitalMixingQ1Prompt => 'What does this mixer simulate?';

  @override
  String get learningDigitalMixingQ1ALabel =>
      'Exact physical pigment chemistry';

  @override
  String get learningDigitalMixingQ1BLabel =>
      'Weighted interpolation of digital color coordinates';

  @override
  String get learningDigitalMixingQ1AExplanation =>
      'Not quite. No material or spectral pigment model is used.';

  @override
  String get learningDigitalMixingQ1BExplanation =>
      'Correct. It averages numerical RGB or LAB coordinates.';

  @override
  String get learningDigitalMixingQ2Prompt =>
      'Does a heavier stop have more numerical influence?';

  @override
  String get learningDigitalMixingQ2ALabel => 'No; weights are ignored';

  @override
  String get learningDigitalMixingQ2BLabel =>
      'Yes, after the weights are normalized';

  @override
  String get learningDigitalMixingQ2AExplanation =>
      'Not quite. Positive weights control the interpolation.';

  @override
  String get learningDigitalMixingQ2BExplanation =>
      'Correct. Normalized weights determine each stop\'s contribution.';

  @override
  String get learningLessonPaletteRelationshipsTitle =>
      'Palette relationships: structured starting points';

  @override
  String get learningLessonPaletteRelationshipsSummary =>
      'Explore named hue relationships without claiming that one rule guarantees a beautiful palette.';

  @override
  String get learningPaletteRelationshipsPredictInstruction =>
      'Predict where a complementary, analogous, or triadic relationship places hues.';

  @override
  String get learningPaletteRelationshipsManipulateInstruction =>
      'Choose a labeled base HEX value and harmony mode, then inspect the named swatches.';

  @override
  String get learningPaletteRelationshipsObserveInstruction =>
      'Read each swatch\'s name, HEX value, role, and hue angle.';

  @override
  String get learningPaletteRelationshipsExplainInstruction =>
      'A harmony scheme is a relationship rule, not a universal beauty rule; context, proportion, contrast, and culture still matter.';

  @override
  String get learningPaletteRelationshipsApplyInstruction =>
      'Copy a palette by value into an experiment or supported project and note its intended context.';

  @override
  String get learningPaletteRelationshipsCheckInstruction =>
      'Answer both questions, read each explanation, and retry freely.';

  @override
  String get learningPaletteRelationshipsManipulateNonVisual =>
      'Use the harmony mode, swatch order, roles, names, HEX values, and angles as the complete alternative.';

  @override
  String get learningPaletteRelationshipsQ1Prompt =>
      'What does a harmony mode provide?';

  @override
  String get learningPaletteRelationshipsQ1ALabel =>
      'A repeatable hue relationship';

  @override
  String get learningPaletteRelationshipsQ1BLabel =>
      'A guarantee that every design is beautiful';

  @override
  String get learningPaletteRelationshipsQ1AExplanation =>
      'Correct. It is a structured relationship you can test in context.';

  @override
  String get learningPaletteRelationshipsQ1BExplanation =>
      'Not quite. No palette rule can guarantee a universal judgment.';

  @override
  String get learningPaletteRelationshipsQ2Prompt =>
      'What else affects a palette in use?';

  @override
  String get learningPaletteRelationshipsQ2ALabel =>
      'Nothing; hue spacing is enough';

  @override
  String get learningPaletteRelationshipsQ2BLabel =>
      'Context, proportion, contrast, material, and surrounding colors';

  @override
  String get learningPaletteRelationshipsQ2AExplanation =>
      'Not quite. A hue rule is only a starting point.';

  @override
  String get learningPaletteRelationshipsQ2BExplanation =>
      'Correct. Real use depends on context and more than hue spacing.';

  @override
  String get learningSectionLearn => 'Learn';

  @override
  String get learningSectionExperiment => 'Experiment';

  @override
  String get learningSectionMyWork => 'My Work';

  @override
  String get learningStartLesson => 'Start lesson';

  @override
  String learningResumeStage(String stage) {
    return 'Resume · $stage';
  }

  @override
  String get learningLessonComplete => 'Completed';

  @override
  String learningLessonProgress(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get learningPrevious => 'Previous';

  @override
  String get learningNext => 'Next';

  @override
  String get learningFinish => 'Finish lesson';

  @override
  String get learningGlossary => 'Glossary';

  @override
  String get learningNonVisualAlternative => 'Text and controls alternative';

  @override
  String learningPracticeValue(int value) {
    return 'Practice value: $value%';
  }

  @override
  String get learningSaveError =>
      'Couldn\'t save this change. Your visible work is kept.';

  @override
  String get learningRetrySave => 'Retry save';

  @override
  String get learningLoadingTitle => 'Opening Color Learning…';

  @override
  String get learningLoadingBody =>
      'Your lessons and experiments stay on this device.';

  @override
  String get learningLoadErrorTitle => 'Color Learning is unavailable';

  @override
  String get learningLoadErrorBody =>
      'Your saved data was not erased. Try opening it again.';

  @override
  String get learningNotebookTitle => 'Experiment Notebook';

  @override
  String get learningNotebookDescription =>
      'Reopen exact tool settings and keep your own observations.';

  @override
  String get learningNotebookEmptyTitle => 'No saved experiments yet';

  @override
  String get learningNotebookEmptyBody =>
      'Save a result from Lab, Mixer, Harmonies, Formula, or Matching.';

  @override
  String get learningOpenExperiment => 'Open an experiment';

  @override
  String get learningOpenNotebook => 'Open Experiment Notebook';

  @override
  String get learningDeleteExperiment => 'Delete experiment';

  @override
  String get learningUseInRoom => 'Use palette in Illustrated Room';

  @override
  String get learningSaveExperiment => 'Save to Notebook';

  @override
  String learningOpenPracticeTool(String tool) {
    return 'Open $tool experiment';
  }

  @override
  String get learningSaveExperimentTitle => 'Save this experiment';

  @override
  String get learningExperimentTitleLabel => 'Experiment title';

  @override
  String get learningExperimentObservationLabel =>
      'What did you observe? (optional)';

  @override
  String get learningExperimentSaveFailed =>
      'This experiment is still on screen but could not be saved. Try the same save again.';

  @override
  String get learningExperimentSaved => 'Experiment saved to your Notebook.';

  @override
  String get learningResetLesson => 'Reset lesson';

  @override
  String get learningResetLessonTitle => 'Reset this lesson?';

  @override
  String get learningResetLessonBody =>
      'Your current steps and answers for this lesson will start again. Other lessons and saved experiments stay unchanged.';

  @override
  String get myWorkExperimentsTitle => 'Color learning experiments';

  @override
  String learningExperimentTool(String tool) {
    return '$tool experiment';
  }

  @override
  String get learningCompletedAnnouncement =>
      'Lesson completed. You can revisit any stage.';

  @override
  String get coloringStudioTitle => 'Coloring Studio';

  @override
  String get coloringCatalogHeadline => 'Color at your pace.';

  @override
  String get coloringCatalogBody =>
      'Twelve original offline drawings. Guided and Free projects stay separate, with no timer, score, or lives.';

  @override
  String get coloringGamesEntryBody =>
      'Relax with 12 original offline drawings in Guided or Free Color. No timer, score, coins, or lives.';

  @override
  String get coloringCopiedPaletteReady =>
      'Your copied Color Learning palette is ready in Free Color.';

  @override
  String get coloringCreateFailed =>
      'The project could not be created. Try again.';

  @override
  String get coloringAllCategories => 'All categories';

  @override
  String get coloringCategoryFruit => 'Fruit';

  @override
  String get coloringCategoryAnimals => 'Animals';

  @override
  String get coloringCategoryNature => 'Trees & Nature';

  @override
  String get coloringCategoryRooms => 'Rooms';

  @override
  String get coloringAllModes => 'All modes';

  @override
  String get coloringGuidedMode => 'Guided Color';

  @override
  String get coloringFreeMode => 'Free Color';

  @override
  String get coloringContinue => 'Continue coloring';

  @override
  String get coloringRetryCatalog => 'Retry Coloring Studio';

  @override
  String get coloringCompletedUnavailable =>
      'This completed artwork is unavailable.';

  @override
  String get coloringCompleteTitle => 'Artwork complete';

  @override
  String get coloringCompleteBody =>
      'Your editable project stays in My Artwork. Exporting creates a separate clean PNG.';

  @override
  String get coloringExportPng => 'Export PNG';

  @override
  String get coloringShare => 'Share';

  @override
  String get coloringUseInRoom => 'Use colors in a room';

  @override
  String get coloringChooseAnother => 'Choose another drawing';

  @override
  String get coloringOpenArtwork => 'Open My Artwork';

  @override
  String get coloringReturnLearning => 'Return to Color Learning';

  @override
  String get coloringExportedComplete =>
      'PNG exported. Your editable project is unchanged.';

  @override
  String get coloringShareCompleted => 'Share completed.';

  @override
  String get coloringShareDismissed => 'Share cancelled. Your project is safe.';

  @override
  String get coloringShareUnavailable =>
      'Sharing is unavailable on this device.';

  @override
  String get coloringPngFailed =>
      'The PNG could not be created. Your editable project is safe.';

  @override
  String get coloringChooseMode =>
      'Choose how you want to color. Each mode keeps its own project.';

  @override
  String get coloringGuidedDescription =>
      'Match each labeled region with its authored color. No timer or penalties.';

  @override
  String get coloringFreeDescription =>
      'Use suggested colors, your saved colors, palettes, or a custom HEX.';

  @override
  String get coloringRegions => 'Regions';

  @override
  String get coloringNotColored => 'Not colored';

  @override
  String get coloringAssignTitle => 'Assign colors to room surfaces';

  @override
  String get coloringAssignBody =>
      'Choose each surface explicitly. The room will not change until you confirm.';

  @override
  String get coloringSurfaceWall => 'Wall';

  @override
  String get coloringSurfaceCeiling => 'Ceiling';

  @override
  String get coloringSurfaceFloor => 'Floor';

  @override
  String get coloringSurfaceFurniture => 'Furniture';

  @override
  String get coloringCancel => 'Cancel';

  @override
  String get coloringApplyRoom => 'Apply to room';

  @override
  String get coloringOpenFailed =>
      'Coloring Studio could not open this project.';

  @override
  String get coloringProjectMissing => 'This coloring project was not found.';

  @override
  String get coloringRevisionMissing => 'This drawing revision is unavailable.';

  @override
  String get coloringSaveDraft =>
      'Your latest change is still visible but was not saved.';

  @override
  String get coloringRetry => 'Retry';

  @override
  String get coloringRegionSelected => 'Region selected.';

  @override
  String get coloringApplyGuided => 'Apply selected color to selected region';

  @override
  String get coloringUndo => 'Undo';

  @override
  String get coloringRedo => 'Redo';

  @override
  String get coloringAllColored => 'Every required region is colored.';

  @override
  String get coloringNextUnfilled => 'Moved to the next unfilled region.';

  @override
  String get coloringFindRegion => 'Find region';

  @override
  String get coloringFinish => 'Finish';

  @override
  String get coloringSaved => 'Saved';

  @override
  String get coloringSaving => 'Saving…';

  @override
  String get coloringNotSaved => 'Not saved';

  @override
  String get coloringChooseGuided => 'Choose one of the guided colors.';

  @override
  String get coloringNowChooseColor => 'Now choose a color for this region.';

  @override
  String get coloringChooseRegion => 'Choose a region first.';

  @override
  String get coloringChooseLabeledColor => 'Choose a labeled color first.';

  @override
  String get coloringAccepted => 'Nice match. The region is colored.';

  @override
  String get coloringWrongColor =>
      'That color belongs to a different region. Try another labeled color.';

  @override
  String get coloringRetryBeforeFinish => 'Retry saving before finishing.';

  @override
  String get coloringFinishRemaining =>
      'Color the remaining required regions first.';

  @override
  String get coloringChangeSaveFailed =>
      'The change could not be saved. Retry is available.';

  @override
  String get coloringMyArtwork => 'My Artwork';

  @override
  String get coloringArtworkBody =>
      'Editable Coloring Studio projects are separate from exported PNG files.';

  @override
  String get coloringRetryArtwork => 'Retry artwork';

  @override
  String get coloringDuplicateFailed => 'The project could not be duplicated.';

  @override
  String get coloringExported => 'PNG exported.';

  @override
  String get coloringExportFailed => 'Export failed. The project is safe.';

  @override
  String get coloringSharingFailed =>
      'Sharing is unavailable. The project is safe.';

  @override
  String get coloringDeleteTitle => 'Delete editable artwork?';

  @override
  String get coloringDeleteBody => 'Exported PNG files are not deleted.';

  @override
  String get coloringDelete => 'Delete';

  @override
  String get coloringDeleteFailed => 'The artwork could not be deleted.';

  @override
  String get coloringEmptyArtwork => 'No coloring projects yet.';

  @override
  String get coloringOpenStudio => 'Open Coloring Studio';

  @override
  String get coloringResume => 'Resume';

  @override
  String get coloringDuplicate => 'Duplicate';

  @override
  String get coloringExport => 'Export';

  @override
  String get coloringSuggestedColors => 'Suggested colors';

  @override
  String get coloringFromLearning => 'From Color Learning';

  @override
  String get coloringMyColors => 'My Colors';

  @override
  String get coloringMyPalettes => 'My Palettes';

  @override
  String get coloringCustomHex => 'Custom HEX';

  @override
  String get coloringHexHint => '#336699';

  @override
  String get coloringUseCustom => 'Use custom color';

  @override
  String get coloringInvalidHex => 'Enter a six-digit HEX color.';

  @override
  String get coloringUnknownDrawing => 'Unknown drawing';

  @override
  String coloringProgress(int filled, int total) {
    return '$filled of $total regions';
  }

  @override
  String coloringSelectedColor(String label) {
    return '$label selected.';
  }

  @override
  String coloringAppliedColor(String hex) {
    return '$hex applied.';
  }

  @override
  String coloringRegionNeeds(String label) {
    return 'Needs $label';
  }

  @override
  String coloringRegionComplete(String label) {
    return '$label complete';
  }

  @override
  String coloringRegionSemantics(String label, String value) {
    return '$label, $value';
  }

  @override
  String coloringProjectSummary(String mode, int count) {
    return '$mode · $count regions';
  }

  @override
  String coloringNumberedSwatch(int number, String label, String hex) {
    return '$number. $label $hex';
  }

  @override
  String coloringNamedHex(String name, String hex) {
    return '$name $hex';
  }

  @override
  String coloringSwatchSemantics(String label, String hex) {
    return '$label, $hex';
  }

  @override
  String coloringSwatchTooltip(String label, String hex) {
    return '$label · $hex';
  }

  @override
  String coloringShareTitle(String title) {
    return 'TintAtlas Coloring Studio — $title';
  }

  @override
  String coloringDifficulty(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'easy': 'Easy',
      'medium': 'Medium',
      'hard': 'Hard',
      'other': 'Unknown difficulty',
    });
    return '$_temp0';
  }

  @override
  String coloringDifficultyBadge(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'easy': 'EASY',
      'medium': 'MEDIUM',
      'hard': 'HARD',
      'other': 'UNKNOWN DIFFICULTY',
    });
    return '$_temp0';
  }

  @override
  String coloringModeSummary(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'guided': 'guided',
      'free': 'free',
      'other': 'unknown mode',
    });
    return '$_temp0';
  }

  @override
  String coloringDrawingTitle(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'coloringFruitRedAppleTitle': 'Red Apple',
      'coloringFruitOrangeSliceTitle': 'Orange Slice',
      'coloringFruitBerryBowlTitle': 'Berry Bowl',
      'coloringAnimalButterflyTitle': 'Butterfly',
      'coloringAnimalTropicalFishTitle': 'Tropical Fish',
      'coloringAnimalParrotTitle': 'Parrot',
      'coloringNatureLeafyTreeTitle': 'Leafy Tree',
      'coloringNatureSunflowerTitle': 'Sunflower',
      'coloringNatureMountainGroveTitle': 'Mountain Grove',
      'coloringRoomCozyLivingTitle': 'Cozy Living Room',
      'coloringRoomCalmBedroomTitle': 'Calm Bedroom',
      'coloringRoomReadingCornerTitle': 'Reading Corner',
      'other': 'Unknown drawing',
    });
    return '$_temp0';
  }

  @override
  String coloringDrawingDescription(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'coloringFruitRedAppleDescription':
          'A bright apple with a leaf, stem, and soft highlight.',
      'coloringFruitOrangeSliceDescription':
          'A cheerful citrus slice with peel, pith, and seed.',
      'coloringFruitBerryBowlDescription':
          'Red and blue berries gathered in a cool blue bowl.',
      'coloringAnimalButterflyDescription':
          'A balanced butterfly with warm wings and violet spots.',
      'coloringAnimalTropicalFishDescription':
          'A lively fish with bold stripes, fin, and bright body.',
      'coloringAnimalParrotDescription':
          'A five-color parrot perched in a friendly profile.',
      'coloringNatureLeafyTreeDescription':
          'A sturdy tree with layered leaves and warm ground.',
      'coloringNatureSunflowerDescription':
          'A tall sunflower against a clear blue sky.',
      'coloringNatureMountainGroveDescription':
          'Pines, snow, and slate peaks in a quiet landscape.',
      'coloringRoomCozyLivingDescription':
          'A calm sofa, rug, table, and wall composition.',
      'coloringRoomCalmBedroomDescription':
          'A restful bed with mist, cream, blue, and sage layers.',
      'coloringRoomReadingCornerDescription':
          'A warm chair, shelf, plant, and lamp for a quiet nook.',
      'other': 'Drawing description unavailable.',
    });
    return '$_temp0';
  }

  @override
  String coloringSlotLabel(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'coloringSlotAppleRed': 'Apple red',
      'coloringSlotLeafGreen': 'Leaf green',
      'coloringSlotStemBrown': 'Stem brown',
      'coloringSlotHighlightCream': 'Highlight cream',
      'coloringSlotPeelOrange': 'Peel orange',
      'coloringSlotFleshOrange': 'Flesh orange',
      'coloringSlotPithCream': 'Pith cream',
      'coloringSlotSeedTan': 'Seed tan',
      'coloringSlotBerryRed': 'Berry red',
      'coloringSlotBerryBlue': 'Berry blue',
      'coloringSlotBowlBlue': 'Bowl blue',
      'coloringSlotRimCream': 'Rim cream',
      'coloringSlotWingGold': 'Wing gold',
      'coloringSlotWingCoral': 'Wing coral',
      'coloringSlotBodyCharcoal': 'Body charcoal',
      'coloringSlotSpotViolet': 'Spot violet',
      'coloringSlotBodyTurquoise': 'Body turquoise',
      'coloringSlotStripeYellow': 'Stripe yellow',
      'coloringSlotStripeCoral': 'Stripe coral',
      'coloringSlotFinBlue': 'Fin blue',
      'coloringSlotEyeCharcoal': 'Eye charcoal',
      'coloringSlotFeatherRed': 'Feather red',
      'coloringSlotFeatherGreen': 'Feather green',
      'coloringSlotFeatherBlue': 'Feather blue',
      'coloringSlotChestYellow': 'Chest yellow',
      'coloringSlotBeakOrange': 'Beak orange',
      'coloringSlotLeafLightGreen': 'Leaf light green',
      'coloringSlotTrunkBrown': 'Trunk brown',
      'coloringSlotGroundTan': 'Ground tan',
      'coloringSlotPetalYellow': 'Petal yellow',
      'coloringSlotCenterBrown': 'Center brown',
      'coloringSlotSkyBlue': 'Sky blue',
      'coloringSlotMountainSlate': 'Mountain slate',
      'coloringSlotPineGreen': 'Pine green',
      'coloringSlotSnowWhite': 'Snow white',
      'coloringSlotEarthGray': 'Earth gray',
      'coloringSlotWallLinen': 'Wall linen',
      'coloringSlotSofaSage': 'Sofa sage',
      'coloringSlotWoodBrown': 'Wood brown',
      'coloringSlotRugCoral': 'Rug coral',
      'coloringSlotAccentSlate': 'Accent slate',
      'coloringSlotWallMist': 'Wall mist',
      'coloringSlotBeddingCream': 'Bedding cream',
      'coloringSlotBlanketBlue': 'Blanket blue',
      'coloringSlotWoodTan': 'Wood tan',
      'coloringSlotAccentSage': 'Accent sage',
      'coloringSlotChairClay': 'Chair clay',
      'coloringSlotShelfBrown': 'Shelf brown',
      'coloringSlotPlantGreen': 'Plant green',
      'coloringSlotLampGold': 'Lamp gold',
      'other': 'Color',
    });
    return '$_temp0';
  }

  @override
  String coloringRegionLabel(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'coloringAppleBody': 'Apple Body',
      'coloringAppleStem': 'Apple Stem',
      'coloringAppleLeaf': 'Apple Leaf',
      'coloringAppleHighlight': 'Apple Highlight',
      'coloringOrangePeel': 'Orange Peel',
      'coloringOrangeFlesh': 'Orange Flesh',
      'coloringOrangePith': 'Orange Pith',
      'coloringOrangeSeed': 'Orange Seed',
      'coloringBerryBowlBody': 'Berry Bowl Body',
      'coloringBerryBowlRim': 'Berry Bowl Rim',
      'coloringBerryRedFruit': 'Berry Red Fruit',
      'coloringBerryBlueFruit': 'Berry Blue Fruit',
      'coloringBerryLeaf': 'Berry Leaf',
      'coloringButterflyGoldWings': 'Butterfly Gold Wings',
      'coloringButterflyCoralWings': 'Butterfly Coral Wings',
      'coloringButterflyBody': 'Butterfly Body',
      'coloringButterflySpots': 'Butterfly Spots',
      'coloringFishBody': 'Fish Body',
      'coloringFishTail': 'Fish Tail',
      'coloringFishCoralStripe': 'Fish Coral Stripe',
      'coloringFishYellowStripe': 'Fish Yellow Stripe',
      'coloringFishEye': 'Fish Eye',
      'coloringParrotRedHead': 'Parrot Red Head',
      'coloringParrotGreenWing': 'Parrot Green Wing',
      'coloringParrotBlueTail': 'Parrot Blue Tail',
      'coloringParrotYellowChest': 'Parrot Yellow Chest',
      'coloringParrotOrangeBeak': 'Parrot Orange Beak',
      'coloringTreeGround': 'Tree Ground',
      'coloringTreeTrunk': 'Tree Trunk',
      'coloringTreeDarkLeaves': 'Tree Dark Leaves',
      'coloringTreeLightLeaves': 'Tree Light Leaves',
      'coloringSunflowerSky': 'Sunflower Sky',
      'coloringSunflowerStemLeaf': 'Sunflower Stem Leaf',
      'coloringSunflowerPetals': 'Sunflower Petals',
      'coloringSunflowerCenter': 'Sunflower Center',
      'coloringMountainSky': 'Mountain Sky',
      'coloringMountainEarth': 'Mountain Earth',
      'coloringMountainSlate': 'Mountain Slate',
      'coloringMountainSnow': 'Mountain Snow',
      'coloringMountainPines': 'Mountain Pines',
      'coloringLivingWall': 'Living Wall',
      'coloringLivingRug': 'Living Rug',
      'coloringLivingSofa': 'Living Sofa',
      'coloringLivingWood': 'Living Wood',
      'coloringLivingAccent': 'Living Accent',
      'coloringBedroomWall': 'Bedroom Wall',
      'coloringBedroomWood': 'Bedroom Wood',
      'coloringBedroomBedding': 'Bedroom Bedding',
      'coloringBedroomBlanket': 'Bedroom Blanket',
      'coloringBedroomAccent': 'Bedroom Accent',
      'coloringReadingWall': 'Reading Wall',
      'coloringReadingShelf': 'Reading Shelf',
      'coloringReadingChair': 'Reading Chair',
      'coloringReadingPlant': 'Reading Plant',
      'coloringReadingLamp': 'Reading Lamp',
      'other': 'Region',
    });
    return '$_temp0';
  }
}
