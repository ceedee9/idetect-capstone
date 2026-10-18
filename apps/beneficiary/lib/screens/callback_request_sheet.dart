import 'package:flutter/material.dart';
import '../core/constants/app_design_system.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

/// Localized label for a callback reason code returned by the API.
String callbackReasonLabel(String reason, AppLocalizations loc) {
  switch (reason) {
    case 'transaction_question':
      return loc.callbackReasonTransaction;
    case 'record_correction':
      return loc.callbackReasonCorrection;
    default:
      return loc.callbackReasonOther;
  }
}

class CallbackRequestSheet extends StatefulWidget {
  final TransactionRecord transaction;

  const CallbackRequestSheet({super.key, required this.transaction});

  @override
  State<CallbackRequestSheet> createState() => _CallbackRequestSheetState();
}

class _CallbackRequestSheetState extends State<CallbackRequestSheet> {
  static const _reasonCodes = [
    'transaction_question',
    'record_correction',
    'other',
  ];

  String? _reason;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations loc) async {
    final reason = _reason;
    final establishmentId = widget.transaction.establishmentId;
    if (reason == null || establishmentId == null) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final result = await ApiService.submitCallbackRequest(
      establishmentId: establishmentId,
      reason: reason,
      note: _noteCtrl.text,
      verificationLogId: widget.transaction.id,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            loc.callbackSuccessMessage(result['reference']?.toString() ?? ''),
          ),
        ),
      );
      navigator.pop();
      return;
    }

    setState(() {
      _submitting = false;
      _errorText = _errorFor(result['status'], loc);
    });
  }

  String _errorFor(Object? status, AppLocalizations loc) {
    if (status == 403 || status == 404) return loc.callbackErrorNotAllowed;
    if (status == 409) return loc.callbackErrorDuplicate;
    return loc.callbackErrorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final canSubmit = _reason != null && !_submitting;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
              loc.callbackSheetTitle,
              style: AppDesignSystem.heading3.copyWith(
                color: AppDesignSystem.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(loc.callbackSheetIntro, style: AppDesignSystem.bodySmall),
            const SizedBox(height: 16),
            Text(
              loc.callbackEstablishmentLabel,
              style: AppDesignSystem.caption,
            ),
            const SizedBox(height: 2),
            Text(
              widget.transaction.establishmentName ??
                  loc.transactionsUnknownEstablishment,
              style: AppDesignSystem.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Text(loc.callbackReasonLabel, style: AppDesignSystem.label),
            const SizedBox(height: 8),
            for (final code in _reasonCodes)
              _reasonTile(code, callbackReasonLabel(code, loc)),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              enabled: !_submitting,
              maxLength: 500,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: loc.callbackNoteLabel,
                hintText: loc.callbackNoteHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: AppDesignSystem.bodySmall.copyWith(
                  color: AppDesignSystem.statusInvalid,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: AppDesignSystem.touchTargetMin,
              child: ElevatedButton(
                onPressed: canSubmit ? () => _submit(loc) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(loc.callbackSubmit, style: AppDesignSystem.buttonMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reasonTile(String code, String label) {
    final selected = _reason == code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        onTap: _submitting ? null : () => setState(() => _reason = code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppDesignSystem.primaryBlue.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
            border: Border.all(
              color: selected
                  ? AppDesignSystem.primaryBlue
                  : AppDesignSystem.borderLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AppDesignSystem.primaryBlue
                    : AppDesignSystem.textHint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: AppDesignSystem.bodyMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
