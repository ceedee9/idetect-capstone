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

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen Locked'**
  String get lockTitle;

  /// No description provided for @lockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For your security, the app locked after 5 minutes of inactivity.'**
  String get lockSubtitle;

  /// No description provided for @lockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to continue'**
  String get lockEnterPin;

  /// No description provided for @lockIncorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN. Please try again.'**
  String get lockIncorrectPin;

  /// No description provided for @lockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock iDetect to continue'**
  String get lockBiometricReason;

  /// No description provided for @lockBiometricButton.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face'**
  String get lockBiometricButton;

  /// No description provided for @lockSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again instead'**
  String get lockSignInAgain;

  /// No description provided for @lockNoUnlockMethod.
  ///
  /// In en, this message translates to:
  /// **'No PIN or biometric is set up on this device. Sign in again to continue.'**
  String get lockNoUnlockMethod;

  /// No description provided for @lockSessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get lockSessionMissing;

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
  /// **'Display language'**
  String get languageToggleTooltip;

  /// No description provided for @languageEnglishLabel.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishLabel;

  /// No description provided for @languageFilipinoLabel.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get languageFilipinoLabel;

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

  /// No description provided for @historyEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get historyEmptyState;

  /// No description provided for @historyDisputeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dispute / Report'**
  String get historyDisputeLabel;

  /// No description provided for @serviceUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'iDetect is unavailable'**
  String get serviceUnavailableTitle;

  /// No description provided for @serviceUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not reach iDetect. Check your connection or try again later.'**
  String get serviceUnavailableMessage;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonRetry;

  /// No description provided for @verificationStatusValid.
  ///
  /// In en, this message translates to:
  /// **'VALID'**
  String get verificationStatusValid;

  /// No description provided for @verificationStatusInvalid.
  ///
  /// In en, this message translates to:
  /// **'INVALID'**
  String get verificationStatusInvalid;

  /// No description provided for @verificationStatusReview.
  ///
  /// In en, this message translates to:
  /// **'NEEDS REVIEW'**
  String get verificationStatusReview;

  /// No description provided for @verificationStatusManualReview.
  ///
  /// In en, this message translates to:
  /// **'MANUAL REVIEW'**
  String get verificationStatusManualReview;

  /// No description provided for @verificationStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'UNKNOWN'**
  String get verificationStatusUnknown;

  /// No description provided for @disputeStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'SUBMITTED'**
  String get disputeStatusSubmitted;

  /// No description provided for @disputeStatusAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'ACKNOWLEDGED'**
  String get disputeStatusAcknowledged;

  /// No description provided for @disputeStatusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'UNDER REVIEW'**
  String get disputeStatusUnderReview;

  /// No description provided for @disputeStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'RESOLVED'**
  String get disputeStatusResolved;

  /// No description provided for @disputeStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'REJECTED'**
  String get disputeStatusRejected;

  /// No description provided for @beneficiaryStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active & valid'**
  String get beneficiaryStatusActive;

  /// No description provided for @beneficiaryStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get beneficiaryStatusExpired;

  /// No description provided for @beneficiaryStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Under investigation'**
  String get beneficiaryStatusSuspended;

  /// No description provided for @beneficiaryStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get beneficiaryStatusRevoked;

  /// No description provided for @beneficiaryStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get beneficiaryStatusUnknown;

  /// No description provided for @statusIdNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'ID Number'**
  String get statusIdNumberLabel;

  /// No description provided for @statusShowIdNumber.
  ///
  /// In en, this message translates to:
  /// **'Show ID number'**
  String get statusShowIdNumber;

  /// No description provided for @statusHideIdNumber.
  ///
  /// In en, this message translates to:
  /// **'Hide ID number'**
  String get statusHideIdNumber;

  /// No description provided for @statusIdNumberHidden.
  ///
  /// In en, this message translates to:
  /// **'ID number hidden. It ends in {lastTwo}.'**
  String statusIdNumberHidden(String lastTwo);

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

  /// No description provided for @disputesNewButton.
  ///
  /// In en, this message translates to:
  /// **'New Dispute'**
  String get disputesNewButton;

  /// No description provided for @disputesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No disputes filed'**
  String get disputesEmptyTitle;

  /// No description provided for @disputesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to file a new dispute'**
  String get disputesEmptySubtitle;

  /// No description provided for @disputesDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispute Details'**
  String get disputesDetailTitle;

  /// No description provided for @disputesTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get disputesTypeLabel;

  /// No description provided for @disputesFiledLabel.
  ///
  /// In en, this message translates to:
  /// **'Filed'**
  String get disputesFiledLabel;

  /// No description provided for @disputesDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get disputesDescriptionLabel;

  /// No description provided for @disputesResolutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get disputesResolutionLabel;

  /// No description provided for @disputesFileTitle.
  ///
  /// In en, this message translates to:
  /// **'File a Dispute'**
  String get disputesFileTitle;

  /// No description provided for @disputesTypeSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Dispute Type'**
  String get disputesTypeSectionLabel;

  /// No description provided for @disputesDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your dispute...'**
  String get disputesDescriptionHint;

  /// No description provided for @disputesEstablishmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Where did this happen?'**
  String get disputesEstablishmentLabel;

  /// No description provided for @disputesFiledOnBehalfLabel.
  ///
  /// In en, this message translates to:
  /// **'Filed for you by'**
  String get disputesFiledOnBehalfLabel;

  /// No description provided for @disputesEstablishmentHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — name the establishment or office, if applicable'**
  String get disputesEstablishmentHint;

  /// No description provided for @disputesEstablishmentRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Name of the establishment or office involved'**
  String get disputesEstablishmentRequiredHint;

  /// No description provided for @disputesEstablishmentPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Valenzuela City Hall, ABC Store'**
  String get disputesEstablishmentPlaceholder;

  /// No description provided for @disputesErrorEmptyEstablishment.
  ///
  /// In en, this message translates to:
  /// **'Please specify where this happened'**
  String get disputesErrorEmptyEstablishment;

  /// No description provided for @disputesSupportingDocLabel.
  ///
  /// In en, this message translates to:
  /// **'Supporting Document'**
  String get disputesSupportingDocLabel;

  /// No description provided for @disputesSupportingDocHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — attach a photo of your ID, barangay cert, etc.'**
  String get disputesSupportingDocHint;

  /// No description provided for @disputesAttachButton.
  ///
  /// In en, this message translates to:
  /// **'Attach Photo / Document'**
  String get disputesAttachButton;

  /// No description provided for @disputesErrorEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get disputesErrorEmptyDescription;

  /// No description provided for @disputesErrorUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String disputesErrorUploadFailed(String error);

  /// No description provided for @disputesSuccessSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Dispute submitted'**
  String get disputesSuccessSnackbar;

  /// No description provided for @disputesSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Dispute'**
  String get disputesSubmitButton;

  /// No description provided for @disputeTypeWrongDenialLabel.
  ///
  /// In en, this message translates to:
  /// **'Wrong Denial'**
  String get disputeTypeWrongDenialLabel;

  /// No description provided for @disputeTypeWrongDenialDesc.
  ///
  /// In en, this message translates to:
  /// **'A business incorrectly denied you the discount'**
  String get disputeTypeWrongDenialDesc;

  /// No description provided for @disputeTypeBusinessRefusalLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Refusal'**
  String get disputeTypeBusinessRefusalLabel;

  /// No description provided for @disputeTypeBusinessRefusalDesc.
  ///
  /// In en, this message translates to:
  /// **'A business refused to honor your valid ID'**
  String get disputeTypeBusinessRefusalDesc;

  /// No description provided for @disputeTypeIncorrectDbInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Incorrect Database Info'**
  String get disputeTypeIncorrectDbInfoLabel;

  /// No description provided for @disputeTypeIncorrectDbInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Your information in our system is incorrect'**
  String get disputeTypeIncorrectDbInfoDesc;

  /// No description provided for @disputeTypeOtherLabel.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get disputeTypeOtherLabel;

  /// No description provided for @disputeTypeOtherDesc.
  ///
  /// In en, this message translates to:
  /// **'A different issue not listed above'**
  String get disputeTypeOtherDesc;

  /// No description provided for @notificationsErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to load notifications.'**
  String get notificationsErrorFallback;

  /// No description provided for @notificationsErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get notificationsErrorGeneric;

  /// No description provided for @notificationsRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get notificationsRetryButton;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh'**
  String get notificationsEmptySubtitle;

  /// No description provided for @notificationsLoadMoreError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more notifications.'**
  String get notificationsLoadMoreError;

  /// No description provided for @notificationFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationFallbackTitle;

  /// No description provided for @callbackRequestButton.
  ///
  /// In en, this message translates to:
  /// **'Request callback'**
  String get callbackRequestButton;

  /// No description provided for @callbackRequestsEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'My callback requests'**
  String get callbackRequestsEntryTitle;

  /// No description provided for @callbackRequestsEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track requests you sent to BPLO'**
  String get callbackRequestsEntrySubtitle;

  /// No description provided for @callbackSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Request a callback'**
  String get callbackSheetTitle;

  /// No description provided for @callbackSheetIntro.
  ///
  /// In en, this message translates to:
  /// **'Send a request to the BPLO office about this establishment. For privacy, the business phone number is not shared. BPLO staff will review your request and reply here.'**
  String get callbackSheetIntro;

  /// No description provided for @callbackEstablishmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Establishment'**
  String get callbackEstablishmentLabel;

  /// No description provided for @callbackReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get callbackReasonLabel;

  /// No description provided for @callbackReasonTransaction.
  ///
  /// In en, this message translates to:
  /// **'Question about this transaction'**
  String get callbackReasonTransaction;

  /// No description provided for @callbackReasonCorrection.
  ///
  /// In en, this message translates to:
  /// **'Record needs correction'**
  String get callbackReasonCorrection;

  /// No description provided for @callbackReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get callbackReasonOther;

  /// No description provided for @callbackNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Additional details (optional)'**
  String get callbackNoteLabel;

  /// No description provided for @callbackNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what you need help with'**
  String get callbackNoteHint;

  /// No description provided for @callbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get callbackSubmit;

  /// No description provided for @callbackSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Request sent. Reference: {reference}'**
  String callbackSuccessMessage(String reference);

  /// No description provided for @callbackErrorNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You can only request a callback for an establishment you have transacted with.'**
  String get callbackErrorNotAllowed;

  /// No description provided for @callbackErrorDuplicate.
  ///
  /// In en, this message translates to:
  /// **'You already have an open request for this establishment.'**
  String get callbackErrorDuplicate;

  /// No description provided for @callbackErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not send your request. Please try again.'**
  String get callbackErrorGeneric;

  /// No description provided for @callbackRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Callback requests'**
  String get callbackRequestsTitle;

  /// No description provided for @callbackRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no callback requests yet.'**
  String get callbackRequestsEmpty;

  /// No description provided for @callbackStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get callbackStatusOpen;

  /// No description provided for @callbackStatusHandled.
  ///
  /// In en, this message translates to:
  /// **'Replied'**
  String get callbackStatusHandled;

  /// No description provided for @callbackNoReplyYet.
  ///
  /// In en, this message translates to:
  /// **'No reply yet'**
  String get callbackNoReplyYet;

  /// No description provided for @callbackReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'BPLO reply'**
  String get callbackReplyLabel;

  /// No description provided for @callbackRequestedOn.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get callbackRequestedOn;
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
