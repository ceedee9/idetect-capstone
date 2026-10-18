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
  String get commonCancel => 'Kanselahin';

  @override
  String get commonBack => '← Bumalik';

  @override
  String get loginBeneficiaryPortal => 'Portal ng Benepisyaryo';

  @override
  String get loginErrorMissingIdBirthdate =>
      'Pakilagay ang iyong ID number at petsa ng kapanganakan.';

  @override
  String get loginErrorMissingMobile => 'Pakilagay ang iyong mobile number.';

  @override
  String get loginErrorInvalidMobile =>
      'Pakilagay ang wastong mobile number sa Pilipinas\n(hal. 09171234567)';

  @override
  String get loginBiometricReasonSignIn =>
      'Mag-sign in gamit ang iyong fingerprint o mukha';

  @override
  String get loginBiometricReasonEnable =>
      'I-enable ang mabilisang pag-sign in sa susunod';

  @override
  String get lockTitle => 'Naka-lock ang Screen';

  @override
  String get lockSubtitle =>
      'Para sa iyong seguridad, na-lock ang app matapos ang 5 minutong walang aktibidad.';

  @override
  String get lockEnterPin => 'Ilagay ang iyong PIN para magpatuloy';

  @override
  String get lockIncorrectPin => 'Mali ang PIN. Subukan muli.';

  @override
  String get lockBiometricReason => 'I-unlock ang iDetect para magpatuloy';

  @override
  String get lockBiometricButton => 'Gumamit ng fingerprint o mukha';

  @override
  String get lockSignInAgain => 'Mag-sign in ulit na lang';

  @override
  String get lockNoUnlockMethod =>
      'Walang naka-set na PIN o biometric sa device na ito. Mag-sign in ulit para magpatuloy.';

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
  String get loginNotYou => 'Hindi ikaw? Gumamit ng ibang ID';

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
      'Kailangan namin ang iyong numero ng cellphone para makapagpadala ng verification code. Isang beses lang ito gagawin.';

  @override
  String get loginMobileHintFormat =>
      'Numero ng cellphone sa Pilipinas (hal. 09171234567)';

  @override
  String get loginRegisterSendOtp => 'Magrehistro at Ipadala ang OTP';

  @override
  String get loginOtpSentInstruction =>
      'May 6-digit na code na ipinadala sa iyong telepono.\nIlagay ito sa ibaba.';

  @override
  String get loginResendOtp => 'Ipadalang Muli ang OTP';

  @override
  String get loginCreatePin => 'Gumawa ng 4-Digit na PIN';

  @override
  String get loginEnterPin => 'Ilagay ang Iyong PIN';

  @override
  String get loginPinSetupHint =>
      'Ang PIN na ito ay nagbibigay-daan sa iyong mag-sign in nang walang text message.';

  @override
  String get loginPinLoginHint =>
      'Ilagay ang iyong 4-digit na PIN para mag-sign in.';

  @override
  String get loginSetPinDialogTitle => 'Magtakda ng PIN';

  @override
  String get loginSetPinDialogContent =>
      'Magtakda ng 4-digit na PIN upang makapag-sign in ka nang hindi na naghihintay ng text message sa susunod.';

  @override
  String get loginNotNow => 'Huwag Muna';

  @override
  String get loginSetPinNow => 'Itakda ang PIN Ngayon';

  @override
  String get loginQuickSignInTitle => 'Mabilisang Pag-sign In';

  @override
  String get loginQuickSignInContent =>
      'Nais mo bang gamitin ang iyong fingerprint o mukha para mag-sign in sa susunod?\n\nMas madali ito — hindi mo na kailangang i-type ang iyong OTP muli.';

  @override
  String get loginYesEnable => 'Oo, I-enable';

  @override
  String get homeSignOut => 'Mag-sign Out';

  @override
  String get homeSignOutConfirm => 'Sigurado ka bang gusto mong mag-sign out?';

  @override
  String get beneficiaryTypeSenior => 'Senior Citizen';

  @override
  String get beneficiaryTypePwd => 'PWD';

  @override
  String get languageToggleTooltip => 'Wika ng display';

  @override
  String get languageEnglishLabel => 'Ingles';

  @override
  String get languageFilipinoLabel => 'Filipino';

  @override
  String get statusErrorLoadProfile =>
      'Hindi ma-load ang iyong profile. I-pull para i-refresh.';

  @override
  String get statusIdDetailsTitle => 'Mga Detalye ng ID';

  @override
  String get statusIssuingOffice => 'Pinanggalingang Tanggapan';

  @override
  String get statusValidFrom => 'Simula ng Bisa';

  @override
  String get statusValidUntil => 'Katapusan ng Bisa';

  @override
  String get statusBirthdate => 'Petsa ng Kapanganakan';

  @override
  String get statusMobile => 'Cellphone Number';

  @override
  String get statusActivitySummaryTitle => 'Buod ng Aktibidad';

  @override
  String get statusTotalVerifications => 'Kabuuang Beripikasyon';

  @override
  String get statusPendingFlags => 'Nakabinbing Flags';

  @override
  String get statusActiveDisputes => 'Aktibong Reklamo';

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
      'Mangyaring bumisita sa iyong opisina ng pag-isyu upang i-renew ang iyong ID.';

  @override
  String get navStatus => 'Katayuan';

  @override
  String get navHistory => 'Kasaysayan';

  @override
  String get navDisputes => 'Reklamo';

  @override
  String get navAlerts => 'Mga Alerto';

  @override
  String get transactionsEmptyState => 'Wala pang mga talaan ng beripikasyon';

  @override
  String get transactionsUnknownEstablishment => 'Hindi Kilala';

  @override
  String get transactionsDetailTitle => 'Mga Detalye ng Beripikasyon';

  @override
  String get transactionsEstablishmentLabel => 'Establisyemento';

  @override
  String get transactionsDateTimeLabel => 'Petsa at Oras';

  @override
  String get transactionsStatusLabel => 'Katayuan';

  @override
  String get transactionsEntryLabel => 'Paraan ng Pagpasok';

  @override
  String get transactionsEntryManual => 'Manwal';

  @override
  String get historyEmptyState => 'Wala pang aktibidad';

  @override
  String get historyDisputeLabel => 'Reklamo / Ulat';

  @override
  String get serviceUnavailableTitle => 'Hindi maabot ang iDetect';

  @override
  String get serviceUnavailableMessage =>
      'Hindi namin maabot ang iDetect. Suriin ang iyong koneksyon o subukan muli mamaya.';

  @override
  String get commonRetry => 'Subukang Muli';

  @override
  String get verificationStatusValid => 'WASTO';

  @override
  String get verificationStatusInvalid => 'HINDI WASTO';

  @override
  String get verificationStatusReview => 'KAILANGAN NG PAGSUSURI';

  @override
  String get verificationStatusManualReview => 'MANWAL NA PAGSUSURI';

  @override
  String get verificationStatusUnknown => 'HINDI ALAM';

  @override
  String get disputeStatusSubmitted => 'NAISUMITE';

  @override
  String get disputeStatusAcknowledged => 'KINILALA';

  @override
  String get disputeStatusUnderReview => 'SINUSURI';

  @override
  String get disputeStatusResolved => 'NALUTAS';

  @override
  String get disputeStatusRejected => 'TINANGGIHAN';

  @override
  String get beneficiaryStatusActive => 'Aktibo at wasto';

  @override
  String get beneficiaryStatusExpired => 'Nag-expire na';

  @override
  String get beneficiaryStatusSuspended => 'Sinusuri';

  @override
  String get beneficiaryStatusRevoked => 'Binawi';

  @override
  String get beneficiaryStatusUnknown => 'Hindi alam';

  @override
  String get statusIdNumberLabel => 'Numero ng ID';

  @override
  String get statusShowIdNumber => 'Ipakita ang numero ng ID';

  @override
  String get statusHideIdNumber => 'Itago ang numero ng ID';

  @override
  String statusIdNumberHidden(String lastTwo) {
    return 'Nakatago ang numero ng ID. Nagtatapos sa $lastTwo.';
  }

  @override
  String get fraudReportTitle => 'Iulat ang Panloloko';

  @override
  String get fraudReportWarningBanner =>
      'Ang pagsusumite ng ulat ng panloloko ay agad na magma-flag sa iyong ID para sa pagsusuri. Nakakatulong ito na protektahan ang iyong mga benepisyo.';

  @override
  String get fraudReportWhatHappened => 'Ano ang nangyari?';

  @override
  String get fraudTypeUnauthorizedLabel => 'Hindi Awtorisadong Paggamit';

  @override
  String get fraudTypeUnauthorizedDesc =>
      'May gumamit ng aking ID nang wala akong pahintulot';

  @override
  String get fraudTypeStolenLabel => 'Nanakaw na ID';

  @override
  String get fraudTypeStolenDesc => 'Ninakaw ang aking pisikal na ID card';

  @override
  String get fraudTypeFakeLabel => 'Pekeng / Ginayang ID';

  @override
  String get fraudTypeFakeDesc => 'May gumawa ng kopya ng aking ID';

  @override
  String get fraudTypeOtherLabel => 'Iba Pa';

  @override
  String get fraudTypeOtherDesc => 'Ibang uri ng panloloko o maling paggamit';

  @override
  String get fraudReportDescribeIncident => 'Ilarawan ang insidente';

  @override
  String get fraudReportDescriptionHint =>
      'Magbigay ng detalye: kailan, saan, at paano mo nalaman ang panloloko...';

  @override
  String get fraudReportErrorEmptyDescription => 'Pakilarawan ang insidente';

  @override
  String get fraudReportSuccessSnackbar =>
      'Matagumpay na naisumite ang ulat ng panloloko';

  @override
  String get fraudReportErrorSnackbar =>
      'Hindi naisumite ang ulat. Pakisubukang muli.';

  @override
  String get fraudReportSubmitting => 'Isinusumite...';

  @override
  String get fraudReportSubmitButton => 'Isumite ang Ulat';

  @override
  String get disputesNewButton => 'Bagong Reklamo';

  @override
  String get disputesEmptyTitle => 'Walang naisumiteng reklamo';

  @override
  String get disputesEmptySubtitle =>
      'Pindutin ang button sa ibaba para maghain ng bagong reklamo';

  @override
  String get disputesDetailTitle => 'Mga Detalye ng Reklamo';

  @override
  String get disputesTypeLabel => 'Uri';

  @override
  String get disputesFiledLabel => 'Isinampa';

  @override
  String get disputesDescriptionLabel => 'Paglalarawan';

  @override
  String get disputesResolutionLabel => 'Resolusyon';

  @override
  String get disputesAcknowledgeResponse => 'Nabasa ko na ang sagot na ito';

  @override
  String disputesResponseAcknowledgedOn(String date) {
    return 'Kinumpirma noong $date';
  }

  @override
  String get disputesAcknowledgeFailed =>
      'Hindi naitala ang iyong kumpirmasyon. Subukan muli.';

  @override
  String get disputesFileTitle => 'Maghain ng Reklamo';

  @override
  String get disputesTypeSectionLabel => 'Uri ng Reklamo';

  @override
  String get disputesDescriptionHint => 'Ilarawan ang iyong reklamo...';

  @override
  String get disputesEstablishmentLabel => 'Saan ito nangyari?';

  @override
  String get disputesFiledOnBehalfLabel => 'Isinampa para sa iyo ng';

  @override
  String get disputesEstablishmentHint =>
      'Opsyonal — ilagay ang pangalan ng establisyemento o tanggapan, kung naaangkop';

  @override
  String get disputesEstablishmentRequiredHint =>
      'Pangalan ng establisyemento o tanggapang kinasangkutan';

  @override
  String get disputesEstablishmentPlaceholder =>
      'hal. Valenzuela City Hall, ABC Store';

  @override
  String get disputesErrorEmptyEstablishment =>
      'Pakilagay kung saan ito nangyari';

  @override
  String get disputesSupportingDocLabel => 'Sumusuportang Dokumento';

  @override
  String get disputesSupportingDocHint =>
      'Opsyonal — maglakip ng larawan ng iyong ID, sertipiko ng barangay, atbp.';

  @override
  String get disputesAttachButton => 'Maglakip ng Larawan / Dokumento';

  @override
  String get disputesErrorEmptyDescription =>
      'Pakilagay ang isang paglalarawan';

  @override
  String disputesErrorUploadFailed(String error) {
    return 'Hindi na-upload: $error';
  }

  @override
  String get disputesSuccessSnackbar => 'Naisumite ang reklamo';

  @override
  String get disputesSubmitButton => 'Isumite ang Reklamo';

  @override
  String get disputeTypeWrongDenialLabel => 'Maling Pagtanggi';

  @override
  String get disputeTypeWrongDenialDesc =>
      'Maling tinanggihan ka ng isang negosyo sa diskwento';

  @override
  String get disputeTypeBusinessRefusalLabel => 'Pagtanggi ng Negosyo';

  @override
  String get disputeTypeBusinessRefusalDesc =>
      'May negosyong tumanggi kilalanin ang iyong wastong ID';

  @override
  String get disputeTypeIncorrectDbInfoLabel =>
      'Maling Impormasyon sa Database';

  @override
  String get disputeTypeIncorrectDbInfoDesc =>
      'Mali ang iyong impormasyon sa aming sistema';

  @override
  String get disputeTypeOtherLabel => 'Iba Pa';

  @override
  String get disputeTypeOtherDesc =>
      'Ibang isyung wala sa mga pagpipilian sa itaas';

  @override
  String get notificationsErrorFallback => 'Hindi ma-load ang mga abiso.';

  @override
  String get notificationsErrorGeneric =>
      'May naganap na error. Pakisubukang muli.';

  @override
  String get notificationsRetryButton => 'Subukang Muli';

  @override
  String get notificationsMarkAllRead => 'Markahan lahat bilang nabasa';

  @override
  String get notificationsEmptyTitle => 'Walang abiso';

  @override
  String get notificationsEmptySubtitle => 'I-pull pababa para mag-refresh';

  @override
  String get notificationsLoadMoreError =>
      'Hindi ma-load ang karagdagang abiso.';

  @override
  String get notificationFallbackTitle => 'Abiso';

  @override
  String get callbackRequestButton => 'Humiling ng tawag';

  @override
  String get callbackRequestsEntryTitle => 'Mga hiling ko na tawag';

  @override
  String get callbackRequestsEntrySubtitle =>
      'Subaybayan ang mga hiling mo sa BPLO';

  @override
  String get callbackSheetTitle => 'Humiling ng tawag';

  @override
  String get callbackSheetIntro =>
      'Magpadala ng hiling sa tanggapan ng BPLO tungkol sa establisimyentong ito. Para sa privacy, hindi ibinabahagi ang numero ng telepono ng negosyo. Susuriin ng staff ng BPLO ang hiling mo at sasagot dito.';

  @override
  String get callbackEstablishmentLabel => 'Establisimyento';

  @override
  String get callbackReasonLabel => 'Dahilan';

  @override
  String get callbackReasonTransaction => 'Tanong tungkol sa transaksyong ito';

  @override
  String get callbackReasonCorrection => 'Kailangang itama ang talaan';

  @override
  String get callbackReasonOther => 'Iba pa';

  @override
  String get callbackNoteLabel => 'Karagdagang detalye (opsyonal)';

  @override
  String get callbackNoteHint => 'Ilarawan kung ano ang kailangan mo ng tulong';

  @override
  String get callbackSubmit => 'Ipadala ang hiling';

  @override
  String callbackSuccessMessage(String reference) {
    return 'Naipadala ang hiling. Reference: $reference';
  }

  @override
  String get callbackErrorNotAllowed =>
      'Para lang sa establisimyentong pinagtransaksyunan mo maaaring humiling ng tawag.';

  @override
  String get callbackErrorDuplicate =>
      'May bukas ka nang hiling para sa establisimyentong ito.';

  @override
  String get callbackErrorGeneric =>
      'Hindi naipadala ang hiling mo. Subukan muli.';

  @override
  String get callbackRequestsTitle => 'Mga hiling na tawag';

  @override
  String get callbackRequestsEmpty => 'Wala ka pang hiling na tawag.';

  @override
  String get callbackStatusOpen => 'Nakabinbin';

  @override
  String get callbackStatusHandled => 'Sinagot na';

  @override
  String get callbackNoReplyYet => 'Wala pang sagot';

  @override
  String get callbackReplyLabel => 'Sagot ng BPLO';

  @override
  String get callbackRequestedOn => 'Hiniling';
}
