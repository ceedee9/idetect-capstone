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
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _limit = 20;

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
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final result = await ApiService.getTransactions(page: _page, limit: _limit);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _transactions.addAll(result.transactions);
          _hasMore = _transactions.length < result.total;
          _page++;
        } else {
          _hasMore = false;
        }
      });
    }
  }

  Future<void> _refresh() async {
    _page = 1;
    _hasMore = true;
    _transactions.clear();
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (_transactions.isEmpty && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppDesignSystem.primaryBlue),
      );
    }

    if (_transactions.isEmpty && !_isLoading) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: AppDesignSystem.primaryBlue,
        child: ListView(
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
                      loc.transactionsEmptyState,
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
        itemCount: _transactions.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _transactions.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppDesignSystem.primaryBlue,
                ),
              ),
            );
          }
          return _buildTile(_transactions[i], loc);
        },
      ),
    );
  }

  Widget _buildTile(TransactionRecord tx, AppLocalizations loc) {
    final statusColors = {
      'valid': AppDesignSystem.statusValid,
      'invalid': AppDesignSystem.statusInvalid,
      'flagged': AppDesignSystem.statusFlagged,
      'expired': Colors.orange,
    };
    final color = statusColors[tx.result] ?? AppDesignSystem.textSecondary;

    final date = DateFormat('MMM d, yyyy').format(tx.verifiedAt);
    final time = DateFormat('h:mm a').format(tx.verifiedAt);

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
                      : tx.result == 'flagged'
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
                    // Was 'â€¢' — a mojibake/encoding bug rendering as
                    // literal garbage text instead of a bullet (•).
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
                  // NOTE: raw API status value, uppercased — not localized.
                  // Same known gap already flagged in status_screen.dart's
                  // AppDesignSystem.getStatusLabel comment; fixing it means
                  // touching that shared helper, out of scope for this file.
                  tx.result.toUpperCase(),
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
      'MMMM d, yyyy  •  h:mm a', // was 'â€¢' — same mojibake fix as above
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
            _detailRow(loc.transactionsStatusLabel, tx.result.toUpperCase()),
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
}
