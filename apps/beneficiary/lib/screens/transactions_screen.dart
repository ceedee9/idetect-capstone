import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_design_system.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final List<TransactionRecord> _transactions = [];
  final List<DisputeRecord> _disputes = [];
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = false;
  bool _transactionsHaveMore = true;
  bool _disputesHaveMore = true;
  int _transactionPage = 1;
  int _disputePage = 1;
  String? _loadError;
  static const int _limit = 20;

  bool get _hasMore => _transactionsHaveMore || _disputesHaveMore;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final transactionResult = _transactionsHaveMore
        ? await ApiService.getTransactions(
            page: _transactionPage,
            limit: _limit,
          )
        : null;
    final disputeResult = _disputesHaveMore
        ? await ApiService.getMyDisputes(page: _disputePage, limit: _limit)
        : null;

    if (mounted) {
      final loc = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        var failed = false;
        if (transactionResult != null) {
          if (transactionResult.success) {
            _transactions.addAll(transactionResult.transactions);
            _transactionsHaveMore =
                _transactions.length < transactionResult.total;
            _transactionPage++;
          } else {
            _transactionsHaveMore = false;
            failed = true;
          }
        } else {
          _transactionsHaveMore = false;
        }
        if (disputeResult != null) {
          if (disputeResult.success) {
            _disputes.addAll(disputeResult.disputes);
            _disputesHaveMore = _disputes.length < disputeResult.total;
            _disputePage++;
          } else {
            _disputesHaveMore = false;
            failed = true;
          }
        } else {
          _disputesHaveMore = false;
        }
        _loadError = failed ? loc.serviceUnavailableMessage : null;
      });
    }
  }

  Future<void> _refresh() async {
    _transactionPage = 1;
    _disputePage = 1;
    _transactionsHaveMore = true;
    _disputesHaveMore = true;
    _transactions.clear();
    _disputes.clear();
    _loadError = null;
    await _loadMore();
  }

  List<_HistoryEntry> _entries() {
    final entries = [
      ..._transactions.map(_HistoryEntry.verification),
      ..._disputes.map(_HistoryEntry.dispute),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final entries = _entries();

    if (entries.isEmpty && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppDesignSystem.primaryBlue),
      );
    }

    if (entries.isEmpty && _loadError != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: AppDesignSystem.primaryBlue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
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
                    Text(_loadError!, style: AppDesignSystem.caption),
                    TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(loc.commonRetry),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (entries.isEmpty && !_isLoading) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: AppDesignSystem.primaryBlue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 64,
                      color: AppDesignSystem.textHint,
                    ),
                    const SizedBox(height: AppDesignSystem.spaceSM),
                    Text(
                      loc.historyEmptyState,
                      style: AppDesignSystem.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppDesignSystem.primaryBlue,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(AppDesignSystem.screenPaddingHorizontal),
        itemCount:
            entries.length + (_hasMore ? 1 : 0) + (_loadError != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (_loadError != null && i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDesignSystem.spaceSM),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppDesignSystem.statusWarning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_loadError!, style: AppDesignSystem.caption),
                  ),
                  IconButton(
                    tooltip: loc.commonRetry,
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            );
          }
          final entryIndex = i - (_loadError != null ? 1 : 0);
          if (entryIndex == entries.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppDesignSystem.primaryBlue,
                ),
              ),
            );
          }
          return _buildTile(entries[entryIndex], loc);
        },
      ),
    );
  }

  Widget _buildTile(_HistoryEntry entry, AppLocalizations loc) {
    if (entry.dispute != null) return _buildDisputeTile(entry.dispute!, loc);
    final tx = entry.transaction!;
    final statusColors = {
      'valid': AppDesignSystem.statusValid,
      'invalid': AppDesignSystem.statusInvalid,
      'flagged': AppDesignSystem.statusFlagged,
      'suspicious': AppDesignSystem.statusWarning,
      'manual_review': AppDesignSystem.interactiveBlue,
      'expired': Colors.orange,
    };
    final color = statusColors[tx.result] ?? AppDesignSystem.textSecondary;

    final date = DateFormat(
      'MMM d, yyyy',
      loc.localeName,
    ).format(tx.verifiedAt);
    final time = DateFormat('h:mm a', loc.localeName).format(tx.verifiedAt);

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
          _showDetail(tx, loc);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tx.result == 'valid'
                      ? Icons.check_circle_outline
                      : tx.result == 'flagged' ||
                            tx.result == 'suspicious' ||
                            tx.result == 'manual_review'
                      ? Icons.flag_outlined
                      : Icons.cancel_outlined,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.establishmentName ??
                          loc.transactionsUnknownEstablishment,
                      style: AppDesignSystem.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('$date  •  $time', style: AppDesignSystem.caption),
                  ],
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
                  _verificationStatusLabel(tx.result, loc),
                  style: AppDesignSystem.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(TransactionRecord tx, AppLocalizations loc) {
    final formatted = DateFormat(
      'MMMM d, yyyy  •  h:mm a',
      loc.localeName,
    ).format(tx.verifiedAt);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesignSystem.radiusLG),
        ),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
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
              loc.transactionsDetailTitle,
              style: AppDesignSystem.heading3.copyWith(
                color: AppDesignSystem.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _detailRow(
              loc.transactionsEstablishmentLabel,
              tx.establishmentName ?? loc.transactionsUnknownEstablishment,
            ),
            _detailRow(loc.transactionsDateTimeLabel, formatted),
            _detailRow(
              loc.transactionsStatusLabel,
              _verificationStatusLabel(tx.result, loc),
            ),
            if (tx.manuallyEntered)
              _detailRow(
                loc.transactionsEntryLabel,
                loc.transactionsEntryManual,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  Widget _buildDisputeTile(DisputeRecord dispute, AppLocalizations loc) {
    final color = _disputeStatusColor(dispute.status);
    final date = DateFormat(
      'MMM d, yyyy  •  h:mm a',
      loc.localeName,
    ).format(dispute.submittedAt);
    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spaceXS),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowSM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${loc.historyDisputeLabel} · ${_disputeTypeLabel(dispute.disputeType, loc)}',
                    style: AppDesignSystem.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _statusBadge(_disputeStatusLabel(dispute.status, loc), color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dispute.explanation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppDesignSystem.caption,
            ),
            const SizedBox(height: 4),
            Text(
              '${loc.disputesFiledLabel}: $date  ·  ${dispute.reference}',
              style: AppDesignSystem.caption.copyWith(
                color: AppDesignSystem.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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

  String _verificationStatusLabel(String status, AppLocalizations loc) {
    switch (status) {
      case 'valid':
        return loc.verificationStatusValid;
      case 'invalid':
        return loc.verificationStatusInvalid;
      case 'suspicious':
      case 'flagged':
        return loc.verificationStatusReview;
      case 'manual_review':
        return loc.verificationStatusManualReview;
      default:
        return loc.verificationStatusUnknown;
    }
  }

  String _disputeStatusLabel(String status, AppLocalizations loc) {
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

  Color _disputeStatusColor(String status) {
    switch (status) {
      case 'resolved':
        return AppDesignSystem.statusValid;
      case 'rejected':
        return AppDesignSystem.statusInvalid;
      case 'under_review':
      case 'investigating':
        return AppDesignSystem.interactiveBlue;
      default:
        return AppDesignSystem.statusWarning;
    }
  }

  String _disputeTypeLabel(String type, AppLocalizations loc) {
    switch (type) {
      case 'wrong_denial':
        return loc.disputeTypeWrongDenialLabel;
      case 'unauthorized_use':
        return loc.fraudTypeUnauthorizedLabel;
      case 'business_refusal':
        return loc.disputeTypeBusinessRefusalLabel;
      case 'incorrect_db_info':
        return loc.disputeTypeIncorrectDbInfoLabel;
      case 'other':
        return loc.disputeTypeOtherLabel;
      default:
        return loc.historyDisputeLabel;
    }
  }
}

class _HistoryEntry {
  final TransactionRecord? transaction;
  final DisputeRecord? dispute;

  const _HistoryEntry._({this.transaction, this.dispute});

  factory _HistoryEntry.verification(TransactionRecord value) =>
      _HistoryEntry._(transaction: value);

  factory _HistoryEntry.dispute(DisputeRecord value) =>
      _HistoryEntry._(dispute: value);

  DateTime get occurredAt => transaction?.verifiedAt ?? dispute!.submittedAt;
}
