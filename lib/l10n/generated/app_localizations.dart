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
  /// **'Turn a camera moment or a favorite photo into a color worth keeping.'**
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
  /// **'Save the shades you love in a personal library, ready to revisit offline.'**
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
  /// **'Color exploration stays on your device. We ask for camera or photo access only when you choose to use it.'**
  String get onboardingControlBody;

  /// Supporting note for the privacy and control tour slide.
  ///
  /// In en, this message translates to:
  /// **'No permission is needed to take this tour.'**
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
