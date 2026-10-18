// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appBeneficiaryFallback => 'Beneficiary';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => '← Back';

  @override
  String get loginBeneficiaryPortal => 'Beneficiary Portal';

  @override
  String get loginErrorMissingIdBirthdate =>
      'Please enter your ID number and birthdate.';

  @override
  String get loginErrorMissingMobile => 'Please enter your mobile number.';

  @override
  String get loginErrorInvalidMobile =>
      'Please enter a valid PH mobile number\n(e.g. 09171234567)';

  @override
  String get loginBiometricReasonSignIn =>
      'Sign in with your fingerprint or face';

  @override
  String get loginBiometricReasonEnable => 'Enable quick sign-in for next time';

  @override
  String get lockTitle => 'Screen Locked';

  @override
  String get lockSubtitle =>
      'For your security, the app locked after 5 minutes of inactivity.';

  @override
  String get lockEnterPin => 'Enter your PIN to continue';

  @override
  String get lockIncorrectPin => 'Incorrect PIN. Please try again.';

  @override
  String get lockBiometricReason => 'Unlock iDetect to continue';

  @override
  String get lockBiometricButton => 'Use fingerprint or face';

  @override
  String get lockSignInAgain => 'Sign in again instead';

  @override
  String get lockNoUnlockMethod =>
      'No PIN or biometric is set up on this device. Sign in again to continue.';

  @override
  String get lockSessionMissing => 'Please sign in again to continue.';

  @override
  String get loginWelcomeBack => 'Welcome back,';

  @override
  String get loginSignInFingerprint => 'Sign In with Fingerprint';

  @override
  String get loginOrSignInOtp => '— or sign in with OTP —';

  @override
  String get loginSignInPin => 'Sign In with PIN';

  @override
  String get loginSendOtp => 'Send OTP to My Phone';

  @override
  String get loginNotYou => 'Not you? Use a different ID';

  @override
  String get loginIdNumberHint => 'Enter your ID Number';

  @override
  String get loginBirthdateHint => 'Select your Birthdate';

  @override
  String get loginContinue => 'Continue';

  @override
  String loginHelloName(String name) {
    return 'Hello, $name!';
  }

  @override
  String get loginMobileExplanation =>
      'We need your mobile number to send you a verification code. You only need to do this once.';

  @override
  String get loginMobileHintFormat =>
      'Philippine mobile number (e.g. 09171234567)';

  @override
  String get loginRegisterSendOtp => 'Register & Send OTP';

  @override
  String get loginOtpSentInstruction =>
      'A 6-digit code was sent to your phone.\nEnter it below.';

  @override
  String get loginResendOtp => 'Resend OTP';

  @override
  String get loginCreatePin => 'Create Your 4-Digit PIN';

  @override
  String get loginEnterPin => 'Enter Your PIN';

  @override
  String get loginPinSetupHint =>
      'This PIN lets you sign in without a text message.';

  @override
  String get loginPinLoginHint => 'Enter your 4-digit PIN to sign in.';

  @override
  String get loginSetPinDialogTitle => 'Set a PIN';

  @override
  String get loginSetPinDialogContent =>
      'Set a 4-digit PIN so you can sign in without waiting for a text message next time.';

  @override
  String get loginNotNow => 'Not Now';

  @override
  String get loginSetPinNow => 'Set PIN Now';

  @override
  String get loginQuickSignInTitle => 'Quick Sign-In';

  @override
  String get loginQuickSignInContent =>
      'Would you like to use your fingerprint or face to sign in next time?\n\nThis makes it easier — no need to type your OTP again.';

  @override
  String get loginYesEnable => 'Yes, Enable';

  @override
  String get homeSignOut => 'Sign Out';

  @override
  String get homeSignOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get beneficiaryTypeSenior => 'Senior Citizen';

  @override
  String get beneficiaryTypePwd => 'PWD';

  @override
  String get languageToggleTooltip => 'Display language';

  @override
  String get languageEnglishLabel => 'English';

  @override
  String get languageFilipinoLabel => 'Filipino';

  @override
  String get statusErrorLoadProfile =>
      'Could not load your profile. Pull to refresh.';

  @override
  String get statusIdDetailsTitle => 'ID Details';

  @override
  String get statusIssuingOffice => 'Issuing Office';

  @override
  String get statusValidFrom => 'Valid From';

  @override
  String get statusValidUntil => 'Valid Until';

  @override
  String get statusBirthdate => 'Birthdate';

  @override
  String get statusMobile => 'Mobile';

  @override
  String get statusActivitySummaryTitle => 'Activity Summary';

  @override
  String get statusTotalVerifications => 'Total Verifications';

  @override
  String get statusPendingFlags => 'Pending Flags';

  @override
  String get statusActiveDisputes => 'Active Disputes';

  @override
  String get statusReportFraudSemantics => 'Report fraud on my ID';

  @override
  String get statusReportFraudButton => 'Report Fraud on My ID';

  @override
  String get statusExpiresToday => 'Your ID expires today!';

  @override
  String get statusExpiresTomorrow => 'Your ID expires tomorrow!';

  @override
  String statusExpiresInDays(int days) {
    return 'Your ID expires in $days days';
  }

  @override
  String get statusRenewInstruction =>
      'Please visit your issuing office to renew your ID.';

  @override
  String get navStatus => 'Status';

  @override
  String get navHistory => 'History';

  @override
  String get navDisputes => 'Disputes';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get transactionsEmptyState => 'No verification records yet';

  @override
  String get transactionsUnknownEstablishment => 'Unknown';

  @override
  String get transactionsDetailTitle => 'Verification Details';

  @override
  String get transactionsEstablishmentLabel => 'Establishment';

  @override
  String get transactionsDateTimeLabel => 'Date & Time';

  @override
  String get transactionsStatusLabel => 'Status';

  @override
  String get transactionsEntryLabel => 'Entry';

  @override
  String get transactionsEntryManual => 'Manual';

  @override
  String get historyEmptyState => 'No activity yet';

  @override
  String get historyDisputeLabel => 'Dispute / Report';

  @override
  String get serviceUnavailableTitle => 'iDetect is unavailable';

  @override
  String get serviceUnavailableMessage =>
      'We could not reach iDetect. Check your connection or try again later.';

  @override
  String get commonRetry => 'Try Again';

  @override
  String get verificationStatusValid => 'VALID';

  @override
  String get verificationStatusInvalid => 'INVALID';

  @override
  String get verificationStatusReview => 'NEEDS REVIEW';

  @override
  String get verificationStatusManualReview => 'MANUAL REVIEW';

  @override
  String get verificationStatusUnknown => 'UNKNOWN';

  @override
  String get disputeStatusSubmitted => 'SUBMITTED';

  @override
  String get disputeStatusAcknowledged => 'ACKNOWLEDGED';

  @override
  String get disputeStatusUnderReview => 'UNDER REVIEW';

  @override
  String get disputeStatusResolved => 'RESOLVED';

  @override
  String get disputeStatusRejected => 'REJECTED';

  @override
  String get beneficiaryStatusActive => 'Active & valid';

  @override
  String get beneficiaryStatusExpired => 'Expired';

  @override
  String get beneficiaryStatusSuspended => 'Under investigation';

  @override
  String get beneficiaryStatusRevoked => 'Revoked';

  @override
  String get beneficiaryStatusUnknown => 'Unknown';

  @override
  String get statusIdNumberLabel => 'ID Number';

  @override
  String get statusShowIdNumber => 'Show ID number';

  @override
  String get statusHideIdNumber => 'Hide ID number';

  @override
  String statusIdNumberHidden(String lastTwo) {
    return 'ID number hidden. It ends in $lastTwo.';
  }

  @override
  String get fraudReportTitle => 'Report Fraud';

  @override
  String get fraudReportWarningBanner =>
      'Filing a fraud report will immediately flag your ID for review. This helps protect your benefits.';

  @override
  String get fraudReportWhatHappened => 'What happened?';

  @override
  String get fraudTypeUnauthorizedLabel => 'Unauthorized Use';

  @override
  String get fraudTypeUnauthorizedDesc =>
      'Someone used my ID without my permission';

  @override
  String get fraudTypeStolenLabel => 'Stolen ID';

  @override
  String get fraudTypeStolenDesc => 'My physical ID card was stolen';

  @override
  String get fraudTypeFakeLabel => 'Fake / Cloned ID';

  @override
  String get fraudTypeFakeDesc => 'Someone created a copy of my ID';

  @override
  String get fraudTypeOtherLabel => 'Other';

  @override
  String get fraudTypeOtherDesc => 'Another type of fraud or misuse';

  @override
  String get fraudReportDescribeIncident => 'Describe the incident';

  @override
  String get fraudReportDescriptionHint =>
      'Provide details: when, where, and how you discovered the fraud...';

  @override
  String get fraudReportErrorEmptyDescription => 'Please describe the incident';

  @override
  String get fraudReportSuccessSnackbar =>
      'Fraud report submitted successfully';

  @override
  String get fraudReportErrorSnackbar =>
      'Failed to submit report. Please try again.';

  @override
  String get fraudReportSubmitting => 'Submitting...';

  @override
  String get fraudReportSubmitButton => 'Submit Report';

  @override
  String get disputesNewButton => 'New Dispute';

  @override
  String get disputesEmptyTitle => 'No disputes filed';

  @override
  String get disputesEmptySubtitle =>
      'Tap the button below to file a new dispute';

  @override
  String get disputesDetailTitle => 'Dispute Details';

  @override
  String get disputesTypeLabel => 'Type';

  @override
  String get disputesFiledLabel => 'Filed';

  @override
  String get disputesDescriptionLabel => 'Description';

  @override
  String get disputesResolutionLabel => 'Resolution';

  @override
  String get disputesFileTitle => 'File a Dispute';

  @override
  String get disputesTypeSectionLabel => 'Dispute Type';

  @override
  String get disputesDescriptionHint => 'Describe your dispute...';

  @override
  String get disputesEstablishmentLabel => 'Where did this happen?';

  @override
  String get disputesFiledOnBehalfLabel => 'Filed for you by';

  @override
  String get disputesEstablishmentHint =>
      'Optional — name the establishment or office, if applicable';

  @override
  String get disputesEstablishmentRequiredHint =>
      'Name of the establishment or office involved';

  @override
  String get disputesEstablishmentPlaceholder =>
      'e.g. Valenzuela City Hall, ABC Store';

  @override
  String get disputesErrorEmptyEstablishment =>
      'Please specify where this happened';

  @override
  String get disputesSupportingDocLabel => 'Supporting Document';

  @override
  String get disputesSupportingDocHint =>
      'Optional — attach a photo of your ID, barangay cert, etc.';

  @override
  String get disputesAttachButton => 'Attach Photo / Document';

  @override
  String get disputesErrorEmptyDescription => 'Please enter a description';

  @override
  String disputesErrorUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get disputesSuccessSnackbar => 'Dispute submitted';

  @override
  String get disputesSubmitButton => 'Submit Dispute';

  @override
  String get disputeTypeWrongDenialLabel => 'Wrong Denial';

  @override
  String get disputeTypeWrongDenialDesc =>
      'A business incorrectly denied you the discount';

  @override
  String get disputeTypeBusinessRefusalLabel => 'Business Refusal';

  @override
  String get disputeTypeBusinessRefusalDesc =>
      'A business refused to honor your valid ID';

  @override
  String get disputeTypeIncorrectDbInfoLabel => 'Incorrect Database Info';

  @override
  String get disputeTypeIncorrectDbInfoDesc =>
      'Your information in our system is incorrect';

  @override
  String get disputeTypeOtherLabel => 'Other';

  @override
  String get disputeTypeOtherDesc => 'A different issue not listed above';

  @override
  String get notificationsErrorFallback => 'Failed to load notifications.';

  @override
  String get notificationsErrorGeneric =>
      'Something went wrong. Please try again.';

  @override
  String get notificationsRetryButton => 'Retry';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsEmptyTitle => 'No notifications';

  @override
  String get notificationsEmptySubtitle => 'Pull down to refresh';

  @override
  String get notificationsLoadMoreError => 'Couldn\'t load more notifications.';

  @override
  String get notificationFallbackTitle => 'Notification';

  @override
  String get callbackRequestButton => 'Request callback';

  @override
  String get callbackRequestsEntryTitle => 'My callback requests';

  @override
  String get callbackRequestsEntrySubtitle => 'Track requests you sent to BPLO';

  @override
  String get callbackSheetTitle => 'Request a callback';

  @override
  String get callbackSheetIntro =>
      'Send a request to the BPLO office about this establishment. For privacy, the business phone number is not shared. BPLO staff will review your request and reply here.';

  @override
  String get callbackEstablishmentLabel => 'Establishment';

  @override
  String get callbackReasonLabel => 'Reason';

  @override
  String get callbackReasonTransaction => 'Question about this transaction';

  @override
  String get callbackReasonCorrection => 'Record needs correction';

  @override
  String get callbackReasonOther => 'Other';

  @override
  String get callbackNoteLabel => 'Additional details (optional)';

  @override
  String get callbackNoteHint => 'Describe what you need help with';

  @override
  String get callbackSubmit => 'Send request';

  @override
  String callbackSuccessMessage(String reference) {
    return 'Request sent. Reference: $reference';
  }

  @override
  String get callbackErrorNotAllowed =>
      'You can only request a callback for an establishment you have transacted with.';

  @override
  String get callbackErrorDuplicate =>
      'You already have an open request for this establishment.';

  @override
  String get callbackErrorGeneric =>
      'Could not send your request. Please try again.';

  @override
  String get callbackRequestsTitle => 'Callback requests';

  @override
  String get callbackRequestsEmpty => 'You have no callback requests yet.';

  @override
  String get callbackStatusOpen => 'Pending';

  @override
  String get callbackStatusHandled => 'Replied';

  @override
  String get callbackNoReplyYet => 'No reply yet';

  @override
  String get callbackReplyLabel => 'BPLO reply';

  @override
  String get callbackRequestedOn => 'Requested';
}
