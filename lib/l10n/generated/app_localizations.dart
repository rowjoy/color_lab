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

  /// Illustrated room comparison section.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get roomCompare;

  /// Copy the editable colors into comparison baseline A.
  ///
  /// In en, this message translates to:
  /// **'Pin current colors as A'**
  String get roomComparePin;

  /// Display pinned comparison colors.
  ///
  /// In en, this message translates to:
  /// **'A · Pinned colors'**
  String get roomCompareA;

  /// Dismiss the temporary comparison.
  ///
  /// In en, this message translates to:
  /// **'Current colors'**
  String get roomCompareCurrent;

  /// Show last saved colors or grayscale for a new design.
  ///
  /// In en, this message translates to:
  /// **'Original · Last saved colors'**
  String get roomCompareOriginal;

  /// Temporary grayscale comparison, preserving edits.
  ///
  /// In en, this message translates to:
  /// **'Black & white preview'**
  String get roomCompareGrayscale;

  /// Compare a copied saved design.
  ///
  /// In en, this message translates to:
  /// **'B · {name}'**
  String roomCompareVariant(String name);

  /// Explains non-destructive comparison behavior.
  ///
  /// In en, this message translates to:
  /// **'Comparisons preserve your edits. Original shows your last saved colors, or black & white for a new design.'**
  String get roomCompareHint;

  /// Clean illustrated room output dimensions.
  ///
  /// In en, this message translates to:
  /// **'Room PNG · 2400 × 1600'**
  String get roomExportArtwork;

  /// Separate palette card with content-sized height.
  ///
  /// In en, this message translates to:
  /// **'Palette card · 1200 px wide'**
  String get roomExportPaletteCard;

  /// Export comparison selection policy.
  ///
  /// In en, this message translates to:
  /// **'Exports the view shown now. The palette card is available for colored views.'**
  String get roomExportDisplayed;

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

  /// Unsupported recoverable room revision or region snapshot. No ineffective retry action is offered.
  ///
  /// In en, this message translates to:
  /// **'A draft from a newer app version can’t be opened yet. It is kept safely on this device.'**
  String get roomDraftUnavailable;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Choose a Look → Change a Surface → Save'**
  String get roomEditFlow;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Choose a Look'**
  String get roomChooseLook;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Change a Surface'**
  String get roomChangeSurface;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Apply Complete Look'**
  String get roomApplyCompleteLook;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Preview — apply to change your room'**
  String get roomLookPreview;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get roomSave;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get roomUpdate;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Save a Copy'**
  String get roomSaveCopy;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'My Designs'**
  String get roomMyDesigns;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'My Palettes'**
  String get roomMyPalettes;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get roomUndo;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get roomRedo;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get roomSaving;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get roomSaved;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Draft could not be saved. Your changes are still here.'**
  String get roomDraftFailed;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get roomRetry;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get roomCustomColor;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get roomClose;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'No saved palettes yet.'**
  String get roomNoPalettes;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Could not load your palettes.'**
  String get roomPalettesFailed;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get roomLoading;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Back wall'**
  String get roomWallBack;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Side wall'**
  String get roomWallSide;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Accent wall'**
  String get roomWallAccent;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Desk'**
  String get roomDesk;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Chair'**
  String get roomChair;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Shelves'**
  String get roomShelves;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get roomConsole;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Sofa'**
  String get roomSofa;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Accent chair'**
  String get roomAccentChair;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Coffee table'**
  String get roomCoffeeTable;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Wardrobe'**
  String get roomWardrobe;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Left bedside table'**
  String get roomBedsideTableLeft;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Right bedside table'**
  String get roomBedsideTableRight;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Bed'**
  String get roomBed;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Sideboard'**
  String get roomSideboard;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Back left chair'**
  String get roomChairBackLeft;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Back right chair'**
  String get roomChairBackRight;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Front left chair'**
  String get roomChairFrontLeft;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Front right chair'**
  String get roomChairFrontRight;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Dining table'**
  String get roomDiningTable;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Upper left cabinets'**
  String get roomCabinetUpperLeft;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Lower left cabinets'**
  String get roomCabinetLowerLeft;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Upper right cabinets'**
  String get roomCabinetUpperRight;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Lower right cabinets'**
  String get roomCabinetLowerRight;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Island'**
  String get roomIsland;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Vanity'**
  String get roomVanity;

  /// Localized illustrated-room region label.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get roomStorage;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'All Walls'**
  String get roomWalls;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get roomCeiling;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get roomFloor;

  /// Illustrated room editor control or accessible surface label.
  ///
  /// In en, this message translates to:
  /// **'Furniture'**
  String get roomFurniture;

  /// No description provided for @roomSelectedSurface.
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String roomSelectedSurface(String name);

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

  /// Initial name of a newly saved real-photo Room project.
  ///
  /// In en, this message translates to:
  /// **'My room'**
  String get roomProjectDefaultName;

  /// Initial color variant name for a real-photo Room project.
  ///
  /// In en, this message translates to:
  /// **'Original colors'**
  String get roomProjectDefaultVariant;

  /// Accessible live status while completed Room edits are saving.
  ///
  /// In en, this message translates to:
  /// **'Saving project…'**
  String get roomProjectSaving;

  /// Status only when all visible completed Room edits are acknowledged on disk.
  ///
  /// In en, this message translates to:
  /// **'Project saved'**
  String get roomProjectSaved;

  /// Safe Room storage error; the visible draft remains editable.
  ///
  /// In en, this message translates to:
  /// **'Project not saved. Your edits are still here. Retry to save them.'**
  String get roomProjectSaveFailed;

  /// A stale Room save never silently overwrites another committed revision.
  ///
  /// In en, this message translates to:
  /// **'Project changed elsewhere. Your edits are still here, but could not be saved. Reopen the project to use its saved version.'**
  String get roomProjectSaveConflict;

  /// Bounded Room storage cannot accept another revision.
  ///
  /// In en, this message translates to:
  /// **'This project has reached its storage limit. Your latest edits are still here but are not saved.'**
  String get roomProjectSaveLimit;

  /// Retry persisting the latest visible Room draft, separate from AI analysis.
  ///
  /// In en, this message translates to:
  /// **'Retry save'**
  String get roomProjectRetrySave;

  /// Honest notice for an editable Room with no available AI masks.
  ///
  /// In en, this message translates to:
  /// **'Manual mode: automatic masks are unavailable. Mark surfaces to preview colors, or retry analysis.'**
  String get roomManualModeNotice;

  /// Create an aligned blank mask project from the prepared photo when AI fails.
  ///
  /// In en, this message translates to:
  /// **'Edit manually'**
  String get roomEditManually;

  /// Explicitly discard a prepared Room photo, separate from stopping analysis or model download.
  ///
  /// In en, this message translates to:
  /// **'Discard photo'**
  String get roomDiscardPhoto;

  /// Retry AI analysis while preserving manual corrections through reanalysis.
  ///
  /// In en, this message translates to:
  /// **'Retry analysis'**
  String get roomRetryAnalysis;

  /// Recoverable AI failure after preparing a room photo.
  ///
  /// In en, this message translates to:
  /// **'Room analysis could not finish. Try again or choose another photo.'**
  String get roomAnalysisFailed;

  /// Explicit consequence before replacing a Room draft whose latest edits are not acknowledged.
  ///
  /// In en, this message translates to:
  /// **'This project has unsaved edits. If you continue and open the new photo, those edits will be discarded. Its last saved version stays on this device.'**
  String get roomProjectReplaceUnsaved;

  /// Title and entry label for the local real-photo project library.
  ///
  /// In en, this message translates to:
  /// **'Room projects'**
  String get roomProjectsTitle;

  /// Local ownership description in Rooms and My Work.
  ///
  /// In en, this message translates to:
  /// **'Your editable room photos, masks and colors stay on this device.'**
  String get roomProjectsDescription;

  /// Library loading status.
  ///
  /// In en, this message translates to:
  /// **'Loading room projects…'**
  String get roomProjectsLoading;

  /// Empty local real-room library title.
  ///
  /// In en, this message translates to:
  /// **'No room projects yet'**
  String get roomProjectsEmpty;

  /// All known projects are unreadable; this does not claim the library was empty.
  ///
  /// In en, this message translates to:
  /// **'No readable room projects'**
  String get roomProjectsNoneReadable;

  /// Empty library next steps.
  ///
  /// In en, this message translates to:
  /// **'Use a room photo to create an editable project, or try an Illustrated Room.'**
  String get roomProjectsEmptyBody;

  /// Safe library read failure title.
  ///
  /// In en, this message translates to:
  /// **'Room projects could not be loaded'**
  String get roomProjectsError;

  /// Safe read failure recovery guidance.
  ///
  /// In en, this message translates to:
  /// **'Your local files have not been removed. Try loading the library again.'**
  String get roomProjectsRetryBody;

  /// Library warning when corrupt records are isolated.
  ///
  /// In en, this message translates to:
  /// **'Some projects could not be read. Your other projects are shown, and the unreadable files have been kept.'**
  String get roomProjectsCorrupt;

  /// Reload project summaries without replacing the repository owner.
  ///
  /// In en, this message translates to:
  /// **'Refresh projects'**
  String get roomProjectsRefresh;

  /// Project last update with locale-formatted date.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String roomProjectUpdated(String date);

  /// Thumbnail accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Photo preview for {name}'**
  String roomProjectThumbnail(String name);

  /// Visible and accessible missing/corrupt thumbnail fallback.
  ///
  /// In en, this message translates to:
  /// **'Photo preview unavailable for {name}'**
  String roomProjectThumbnailUnavailable(String name);

  /// Warning retained until a successful repairing project save.
  ///
  /// In en, this message translates to:
  /// **'Recovered an earlier saved version. Some later changes could not be read. The original files have been kept.'**
  String get roomProjectRecovered;

  /// Thumbnail-only recovery warning.
  ///
  /// In en, this message translates to:
  /// **'The photo preview could not be read. Your editable photo and masks are available.'**
  String get roomProjectThumbnailWarning;

  /// Open a stored room project.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get roomProjectOpen;

  /// Accessible named project Open action.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String roomProjectOpenLabel(String name);

  /// Continue the active room draft without reopening it.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get roomProjectContinue;

  /// Accessible active draft action.
  ///
  /// In en, this message translates to:
  /// **'Continue {name}'**
  String roomProjectContinueLabel(String name);

  /// Accessible card menu label.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String roomProjectMenu(String name);

  /// Rename a real-room project.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get roomProjectRename;

  /// Editable project name field label.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get roomProjectName;

  /// Bounded project name validation.
  ///
  /// In en, this message translates to:
  /// **'Use 1–80 characters, with no control characters.'**
  String get roomProjectNameInvalid;

  /// Create an independent local copy of a room project.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get roomProjectDuplicate;

  /// Honest name of an independent project copy. Keep the suffix short enough for an 80-character name.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String roomProjectCopyName(String name);

  /// Color comparison action, disabled until comparison is implemented.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get roomProjectCompare;

  /// Honest boundary for the disabled comparison action.
  ///
  /// In en, this message translates to:
  /// **'Comparison is not available yet.'**
  String get roomProjectCompareUnavailable;

  /// Delete only the selected local room project.
  ///
  /// In en, this message translates to:
  /// **'Delete project'**
  String get roomProjectDelete;

  /// Explicit selected project deletion confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String roomProjectDeleteTitle(String name);

  /// Precise local-only deletion consequence and active draft authorization.
  ///
  /// In en, this message translates to:
  /// **'This removes this project’s local working photo, masks and color variants, including any unsaved edits. Images already saved or shared outside the app are not removed. Other projects stay on this device.'**
  String get roomProjectDeleteBody;

  /// Dismiss a project action without changes.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get roomProjectCancel;

  /// Safe guidance for an incompatible busy operation.
  ///
  /// In en, this message translates to:
  /// **'A project action is in progress. Wait for it to finish, then try again.'**
  String get roomProjectActionBusy;

  /// Preserve a saving, failed or conflicted session rather than bypassing it.
  ///
  /// In en, this message translates to:
  /// **'Continue your current project and wait for Project saved, or retry saving its edits, before changing another project. Your visible edits are still here.'**
  String get roomProjectActionUnsaved;

  /// CAS conflict without automatic rebase or false success.
  ///
  /// In en, this message translates to:
  /// **'This project changed since this list was loaded. Refresh the library and review its saved version before trying again. Your current draft has been kept.'**
  String get roomProjectActionConflict;

  /// Safe missing/corrupt/invalid project failure.
  ///
  /// In en, this message translates to:
  /// **'This project is missing or could not be read. Return to the library or try again. Any current draft has been kept.'**
  String get roomProjectActionUnavailable;

  /// Generic safe storage failure without raw exception or paths.
  ///
  /// In en, this message translates to:
  /// **'The project action could not be completed. Check available device storage and try again.'**
  String get roomProjectActionStorage;

  /// Bounded project storage or collision failure.
  ///
  /// In en, this message translates to:
  /// **'This project action reached a storage or identifier limit. Refresh the library and try again.'**
  String get roomProjectActionLimit;

  /// Loading state while reconstructing a saved editor.
  ///
  /// In en, this message translates to:
  /// **'Opening room project…'**
  String get roomProjectOpening;

  /// Saved project deep-link recovery title.
  ///
  /// In en, this message translates to:
  /// **'Room project could not be opened'**
  String get roomProjectOpenError;

  /// Busy state for project actions.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get roomProjectWorking;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Color variants'**
  String get roomVariantsTitle;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Create variant'**
  String get roomVariantCreate;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Rename variant'**
  String get roomVariantRename;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Delete variant'**
  String get roomVariantDelete;

  /// Confirmation title naming the color alternative to delete.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String roomVariantDeleteTitle(String name);

  /// Scope of deleting one color variant.
  ///
  /// In en, this message translates to:
  /// **'This removes the “{name}” color alternative. The project photo, masks, and other variants remain.'**
  String roomVariantDeleteConsequence(String name);

  /// Named deterministic survivor after deleting the active variant.
  ///
  /// In en, this message translates to:
  /// **'The selected variant will switch to “{name}”.'**
  String roomVariantDeleteSelection(String name);

  /// Consequence of deleting the pinned comparison variant.
  ///
  /// In en, this message translates to:
  /// **'This is the pinned baseline. Comparison will be cleared.'**
  String get roomVariantDeleteBaseline;

  /// Safe feedback when a deletion confirmation has become stale.
  ///
  /// In en, this message translates to:
  /// **'The project or variants changed while this confirmation was open. Review the variant and try again.'**
  String get roomVariantDeleteChanged;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Pin as baseline'**
  String get roomVariantPin;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Variant name'**
  String get roomVariantName;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get roomVariantApply;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Use a name with 1–80 characters and no control characters.'**
  String get roomVariantInvalidName;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Choose a different name. Each variant needs a unique name.'**
  String get roomVariantDuplicateName;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'This project already has 32 variants. Delete one before creating another.'**
  String get roomVariantLimit;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one variant in this project.'**
  String get roomVariantFinal;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'This variant cannot be changed right now. Return to the project and try again.'**
  String get roomVariantUnavailable;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Clear comparison'**
  String get roomComparisonClear;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Create another variant to compare two color choices.'**
  String get roomComparisonNeedVariant;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Select a different variant to compare with the pinned baseline.'**
  String get roomComparisonSelectOther;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Pin a baseline and select another variant to compare. Color edits apply to the selected variant.'**
  String get roomComparisonGuide;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Compare variants'**
  String get roomComparisonTitle;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Original room photo'**
  String get roomComparisonOriginal;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Comparison divider'**
  String get roomComparisonDivider;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Comparison could not update. Your variants are safe.'**
  String get roomComparisonFailed;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Updating comparison…'**
  String get roomComparisonUpdating;

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'{letter} · {name}'**
  String roomVariantLabel(String letter, String name);

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'{label} · Selected'**
  String roomVariantSelected(String label);

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Baseline: {label}'**
  String roomVariantBaseline(String label);

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String roomComparisonActive(String name);

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'Baseline: {name}'**
  String roomComparisonBaseline(String name);

  /// Room variant and comparison control.
  ///
  /// In en, this message translates to:
  /// **'{percent}% selected variant'**
  String roomComparisonPosition(int percent);

  /// Label that opens product information and open-source licenses.
  ///
  /// In en, this message translates to:
  /// **'About {appName} & licenses'**
  String aboutAndLicenses(String appName);

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Display calibration, camera processing, lighting, wall texture, paint finish, surrounding colors, and variation in real paint can change how colors appear. Previews guide exploration and are not calibrated matches for buying paint.'**
  String get roomExportLimits;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'PNG · {width} × {height} pixels. Exported at the processed working resolution.'**
  String roomExportResolution(int width, int height);

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Export selected variant: {name}'**
  String roomExportSelected(String name);

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Save image adds an external image to Photos or Gallery. Share opens the system sheet. Neither action saves the editable project.'**
  String get roomExportEffects;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'This project has unsaved edits. Exporting an image does not save those edits.'**
  String get roomExportUnsaved;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'{appName} room preview'**
  String roomExportTitle(String appName);

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get roomExportSave;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Share PNG'**
  String get roomExportShare;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Preparing image…'**
  String get roomExportSaving;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Image added to Photos or Gallery.'**
  String get roomExportSaved;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'The share sheet completed.'**
  String get roomExportShared;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Share sheet dismissed.'**
  String get roomExportDismissed;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'The sharing result could not be determined.'**
  String get roomExportUnavailable;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Photo access is off. Allow access in Settings, then try saving again.'**
  String get roomExportAccess;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Storage is full. Free some space, then retry Save image. Check Photos or Gallery first; an image may already have been added.'**
  String get roomExportCapacity;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the image was saved. Check Photos or Gallery before retrying; an image may already have been added.'**
  String get roomExportSaveFailed;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Could not share the PNG. Try again.'**
  String get roomExportShareFailed;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'This preview could not be verified for export. Your photo and edits are safe. Retry the preview.'**
  String get roomExportInvalid;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Export was interrupted. Return to the current preview and try again.'**
  String get roomExportInterrupted;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get roomOpenSettings;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get roomTryAgain;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get roomChoosePhoto;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Choose another supported image'**
  String get roomChooseSupported;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Choose a smaller image'**
  String get roomChooseSmaller;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Retry preview'**
  String get roomRetryPreview;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Retry Save image'**
  String get roomRetrySaveImage;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Retry Share'**
  String get roomRetryShare;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Photo access is off. Allow access in Settings to continue.'**
  String get roomPhotoPermission;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'A camera is unavailable. Choose a photo from this device.'**
  String get roomCameraUnavailable;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'The photo picker is unavailable. Try again.'**
  String get roomPickerUnavailable;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'This format is not supported. Choose a JPEG, PNG, GIF, WebP, BMP, or TIFF image.'**
  String get roomPhotoUnsupported;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'This image could not be read. Choose another supported image.'**
  String get roomPhotoInvalid;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'This image is too large to process. Choose a smaller image.'**
  String get roomPhotoTooLarge;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be prepared. Choose another supported image.'**
  String get roomPhotoPreparation;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'The photo request could not be stored. Your prepared photo is kept when available. Retry the storage action.'**
  String get roomPhotoStorage;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Retry photo storage'**
  String get roomRetryPhotoStorage;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Automatic masks need model setup. Your photo is kept; set up the models or edit manually.'**
  String get roomModelUnavailable;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'The installed models could not analyze this photo. Your photo is kept; retry model setup or edit manually.'**
  String get roomModelIncompatible;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Automatic analysis returned unusable masks. Your photo is kept; retry analysis or edit manually.'**
  String get roomAnalysisInvalid;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Set up models'**
  String get roomModelSetupAction;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Preview could not update. Your photo and masks are safe.'**
  String get roomPreviewFailed;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Restore AI masks?'**
  String get roomRestoreTitle;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Your manual changes will be replaced by the original automatic masks. This clears the undo history.'**
  String get roomRestoreMessage;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get roomRestoreAction;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Replace room photo?'**
  String get roomReplaceTitle;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'After a new photo is analyzed successfully, it replaces these masks and their undo history. Your current masks stay available if you cancel or analysis fails.'**
  String get roomReplaceMessage;

  /// Room photo privacy, export, or typed recovery copy.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get roomDialogCancel;

  /// Original Soft Linen starter palette name.
  ///
  /// In en, this message translates to:
  /// **'Soft Linen'**
  String get illustratedPaletteSoftLinenName;

  /// Original Soft Linen starter palette description.
  ///
  /// In en, this message translates to:
  /// **'Soft neutrals with a deeper warm accent.'**
  String get illustratedPaletteSoftLinenDescription;

  /// Original Quiet Sage starter palette name.
  ///
  /// In en, this message translates to:
  /// **'Quiet Sage'**
  String get illustratedPaletteQuietSageName;

  /// Original Quiet Sage starter palette description.
  ///
  /// In en, this message translates to:
  /// **'Muted greens with a gentle neutral contrast.'**
  String get illustratedPaletteQuietSageDescription;

  /// Original Airy Slate starter palette name.
  ///
  /// In en, this message translates to:
  /// **'Airy Slate'**
  String get illustratedPaletteAirySlateName;

  /// Original Airy Slate starter palette description.
  ///
  /// In en, this message translates to:
  /// **'Pale cool tones with a deeper blue-gray accent.'**
  String get illustratedPaletteAirySlateDescription;

  /// Original Clay and Cream starter palette name.
  ///
  /// In en, this message translates to:
  /// **'Clay and Cream'**
  String get illustratedPaletteClayAndCreamName;

  /// Original Clay and Cream starter palette description.
  ///
  /// In en, this message translates to:
  /// **'Cream and earthy tones with a dark brown accent.'**
  String get illustratedPaletteClayAndCreamDescription;

  /// Original Mist and Ink starter palette name.
  ///
  /// In en, this message translates to:
  /// **'Mist and Ink'**
  String get illustratedPaletteMistAndInkName;

  /// Original Mist and Ink starter palette description.
  ///
  /// In en, this message translates to:
  /// **'Light gray and blue tones with a dark ink accent.'**
  String get illustratedPaletteMistAndInkDescription;

  /// Original Sunwashed Olive starter palette name.
  ///
  /// In en, this message translates to:
  /// **'Sunwashed Olive'**
  String get illustratedPaletteSunwashedOliveName;

  /// Original Sunwashed Olive starter palette description.
  ///
  /// In en, this message translates to:
  /// **'Warm yellow and olive tones with a deep green accent.'**
  String get illustratedPaletteSunwashedOliveDescription;

  /// Illustrated Room original palette guide copy.
  ///
  /// In en, this message translates to:
  /// **'Why these looks?'**
  String get illustratedPaletteGuideTitle;

  /// Illustrated Room original palette guide copy.
  ///
  /// In en, this message translates to:
  /// **'Close palette guide'**
  String get illustratedPaletteGuideClose;

  /// Illustrated Room original palette guide copy.
  ///
  /// In en, this message translates to:
  /// **'Original color combinations for exploring your room. Each palette supplies wall, ceiling, floor and furniture colors.'**
  String get illustratedPaletteGuideIntro;

  /// Illustrated Room original palette guide copy.
  ///
  /// In en, this message translates to:
  /// **'This is a non-calibrated display preview. Screen calibration, lighting, surface texture, paint finish and surrounding colors can change appearance. Compare physical samples in your room before buying paint.'**
  String get illustratedPalettePreviewLimit;

  /// Illustrated Room original palette guide copy.
  ///
  /// In en, this message translates to:
  /// **'Starting look'**
  String get illustratedPaletteRecommended;

  /// Illustrated Room original palette guide copy.
  ///
  /// In en, this message translates to:
  /// **'{name}, Starting look'**
  String illustratedPaletteRecommendedLabel(String name);

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Predict'**
  String get learningStepPredictTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Manipulate'**
  String get learningStepManipulateTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Observe'**
  String get learningStepObserveTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Explain'**
  String get learningStepExplainTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get learningStepApplyTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get learningStepCheckTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Use the labeled names, values, and controls; seeing a color difference is not required.'**
  String get learningNonVisualInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Try again as often as you like.'**
  String get learningRetryHint;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'HSL: hue angle, saturation, and lightness coordinates for an RGB color.'**
  String get learningGlossaryHsl;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'HSV: hue, saturation, and value; value is the brightest RGB channel.'**
  String get learningGlossaryHsv;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'RGB: encoded red, green, and blue display channels.'**
  String get learningGlossaryRgb;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'HEX: a compact written form of encoded RGB channel values.'**
  String get learningGlossaryHex;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'CIELAB: lightness and opponent-color coordinates computed here from sRGB.'**
  String get learningGlossaryLab;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'CMYK: a simplified digital conversion here, not a press or ink profile.'**
  String get learningGlossaryCmyk;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Delta-E: points of computed color difference, not diagnostic accuracy or a calibrated purchase match.'**
  String get learningGlossaryDeltaE;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Hue: a circular color-family angle; neutrals can have no visible hue.'**
  String get learningGlossaryHue;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Saturation: colorfulness relative to a gray at the same model coordinates.'**
  String get learningGlossarySaturation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Lightness and value use different model definitions and are not interchangeable.'**
  String get learningGlossaryLightnessValue;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Digital interpolation averages numerical color coordinates; it does not simulate material pigments.'**
  String get learningGlossaryDigitalInterpolation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Harmony: a repeatable hue relationship, not a guarantee that a palette is beautiful.'**
  String get learningGlossaryHarmony;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Color coordinates: several views of one color'**
  String get learningLessonCoordinatesTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Read one display color through HSL, RGB/HEX, LAB, and simplified CMYK coordinates.'**
  String get learningLessonCoordinatesSummary;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Predict which coordinates will change when you adjust one visible color.'**
  String get learningCoordinatesPredictInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Adjust hue, saturation, and lightness while reading the labeled HSL, RGB/HEX, LAB, and CMYK values.'**
  String get learningCoordinatesManipulateInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Compare the numbers. Delta-E points describe a computed difference; they do not diagnose vision or guarantee a physical match.'**
  String get learningCoordinatesObserveInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'RGB and HEX encode display channels; LAB and simplified CMYK describe the same digital color through different models.'**
  String get learningCoordinatesExplainInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Save a labeled color experiment. A generated formula is not a paint recipe, and a screen preview is not a purchase match.'**
  String get learningCoordinatesApplyInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Answer both questions, read each explanation, and retry freely.'**
  String get learningCoordinatesCheckInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Enter or adjust the labeled HSL values and read every resulting coordinate as text.'**
  String get learningCoordinatesManipulateNonVisual;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'What does a HEX color encode?'**
  String get learningCoordinatesQ1Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Encoded RGB display channels'**
  String get learningCoordinatesQ1ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'A physical paint formula'**
  String get learningCoordinatesQ1BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. HEX writes encoded red, green, and blue channel values.'**
  String get learningCoordinatesQ1AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. HEX describes display channels, not material ingredients.'**
  String get learningCoordinatesQ1BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'What do Delta-E points prove here?'**
  String get learningCoordinatesQ2Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'They certify exact paint and vision accuracy'**
  String get learningCoordinatesQ2ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'They describe a computed difference between color coordinates'**
  String get learningCoordinatesQ2BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. The number is not a diagnosis, calibration certificate, or purchase guarantee.'**
  String get learningCoordinatesQ2AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. Delta-E is a model-based distance that needs context.'**
  String get learningCoordinatesQ2BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Hue: the color-family angle'**
  String get learningLessonHueTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Change the circular hue coordinate while names and numbers keep the activity usable without color-only cues.'**
  String get learningLessonHueSummary;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Predict the named color family after moving the hue angle.'**
  String get learningHuePredictInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Adjust hue by slider, keyboard, or number and read its degree value and color-family label.'**
  String get learningHueManipulateInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Notice that the angle wraps around at 360 degrees and a neutral may show no visible hue.'**
  String get learningHueObserveInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Hue is a circular coordinate; it is not a measure of brightness or saturation.'**
  String get learningHueExplainInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Choose a hue for a labeled design intention and save the exact value.'**
  String get learningHueApplyInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Answer both questions, read each explanation, and retry freely.'**
  String get learningHueCheckInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Use the degree value and color-family label; no subtle visual comparison is required.'**
  String get learningHueManipulateNonVisual;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'What happens after hue reaches 360°?'**
  String get learningHueQ1Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'It wraps to 0° on the color circle'**
  String get learningHueQ1ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'It becomes maximum brightness'**
  String get learningHueQ1BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. Hue is circular, so 360° and 0° meet.'**
  String get learningHueQ1AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Hue angle does not set brightness.'**
  String get learningHueQ1BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'What does hue mainly identify?'**
  String get learningHueQ2Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'How light a color is'**
  String get learningHueQ2ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Its position around a color-family circle'**
  String get learningHueQ2BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Lightness is a separate coordinate.'**
  String get learningHueQ2AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. Hue identifies a circular family position.'**
  String get learningHueQ2BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Saturation: color versus gray'**
  String get learningLessonSaturationTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Explore saturation with labeled values while keeping hue and lightness separate.'**
  String get learningLessonSaturationSummary;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Predict whether lowering saturation moves the color toward a gray.'**
  String get learningSaturationPredictInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Adjust saturation with a labeled percentage while hue and lightness stay fixed.'**
  String get learningSaturationManipulateInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Read the same hue and lightness beside a changing saturation value.'**
  String get learningSaturationObserveInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'In HSL, saturation describes distance from a gray at that lightness; it is not brightness.'**
  String get learningSaturationExplainInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Choose a saturation for a muted or vivid intention and record the percentage.'**
  String get learningSaturationApplyInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Answer both questions, read each explanation, and retry freely.'**
  String get learningSaturationCheckInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Use the saturation percentage and muted/vivid text labels instead of judging intensity by sight.'**
  String get learningSaturationManipulateNonVisual;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'At 0% HSL saturation, what remains visible?'**
  String get learningSaturationQ1Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'The most vivid form of the hue'**
  String get learningSaturationQ1ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'A gray determined by lightness'**
  String get learningSaturationQ1BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Maximum vividness is not 0%.'**
  String get learningSaturationQ1AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. Zero saturation removes visible hue in HSL.'**
  String get learningSaturationQ1BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Does saturation mean brightness?'**
  String get learningSaturationQ2Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Yes, they are the same coordinate'**
  String get learningSaturationQ2ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'No, lightness/value describe different model dimensions'**
  String get learningSaturationQ2BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Saturation and brightness-like coordinates are separate.'**
  String get learningSaturationQ2AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. The model keeps saturation separate from lightness or value.'**
  String get learningSaturationQ2BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Lightness and value: two different scales'**
  String get learningLessonLightnessValueTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Compare HSL lightness with HSV value without treating the terms as interchangeable.'**
  String get learningLessonLightnessValueSummary;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Predict how an HSL lightness change affects the labeled RGB result.'**
  String get learningLightnessValuePredictInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Adjust HSL lightness and read both HSL lightness and computed HSV value.'**
  String get learningLightnessValueManipulateInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Notice that HSL lightness and HSV value can show different numbers for one RGB color.'**
  String get learningLightnessValueObserveInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'HSL lightness averages channel extremes; HSV value uses the brightest channel.'**
  String get learningLightnessValueExplainInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Record a lightness choice and its separate value reading for a design note.'**
  String get learningLightnessValueApplyInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Answer both questions, read each explanation, and retry freely.'**
  String get learningLightnessValueCheckInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Compare the printed HSL lightness and HSV value percentages rather than relying on appearance.'**
  String get learningLightnessValueManipulateNonVisual;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Are HSL lightness and HSV value interchangeable?'**
  String get learningLightnessValueQ1Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'No; their model definitions differ'**
  String get learningLightnessValueQ1ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Yes; they always have the same number'**
  String get learningLightnessValueQ1BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. They can describe one RGB color with different numbers.'**
  String get learningLightnessValueQ1AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. The models calculate these coordinates differently.'**
  String get learningLightnessValueQ1BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'What does HSV value use?'**
  String get learningLightnessValueQ2Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'The average of the lightest and darkest channel'**
  String get learningLightnessValueQ2ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'The brightest RGB channel'**
  String get learningLightnessValueQ2BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. That resembles the HSL lightness calculation.'**
  String get learningLightnessValueQ2AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. HSV value is based on the maximum RGB channel.'**
  String get learningLightnessValueQ2BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Digital mixing: average coordinates'**
  String get learningLessonDigitalMixingTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Mix weighted RGB or LAB values while keeping the result distinct from real pigment behavior.'**
  String get learningLessonDigitalMixingSummary;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Predict which weighted input will pull the numerical result closer.'**
  String get learningDigitalMixingPredictInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Change labeled color stops, weights, and RGB/LAB interpolation mode.'**
  String get learningDigitalMixingManipulateInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Read normalized percentages and the resulting HEX value for each digital method.'**
  String get learningDigitalMixingObserveInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Digital RGB/LAB interpolation is not pigment mixing; paint, ink, light, texture, and profiles can behave differently.'**
  String get learningDigitalMixingExplainInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Save the exact stops, weights, mode, result, and an observation in the notebook.'**
  String get learningDigitalMixingApplyInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Answer both questions, read each explanation, and retry freely.'**
  String get learningDigitalMixingCheckInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Use stop names, HEX values, weights, normalized percentages, and the result text.'**
  String get learningDigitalMixingManipulateNonVisual;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'What does this mixer simulate?'**
  String get learningDigitalMixingQ1Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Exact physical pigment chemistry'**
  String get learningDigitalMixingQ1ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Weighted interpolation of digital color coordinates'**
  String get learningDigitalMixingQ1BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. No material or spectral pigment model is used.'**
  String get learningDigitalMixingQ1AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. It averages numerical RGB or LAB coordinates.'**
  String get learningDigitalMixingQ1BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Does a heavier stop have more numerical influence?'**
  String get learningDigitalMixingQ2Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'No; weights are ignored'**
  String get learningDigitalMixingQ2ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Yes, after the weights are normalized'**
  String get learningDigitalMixingQ2BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Positive weights control the interpolation.'**
  String get learningDigitalMixingQ2AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. Normalized weights determine each stop\'s contribution.'**
  String get learningDigitalMixingQ2BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Palette relationships: structured starting points'**
  String get learningLessonPaletteRelationshipsTitle;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Explore named hue relationships without claiming that one rule guarantees a beautiful palette.'**
  String get learningLessonPaletteRelationshipsSummary;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Predict where a complementary, analogous, or triadic relationship places hues.'**
  String get learningPaletteRelationshipsPredictInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Choose a labeled base HEX value and harmony mode, then inspect the named swatches.'**
  String get learningPaletteRelationshipsManipulateInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Read each swatch\'s name, HEX value, role, and hue angle.'**
  String get learningPaletteRelationshipsObserveInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'A harmony scheme is a relationship rule, not a universal beauty rule; context, proportion, contrast, and culture still matter.'**
  String get learningPaletteRelationshipsExplainInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Copy a palette by value into an experiment or supported project and note its intended context.'**
  String get learningPaletteRelationshipsApplyInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Answer both questions, read each explanation, and retry freely.'**
  String get learningPaletteRelationshipsCheckInstruction;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Use the harmony mode, swatch order, roles, names, HEX values, and angles as the complete alternative.'**
  String get learningPaletteRelationshipsManipulateNonVisual;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'What does a harmony mode provide?'**
  String get learningPaletteRelationshipsQ1Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'A repeatable hue relationship'**
  String get learningPaletteRelationshipsQ1ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'A guarantee that every design is beautiful'**
  String get learningPaletteRelationshipsQ1BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. It is a structured relationship you can test in context.'**
  String get learningPaletteRelationshipsQ1AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. No palette rule can guarantee a universal judgment.'**
  String get learningPaletteRelationshipsQ1BExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'What else affects a palette in use?'**
  String get learningPaletteRelationshipsQ2Prompt;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Nothing; hue spacing is enough'**
  String get learningPaletteRelationshipsQ2ALabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Context, proportion, contrast, material, and surrounding colors'**
  String get learningPaletteRelationshipsQ2BLabel;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Not quite. A hue rule is only a starting point.'**
  String get learningPaletteRelationshipsQ2AExplanation;

  /// Color Foundations learning copy.
  ///
  /// In en, this message translates to:
  /// **'Correct. Real use depends on context and more than hue spacing.'**
  String get learningPaletteRelationshipsQ2BExplanation;

  /// Color Learning main curriculum section.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learningSectionLearn;

  /// Color Learning tools section.
  ///
  /// In en, this message translates to:
  /// **'Experiment'**
  String get learningSectionExperiment;

  /// Color Learning saved-work section.
  ///
  /// In en, this message translates to:
  /// **'My Work'**
  String get learningSectionMyWork;

  /// Start an untouched lesson.
  ///
  /// In en, this message translates to:
  /// **'Start lesson'**
  String get learningStartLesson;

  /// Resume a lesson at its durable stage.
  ///
  /// In en, this message translates to:
  /// **'Resume · {stage}'**
  String learningResumeStage(String stage);

  /// Completed lesson status.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get learningLessonComplete;

  /// Current lesson step.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String learningLessonProgress(int current, int total);

  /// Move to the previous lesson step.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get learningPrevious;

  /// Move to the next lesson step.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get learningNext;

  /// Mark a lesson complete after its checks.
  ///
  /// In en, this message translates to:
  /// **'Finish lesson'**
  String get learningFinish;

  /// Open contextual color definitions.
  ///
  /// In en, this message translates to:
  /// **'Glossary'**
  String get learningGlossary;

  /// Heading for a non-color-only activity route.
  ///
  /// In en, this message translates to:
  /// **'Text and controls alternative'**
  String get learningNonVisualAlternative;

  /// Labeled manipulation value.
  ///
  /// In en, this message translates to:
  /// **'Practice value: {value}%'**
  String learningPracticeValue(int value);

  /// Learning write failure that retains visible state.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save this change. Your visible work is kept.'**
  String get learningSaveError;

  /// Retry the retained learning draft.
  ///
  /// In en, this message translates to:
  /// **'Retry save'**
  String get learningRetrySave;

  /// Learning library loading title.
  ///
  /// In en, this message translates to:
  /// **'Opening Color Learning…'**
  String get learningLoadingTitle;

  /// Learning library loading body.
  ///
  /// In en, this message translates to:
  /// **'Your lessons and experiments stay on this device.'**
  String get learningLoadingBody;

  /// Learning library load error title.
  ///
  /// In en, this message translates to:
  /// **'Color Learning is unavailable'**
  String get learningLoadErrorTitle;

  /// Learning library load error body.
  ///
  /// In en, this message translates to:
  /// **'Your saved data was not erased. Try opening it again.'**
  String get learningLoadErrorBody;

  /// Saved color experiment screen title.
  ///
  /// In en, this message translates to:
  /// **'Experiment Notebook'**
  String get learningNotebookTitle;

  /// Saved color experiment screen description.
  ///
  /// In en, this message translates to:
  /// **'Reopen exact tool settings and keep your own observations.'**
  String get learningNotebookDescription;

  /// Empty experiment notebook title.
  ///
  /// In en, this message translates to:
  /// **'No saved experiments yet'**
  String get learningNotebookEmptyTitle;

  /// Empty experiment notebook explanation.
  ///
  /// In en, this message translates to:
  /// **'Save a result from Lab, Mixer, Harmonies, Formula, or Matching.'**
  String get learningNotebookEmptyBody;

  /// Open the experiment tools.
  ///
  /// In en, this message translates to:
  /// **'Open an experiment'**
  String get learningOpenExperiment;

  /// Open saved learning work.
  ///
  /// In en, this message translates to:
  /// **'Open Experiment Notebook'**
  String get learningOpenNotebook;

  /// Delete one saved experiment.
  ///
  /// In en, this message translates to:
  /// **'Delete experiment'**
  String get learningDeleteExperiment;

  /// Copies experiment result colors into Illustrated Room.
  ///
  /// In en, this message translates to:
  /// **'Use palette in Illustrated Room'**
  String get learningUseInRoom;

  /// Save the current typed experiment state.
  ///
  /// In en, this message translates to:
  /// **'Save to Notebook'**
  String get learningSaveExperiment;

  /// Open the authored manipulation tool from a lesson.
  ///
  /// In en, this message translates to:
  /// **'Open {tool} experiment'**
  String learningOpenPracticeTool(String tool);

  /// Experiment save dialog title.
  ///
  /// In en, this message translates to:
  /// **'Save this experiment'**
  String get learningSaveExperimentTitle;

  /// Experiment title field label.
  ///
  /// In en, this message translates to:
  /// **'Experiment title'**
  String get learningExperimentTitleLabel;

  /// Experiment observation field label.
  ///
  /// In en, this message translates to:
  /// **'What did you observe? (optional)'**
  String get learningExperimentObservationLabel;

  /// Recoverable experiment write failure.
  ///
  /// In en, this message translates to:
  /// **'This experiment is still on screen but could not be saved. Try the same save again.'**
  String get learningExperimentSaveFailed;

  /// Experiment save confirmation.
  ///
  /// In en, this message translates to:
  /// **'Experiment saved to your Notebook.'**
  String get learningExperimentSaved;

  /// Intentional lesson reset action.
  ///
  /// In en, this message translates to:
  /// **'Reset lesson'**
  String get learningResetLesson;

  /// Lesson reset confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Reset this lesson?'**
  String get learningResetLessonTitle;

  /// Lesson reset confirmation explanation.
  ///
  /// In en, this message translates to:
  /// **'Your current steps and answers for this lesson will start again. Other lessons and saved experiments stay unchanged.'**
  String get learningResetLessonBody;

  /// My Work learning notebook section title.
  ///
  /// In en, this message translates to:
  /// **'Color learning experiments'**
  String get myWorkExperimentsTitle;

  /// Accessible experiment tool label.
  ///
  /// In en, this message translates to:
  /// **'{tool} experiment'**
  String learningExperimentTool(String tool);

  /// Lesson completion confirmation.
  ///
  /// In en, this message translates to:
  /// **'Lesson completed. You can revisit any stage.'**
  String get learningCompletedAnnouncement;

  /// Coloring Studio: StudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Coloring Studio'**
  String get coloringStudioTitle;

  /// Coloring Studio: CatalogHeadline.
  ///
  /// In en, this message translates to:
  /// **'Color at your pace.'**
  String get coloringCatalogHeadline;

  /// Coloring Studio: CatalogBody.
  ///
  /// In en, this message translates to:
  /// **'Twelve original offline drawings. Guided and Free projects stay separate, with no timer, score, or lives.'**
  String get coloringCatalogBody;

  /// Coloring Studio entry shown in the Games hub.
  ///
  /// In en, this message translates to:
  /// **'Relax with 12 original offline drawings in Guided or Free Color. No timer, score, coins, or lives.'**
  String get coloringGamesEntryBody;

  /// Coloring Studio: CopiedPaletteReady.
  ///
  /// In en, this message translates to:
  /// **'Your copied Color Learning palette is ready in Free Color.'**
  String get coloringCopiedPaletteReady;

  /// Coloring Studio: CreateFailed.
  ///
  /// In en, this message translates to:
  /// **'The project could not be created. Try again.'**
  String get coloringCreateFailed;

  /// Coloring Studio: AllCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get coloringAllCategories;

  /// Coloring Studio: CategoryFruit.
  ///
  /// In en, this message translates to:
  /// **'Fruit'**
  String get coloringCategoryFruit;

  /// Coloring Studio: CategoryAnimals.
  ///
  /// In en, this message translates to:
  /// **'Animals'**
  String get coloringCategoryAnimals;

  /// Coloring Studio: CategoryNature.
  ///
  /// In en, this message translates to:
  /// **'Trees & Nature'**
  String get coloringCategoryNature;

  /// Coloring Studio: CategoryRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get coloringCategoryRooms;

  /// Coloring Studio: AllModes.
  ///
  /// In en, this message translates to:
  /// **'All modes'**
  String get coloringAllModes;

  /// Coloring Studio: GuidedMode.
  ///
  /// In en, this message translates to:
  /// **'Guided Color'**
  String get coloringGuidedMode;

  /// Coloring Studio: FreeMode.
  ///
  /// In en, this message translates to:
  /// **'Free Color'**
  String get coloringFreeMode;

  /// Coloring Studio: Continue.
  ///
  /// In en, this message translates to:
  /// **'Continue coloring'**
  String get coloringContinue;

  /// Coloring Studio: RetryCatalog.
  ///
  /// In en, this message translates to:
  /// **'Retry Coloring Studio'**
  String get coloringRetryCatalog;

  /// Coloring Studio: CompletedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This completed artwork is unavailable.'**
  String get coloringCompletedUnavailable;

  /// Coloring Studio: CompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Artwork complete'**
  String get coloringCompleteTitle;

  /// Coloring Studio: CompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Your editable project stays in My Artwork. Exporting creates a separate clean PNG.'**
  String get coloringCompleteBody;

  /// Coloring Studio: ExportPng.
  ///
  /// In en, this message translates to:
  /// **'Export PNG'**
  String get coloringExportPng;

  /// Coloring Studio: Share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get coloringShare;

  /// Coloring Studio: UseInRoom.
  ///
  /// In en, this message translates to:
  /// **'Use colors in a room'**
  String get coloringUseInRoom;

  /// Coloring Studio: ChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another drawing'**
  String get coloringChooseAnother;

  /// Coloring Studio: OpenArtwork.
  ///
  /// In en, this message translates to:
  /// **'Open My Artwork'**
  String get coloringOpenArtwork;

  /// Coloring Studio: ReturnLearning.
  ///
  /// In en, this message translates to:
  /// **'Return to Color Learning'**
  String get coloringReturnLearning;

  /// Coloring Studio: ExportedComplete.
  ///
  /// In en, this message translates to:
  /// **'PNG exported. Your editable project is unchanged.'**
  String get coloringExportedComplete;

  /// Coloring Studio: ShareCompleted.
  ///
  /// In en, this message translates to:
  /// **'Share completed.'**
  String get coloringShareCompleted;

  /// Coloring Studio: ShareDismissed.
  ///
  /// In en, this message translates to:
  /// **'Share cancelled. Your project is safe.'**
  String get coloringShareDismissed;

  /// Coloring Studio: ShareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing is unavailable on this device.'**
  String get coloringShareUnavailable;

  /// Coloring Studio: PngFailed.
  ///
  /// In en, this message translates to:
  /// **'The PNG could not be created. Your editable project is safe.'**
  String get coloringPngFailed;

  /// Coloring Studio: ChooseMode.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to color. Each mode keeps its own project.'**
  String get coloringChooseMode;

  /// Coloring Studio: GuidedDescription.
  ///
  /// In en, this message translates to:
  /// **'Match each labeled region with its authored color. No timer or penalties.'**
  String get coloringGuidedDescription;

  /// Coloring Studio: FreeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use suggested colors, your saved colors, palettes, or a custom HEX.'**
  String get coloringFreeDescription;

  /// Coloring Studio: Regions.
  ///
  /// In en, this message translates to:
  /// **'Regions'**
  String get coloringRegions;

  /// Coloring Studio: NotColored.
  ///
  /// In en, this message translates to:
  /// **'Not colored'**
  String get coloringNotColored;

  /// Coloring Studio: AssignTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign colors to room surfaces'**
  String get coloringAssignTitle;

  /// Coloring Studio: AssignBody.
  ///
  /// In en, this message translates to:
  /// **'Choose each surface explicitly. The room will not change until you confirm.'**
  String get coloringAssignBody;

  /// Coloring Studio: SurfaceWall.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get coloringSurfaceWall;

  /// Coloring Studio: SurfaceCeiling.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get coloringSurfaceCeiling;

  /// Coloring Studio: SurfaceFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get coloringSurfaceFloor;

  /// Coloring Studio: SurfaceFurniture.
  ///
  /// In en, this message translates to:
  /// **'Furniture'**
  String get coloringSurfaceFurniture;

  /// Coloring Studio: Cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get coloringCancel;

  /// Coloring Studio: ApplyRoom.
  ///
  /// In en, this message translates to:
  /// **'Apply to room'**
  String get coloringApplyRoom;

  /// Coloring Studio: OpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Coloring Studio could not open this project.'**
  String get coloringOpenFailed;

  /// Coloring Studio: ProjectMissing.
  ///
  /// In en, this message translates to:
  /// **'This coloring project was not found.'**
  String get coloringProjectMissing;

  /// Coloring Studio: RevisionMissing.
  ///
  /// In en, this message translates to:
  /// **'This drawing revision is unavailable.'**
  String get coloringRevisionMissing;

  /// Coloring Studio: SaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Your latest change is still visible but was not saved.'**
  String get coloringSaveDraft;

  /// Coloring Studio: Retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get coloringRetry;

  /// Coloring Studio: RegionSelected.
  ///
  /// In en, this message translates to:
  /// **'Region selected.'**
  String get coloringRegionSelected;

  /// Coloring Studio: ApplyGuided.
  ///
  /// In en, this message translates to:
  /// **'Apply selected color to selected region'**
  String get coloringApplyGuided;

  /// Coloring Studio: Undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get coloringUndo;

  /// Coloring Studio: Redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get coloringRedo;

  /// Coloring Studio: AllColored.
  ///
  /// In en, this message translates to:
  /// **'Every required region is colored.'**
  String get coloringAllColored;

  /// Coloring Studio: NextUnfilled.
  ///
  /// In en, this message translates to:
  /// **'Moved to the next unfilled region.'**
  String get coloringNextUnfilled;

  /// Coloring Studio: FindRegion.
  ///
  /// In en, this message translates to:
  /// **'Find region'**
  String get coloringFindRegion;

  /// Coloring Studio: Finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get coloringFinish;

  /// Coloring Studio: Saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get coloringSaved;

  /// Coloring Studio: Saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get coloringSaving;

  /// Coloring Studio: NotSaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get coloringNotSaved;

  /// Coloring Studio: ChooseGuided.
  ///
  /// In en, this message translates to:
  /// **'Choose one of the guided colors.'**
  String get coloringChooseGuided;

  /// Coloring Studio: NowChooseColor.
  ///
  /// In en, this message translates to:
  /// **'Now choose a color for this region.'**
  String get coloringNowChooseColor;

  /// Coloring Studio: ChooseRegion.
  ///
  /// In en, this message translates to:
  /// **'Choose a region first.'**
  String get coloringChooseRegion;

  /// Coloring Studio: ChooseLabeledColor.
  ///
  /// In en, this message translates to:
  /// **'Choose a labeled color first.'**
  String get coloringChooseLabeledColor;

  /// Coloring Studio: Accepted.
  ///
  /// In en, this message translates to:
  /// **'Nice match. The region is colored.'**
  String get coloringAccepted;

  /// Coloring Studio: WrongColor.
  ///
  /// In en, this message translates to:
  /// **'That color belongs to a different region. Try another labeled color.'**
  String get coloringWrongColor;

  /// Coloring Studio: RetryBeforeFinish.
  ///
  /// In en, this message translates to:
  /// **'Retry saving before finishing.'**
  String get coloringRetryBeforeFinish;

  /// Coloring Studio: FinishRemaining.
  ///
  /// In en, this message translates to:
  /// **'Color the remaining required regions first.'**
  String get coloringFinishRemaining;

  /// Coloring Studio: ChangeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The change could not be saved. Retry is available.'**
  String get coloringChangeSaveFailed;

  /// Coloring Studio: MyArtwork.
  ///
  /// In en, this message translates to:
  /// **'My Artwork'**
  String get coloringMyArtwork;

  /// Coloring Studio: ArtworkBody.
  ///
  /// In en, this message translates to:
  /// **'Editable Coloring Studio projects are separate from exported PNG files.'**
  String get coloringArtworkBody;

  /// Coloring Studio: RetryArtwork.
  ///
  /// In en, this message translates to:
  /// **'Retry artwork'**
  String get coloringRetryArtwork;

  /// Coloring Studio: DuplicateFailed.
  ///
  /// In en, this message translates to:
  /// **'The project could not be duplicated.'**
  String get coloringDuplicateFailed;

  /// Coloring Studio: Exported.
  ///
  /// In en, this message translates to:
  /// **'PNG exported.'**
  String get coloringExported;

  /// Coloring Studio: ExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. The project is safe.'**
  String get coloringExportFailed;

  /// Coloring Studio: SharingFailed.
  ///
  /// In en, this message translates to:
  /// **'Sharing is unavailable. The project is safe.'**
  String get coloringSharingFailed;

  /// Coloring Studio: DeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete editable artwork?'**
  String get coloringDeleteTitle;

  /// Coloring Studio: DeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Exported PNG files are not deleted.'**
  String get coloringDeleteBody;

  /// Coloring Studio: Delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get coloringDelete;

  /// Coloring Studio: DeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The artwork could not be deleted.'**
  String get coloringDeleteFailed;

  /// Coloring Studio: EmptyArtwork.
  ///
  /// In en, this message translates to:
  /// **'No coloring projects yet.'**
  String get coloringEmptyArtwork;

  /// Coloring Studio: OpenStudio.
  ///
  /// In en, this message translates to:
  /// **'Open Coloring Studio'**
  String get coloringOpenStudio;

  /// Coloring Studio: Resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get coloringResume;

  /// Coloring Studio: Duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get coloringDuplicate;

  /// Coloring Studio: Export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get coloringExport;

  /// Coloring Studio: SuggestedColors.
  ///
  /// In en, this message translates to:
  /// **'Suggested colors'**
  String get coloringSuggestedColors;

  /// Coloring Studio: FromLearning.
  ///
  /// In en, this message translates to:
  /// **'From Color Learning'**
  String get coloringFromLearning;

  /// Coloring Studio: MyColors.
  ///
  /// In en, this message translates to:
  /// **'My Colors'**
  String get coloringMyColors;

  /// Coloring Studio: MyPalettes.
  ///
  /// In en, this message translates to:
  /// **'My Palettes'**
  String get coloringMyPalettes;

  /// Coloring Studio: CustomHex.
  ///
  /// In en, this message translates to:
  /// **'Custom HEX'**
  String get coloringCustomHex;

  /// Coloring Studio: HexHint.
  ///
  /// In en, this message translates to:
  /// **'#336699'**
  String get coloringHexHint;

  /// Coloring Studio: UseCustom.
  ///
  /// In en, this message translates to:
  /// **'Use custom color'**
  String get coloringUseCustom;

  /// Coloring Studio: InvalidHex.
  ///
  /// In en, this message translates to:
  /// **'Enter a six-digit HEX color.'**
  String get coloringInvalidHex;

  /// Coloring Studio: UnknownDrawing.
  ///
  /// In en, this message translates to:
  /// **'Unknown drawing'**
  String get coloringUnknownDrawing;

  /// Coloring Studio: Progress.
  ///
  /// In en, this message translates to:
  /// **'{filled} of {total} regions'**
  String coloringProgress(int filled, int total);

  /// Coloring Studio: SelectedColor.
  ///
  /// In en, this message translates to:
  /// **'{label} selected.'**
  String coloringSelectedColor(String label);

  /// Coloring Studio: AppliedColor.
  ///
  /// In en, this message translates to:
  /// **'{hex} applied.'**
  String coloringAppliedColor(String hex);

  /// Coloring Studio: RegionNeeds.
  ///
  /// In en, this message translates to:
  /// **'Needs {label}'**
  String coloringRegionNeeds(String label);

  /// Coloring Studio: RegionComplete.
  ///
  /// In en, this message translates to:
  /// **'{label} complete'**
  String coloringRegionComplete(String label);

  /// Coloring Studio: RegionSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}, {value}'**
  String coloringRegionSemantics(String label, String value);

  /// Coloring Studio: ProjectSummary.
  ///
  /// In en, this message translates to:
  /// **'{mode} · {count} regions'**
  String coloringProjectSummary(String mode, int count);

  /// Coloring Studio: NumberedSwatch.
  ///
  /// In en, this message translates to:
  /// **'{number}. {label} {hex}'**
  String coloringNumberedSwatch(int number, String label, String hex);

  /// Coloring Studio: NamedHex.
  ///
  /// In en, this message translates to:
  /// **'{name} {hex}'**
  String coloringNamedHex(String name, String hex);

  /// Coloring Studio: SwatchSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}, {hex}'**
  String coloringSwatchSemantics(String label, String hex);

  /// Coloring Studio: SwatchTooltip.
  ///
  /// In en, this message translates to:
  /// **'{label} · {hex}'**
  String coloringSwatchTooltip(String label, String hex);

  /// Coloring Studio: ShareTitle.
  ///
  /// In en, this message translates to:
  /// **'TintAtlas Coloring Studio — {title}'**
  String coloringShareTitle(String title);

  /// Coloring Studio: Difficulty.
  ///
  /// In en, this message translates to:
  /// **'{key, select, easy{Easy} medium{Medium} hard{Hard} other{Unknown difficulty}}'**
  String coloringDifficulty(String key);

  /// Coloring Studio: DifficultyBadge.
  ///
  /// In en, this message translates to:
  /// **'{key, select, easy{EASY} medium{MEDIUM} hard{HARD} other{UNKNOWN DIFFICULTY}}'**
  String coloringDifficultyBadge(String key);

  /// Coloring Studio: ModeSummary.
  ///
  /// In en, this message translates to:
  /// **'{key, select, guided{guided} free{free} other{unknown mode}}'**
  String coloringModeSummary(String key);

  /// Resolves stable Coloring artwork keys; translate every select branch and keep keys unchanged.
  ///
  /// In en, this message translates to:
  /// **'{key, select, coloringFruitRedAppleTitle{Red Apple} coloringFruitOrangeSliceTitle{Orange Slice} coloringFruitBerryBowlTitle{Berry Bowl} coloringAnimalButterflyTitle{Butterfly} coloringAnimalTropicalFishTitle{Tropical Fish} coloringAnimalParrotTitle{Parrot} coloringNatureLeafyTreeTitle{Leafy Tree} coloringNatureSunflowerTitle{Sunflower} coloringNatureMountainGroveTitle{Mountain Grove} coloringRoomCozyLivingTitle{Cozy Living Room} coloringRoomCalmBedroomTitle{Calm Bedroom} coloringRoomReadingCornerTitle{Reading Corner} other{Unknown drawing}}'**
  String coloringDrawingTitle(String key);

  /// Resolves stable Coloring artwork keys; translate every select branch and keep keys unchanged.
  ///
  /// In en, this message translates to:
  /// **'{key, select, coloringFruitRedAppleDescription{A bright apple with a leaf, stem, and soft highlight.} coloringFruitOrangeSliceDescription{A cheerful citrus slice with peel, pith, and seed.} coloringFruitBerryBowlDescription{Red and blue berries gathered in a cool blue bowl.} coloringAnimalButterflyDescription{A balanced butterfly with warm wings and violet spots.} coloringAnimalTropicalFishDescription{A lively fish with bold stripes, fin, and bright body.} coloringAnimalParrotDescription{A five-color parrot perched in a friendly profile.} coloringNatureLeafyTreeDescription{A sturdy tree with layered leaves and warm ground.} coloringNatureSunflowerDescription{A tall sunflower against a clear blue sky.} coloringNatureMountainGroveDescription{Pines, snow, and slate peaks in a quiet landscape.} coloringRoomCozyLivingDescription{A calm sofa, rug, table, and wall composition.} coloringRoomCalmBedroomDescription{A restful bed with mist, cream, blue, and sage layers.} coloringRoomReadingCornerDescription{A warm chair, shelf, plant, and lamp for a quiet nook.} other{Drawing description unavailable.}}'**
  String coloringDrawingDescription(String key);

  /// Resolves stable Coloring artwork keys; translate every select branch and keep keys unchanged.
  ///
  /// In en, this message translates to:
  /// **'{key, select, coloringSlotAppleRed{Apple red} coloringSlotLeafGreen{Leaf green} coloringSlotStemBrown{Stem brown} coloringSlotHighlightCream{Highlight cream} coloringSlotPeelOrange{Peel orange} coloringSlotFleshOrange{Flesh orange} coloringSlotPithCream{Pith cream} coloringSlotSeedTan{Seed tan} coloringSlotBerryRed{Berry red} coloringSlotBerryBlue{Berry blue} coloringSlotBowlBlue{Bowl blue} coloringSlotRimCream{Rim cream} coloringSlotWingGold{Wing gold} coloringSlotWingCoral{Wing coral} coloringSlotBodyCharcoal{Body charcoal} coloringSlotSpotViolet{Spot violet} coloringSlotBodyTurquoise{Body turquoise} coloringSlotStripeYellow{Stripe yellow} coloringSlotStripeCoral{Stripe coral} coloringSlotFinBlue{Fin blue} coloringSlotEyeCharcoal{Eye charcoal} coloringSlotFeatherRed{Feather red} coloringSlotFeatherGreen{Feather green} coloringSlotFeatherBlue{Feather blue} coloringSlotChestYellow{Chest yellow} coloringSlotBeakOrange{Beak orange} coloringSlotLeafLightGreen{Leaf light green} coloringSlotTrunkBrown{Trunk brown} coloringSlotGroundTan{Ground tan} coloringSlotPetalYellow{Petal yellow} coloringSlotCenterBrown{Center brown} coloringSlotSkyBlue{Sky blue} coloringSlotMountainSlate{Mountain slate} coloringSlotPineGreen{Pine green} coloringSlotSnowWhite{Snow white} coloringSlotEarthGray{Earth gray} coloringSlotWallLinen{Wall linen} coloringSlotSofaSage{Sofa sage} coloringSlotWoodBrown{Wood brown} coloringSlotRugCoral{Rug coral} coloringSlotAccentSlate{Accent slate} coloringSlotWallMist{Wall mist} coloringSlotBeddingCream{Bedding cream} coloringSlotBlanketBlue{Blanket blue} coloringSlotWoodTan{Wood tan} coloringSlotAccentSage{Accent sage} coloringSlotChairClay{Chair clay} coloringSlotShelfBrown{Shelf brown} coloringSlotPlantGreen{Plant green} coloringSlotLampGold{Lamp gold} other{Color}}'**
  String coloringSlotLabel(String key);

  /// Resolves stable Coloring artwork keys; translate every select branch and keep keys unchanged.
  ///
  /// In en, this message translates to:
  /// **'{key, select, coloringAppleBody{Apple Body} coloringAppleStem{Apple Stem} coloringAppleLeaf{Apple Leaf} coloringAppleHighlight{Apple Highlight} coloringOrangePeel{Orange Peel} coloringOrangeFlesh{Orange Flesh} coloringOrangePith{Orange Pith} coloringOrangeSeed{Orange Seed} coloringBerryBowlBody{Berry Bowl Body} coloringBerryBowlRim{Berry Bowl Rim} coloringBerryRedFruit{Berry Red Fruit} coloringBerryBlueFruit{Berry Blue Fruit} coloringBerryLeaf{Berry Leaf} coloringButterflyGoldWings{Butterfly Gold Wings} coloringButterflyCoralWings{Butterfly Coral Wings} coloringButterflyBody{Butterfly Body} coloringButterflySpots{Butterfly Spots} coloringFishBody{Fish Body} coloringFishTail{Fish Tail} coloringFishCoralStripe{Fish Coral Stripe} coloringFishYellowStripe{Fish Yellow Stripe} coloringFishEye{Fish Eye} coloringParrotRedHead{Parrot Red Head} coloringParrotGreenWing{Parrot Green Wing} coloringParrotBlueTail{Parrot Blue Tail} coloringParrotYellowChest{Parrot Yellow Chest} coloringParrotOrangeBeak{Parrot Orange Beak} coloringTreeGround{Tree Ground} coloringTreeTrunk{Tree Trunk} coloringTreeDarkLeaves{Tree Dark Leaves} coloringTreeLightLeaves{Tree Light Leaves} coloringSunflowerSky{Sunflower Sky} coloringSunflowerStemLeaf{Sunflower Stem Leaf} coloringSunflowerPetals{Sunflower Petals} coloringSunflowerCenter{Sunflower Center} coloringMountainSky{Mountain Sky} coloringMountainEarth{Mountain Earth} coloringMountainSlate{Mountain Slate} coloringMountainSnow{Mountain Snow} coloringMountainPines{Mountain Pines} coloringLivingWall{Living Wall} coloringLivingRug{Living Rug} coloringLivingSofa{Living Sofa} coloringLivingWood{Living Wood} coloringLivingAccent{Living Accent} coloringBedroomWall{Bedroom Wall} coloringBedroomWood{Bedroom Wood} coloringBedroomBedding{Bedroom Bedding} coloringBedroomBlanket{Bedroom Blanket} coloringBedroomAccent{Bedroom Accent} coloringReadingWall{Reading Wall} coloringReadingShelf{Reading Shelf} coloringReadingChair{Reading Chair} coloringReadingPlant{Reading Plant} coloringReadingLamp{Reading Lamp} other{Region}}'**
  String coloringRegionLabel(String key);
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
