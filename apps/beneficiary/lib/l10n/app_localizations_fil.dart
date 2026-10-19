// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get appBeneficiaryFallback => 'Benepisyaryo';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => '← Back';

  @override
  String get loginBeneficiaryPortal => 'Portal ng Benepisyaryo';

  @override
  String get loginWelcomeTitle => 'Maligayang pagdating sa iDetect';

  @override
  String get loginWelcomeSubtitle => 'Piliin kung paano ka magpapatuloy.';

  @override
  String get loginActivateButton => 'I-activate ang aking account';

  @override
  String get loginActivateHint =>
      'Unang beses dito? Gamitin ang ID at petsa ng kapanganakan sa iyong talaan.';

  @override
  String get loginSignInButton => 'Mag-sign in';

  @override
  String get loginSignInHint =>
      'Na-activate na? Mag-sign in gamit ang iyong PIN o fingerprint.';

  @override
  String get loginAlreadyHaveAccount => 'May account na ako';

  @override
  String get loginForgotPin => 'Nakalimutan ang PIN? Gumamit ng one-time code';

  @override
  String get loginSwitchAccount => 'Hindi ikaw ito? Magpalit ng account';

  @override
  String get loginActivateTitle => 'I-activate ang iyong account';

  @override
  String get loginActivateSubtitle =>
      'Ilagay ang ID number at petsa ng kapanganakan sa iyong talaan ng benepisyaryo. Magpapadala kami ng one-time code sa iyong telepono.';

  @override
  String get loginActivateHelp =>
      'Kung tugma ang iyong detalye sa aming talaan, makakatanggap ka ng code sa loob ng isang minuto. Hindi pa dumating? Bisitahin ang iyong opisina.';

  @override
  String get loginErrorMissingIdBirthdate =>
      'Pakilagay ang iyong ID number at petsa ng kapanganakan.';

  @override
  String get loginErrorMissingMobile => 'Pakilagay ang iyong cellphone number.';

  @override
  String get loginErrorInvalidMobile =>
      'Pakilagay ang valid cellphone number sa Pilipinas\n(halimbawa: 09171234567)';

  @override
  String get loginBiometricReasonSignIn =>
      'Mag-sign in gamit ang iyong fingerprint o mukha';

  @override
  String get loginBiometricReasonEnable =>
      'I-on ang mabilis na pag-sign in sa susunod';

  @override
  String get lockTitle => 'Naka-lock ang Screen';

  @override
  String get lockSubtitle =>
      'Para sa iyong seguridad, na-lock ang app dahil 5 minuto itong hindi ginamit.';

  @override
  String get lockEnterPin => 'Ilagay ang iyong PIN para magpatuloy';

  @override
  String get lockIncorrectPin => 'Mali ang PIN. Pakisubukan ulit.';

  @override
  String get lockBiometricReason => 'I-unlock ang iDetect para magpatuloy';

  @override
  String get lockBiometricButton => 'Gumamit ng fingerprint o mukha';

  @override
  String get lockSignInAgain => 'Mag-sign in ulit na lang';

  @override
  String get lockNoUnlockMethod =>
      'Walang naka-set na PIN, fingerprint, o mukha sa phone na ito. Mag-sign in ulit para magpatuloy.';

  @override
  String get lockSessionMissing => 'Mag-sign in ulit para magpatuloy.';

  @override
  String get loginWelcomeBack => 'Maligayang pagbabalik,';

  @override
  String get loginSignInFingerprint => 'Mag-sign In gamit ang Fingerprint';

  @override
  String get loginOrSignInOtp => '— o mag-sign in gamit ang OTP —';

  @override
  String get loginSignInPin => 'Mag-sign In gamit ang PIN';

  @override
  String get loginSendOtp => 'Ipadala ang OTP sa Aking Cellphone';

  @override
  String get loginNotYou => 'Hindi ikaw ito? Gumamit ng ibang ID';

  @override
  String get loginIdNumberHint => 'Ilagay ang iyong ID Number';

  @override
  String get loginBirthdateHint => 'Piliin ang iyong Petsa ng Kapanganakan';

  @override
  String get loginContinue => 'Magpatuloy';

  @override
  String loginHelloName(String name) {
    return 'Kumusta, $name!';
  }

  @override
  String get loginMobileExplanation =>
      'Kailangan namin ang iyong cellphone number para makapagpadala ng verification code. Isang beses lang ito kailangang gawin.';

  @override
  String get loginMobileHintFormat =>
      'Cellphone number sa Pilipinas (halimbawa: 09171234567)';

  @override
  String get loginRegisterSendOtp => 'Mag-register at Ipadala ang OTP';

  @override
  String get loginOtpSentInstruction =>
      'Nagpadala kami ng 6-digit na code sa iyong cellphone.\nIlagay ito sa ibaba.';

  @override
  String get loginResendOtp => 'Ipadala Ulit ang OTP';

  @override
  String get loginCreatePin => 'Gumawa ng 4-Digit na PIN';

  @override
  String get loginEnterPin => 'Ilagay ang Iyong PIN';

  @override
  String get loginPinSetupHint =>
      'Sa PIN na ito, makakapag-sign in ka nang hindi na kailangan ng text message.';

  @override
  String get loginPinLoginHint =>
      'Ilagay ang iyong 4-digit na PIN para mag-sign in.';

  @override
  String get loginSetPinDialogTitle => 'Maglagay ng PIN';

  @override
  String get loginSetPinDialogContent =>
      'Maglagay ng 4-digit na PIN para makapag-sign in ka sa susunod nang hindi naghihintay ng text message.';

  @override
  String get loginNotNow => 'Huwag Muna';

  @override
  String get loginSetPinNow => 'Itakda ang PIN Ngayon';

  @override
  String get loginQuickSignInTitle => 'Mabilis na Pag-sign In';

  @override
  String get loginQuickSignInContent =>
      'Gusto mo bang gamitin ang iyong fingerprint o mukha sa pag-sign in sa susunod?\n\nMas madali ito — hindi mo na kailangang ilagay ulit ang OTP.';

  @override
  String get loginYesEnable => 'Oo, I-on';

  @override
  String get homeSignOut => 'Mag-sign Out';

  @override
  String get homeSignOutConfirm => 'Sigurado ka bang gusto mong mag-sign out?';

  @override
  String get beneficiaryTypeSenior => 'Senior Citizen';

  @override
  String get beneficiaryTypePwd => 'PWD';

  @override
  String get languageToggleTooltip => 'Wika ng screen';

  @override
  String get languageEnglishLabel => 'Ingles';

  @override
  String get languageFilipinoLabel => 'Filipino';

  @override
  String get statusErrorLoadProfile =>
      'Hindi ma-load ang iyong profile. Hilahin pababa ang screen para i-refresh.';

  @override
  String get statusIdDetailsTitle => 'Detalye ng ID';

  @override
  String get statusIssuingOffice => 'Opisinang Nag-isyu';

  @override
  String get statusValidFrom => 'Valid Mula';

  @override
  String get statusValidUntil => 'Valid Hanggang';

  @override
  String get statusBirthdate => 'Petsa ng Kapanganakan';

  @override
  String get statusMobile => 'Cellphone Number';

  @override
  String get statusActivitySummaryTitle => 'Buod ng Aktibidad';

  @override
  String get statusTotalVerifications => 'Kabuuang Pag-verify';

  @override
  String get statusPendingFlags => 'Flag na Naghihintay';

  @override
  String get statusActiveDisputes => 'Reklamong Bukas Pa';

  @override
  String get statusReportFraudSemantics => 'Mag-ulat ng panloloko sa aking ID';

  @override
  String get statusReportFraudButton => 'Iulat ang Panloloko sa Aking ID';

  @override
  String get statusExpiresToday => 'Mag-e-expire ang iyong ID ngayon!';

  @override
  String get statusExpiresTomorrow => 'Mag-e-expire ang iyong ID bukas!';

  @override
  String statusExpiresInDays(int days) {
    return 'Mag-e-expire ang iyong ID sa loob ng $days na araw';
  }

  @override
  String get statusRenewInstruction =>
      'Pumunta sa opisinang nag-isyu ng iyong ID para i-renew ito.';

  @override
  String get navStatus => 'Status';

  @override
  String get navHistory => 'History';

  @override
  String get navDisputes => 'Reklamo';

  @override
  String get navAlerts => 'Mga Abiso';

  @override
  String get transactionsEmptyState => 'Wala pang record ng pag-verify';

  @override
  String get transactionsUnknownEstablishment => 'Hindi Kilala';

  @override
  String get transactionsDetailTitle => 'Detalye ng Pag-verify';

  @override
  String get transactionsEstablishmentLabel => 'Negosyo';

  @override
  String get transactionsDateTimeLabel => 'Petsa at Oras';

  @override
  String get transactionsStatusLabel => 'Status';

  @override
  String get transactionsEntryLabel => 'Paraan ng Paglalagay';

  @override
  String get transactionsEntryManual => 'Mano-mano';

  @override
  String get historyEmptyState => 'Wala pang aktibidad';

  @override
  String get historyDisputeLabel => 'Reklamo / Ulat';

  @override
  String get serviceUnavailableTitle => 'Hindi magamit ang iDetect ngayon';

  @override
  String get serviceUnavailableMessage =>
      'Hindi kami makakonekta sa iDetect. Tingnan ang iyong internet connection o subukan ulit mamaya.';

  @override
  String get commonRetry => 'Subukan Ulit';

  @override
  String get verificationStatusValid => 'VALID';

  @override
  String get verificationStatusInvalid => 'HINDI VALID';

  @override
  String get verificationStatusReview => 'KAILANGAN NG PAGSUSURI';

  @override
  String get verificationStatusManualReview => 'MANO-MANONG PAGSUSURI';

  @override
  String get verificationStatusUnknown => 'HINDI ALAM';

  @override
  String get disputeStatusSubmitted => 'NAIPADALA';

  @override
  String get disputeStatusAcknowledged => 'NATANGGAP';

  @override
  String get disputeStatusUnderReview => 'SINUSURI';

  @override
  String get disputeStatusResolved => 'NAAYOS NA';

  @override
  String get disputeStatusRejected => 'TINANGGIHAN';

  @override
  String get beneficiaryStatusActive => 'Aktibo at valid';

  @override
  String get beneficiaryStatusExpired => 'Nag-expire na';

  @override
  String get beneficiaryStatusSuspended => 'Iniimbestigahan';

  @override
  String get beneficiaryStatusRevoked => 'Kinansela';

  @override
  String get beneficiaryStatusUnknown => 'Hindi alam';

  @override
  String get statusIdNumberLabel => 'ID Number';

  @override
  String get statusShowIdNumber => 'Ipakita ang ID number';

  @override
  String get statusHideIdNumber => 'Itago ang ID number';

  @override
  String statusIdNumberHidden(String lastTwo) {
    return 'Nakatago ang ID number. Nagtatapos ito sa $lastTwo.';
  }

  @override
  String get fraudReportTitle => 'Iulat ang Panloloko';

  @override
  String get fraudReportWarningBanner =>
      'Kapag nagpadala ka ng ulat ng panloloko, agad na magkakaroon ng flag ang iyong ID para masuri. Makakatulong ito para maprotektahan ang iyong mga benepisyo.';

  @override
  String get fraudReportWhatHappened => 'Ano ang nangyari?';

  @override
  String get fraudTypeUnauthorizedLabel => 'Ginamit Nang Walang Pahintulot';

  @override
  String get fraudTypeUnauthorizedDesc =>
      'May gumamit ng aking ID nang wala akong pahintulot';

  @override
  String get fraudTypeStolenLabel => 'Ninakaw na ID';

  @override
  String get fraudTypeStolenDesc => 'Ninakaw ang aking ID card';

  @override
  String get fraudTypeFakeLabel => 'Peke / Kinopyang ID';

  @override
  String get fraudTypeFakeDesc => 'May gumawa ng kopya ng aking ID';

  @override
  String get fraudTypeOtherLabel => 'Iba Pa';

  @override
  String get fraudTypeOtherDesc => 'Ibang uri ng panloloko o maling paggamit';

  @override
  String get fraudReportDescribeIncident => 'Ikuwento ang nangyari';

  @override
  String get fraudReportDescriptionHint =>
      'Magbigay ng detalye: kailan, saan, at paano mo nalaman ang panloloko...';

  @override
  String get fraudReportErrorEmptyDescription => 'Pakisulat ang nangyari';

  @override
  String get fraudReportSuccessSnackbar => 'Naipadala na ang ulat ng panloloko';

  @override
  String get fraudReportErrorSnackbar =>
      'Hindi naipadala ang ulat. Pakisubukan ulit.';

  @override
  String get fraudReportSubmitting => 'Ipinapadala...';

  @override
  String get fraudReportSubmitButton => 'Ipadala ang Ulat';

  @override
  String get disputesNewButton => 'Bagong Reklamo';

  @override
  String get disputesEmptyTitle => 'Wala pang na-file na reklamo';

  @override
  String get disputesEmptySubtitle =>
      'Pindutin ang button sa ibaba para mag-file ng bagong reklamo';

  @override
  String get disputesDetailTitle => 'Mga Detalye ng Reklamo';

  @override
  String get disputesTypeLabel => 'Uri';

  @override
  String get disputesFiledLabel => 'Na-file';

  @override
  String get disputesDescriptionLabel => 'Paglalarawan';

  @override
  String get disputesResolutionLabel => 'Solusyon';

  @override
  String get disputesAcknowledgeResponse => 'Nabasa ko na ang sagot na ito';

  @override
  String disputesResponseAcknowledgedOn(String date) {
    return 'Nabasa noong $date';
  }

  @override
  String get disputesAcknowledgeFailed =>
      'Hindi nai-save na nabasa mo na ang sagot. Pakisubukan ulit.';

  @override
  String get disputesFileTitle => 'Mag-file ng Reklamo';

  @override
  String get disputesTypeSectionLabel => 'Uri ng Reklamo';

  @override
  String get disputesDescriptionHint => 'Ikuwento ang iyong reklamo...';

  @override
  String get disputesEstablishmentLabel => 'Saan ito nangyari?';

  @override
  String get disputesFiledOnBehalfLabel => 'Na-file para sa iyo ng';

  @override
  String get disputesEstablishmentHint =>
      'Opsyonal — ilagay ang pangalan ng negosyo o opisina, kung mayroon';

  @override
  String get disputesEstablishmentRequiredHint =>
      'Pangalan ng negosyo o opisinang may kinalaman dito';

  @override
  String get disputesEstablishmentPlaceholder =>
      'Halimbawa: Valenzuela City Hall, ABC Store';

  @override
  String get disputesErrorEmptyEstablishment =>
      'Pakilagay kung saan ito nangyari';

  @override
  String get disputesSupportingDocLabel => 'Kasamang Dokumento';

  @override
  String get disputesSupportingDocHint =>
      'Opsyonal — mag-attach ng litrato ng iyong ID, barangay certificate, at iba pa.';

  @override
  String get disputesAttachButton => 'Mag-attach ng Litrato / Dokumento';

  @override
  String get disputesErrorEmptyDescription => 'Pakisulat ang iyong reklamo';

  @override
  String disputesErrorUploadFailed(String error) {
    return 'Hindi na-upload: $error';
  }

  @override
  String get disputesSuccessSnackbar => 'Naipadala na ang reklamo';

  @override
  String get disputesSubmitButton => 'Ipadala ang Reklamo';

  @override
  String get disputeTypeWrongDenialLabel => 'Maling Pagtanggi';

  @override
  String get disputeTypeWrongDenialDesc =>
      'Hindi ka binigyan ng diskwento ng isang negosyo kahit dapat kang makakuha nito';

  @override
  String get disputeTypeBusinessRefusalLabel => 'Pagtanggi ng Negosyo';

  @override
  String get disputeTypeBusinessRefusalDesc =>
      'May negosyong hindi tumanggap ng iyong valid na ID';

  @override
  String get disputeTypeIncorrectDbInfoLabel => 'Maling Impormasyon sa Sistema';

  @override
  String get disputeTypeIncorrectDbInfoDesc =>
      'Mali ang iyong impormasyon sa aming sistema';

  @override
  String get disputeTypeOtherLabel => 'Iba Pa';

  @override
  String get disputeTypeOtherDesc =>
      'Ibang problemang hindi nakalista sa itaas';

  @override
  String get notificationsErrorFallback => 'Hindi ma-load ang mga abiso.';

  @override
  String get notificationsErrorGeneric =>
      'May nangyaring problema. Pakisubukan ulit.';

  @override
  String get notificationsRetryButton => 'Subukan Ulit';

  @override
  String get notificationsMarkAllRead => 'Markahang nabasa na ang lahat';

  @override
  String get notificationsEmptyTitle => 'Walang abiso';

  @override
  String get notificationsEmptySubtitle => 'Hilahin pababa para mag-refresh';

  @override
  String get notificationsLoadMoreError => 'Hindi ma-load ang iba pang abiso.';

  @override
  String get notificationFallbackTitle => 'Abiso';

  @override
  String get callbackRequestButton => 'Humiling ng tawag';

  @override
  String get callbackRequestsEntryTitle => 'Mga hiniling kong tawag';

  @override
  String get callbackRequestsEntrySubtitle =>
      'Tingnan ang mga hiniling mo sa BPLO';

  @override
  String get callbackSheetTitle => 'Humiling ng tawag';

  @override
  String get callbackSheetIntro =>
      'Magpadala ng hiling sa opisina ng BPLO tungkol sa negosyong ito. Para sa privacy, hindi ibinibigay ang phone number ng negosyo. Titingnan ng staff ng BPLO ang hiling mo at sasagot dito.';

  @override
  String get callbackEstablishmentLabel => 'Negosyo';

  @override
  String get callbackReasonLabel => 'Dahilan';

  @override
  String get callbackReasonTransaction => 'Tanong tungkol sa transaksyong ito';

  @override
  String get callbackReasonCorrection => 'Kailangang itama ang record';

  @override
  String get callbackReasonOther => 'Iba pa';

  @override
  String get callbackNoteLabel => 'Dagdag na detalye (opsyonal)';

  @override
  String get callbackNoteHint => 'Sabihin kung anong tulong ang kailangan mo';

  @override
  String get callbackSubmit => 'Ipadala ang hiling';

  @override
  String callbackSuccessMessage(String reference) {
    return 'Naipadala ang hiling. Reference: $reference';
  }

  @override
  String get callbackErrorNotAllowed =>
      'Makakahiling ka lang ng tawag sa negosyong may transaksyon ka na.';

  @override
  String get callbackErrorDuplicate =>
      'May hiling ka na para sa negosyong ito na hindi pa nasasagot.';

  @override
  String get callbackErrorGeneric =>
      'Hindi naipadala ang hiling mo. Subukan ulit.';

  @override
  String get callbackRequestsTitle => 'Mga hiniling na tawag';

  @override
  String get callbackRequestsEmpty => 'Wala ka pang hiniling na tawag.';

  @override
  String get callbackStatusOpen => 'Naghihintay';

  @override
  String get callbackStatusHandled => 'Sinagot na';

  @override
  String get callbackNoReplyYet => 'Wala pang sagot';

  @override
  String get callbackReplyLabel => 'Sagot ng BPLO';

  @override
  String get callbackRequestedOn => 'Hiniling';
}
