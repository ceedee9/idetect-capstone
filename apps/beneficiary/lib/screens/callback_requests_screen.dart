import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_design_system.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'callback_request_sheet.dart';

class CallbackRequestsScreen extends StatefulWidget {
  const CallbackRequestsScreen({super.key});

  @override
  State<CallbackRequestsScreen> createState() => _CallbackRequestsScreenState();
}

class _CallbackRequestsScreenState extends State<CallbackRequestsScreen> {
  List<CallbackRequestRecord> _items = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final result = await ApiService.getMyCallbackRequests();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = !result.success;
      if (result.success) _items = result.requests;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.callbackRequestsTitle)),
      body: _buildBody(loc),
    );
  }

  Widget _buildBody(AppLocalizations loc) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppDesignSystem.primaryBlue),
      );
    }

    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.serviceUnavailableMessage, style: AppDesignSystem.caption),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(loc.commonRetry),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppDesignSystem.primaryBlue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Text(
                  loc.callbackRequestsEmpty,
                  style: AppDesignSystem.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppDesignSystem.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDesignSystem.screenPaddingHorizontal),
        itemCount: _items.length,
        itemBuilder: (_, i) => _buildCard(_items[i], loc),
      ),
    );
  }

  Widget _buildCard(CallbackRequestRecord request, AppLocalizations loc) {
    final handled = request.isHandled;
    final statusColor = handled
        ? AppDesignSystem.statusValid
        : AppDesignSystem.statusWarning;
    final date = DateFormat(
      'MMM d, yyyy  •  h:mm a',
      loc.localeName,
    ).format(request.createdAt.toLocal());
    final note = request.staffNote?.trim();
    final hasReply = handled && note != null && note.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spaceXS),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.establishmentName ??
                      loc.transactionsUnknownEstablishment,
                  style: AppDesignSystem.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _statusBadge(
                handled ? loc.callbackStatusHandled : loc.callbackStatusOpen,
                statusColor,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            callbackReasonLabel(request.reason, loc),
            style: AppDesignSystem.caption,
          ),
          const SizedBox(height: 4),
          Text(
            '${loc.callbackRequestedOn}: $date  ·  ${request.reference}',
            style: AppDesignSystem.caption.copyWith(
              color: AppDesignSystem.textHint,
            ),
          ),
          if (hasReply) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.backgroundWarm,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.callbackReplyLabel,
                    style: AppDesignSystem.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(note, style: AppDesignSystem.bodySmall),
                ],
              ),
            ),
          ] else if (!handled) ...[
            const SizedBox(height: 8),
            Text(
              loc.callbackNoReplyYet,
              style: AppDesignSystem.caption.copyWith(
                color: AppDesignSystem.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
      ),
      child: Text(
        label,
        style: AppDesignSystem.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
