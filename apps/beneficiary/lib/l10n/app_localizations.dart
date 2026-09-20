import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fil'),
  ];

  /// Fallback name shown in the home app bar when no full_name is available
  ///
  /// In en, this message translates to:
  /// **'Beneficiary'**
  String get appBeneficiaryFallback;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'← Back'**
  String get commonBack;

  /// No description provided for @loginBeneficiaryPortal.
  ///
  /// In en, this message translates to:
  /// **'Beneficiary Portal'**
  String get loginBeneficiaryPortal;

  /// No description provided for @loginErrorMissingIdBirthdate.
  ///
  /// In en, this message translates to:
  /// **'Please enter your ID number and birthdate.'**
  String get loginErrorMissingIdBirthdate;

  /// No description provided for @loginErrorMissingMobile.
  ///
  /// In en, this message translates to:
  /// **'Please enter your mobile number.'**
  String get loginErrorMissingMobile;

  /// No description provided for @loginErrorInvalidMobile.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid PH mobile number\n(e.g. 09171234567)'**
  String get loginErrorInvalidMobile;

  /// No description provided for @loginBiometricReasonSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your fingerprint or face'**
  String get loginBiometricReasonSignIn;

  /// No description provided for @loginBiometricReasonEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable quick sign-in for next time'**
  String get loginBiometricReasonEnable;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get loginWelcomeBack;

  /// No description provided for @loginSignInFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Sign In with Fingerprint'**
  String get loginSignInFingerprint;

  /// No description provided for @loginOrSignInOtp.
  ///
  /// In en, this message translates to:
  /// **'— or sign in with OTP —'**
  String get loginOrSignInOtp;

  /// No description provided for @loginSignInPin.
  ///
  /// In en, this message translates to:
  /// **'Sign In with PIN'**
  String get loginSignInPin;

  /// No description provided for @loginSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP to My Phone'**
  String get loginSendOtp;

  /// No description provided for @loginNotYou.
  ///
  /// In en, this message translates to:
  /// **'Not you? Use a different ID'**
  String get loginNotYou;

  /// No description provided for @loginIdNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your ID Number'**
  String get loginIdNumberHint;

  /// No description provided for @loginBirthdateHint.
  ///
  /// In en, this message translates to:
  /// **'Select your Birthdate'**
  String get loginBirthdateHint;

  /// No description provided for @loginContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get loginContinue;

  /// No description provided for @loginHelloName.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}!'**
  String loginHelloName(String name);

  /// No description provided for @loginMobileExplanation.
  ///
  /// In en, this message translates to:
  /// **'We need your mobile number to send you a verification code. You only need to do this once.'**
  String get loginMobileExplanation;

  /// No description provided for @loginMobileHintFormat.
  ///
  /// In en, this message translates to:
  /// **'Philippine mobile number (e.g. 09171234567)'**
  String get loginMobileHintFormat;

  /// No description provided for @loginRegisterSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Register & Send OTP'**
  String get loginRegisterSendOtp;

  /// No description provided for @loginOtpSentInstruction.
  ///
  /// In en, this message translates to:
  /// **'A 6-digit code was sent to your phone.\nEnter it below.'**
  String get loginOtpSentInstruction;

  /// No description provided for @loginResendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get loginResendOtp;

  /// No description provided for @loginCreatePin.
  ///
  /// In en, this message translates to:
  /// **'Create Your 4-Digit PIN'**
  String get loginCreatePin;

  /// No description provided for @loginEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter Your PIN'**
  String get loginEnterPin;

  /// No description provided for @loginPinSetupHint.
  ///
  /// In en, this message translates to:
  /// **'This PIN lets you sign in without a text message.'**
  String get loginPinSetupHint;

  /// No description provided for @loginPinLoginHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit PIN to sign in.'**
  String get loginPinLoginHint;

  /// No description provided for @loginSetPinDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get loginSetPinDialogTitle;

  /// No description provided for @loginSetPinDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Set a 4-digit PIN so you can sign in without waiting for a text message next time.'**
  String get loginSetPinDialogContent;

  /// No description provided for @loginNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get loginNotNow;

  /// No description provided for @loginSetPinNow.
  ///
  /// In en, this message translates to:
  /// **'Set PIN Now'**
  String get loginSetPinNow;

  /// No description provided for @loginQuickSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Sign-In'**
  String get loginQuickSignInTitle;

  /// No description provided for @loginQuickSignInContent.
  ///
  /// In en, this message translates to:
  /// **'Would you like to use your fingerprint or face to sign in next time?\n\nThis makes it easier — no need to type your OTP again.'**
  String get loginQuickSignInContent;

  /// No description provided for @loginYesEnable.
  ///
  /// In en, this message translates to:
  /// **'Yes, Enable'**
  String get loginYesEnable;

  /// No description provided for @homeSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get homeSignOut;

  /// No description provided for @homeSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get homeSignOutConfirm;

  /// No description provided for @beneficiaryTypeSenior.
  ///
  /// In en, this message translates to:
  /// **'Senior Citizen'**
  String get beneficiaryTypeSenior;

  /// No description provided for @beneficiaryTypePwd.
  ///
  /// In en, this message translates to:
  /// **'PWD'**
  String get beneficiaryTypePwd;

  /// No description provided for @languageToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get languageToggleTooltip;

  /// No description provided for @statusErrorLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile. Pull to refresh.'**
  String get statusErrorLoadProfile;

  /// No description provided for @statusIdDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'ID Details'**
  String get statusIdDetailsTitle;

  /// No description provided for @statusIssuingOffice.
  ///
  /// In en, this message translates to:
  /// **'Issuing Office'**
  String get statusIssuingOffice;

  /// No description provided for @statusValidFrom.
  ///
  /// In en, this message translates to:
  /// **'Valid From'**
  String get statusValidFrom;

  /// No description provided for @statusValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid Until'**
  String get statusValidUntil;

  /// No description provided for @statusBirthdate.
  ///
  /// In en, this message translates to:
  /// **'Birthdate'**
  String get statusBirthdate;

  /// No description provided for @statusMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get statusMobile;

  /// No description provided for @statusActivitySummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Summary'**
  String get statusActivitySummaryTitle;

  /// No description provided for @statusTotalVerifications.
  ///
  /// In en, this message translates to:
  /// **'Total Verifications'**
  String get statusTotalVerifications;

  /// No description provided for @statusPendingFlags.
  ///
  /// In en, this message translates to:
  /// **'Pending Flags'**
  String get statusPendingFlags;

  /// No description provided for @statusActiveDisputes.
  ///
  /// In en, this message translates to:
  /// **'Active Disputes'**
  String get statusActiveDisputes;

  /// No description provided for @statusReportFraudSemantics.
  ///
  /// In en, this message translates to:
  /// **'Report fraud on my ID'**
  String get statusReportFraudSemantics;

  /// No description provided for @statusReportFraudButton.
  ///
  /// In en, this message translates to:
  /// **'Report Fraud on My ID'**
  String get statusReportFraudButton;

  /// No description provided for @statusExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'Your ID expires today!'**
  String get statusExpiresToday;

  /// No description provided for @statusExpiresTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Your ID expires tomorrow!'**
  String get statusExpiresTomorrow;

  /// No description provided for @statusExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Your ID expires in {days} days'**
  String statusExpiresInDays(int days);

  /// No description provided for @statusRenewInstruction.
  ///
  /// In en, this message translates to:
  /// **'Please visit your issuing office to renew your ID.'**
  String get statusRenewInstruction;

  /// No description provided for @navStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get navStatus;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navDisputes.
  ///
  /// In en, this message translates to:
  /// **'Disputes'**
  String get navDisputes;

  /// No description provided for @navAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get navAlerts;

  /// No description provided for @transactionsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No verification records yet'**
  String get transactionsEmptyState;

  /// No description provided for @transactionsUnknownEstablishment.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get transactionsUnknownEstablishment;

  /// No description provided for @transactionsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Details'**
  String get transactionsDetailTitle;

  /// No description provided for @transactionsEstablishmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Establishment'**
  String get transactionsEstablishmentLabel;

  /// No description provided for @transactionsDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get transactionsDateTimeLabel;

  /// No description provided for @transactionsStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get transactionsStatusLabel;

  /// No description provided for @transactionsEntryLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get transactionsEntryLabel;

  /// No description provided for @transactionsEntryManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get transactionsEntryManual;

  /// No description provided for @fraudReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Fraud'**
  String get fraudReportTitle;

  /// No description provided for @fraudReportWarningBanner.
  ///
  /// In en, this message translates to:
  /// **'Filing a fraud report will immediately flag your ID for review. This helps protect your benefits.'**
  String get fraudReportWarningBanner;

  /// No description provided for @fraudReportWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get fraudReportWhatHappened;

  /// No description provided for @fraudTypeUnauthorizedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized Use'**
  String get fraudTypeUnauthorizedLabel;

  /// No description provided for @fraudTypeUnauthorizedDesc.
  ///
  /// In en, this message translates to:
  /// **'Someone used my ID without my permission'**
  String get fraudTypeUnauthorizedDesc;

  /// No description provided for @fraudTypeStolenLabel.
  ///
  /// In en, this message translates to:
  /// **'Stolen ID'**
  String get fraudTypeStolenLabel;

  /// No description provided for @fraudTypeStolenDesc.
  ///
  /// In en, this message translates to:
  /// **'My physical ID card was stolen'**
  String get fraudTypeStolenDesc;

  /// No description provided for @fraudTypeFakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fake / Cloned ID'**
  String get fraudTypeFakeLabel;

  /// No description provided for @fraudTypeFakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Someone created a copy of my ID'**
  String get fraudTypeFakeDesc;

  /// No description provided for @fraudTypeOtherLabel.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get fraudTypeOtherLabel;

  /// No description provided for @fraudTypeOtherDesc.
  ///
  /// In en, this message translates to:
  /// **'Another type of fraud or misuse'**
  String get fraudTypeOtherDesc;

  /// No description provided for @fraudReportDescribeIncident.
  ///
  /// In en, this message translates to:
  /// **'Describe the incident'**
  String get fraudReportDescribeIncident;

  /// No description provided for @fraudReportDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Provide details: when, where, and how you discovered the fraud...'**
  String get fraudReportDescriptionHint;

  /// No description provided for @fraudReportErrorEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Please describe the incident'**
  String get fraudReportErrorEmptyDescription;

  /// No description provided for @fraudReportSuccessSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Fraud report submitted successfully'**
  String get fraudReportSuccessSnackbar;

  /// No description provided for @fraudReportErrorSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report. Please try again.'**
  String get fraudReportErrorSnackbar;

  /// No description provided for @fraudReportSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get fraudReportSubmitting;

  /// No description provided for @fraudReportSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get fraudReportSubmitButton;

  /// No description provided for @notificationFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationFallbackTitle;
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
      <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fil':
      return AppLocalizationsFil();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
