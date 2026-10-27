// GENERATED CODE - DO NOT MODIFY BY HAND.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Room model setup: Use my photo
  ///
  /// In en, this message translates to:
  /// **'Use my photo'**
  String get roomUsePhoto;

  /// Room model setup: Try an Illustrated Room
  ///
  /// In en, this message translates to:
  /// **'Try an Illustrated Room'**
  String get roomTryIllustrated;

  /// Room model setup: Set up Room photo analysis
  ///
  /// In en, this message translates to:
  /// **'Set up Room photo analysis'**
  String get roomSetupTitle;

  /// Room model setup: Download the optional AI models to find surfaces in your room photo.
  ///
  /// In en, this message translates to:
  /// **'Download the optional AI models to find surfaces in your room photo.'**
  String get roomSetupIntro;

  /// Room model setup: Your photo stays on this device. Downloading models uses the network but never uploads your photos.
  ///
  /// In en, this message translates to:
  /// **'Your photo stays on this device. Downloading models uses the network but never uploads your photos.'**
  String get roomSetupPrivacy;

  /// Room model setup: Once verified models are saved, room analysis works offline.
  ///
  /// In en, this message translates to:
  /// **'Once verified models are saved, room analysis works offline.'**
  String get roomSetupOffline;

  /// Room model setup: Download
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get roomSetupDownload;

  /// Room model setup: Later
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get roomSetupLater;

  /// Room model setup: Continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get roomSetupContinue;

  /// Room model setup: Retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get roomSetupRetry;

  /// Room model setup: Download paused. Your saved progress is kept; Retry resumes when possible.
  ///
  /// In en, this message translates to:
  /// **'Download paused. Your saved progress is kept; Retry resumes when possible.'**
  String get roomSetupCancelled;

  /// Room model setup: Could not download or verify the models. Check your connection, then retry. Your photo is safe.
  ///
  /// In en, this message translates to:
  /// **'Could not download or verify the models. Check your connection, then retry. Your photo is safe.'**
  String get roomSetupFailure;

  /// Room model setup: There is not enough storage space. Free some space on this device, then retry. Your photo is safe.
  ///
  /// In en, this message translates to:
  /// **'There is not enough storage space. Free some space on this device, then retry. Your photo is safe.'**
  String get roomSetupStorageFull;

  /// Room model setup: Verified models are saved on this device. Continue to choose your photo.
  ///
  /// In en, this message translates to:
  /// **'Verified models are saved on this device. Continue to choose your photo.'**
  String get roomSetupReady;

  /// Room model setup: Checking saved AI models…
  ///
  /// In en, this message translates to:
  /// **'Checking saved AI models…'**
  String get roomModelsChecking;

  /// Room model setup: Downloading AI models…
  ///
  /// In en, this message translates to:
  /// **'Downloading AI models…'**
  String get roomModelsDownloading;

  /// Room model setup: Verifying AI models…
  ///
  /// In en, this message translates to:
  /// **'Verifying AI models…'**
  String get roomModelsVerifying;

  /// Room model setup: Room surfaces
  ///
  /// In en, this message translates to:
  /// **'Room surfaces'**
  String get roomModelsSurfaces;

  /// Room model setup: Foreground depth protection
  ///
  /// In en, this message translates to:
  /// **'Foreground depth protection'**
  String get roomModelsDepth;

  /// Room model setup: Your photo stays on this device. Once models are saved, AI works offline.
  ///
  /// In en, this message translates to:
  /// **'Your photo stays on this device. Once models are saved, AI works offline.'**
  String get roomModelsPrivacyOffline;

  /// Room model setup: Room analysis uses the models saved on this device and works offline.
  ///
  /// In en, this message translates to:
  /// **'Room analysis uses the models saved on this device and works offline.'**
  String get roomModelsEditorOffline;

  /// Room model setup: {bytes} bytes · {mib} MiB
  ///
  /// In en, this message translates to:
  /// **'{bytes} bytes · {mib} MiB'**
  String roomSetupSize(String bytes, String mib);

  /// Room model setup: {received} / {total} MiB · {percent}%
  ///
  /// In en, this message translates to:
  /// **'{received} / {total} MiB · {percent}%'**
  String roomModelsProgress(String received, String total, String percent);

  /// Removal-specific error: independent file deletes can partially succeed before an I/O failure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove all Room models. Some downloaded model files may already have been removed. Refresh storage, then retry removal.'**
  String get modelsRemovalError;

  /// Refresh the model inventory after an operation or storage error.
  ///
  /// In en, this message translates to:
  /// **'Refresh storage'**
  String get modelsRefresh;

  /// Category for explicitly resetting preferences and replaying onboarding.
  ///
  /// In en, this message translates to:
  /// **'Appearance, accessibility, and welcome preferences'**
  String get dataPreferences;

  /// Dismiss a confirmation without making changes.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Settings: Accessibility
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get settingsAccessibility;

  /// Settings: Reduce motion
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get settingsReduceMotion;

  /// Settings: High contrast
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get settingsHighContrast;

  /// Settings: Always show color labels
  ///
  /// In en, this message translates to:
  /// **'Always show color labels'**
  String get settingsColorLabels;

  /// Settings: Privacy
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacyEntry;

  /// Settings: Manage local data
  ///
  /// In en, this message translates to:
  /// **'Manage local data'**
  String get settingsDataEntry;

  /// Settings: Model storage
  ///
  /// In en, this message translates to:
  /// **'Model storage'**
  String get settingsModelsEntry;

  /// Settings: Licenses
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get settingsLicensesEntry;

  /// Settings: Photos are processed on this device. Camera and photo access are optional and requested only when you choose those tools. Room photo analysis needs an optional model download; downloading models uses the network but does not upload your photos.
  ///
  /// In en, this message translates to:
  /// **'Photos are processed on this device. Camera and photo access are optional and requested only when you choose those tools. Room photo analysis needs an optional model download; downloading models uses the network but does not upload your photos.'**
  String get privacyBody;

  /// Settings: Saved colors, palettes, illustrated rooms, and game profiles stay on this device. Game profiles share the same color libraries. Switching or deleting a profile does not delete those libraries.
  ///
  /// In en, this message translates to:
  /// **'Saved colors, palettes, illustrated rooms, and game profiles stay on this device. Game profiles share the same color libraries. Switching or deleting a profile does not delete those libraries.'**
  String get privacyLibraries;

  /// Settings: You control which local data to delete. Exported images and photo acquisition metadata are excluded from these controls. Models can be downloaded again when you choose Room photo analysis.
  ///
  /// In en, this message translates to:
  /// **'You control which local data to delete. Exported images and photo acquisition metadata are excluded from these controls. Models can be downloaded again when you choose Room photo analysis.'**
  String get privacyControls;

  /// Settings: Select the data to review. Nothing is selected by default. Exported files and photo acquisition metadata are never included.
  ///
  /// In en, this message translates to:
  /// **'Select the data to review. Nothing is selected by default. Exported files and photo acquisition metadata are never included.'**
  String get dataIntro;

  /// Settings: Saved colors
  ///
  /// In en, this message translates to:
  /// **'Saved colors'**
  String get dataSavedColors;

  /// Settings: Saved palettes
  ///
  /// In en, this message translates to:
  /// **'Saved palettes'**
  String get dataSavedPalettes;

  /// Settings: Illustrated room designs
  ///
  /// In en, this message translates to:
  /// **'Illustrated room designs'**
  String get dataIllustratedRooms;

  /// Settings: All game profiles and legacy progress
  ///
  /// In en, this message translates to:
  /// **'All game profiles and legacy progress'**
  String get dataGames;

  /// Settings: Downloaded Room models
  ///
  /// In en, this message translates to:
  /// **'Downloaded Room models'**
  String get dataModels;

  /// Settings: Room photo projects
  ///
  /// In en, this message translates to:
  /// **'Room photo projects'**
  String get dataRoomProjects;

  /// Settings: Coloring projects
  ///
  /// In en, this message translates to:
  /// **'Coloring projects'**
  String get dataColoringProjects;

  /// Settings: Learning progress
  ///
  /// In en, this message translates to:
  /// **'Learning progress'**
  String get dataLearningProgress;

  /// Settings: Not available yet
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get dataUnavailable;

  /// Settings: Review selected data
  ///
  /// In en, this message translates to:
  /// **'Review selected data'**
  String get dataPreview;

  /// Settings: Review deletion
  ///
  /// In en, this message translates to:
  /// **'Review deletion'**
  String get dataReviewTitle;

  /// Settings: Continue to confirmation
  ///
  /// In en, this message translates to:
  /// **'Continue to confirmation'**
  String get dataContinue;

  /// Settings: Delete selected data?
  ///
  /// In en, this message translates to:
  /// **'Delete selected data?'**
  String get dataConfirmTitle;

  /// Settings: This cannot be undone. Only the reviewed categories will be deleted. Deleting all game data removes every local player and their progress; you can create a new player afterward.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Only the reviewed categories will be deleted. Deleting all game data removes every local player and their progress; you can create a new player afterward.'**
  String get dataConfirmBody;

  /// Settings: Delete reviewed data
  ///
  /// In en, this message translates to:
  /// **'Delete reviewed data'**
  String get dataDelete;

  /// Settings: Unable to complete this operation. Your selection is retained. Review the data again before retrying. A storage error during deletion may leave some selected data removed.
  ///
  /// In en, this message translates to:
  /// **'Unable to complete this operation. Your selection is retained. Review the data again before retrying. A storage error during deletion may leave some selected data removed.'**
  String get dataError;

  /// Settings: Selected data deleted.
  ///
  /// In en, this message translates to:
  /// **'Selected data deleted.'**
  String get dataSuccess;

  /// Settings: Room photo models are optional. Opening this screen does not download them. Removing models cancels any active download. Only model files and partial downloads are removed.
  ///
  /// In en, this message translates to:
  /// **'Room photo models are optional. Opening this screen does not download them. Removing models cancels any active download. Only model files and partial downloads are removed.'**
  String get modelsIntro;

  /// Settings: Remove downloaded models
  ///
  /// In en, this message translates to:
  /// **'Remove downloaded models'**
  String get modelsRemove;

  /// Settings: Remove Room models?
  ///
  /// In en, this message translates to:
  /// **'Remove Room models?'**
  String get modelsConfirm;

  /// Settings: No downloaded models.
  ///
  /// In en, this message translates to:
  /// **'No downloaded models.'**
  String get modelsEmpty;

  /// Settings: Model storage is unavailable. Try again.
  ///
  /// In en, this message translates to:
  /// **'Model storage is unavailable. Try again.'**
  String get modelsError;

  /// Settings: Room models removed.
  ///
  /// In en, this message translates to:
  /// **'Room models removed.'**
  String get modelsRemoved;

  /// Exact preview record count and estimated size.
  ///
  /// In en, this message translates to:
  /// **'{records} records · approximately {bytes} bytes'**
  String dataPreviewSummary(int records, int bytes);

  /// Stored Room revisions are storage detail, not additional project records.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 room project revision} other{{count} room project revisions}}'**
  String dataRoomProjectRevisionSummary(int count);

  /// Installed model inventory.
  ///
  /// In en, this message translates to:
  /// **'{files} model files · {bytes} bytes'**
  String modelsSummary(int files, int bytes);

  /// Compact product name shown inside the app.
  ///
  /// In en, this message translates to:
  /// **'TintAtlas'**
  String get appName;

  /// Full public product title used by stores and metadata.
  ///
  /// In en, this message translates to:
  /// **'TintAtlas: Room Visualizer'**
  String get storeTitle;

  /// Room model setup completion status.
  ///
  /// In en, this message translates to:
  /// **'Room Studio is ready'**
  String get roomStudioReady;

  /// Room model setup failure status.
  ///
  /// In en, this message translates to:
  /// **'Setup could not finish'**
  String get setupCouldNotFinish;

  /// Room model download status.
  ///
  /// In en, this message translates to:
  /// **'Downloading AI models…'**
  String get downloadingAiModels;

  /// Room model verification status.
  ///
  /// In en, this message translates to:
  /// **'Verifying AI models…'**
  String get verifyingAiModels;

  /// Room model startup check status.
  ///
  /// In en, this message translates to:
  /// **'Checking saved AI models…'**
  String get checkingSavedAiModels;

  /// Heading for the initial Room Studio model setup.
  ///
  /// In en, this message translates to:
  /// **'Room Studio setup'**
  String get roomStudioSetup;

  /// Whole-number setup progress percentage.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String progressPercent(int percent);

  /// Downloaded and total model sizes in mebibytes.
  ///
  /// In en, this message translates to:
  /// **'{received} / {total} MiB'**
  String downloadProgressMib(String received, String total);

  /// Recovery guidance after Room Studio setup fails.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and available storage, then retry. Verified files are kept.'**
  String get setupFailureHelp;

  /// Room model setup size and offline behavior explanation.
  ///
  /// In en, this message translates to:
  /// **'First setup downloads about 65.2 MiB. Saved models are checked automatically and work offline.'**
  String get setupDownloadHelp;

  /// Room photo privacy assurance.
  ///
  /// In en, this message translates to:
  /// **'Your room photos stay on this device.'**
  String get roomPhotosStayOnDevice;

  /// Button that retries Room Studio setup.
  ///
  /// In en, this message translates to:
  /// **'Retry setup'**
  String get retrySetup;

  /// Capture navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get captureDestination;

  /// Home navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeDestination;

  /// Rooms navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get roomsDestination;

  /// Color learning navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learnDestination;

  /// Palette navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get paletteDestination;

  /// Color Lab navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get labDestination;

  /// Room navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get roomDestination;

  /// Games navigation destination label.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get gamesDestination;

  /// Games empty-state heading shown before the first local player exists.
  ///
  /// In en, this message translates to:
  /// **'Create your player'**
  String get gamesCreatePlayerTitle;

  /// Games empty-state explanation for device-local named player progress.
  ///
  /// In en, this message translates to:
  /// **'Choose a local name before playing. Your levels, coins, scores, and badges stay with this player on this device.'**
  String get gamesCreatePlayerBody;

  /// Action that opens required first-player creation.
  ///
  /// In en, this message translates to:
  /// **'Create Player'**
  String get gamesCreatePlayerAction;

  /// Accessible action label for starting a named game.
  ///
  /// In en, this message translates to:
  /// **'Play {game}'**
  String gamesPlayNamedGame(String game);

  /// Accessible action label for resuming a named game.
  ///
  /// In en, this message translates to:
  /// **'Continue {game}'**
  String gamesContinueNamedGame(String game);

  /// Visible action label for starting a game.
  ///
  /// In en, this message translates to:
  /// **'Play game'**
  String get gamesPlayGame;

  /// Visible action label for resuming a game.
  ///
  /// In en, this message translates to:
  /// **'Continue game'**
  String get gamesContinueGame;

  /// Visible progress label while a game launch is being saved.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get gamesStartingGame;

  /// Accessible action label for replaying a completed level.
  ///
  /// In en, this message translates to:
  /// **'Replay level {level}'**
  String gameReplayLevel(int level);

  /// Accessible action label for starting the current level.
  ///
  /// In en, this message translates to:
  /// **'Play current level {level}'**
  String gamePlayCurrentLevel(int level);

  /// Visible label beneath the current level node.
  ///
  /// In en, this message translates to:
  /// **'Play Level {level}'**
  String gamePlayLevel(int level);

  /// Visible label for an earned level milestone badge.
  ///
  /// In en, this message translates to:
  /// **'Badge earned'**
  String get gameBadgeEarned;

  /// Accessibility label for a root navigation tab.
  ///
  /// In en, this message translates to:
  /// **'{destination} tab'**
  String destinationTab(String destination);

  /// Tooltip for opening appearance settings.
  ///
  /// In en, this message translates to:
  /// **'Appearance settings'**
  String get appearanceSettings;

  /// Eyebrow on the Home screen.
  ///
  /// In en, this message translates to:
  /// **'ROOM-FIRST COLOR'**
  String get homeEyebrow;

  /// Primary Home screen heading.
  ///
  /// In en, this message translates to:
  /// **'See your space in a new color.'**
  String get homeTitle;

  /// Home screen product explanation.
  ///
  /// In en, this message translates to:
  /// **'Try an illustrated room instantly, then explore color learning and games at your own pace.'**
  String get homeDescription;

  /// Sample-room quick-start heading.
  ///
  /// In en, this message translates to:
  /// **'Start with a sample room'**
  String get homeSampleTitle;

  /// Sample-room quick-start explanation.
  ///
  /// In en, this message translates to:
  /// **'No photo, permission, or AI model download is needed.'**
  String get homeSampleBody;

  /// Button that opens the sample living room.
  ///
  /// In en, this message translates to:
  /// **'Try a living room'**
  String get homeTrySampleRoom;

  /// Recent-activity section title on Home.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get homeContinueTitle;

  /// Home placeholder when no resumable activity exists.
  ///
  /// In en, this message translates to:
  /// **'Nothing to continue yet. Your next room, lesson, or game will appear here.'**
  String get homeContinueEmpty;

  /// Disabled Continue placeholder action.
  ///
  /// In en, this message translates to:
  /// **'Nothing to continue yet'**
  String get homeNothingToContinue;

  /// Home card title for Room Studio.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get homeRoomsTitle;

  /// Home Rooms card description.
  ///
  /// In en, this message translates to:
  /// **'Visualize your own photo or recolor an illustrated room.'**
  String get homeRoomsBody;

  /// Home card title for color learning.
  ///
  /// In en, this message translates to:
  /// **'Learn Color'**
  String get homeLearnTitle;

  /// Home Learn card description.
  ///
  /// In en, this message translates to:
  /// **'Study color through guided tools and practical experiments.'**
  String get homeLearnBody;

  /// Home card title for games.
  ///
  /// In en, this message translates to:
  /// **'Color Games'**
  String get homeGamesTitle;

  /// Home Games card description.
  ///
  /// In en, this message translates to:
  /// **'Practice, solve, and relax with optional color-focused play.'**
  String get homeGamesBody;

  /// Home card title for the local shared library.
  ///
  /// In en, this message translates to:
  /// **'My Work'**
  String get homeMyWorkTitle;

  /// Home My Work card description.
  ///
  /// In en, this message translates to:
  /// **'Find your saved colors, palettes, and illustrated designs.'**
  String get homeMyWorkBody;

  /// Eyebrow on the Learn screen.
  ///
  /// In en, this message translates to:
  /// **'COLOR LEARNING'**
  String get learnEyebrow;

  /// Primary Learn screen heading.
  ///
  /// In en, this message translates to:
  /// **'Learn color by trying it.'**
  String get learnTitle;

  /// Learn screen explanation.
  ///
  /// In en, this message translates to:
  /// **'Use real tools to explore perception, relationships, mixing, and practical color choices.'**
  String get learnDescription;

  /// Guided learning section heading.
  ///
  /// In en, this message translates to:
  /// **'Learn with color'**
  String get learnGuidedTitle;

  /// Color experiment section heading.
  ///
  /// In en, this message translates to:
  /// **'Experiment'**
  String get learnExperimentTitle;

  /// Link to the vision plate learning tool.
  ///
  /// In en, this message translates to:
  /// **'Explore vision plates'**
  String get learnOpenVision;

  /// Link to color matching practice.
  ///
  /// In en, this message translates to:
  /// **'Practice color matching'**
  String get learnOpenMatching;

  /// Link to the camera and photo color tool.
  ///
  /// In en, this message translates to:
  /// **'Capture a color'**
  String get learnOpenCapture;

  /// Link to the saved color library.
  ///
  /// In en, this message translates to:
  /// **'Open saved colors'**
  String get learnOpenPalette;

  /// Link to the HSL Color Lab.
  ///
  /// In en, this message translates to:
  /// **'Open Color Lab'**
  String get learnOpenLab;

  /// Link to the color mixer.
  ///
  /// In en, this message translates to:
  /// **'Mix colors'**
  String get learnOpenMixer;

  /// Link to the color formula tool.
  ///
  /// In en, this message translates to:
  /// **'Build a color formula'**
  String get learnOpenFormula;

  /// Link to the harmony tool.
  ///
  /// In en, this message translates to:
  /// **'Explore color harmonies'**
  String get learnOpenHarmonies;

  /// Link from Learn to My Work.
  ///
  /// In en, this message translates to:
  /// **'Review My Work'**
  String get learnOpenMyWork;

  /// Eyebrow on the My Work screen.
  ///
  /// In en, this message translates to:
  /// **'SAVED ON THIS DEVICE'**
  String get myWorkEyebrow;

  /// My Work screen heading.
  ///
  /// In en, this message translates to:
  /// **'My Work'**
  String get myWorkTitle;

  /// My Work local ownership explanation.
  ///
  /// In en, this message translates to:
  /// **'Your shared color library stays on this installation and is separate from game profiles.'**
  String get myWorkDescription;

  /// Saved colors section title in My Work.
  ///
  /// In en, this message translates to:
  /// **'Saved colors'**
  String get myWorkColorsTitle;

  /// Saved palettes section title in My Work.
  ///
  /// In en, this message translates to:
  /// **'Saved palettes'**
  String get myWorkPalettesTitle;

  /// Saved room designs section title in My Work.
  ///
  /// In en, this message translates to:
  /// **'Illustrated room designs'**
  String get myWorkRoomDesignsTitle;

  /// Loading title for saved colors.
  ///
  /// In en, this message translates to:
  /// **'Loading saved colors'**
  String get myWorkColorsLoading;

  /// Loading title for saved palettes.
  ///
  /// In en, this message translates to:
  /// **'Loading saved palettes'**
  String get myWorkPalettesLoading;

  /// Loading title for saved room designs.
  ///
  /// In en, this message translates to:
  /// **'Loading room designs'**
  String get myWorkRoomDesignsLoading;

  /// Independent library loading explanation.
  ///
  /// In en, this message translates to:
  /// **'Your other libraries remain available while this section loads.'**
  String get myWorkLoadingBody;

  /// Friendly saved colors load error.
  ///
  /// In en, this message translates to:
  /// **'Saved colors couldn\'t be loaded'**
  String get myWorkColorsError;

  /// Friendly saved palettes load error.
  ///
  /// In en, this message translates to:
  /// **'Saved palettes couldn\'t be loaded'**
  String get myWorkPalettesError;

  /// Friendly saved room designs load error.
  ///
  /// In en, this message translates to:
  /// **'Room designs couldn\'t be loaded'**
  String get myWorkRoomDesignsError;

  /// Independent library error recovery explanation.
  ///
  /// In en, this message translates to:
  /// **'This section can be retried without changing your other work.'**
  String get myWorkErrorBody;

  /// Empty saved colors title.
  ///
  /// In en, this message translates to:
  /// **'No saved colors yet'**
  String get myWorkColorsEmpty;

  /// Empty saved colors guidance.
  ///
  /// In en, this message translates to:
  /// **'Capture, enter, or explore a color to keep it here.'**
  String get myWorkColorsEmptyBody;

  /// Empty saved palettes title.
  ///
  /// In en, this message translates to:
  /// **'No saved palettes yet'**
  String get myWorkPalettesEmpty;

  /// Empty saved palettes guidance.
  ///
  /// In en, this message translates to:
  /// **'Save a harmony when you find a combination you like.'**
  String get myWorkPalettesEmptyBody;

  /// Empty saved room designs title.
  ///
  /// In en, this message translates to:
  /// **'No illustrated designs yet'**
  String get myWorkRoomDesignsEmpty;

  /// Empty saved room designs guidance.
  ///
  /// In en, this message translates to:
  /// **'Recolor an illustrated room and save the design to keep it here.'**
  String get myWorkRoomDesignsEmptyBody;

  /// Action from empty saved colors.
  ///
  /// In en, this message translates to:
  /// **'Explore colors'**
  String get myWorkExploreColors;

  /// Action from empty saved palettes.
  ///
  /// In en, this message translates to:
  /// **'Create a palette'**
  String get myWorkCreatePalette;

  /// Action from empty saved room designs.
  ///
  /// In en, this message translates to:
  /// **'Try an illustrated room'**
  String get myWorkTryRoom;

  /// Fallback label for an unavailable saved room template.
  ///
  /// In en, this message translates to:
  /// **'Room template temporarily unavailable'**
  String get myWorkUnavailableRoom;

  /// Unknown-route recovery heading.
  ///
  /// In en, this message translates to:
  /// **'That page isn\'t available'**
  String get routeUnavailableTitle;

  /// Unknown-route recovery guidance.
  ///
  /// In en, this message translates to:
  /// **'Return Home and choose another TintAtlas tool.'**
  String get routeUnavailableBody;

  /// Button that recovers to the Home root.
  ///
  /// In en, this message translates to:
  /// **'Return Home'**
  String get returnHome;

  /// Button that skips the welcome tour.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Current welcome-tour page and total page count.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStep(int current, int total);

  /// Button that returns to the previous tour page.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Button that retries a failed action.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Button that closes a replayed welcome tour.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Button that completes first-run onboarding.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// Button that advances the welcome tour.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Eyebrow for the color discovery tour slide.
  ///
  /// In en, this message translates to:
  /// **'A CURIOUS EYE'**
  String get onboardingCuriousEyeEyebrow;

  /// Title for the color discovery tour slide.
  ///
  /// In en, this message translates to:
  /// **'Find your next shade.'**
  String get onboardingCuriousEyeTitle;

  /// Body for the color discovery tour slide.
  ///
  /// In en, this message translates to:
  /// **'Explore colors from a camera moment or favorite photo. Try wall colors in Rooms, including illustrated rooms you can use offline.'**
  String get onboardingCuriousEyeBody;

  /// Supporting note for the color discovery tour slide.
  ///
  /// In en, this message translates to:
  /// **'Explore a shade. Discover its name and color codes.'**
  String get onboardingCuriousEyeNote;

  /// Eyebrow for the saved library tour slide.
  ///
  /// In en, this message translates to:
  /// **'MAKE IT PERSONAL'**
  String get onboardingPersonalEyebrow;

  /// Title for the saved library tour slide.
  ///
  /// In en, this message translates to:
  /// **'A little library of you.'**
  String get onboardingPersonalTitle;

  /// Body for the saved library tour slide.
  ///
  /// In en, this message translates to:
  /// **'Save shades and palettes in My Work. Explore color in Learn and practice with Games. Your libraries are shared across local game profiles.'**
  String get onboardingPersonalBody;

  /// Supporting note for the saved library tour slide.
  ///
  /// In en, this message translates to:
  /// **'Your saved colors stay on this device.'**
  String get onboardingPersonalNote;

  /// Eyebrow for the privacy and control tour slide.
  ///
  /// In en, this message translates to:
  /// **'ON YOUR TERMS'**
  String get onboardingControlEyebrow;

  /// Title for the privacy and control tour slide.
  ///
  /// In en, this message translates to:
  /// **'Your curiosity. Your control.'**
  String get onboardingControlTitle;

  /// Body for the privacy and control tour slide.
  ///
  /// In en, this message translates to:
  /// **'Photos are processed on this device. Camera and photo permissions are optional. Room photo analysis offers an optional model download when you choose it.'**
  String get onboardingControlBody;

  /// Supporting note for the privacy and control tour slide.
  ///
  /// In en, this message translates to:
  /// **'Skip anytime. Replay this tour from Settings. No permission is needed to take this tour.'**
  String get onboardingControlNote;

  /// Recoverable error shown when onboarding completion cannot be saved.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t finish the tour. Please try again.'**
  String get tourFinishError;

  /// Heading shown when local preferences cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your preferences'**
  String get preferencesLoadErrorTitle;

  /// Reassurance and recovery guidance after preferences fail to load.
  ///
  /// In en, this message translates to:
  /// **'Your saved colors haven\'t been changed. Please try again.'**
  String get preferencesLoadErrorBody;

  /// Startup status while local preferences load.
  ///
  /// In en, this message translates to:
  /// **'Loading your preferences…'**
  String get loadingPreferences;

  /// Recoverable error shown when appearance preferences cannot be saved.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your appearance. Try again.'**
  String get settingsSaveError;

  /// Appearance section heading.
  ///
  /// In en, this message translates to:
  /// **'Make yourself at home'**
  String get settingsAppearanceTitle;

  /// Appearance section supporting text.
  ///
  /// In en, this message translates to:
  /// **'Choose your canvas.'**
  String get settingsAppearanceSubtitle;

  /// Accessibility label for closing settings.
  ///
  /// In en, this message translates to:
  /// **'Close settings'**
  String get closeSettings;

  /// Theme option that follows the operating system.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeFollowSystem;

  /// Light theme option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Live status while an appearance preference is saving.
  ///
  /// In en, this message translates to:
  /// **'Saving appearance…'**
  String get savingAppearance;

  /// Appearance preference storage assurance.
  ///
  /// In en, this message translates to:
  /// **'Your choice is saved on this device.'**
  String get appearanceSavedOnDevice;

  /// Welcome-tour settings section heading.
  ///
  /// In en, this message translates to:
  /// **'A little orientation'**
  String get settingsOrientationTitle;

  /// Welcome-tour settings section supporting text.
  ///
  /// In en, this message translates to:
  /// **'A fresh look at the basics, whenever you like.'**
  String get settingsOrientationSubtitle;

  /// Button that opens the welcome tour again.
  ///
  /// In en, this message translates to:
  /// **'Replay welcome tour'**
  String get replayWelcomeTour;

  /// Local-data privacy section heading.
  ///
  /// In en, this message translates to:
  /// **'Your colors stay yours'**
  String get settingsPrivacyTitle;

  /// Local-data privacy explanation.
  ///
  /// In en, this message translates to:
  /// **'Photos, saved colors and preferences stay on your device. No account or cloud upload is needed.'**
  String get settingsPrivacySubtitle;

  /// Label that opens product information and open-source licenses.
  ///
  /// In en, this message translates to:
  /// **'About {appName} & licenses'**
  String aboutAndLicenses(String appName);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
