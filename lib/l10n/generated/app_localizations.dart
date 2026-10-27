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
