import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_design_system.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputeType {
  final IconData icon;
  final String label;
  final String desc;
  const _DisputeType({
    required this.icon,
    required this.label,
    required this.desc,
  });
}

/// Lets the beneficiary confirm they read the staff response.
class _AcknowledgeResponseButton extends StatefulWidget {
  const _AcknowledgeResponseButton({
    required this.disputeId,
    required this.loc,
    required this.onDone,
  });

  final String disputeId;
  final AppLocalizations loc;
  final VoidCallback onDone;

  @override
  State<_AcknowledgeResponseButton> createState() =>
      _AcknowledgeResponseButtonState();
}

class _AcknowledgeResponseButtonState
    extends State<_AcknowledgeResponseButton> {
  bool _busy = false;

  Future<void> _acknowledge() async {
    setState(() => _busy = true);
    final error = await ApiService.acknowledgeDisputeResponse(widget.disputeId);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      widget.onDone();
      return;
    }
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.loc.disputesAcknowledgeFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : _acknowledge,
        child: _busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.loc.disputesAcknowledgeResponse),
      ),
    );
  }
}

class _DisputesScreenState extends State<DisputesScreen> {
  List<DisputeRecord>? _disputes;
  bool _isLoading = true;
  String? _error;

  // Dispute types where "where did this happen" is essential to
  // investigate — a business/establishment refusing or misusing the ID.
  // incorrect_db_info is a records issue with no associated establishment,
  // so it stays optional there.
  static const Set<String> _establishmentRequiredTypes = {
    'wrong_denial',
    'unauthorized_use',
    'business_refusal',
  };

  bool _isEstablishmentRequired(String type) =>
      _establishmentRequiredTypes.contains(type);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ApiService.getMyDisputes();
    if (mounted) {
      final loc = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _disputes = result.disputes;
        _error = result.success ? null : loc.serviceUnavailableMessage;
      });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'submitted':
      case 'open':
        return Colors.orange;
      case 'acknowledged':
      case 'under_review':
      case 'investigating':
        return AppDesignSystem.interactiveBlue;
      case 'resolved':
        return AppDesignSystem.statusValid;
      case 'rejected':
        return AppDesignSystem.statusInvalid;
      default:
        return AppDesignSystem.textSecondary;
    }
  }

  String _statusLabel(String status, AppLocalizations loc) {
    switch (status) {
      case 'submitted':
      case 'open':
        return loc.disputeStatusSubmitted;
      case 'acknowledged':
        return loc.disputeStatusAcknowledged;
      case 'under_review':
      case 'investigating':
        return loc.disputeStatusUnderReview;
      case 'resolved':
        return loc.disputeStatusResolved;
      case 'rejected':
        return loc.disputeStatusRejected;
      default:
        return loc.disputeStatusSubmitted;
    }
  }

  // Known dispute-type keys get explicit localized label/icon/description
  // (matching fraud_report_screen's pattern) instead of the mechanical
  // word-capitalization _formatType did before — that approach can't be
  // translated and produced awkward results (e.g. "Incorrect Db Info").
  // _formatType is kept only as a fallback for an unrecognized type value.
  Map<String, _DisputeType> _typesFor(AppLocalizations loc) => {
    'wrong_denial': _DisputeType(
      icon: Icons.block_outlined,
      label: loc.disputeTypeWrongDenialLabel,
      desc: loc.disputeTypeWrongDenialDesc,
    ),
    // Reuses the fraud-report screen's "unauthorized use" strings —
    // genuinely the same phrase/meaning in both contexts.
    'unauthorized_use': _DisputeType(
      icon: Icons.person_off_outlined,
      label: loc.fraudTypeUnauthorizedLabel,
      desc: loc.fraudTypeUnauthorizedDesc,
    ),
    'business_refusal': _DisputeType(
      icon: Icons.storefront_outlined,
      label: loc.disputeTypeBusinessRefusalLabel,
      desc: loc.disputeTypeBusinessRefusalDesc,
    ),
    'incorrect_db_info': _DisputeType(
      icon: Icons.fact_check_outlined,
      label: loc.disputeTypeIncorrectDbInfoLabel,
      desc: loc.disputeTypeIncorrectDbInfoDesc,
    ),
    'other': _DisputeType(
      icon: Icons.more_horiz,
      label: loc.disputeTypeOtherLabel,
      desc: loc.disputeTypeOtherDesc,
    ),
  };

  String _formatType(String t, AppLocalizations loc) {
    final known = _typesFor(loc)[t];
    if (known != null) return known.label;
    return t
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundWarm,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppDesignSystem.primaryBlue,
              ),
            )
          : _error != null
          ? _buildUnavailable(loc)
          : _disputes!.isEmpty
          ? _buildEmpty(loc)
          : RefreshIndicator(
              onRefresh: _load,
              color: AppDesignSystem.primaryBlue,
              child: ListView.builder(
                padding: const EdgeInsets.all(
                  AppDesignSystem.screenPaddingHorizontal,
                ),
                itemCount: _disputes!.length,
                itemBuilder: (_, i) => _buildTile(_disputes![i], loc),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.selectionClick();
          _showNewDispute();
        },
        backgroundColor: AppDesignSystem.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(loc.disputesNewButton, style: AppDesignSystem.buttonMedium),
      ),
    );
  }

  Widget _buildUnavailable(AppLocalizations loc) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 56,
                    color: AppDesignSystem.textHint,
                  ),
                  const SizedBox(height: AppDesignSystem.spaceSM),
                  Text(
                    loc.serviceUnavailableTitle,
                    style: AppDesignSystem.bodyMedium,
                  ),
                  const SizedBox(height: AppDesignSystem.spaceXS),
                  Text(
                    _error!,
                    style: AppDesignSystem.caption,
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(loc.commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel, size: 64, color: AppDesignSystem.textHint),
          const SizedBox(height: AppDesignSystem.spaceSM),
          Text(loc.disputesEmptyTitle, style: AppDesignSystem.bodyMedium),
          const SizedBox(height: AppDesignSystem.spaceXS),
          Text(loc.disputesEmptySubtitle, style: AppDesignSystem.caption),
        ],
      ),
    );
  }

  Widget _buildTile(DisputeRecord d, AppLocalizations loc) {
    final date = DateFormat(
      'MMM d, yyyy',
      loc.localeName,
    ).format(d.submittedAt);
    final color = _statusColor(d.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spaceXS),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowSM,
      ),
      child: InkWell(
        borderRadius: AppDesignSystem.cardRadius,
        onTap: () {
          HapticFeedback.selectionClick();
          _showDetail(d, loc);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatType(d.disputeType, loc),
                      style: AppDesignSystem.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusFull,
                      ),
                    ),
                    child: Text(
                      // NOTE: raw API status value, uppercased — not
                      // localized. Same known, already-flagged gap as
                      // AppDesignSystem.getStatusLabel and
                      // transactions_screen's result badge.
                      _statusLabel(d.status, loc),
                      style: AppDesignSystem.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                d.explanation,
                style: AppDesignSystem.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                date,
                style: AppDesignSystem.caption.copyWith(
                  color: AppDesignSystem.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(DisputeRecord d, AppLocalizations loc) {
    final formatted = DateFormat(
      'MMMM d, yyyy  •  h:mm a',
      loc.localeName,
    ).format(d.submittedAt);
    final color = _statusColor(d.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesignSystem.radiusLG),
        ),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDesignSystem.borderLight,
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusFull,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              loc.disputesDetailTitle,
              style: AppDesignSystem.heading3.copyWith(
                color: AppDesignSystem.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Status — was a bare, unstyled Text('Status: ') with no
            // AppDesignSystem style at all, unlike everything else here.
            Row(
              children: [
                Text(
                  '${loc.transactionsStatusLabel}: ',
                  style: AppDesignSystem.bodyMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      AppDesignSystem.radiusFull,
                    ),
                  ),
                  child: Text(
                    _statusLabel(d.status, loc),
                    style: AppDesignSystem.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _detailRow(loc.disputesTypeLabel, _formatType(d.disputeType, loc)),
            _detailRow(loc.disputesFiledLabel, formatted),
            // Surfaces where the incident happened, when provided,
            // mirroring establishment_name already shown on the staff
            // portals' dispute detail view.
            if (d.establishmentName != null && d.establishmentName!.isNotEmpty)
              _detailRow(loc.disputesEstablishmentLabel, d.establishmentName!),
            if (d.filedOnBehalf && d.filedByEstablishmentName != null)
              _detailRow(
                loc.disputesFiledOnBehalfLabel,
                d.filedByEstablishmentName!,
              ),
            const SizedBox(height: 12),

            Text(loc.disputesDescriptionLabel, style: AppDesignSystem.heading4),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.backgroundWarm,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
              ),
              child: Text(d.explanation, style: AppDesignSystem.bodyMedium),
            ),

            if (d.resolution != null) ...[
              const SizedBox(height: 16),
              Text(
                loc.disputesResolutionLabel,
                style: AppDesignSystem.heading4,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesignSystem.statusValid.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                ),
                child: Text(d.resolution!, style: AppDesignSystem.bodyMedium),
              ),
              const SizedBox(height: 12),
              if (d.beneficiaryAcknowledgedAt != null)
                Text(
                  loc.disputesResponseAcknowledgedOn(
                    DateFormat(
                      'MMM d, yyyy  •  h:mm a',
                      loc.localeName,
                    ).format(d.beneficiaryAcknowledgedAt!.toLocal()),
                  ),
                  style: AppDesignSystem.caption.copyWith(
                    color: AppDesignSystem.statusValid,
                  ),
                )
              else
                _AcknowledgeResponseButton(
                  disputeId: d.id,
                  loc: loc,
                  onDone: _load,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppDesignSystem.bodySmall.copyWith(
                color: AppDesignSystem.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppDesignSystem.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── New Dispute Sheet ──
  void _showNewDispute() {
    final loc = AppLocalizations.of(context)!;
    final types = _typesFor(loc);
    String selectedType = 'wrong_denial';
    final descCtrl = TextEditingController();
    // Lets the beneficiary say where the issue happened (business name,
    // government office, etc.) so it flows through to the
    // establishment_name field already displayed on the staff portals'
    // dispute list/detail views. Required or optional depending on
    // selectedType — see _isEstablishmentRequired.
    final establishmentCtrl = TextEditingController();
    XFile? pickedFile;
    bool isUploading = false;
    String? uploadError;
    // Inline validation state, shown under each field itself instead of
    // relying solely on a SnackBar that's easy to miss.
    String? descError;
    String? establishmentError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesignSystem.radiusLG),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.borderLight,
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusFull,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  loc.disputesFileTitle,
                  style: AppDesignSystem.heading3.copyWith(
                    color: AppDesignSystem.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Dispute type — full-width selectable cards, matching
                // fraud_report_screen's pattern instead of the smaller
                // ChoiceChip row this used before. Same kind of
                // "choose one of ~4 categories" interaction deserves
                // the same tap-target size and visual treatment across
                // the app, not two different conventions.
                Text(
                  loc.disputesTypeSectionLabel,
                  style: AppDesignSystem.heading4,
                ),
                const SizedBox(height: 8),
                ...types.entries.map((e) {
                  final active = e.key == selectedType;
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDesignSystem.spaceXS,
                    ),
                    child: Semantics(
                      label: '${e.value.label}. ${e.value.desc}',
                      selected: active,
                      button: true,
                      child: InkWell(
                        borderRadius: AppDesignSystem.cardRadius,
                        onTap: () {
                          if (!active) HapticFeedback.selectionClick();
                          setSheetState(() {
                            selectedType = e.key;
                            // Re-evaluate: a message that was required
                            // for the old type may no longer apply
                            // (or vice versa) after switching type.
                            if (!_isEstablishmentRequired(selectedType)) {
                              establishmentError = null;
                            } else if (establishmentCtrl.text
                                .trim()
                                .isNotEmpty) {
                              establishmentError = null;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: active
                                ? AppDesignSystem.primaryBlue.withOpacity(0.06)
                                : Colors.white,
                            borderRadius: AppDesignSystem.cardRadius,
                            border: Border.all(
                              color: active
                                  ? AppDesignSystem.primaryBlue
                                  : AppDesignSystem.borderLight,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                e.value.icon,
                                color: active
                                    ? AppDesignSystem.primaryBlue
                                    : AppDesignSystem.textSecondary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.value.label,
                                      style: AppDesignSystem.bodySmall.copyWith(
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: active
                                            ? AppDesignSystem.primaryBlue
                                            : AppDesignSystem.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      e.value.desc,
                                      style: AppDesignSystem.caption,
                                    ),
                                  ],
                                ),
                              ),
                              if (active)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppDesignSystem.primaryBlue,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Description — required for every dispute type: marked
                // with an asterisk, and shows an inline error + red
                // border when the user tries to submit blank, instead
                // of only a SnackBar.
                Text(
                  '${loc.disputesDescriptionLabel} *',
                  style: AppDesignSystem.heading4,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  onChanged: (value) {
                    if (descError != null && value.trim().isNotEmpty) {
                      setSheetState(() => descError = null);
                    }
                  },
                  decoration: AppDesignSystem.inputDecoration(
                    hintText: loc.disputesDescriptionHint,
                  ).copyWith(errorText: descError, errorMaxLines: 2),
                ),
                const SizedBox(height: 16),

                // Where the issue happened — required only for dispute
                // types that inherently involve a specific business or
                // office (see _establishmentRequiredTypes); optional
                // otherwise (e.g. incorrect_db_info). Label, hint and
                // validation all update live as selectedType changes.
                Builder(
                  builder: (_) {
                    final required = _isEstablishmentRequired(selectedType);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          required
                              ? '${loc.disputesEstablishmentLabel} *'
                              : loc.disputesEstablishmentLabel,
                          style: AppDesignSystem.heading4,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          required
                              ? loc.disputesEstablishmentRequiredHint
                              : loc.disputesEstablishmentHint,
                          style: AppDesignSystem.caption.copyWith(
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: establishmentCtrl,
                          onChanged: (value) {
                            if (establishmentError != null &&
                                value.trim().isNotEmpty) {
                              setSheetState(() => establishmentError = null);
                            }
                          },
                          decoration:
                              AppDesignSystem.inputDecoration(
                                hintText: loc.disputesEstablishmentPlaceholder,
                              ).copyWith(
                                errorText: establishmentError,
                                errorMaxLines: 2,
                              ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ── Supporting document picker ──
                Text(
                  loc.disputesSupportingDocLabel,
                  style: AppDesignSystem.heading4,
                ),
                const SizedBox(height: 4),
                Text(
                  loc.disputesSupportingDocHint,
                  style: AppDesignSystem.caption.copyWith(
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (pickedFile != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.primaryBlue.withOpacity(0.05),
                      border: Border.all(
                        color: AppDesignSystem.primaryBlue.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusSM,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(pickedFile!.path),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            pickedFile!.name,
                            style: AppDesignSystem.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Was default IconButton sizing (~34dp total) —
                        // under this system's 56dp touch-target floor.
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setSheetState(() => pickedFile = null);
                            },
                            color: AppDesignSystem.textSecondary,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: AppDesignSystem.touchTargetMin,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (picked != null) {
                          setSheetState(() => pickedFile = picked);
                        }
                      },
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: Text(loc.disputesAttachButton),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppDesignSystem.primaryBlue,
                        side: BorderSide(
                          color: AppDesignSystem.primaryBlue.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppDesignSystem.buttonRadius,
                        ),
                      ),
                    ),
                  ),
                if (uploadError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      uploadError!,
                      style: AppDesignSystem.caption.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: AppDesignSystem.touchTargetPrimary,
                  child: ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            final text = descCtrl.text.trim();
                            final establishment = establishmentCtrl.text.trim();

                            // Validate required description inline
                            // (red border + message under the field)
                            // instead of only a SnackBar, so it's
                            // obvious before/without needing to notice
                            // a transient toast.
                            if (text.isEmpty) {
                              setSheetState(() {
                                descError = loc.disputesErrorEmptyDescription;
                              });
                              HapticFeedback.selectionClick();
                              return;
                            }

                            // Validate establishment only for the
                            // dispute types where it's required.
                            if (_isEstablishmentRequired(selectedType) &&
                                establishment.isEmpty) {
                              setSheetState(() {
                                establishmentError =
                                    loc.disputesErrorEmptyEstablishment;
                              });
                              HapticFeedback.selectionClick();
                              return;
                            }

                            HapticFeedback.mediumImpact();
                            setSheetState(() {
                              isUploading = true;
                              uploadError = null;
                            });

                            // Upload document first if one was selected
                            String? docPath;
                            if (pickedFile != null) {
                              final uploadResult =
                                  await ApiService.uploadDisputeDoc(
                                    pickedFile!.path,
                                  );
                              if (uploadResult['error'] != null) {
                                setSheetState(() {
                                  isUploading = false;
                                  uploadError = loc.disputesErrorUploadFailed(
                                    uploadResult['error'].toString(),
                                  );
                                });
                                return;
                              }
                              docPath = uploadResult['path'] as String?;
                            }

                            // FIX: previously popped the sheet here,
                            // before submitDispute had even been
                            // called — if that call failed, the sheet
                            // was already gone and the person's typed
                            // description + selected type were lost
                            // with no way to retry without starting
                            // over. Now the sheet only closes on
                            // confirmed success, mirroring how the
                            // doc-upload failure case above already
                            // (correctly) keeps the sheet open.
                            final result = await ApiService.submitDispute(
                              disputeType: selectedType,
                              explanation: text,
                              establishmentName: establishment.isEmpty
                                  ? null
                                  : establishment,
                              supportingDocPath: docPath,
                            );

                            if (result['error'] == null) {
                              Navigator.pop(ctx);
                              _load();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(loc.disputesSuccessSnackbar),
                                    backgroundColor:
                                        AppDesignSystem.statusValid,
                                  ),
                                );
                              }
                            } else {
                              setSheetState(() {
                                isUploading = false;
                                uploadError = result['error'].toString();
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppDesignSystem.buttonRadius,
                      ),
                    ),
                    child: isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              loc.disputesSubmitButton,
                              style: AppDesignSystem.buttonMedium,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
