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
  String get languageToggleTooltip => 'Baguhin ang wika';

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
  String get disputesFileTitle => 'Maghain ng Reklamo';

  @override
  String get disputesTypeSectionLabel => 'Uri ng Reklamo';

  @override
  String get disputesDescriptionHint => 'Ilarawan ang iyong reklamo...';

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
}
