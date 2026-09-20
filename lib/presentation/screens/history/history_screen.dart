// =============================================================================
// FILE: lib/presentation/screens/history/history_screen.dart
// REQ-2.16.5: Establishment staff compliance report — date range filter,
//             summary counts (VALID/SUSPICIOUS/INVALID), paginated log.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_design_system.dart';
import '../../../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _pageSize = 20;
  static const Color _primary = AppDesignSystem.primaryBlue;
  static const Color _validColor = AppDesignSystem.statusValid;
  static const Color _suspiciousColor = AppDesignSystem.statusSuspicious;
  static const Color _invalidColor = AppDesignSystem.statusInvalid;

  List<Map<String, dynamic>> _records = [];
  int _totalRecords = 0;
  int _currentPage = 1;
  int _totalPages = 1;

  // Summary counts loaded together with the data
  int _validCount = 0;
  int _suspiciousCount = 0;
  int _invalidCount = 0;

  bool _loading = false;
  String? _error;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _resultFilter; // null = all

  @override
  void initState() {
    super.initState();
    _load(page: 1, replace: true);
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  String? _fmtDate(DateTime? d) => d == null
      ? null
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load({required int page, required bool replace}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.getVerificationHistory(
      page: page,
      limit: _pageSize,
      startDate: _fmtDate(_startDate),
      endDate: _fmtDate(_endDate),
      resultFilter: _resultFilter,
    );

    if (!mounted) return;

    if (result.containsKey('error')) {
      setState(() {
        _loading = false;
        _error = result['error'] as String;
      });
      return;
    }

    final rows = (result['data'] as List? ?? []).cast<Map<String, dynamic>>();
    final pagination = result['pagination'] as Map<String, dynamic>? ?? {};

    // Re-compute summary from current page results (we need to sum across all
    // pages when filters are active — reload all for summary if on page 1).
    if (replace) {
      await _loadSummary();
    }

    setState(() {
      _loading = false;
      _currentPage = page;
      _totalRecords = (pagination['total'] is num
              ? (pagination['total'] as num)
              : num.tryParse(pagination['total'].toString()) ?? 0)
          .toInt();
      _totalPages = (pagination['pages'] is num
              ? (pagination['pages'] as num)
              : num.tryParse(pagination['pages'].toString()) ?? 1)
          .toInt();
      if (replace) {
        _records = rows;
      } else {
        _records = [..._records, ...rows];
      }
    });
  }

  /// Load summary counts (all pages) with current date/type filter.
  Future<void> _loadSummary() async {
    // Load a large batch without result filter to get per-result counts
    final res = await ApiService.getVerificationHistory(
      page: 1,
      limit: 10000,
      startDate: _fmtDate(_startDate),
      endDate: _fmtDate(_endDate),
    );
    if (!mounted || res.containsKey('error')) return;
    final rows = (res['data'] as List? ?? []).cast<Map<String, dynamic>>();
    int v = 0, s = 0, inv = 0;
    for (final r in rows) {
      final result = (r['result'] as String? ?? '').toLowerCase();
      // 'manual_review' is displayed as VALID in _RecordTile ("ID found in
      // DB — treat as valid"), so it must be folded into the valid tally
      // here too, or this summary and the visible list disagree.
      if (result == 'valid' || result == 'manual_review')
        v++;
      else if (result == 'suspicious')
        s++;
      else if (result == 'invalid') inv++;
    }
    if (mounted) {
      setState(() {
        _validCount = v;
        _suspiciousCount = s;
        _invalidCount = inv;
      });
    }
  }

  void _applyFilters() {
    _load(page: 1, replace: true);
  }

  // ── Date picker helpers ───────────────────────────────────────────────────

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _endDate = d);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtTs(String? ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.month}/${dt.day}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  Color _resultColor(String r) {
    switch (r.toLowerCase()) {
      case 'valid':
      case 'manual_review': // ID found in DB — treat as valid
        return _validColor;
      case 'suspicious':
        return _suspiciousColor;
      case 'invalid':
        return _invalidColor;
      default:
        return AppDesignSystem.textTertiary;
    }
  }

  IconData _resultIcon(String r) {
    switch (r.toLowerCase()) {
      case 'valid':
      case 'manual_review': // ID found in DB — treat as valid
        return Icons.check_circle_outline;
      case 'suspicious':
        return Icons.warning_amber_outlined;
      case 'invalid':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _typeLabel(String? t) {
    if (t == null) return '—';
    if (t.contains('senior')) return 'Senior Citizen';
    if (t.contains('pwd')) return 'PWD';
    return t;
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text(
          'Verification History',
          style: GoogleFonts.sourceSerif4(
              fontWeight: FontWeight.w700, fontSize: 19),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _load(page: 1, replace: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(page: 1, replace: true),
        child: CustomScrollView(
          slivers: [
            // ── Summary cards ──────────────────────────────────────────
            SliverToBoxAdapter(child: _buildSummarySection()),
            // ── Filters ───────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildFilters()),
            // ── Error state ───────────────────────────────────────────
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ErrorBanner(message: _error!),
                ),
              ),
            // ── Records ───────────────────────────────────────────────
            if (_loading && _records.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_loading && _records.isEmpty && _error == null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 64, color: AppDesignSystem.textTertiary),
                      const SizedBox(height: 12),
                      Text(
                        'No verification records found.',
                        style: AppDesignSystem.bodyMedium
                            .copyWith(color: AppDesignSystem.textTertiary),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i < _records.length) {
                      return _RecordTile(
                        record: _records[i],
                        resultColor: _resultColor(
                            _records[i]['result'] as String? ?? ''),
                        resultIcon:
                            _resultIcon(_records[i]['result'] as String? ?? ''),
                        fmtTs: _fmtTs,
                        typeLabel: _typeLabel,
                      );
                    }
                    // Loading indicator for pagination
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  childCount: _records.length +
                      (_loading && _records.isNotEmpty ? 1 : 0),
                ),
              ),
            // ── Pagination ────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildPagination()),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final total = _validCount + _suspiciousCount + _invalidCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPLIANCE SUMMARY',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SummaryCard(
                label: 'Total',
                count: total == 0 ? _totalRecords : total,
                color: _primary,
                icon: Icons.analytics_outlined,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Valid',
                count: _validCount,
                color: _validColor,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Suspicious',
                count: _suspiciousCount,
                color: _suspiciousColor,
                icon: Icons.warning_amber_outlined,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Invalid',
                count: _invalidCount,
                color: _invalidColor,
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final hasFilter =
        _startDate != null || _endDate != null || _resultFilter != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        border: Border.all(color: AppDesignSystem.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined,
                  size: 16, color: AppDesignSystem.iconLight),
              const SizedBox(width: 6),
              Text(
                'Filter by date range & result',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              const Spacer(),
              if (hasFilter)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _resultFilter = null;
                    });
                    _applyFilters();
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppDesignSystem.secondaryBlue,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: _startDate == null
                      ? 'From date'
                      : 'From: ${_fmtDate(_startDate)}',
                  onTap: _pickStart,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateButton(
                  label: _endDate == null
                      ? 'To date'
                      : 'To: ${_fmtDate(_endDate)}',
                  onTap: _pickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Result filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _resultFilter == null,
                  color: _primary,
                  onTap: () {
                    setState(() => _resultFilter = null);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Valid',
                  selected: _resultFilter == 'valid',
                  color: _validColor,
                  onTap: () {
                    setState(() => _resultFilter = 'valid');
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Suspicious',
                  selected: _resultFilter == 'suspicious',
                  color: _suspiciousColor,
                  onTap: () {
                    setState(() => _resultFilter = 'suspicious');
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Invalid',
                  selected: _resultFilter == 'invalid',
                  color: _invalidColor,
                  onTap: () {
                    setState(() => _resultFilter = 'invalid');
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search_rounded, size: 14),
                  label: Text('Apply',
                      style: GoogleFonts.ibmPlexMono(
                          fontSize: 11, letterSpacing: 0.4)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDesignSystem.radiusSM),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1
                ? () => _load(page: _currentPage - 1, replace: true)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: _primary,
          ),
          Text(
            'Page $_currentPage of $_totalPages',
            style: GoogleFonts.ibmPlexMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: AppDesignSystem.textSecondary),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () => _load(page: _currentPage + 1, replace: true)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: _primary,
          ),
        ],
      ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: GoogleFonts.sourceSerif4(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color),
            ),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.ibmPlexMono(
                  fontSize: 9,
                  letterSpacing: 0.6,
                  color: color.withOpacity(0.85),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppDesignSystem.backgroundLightBlue,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
          border: Border.all(color: AppDesignSystem.borderLight),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 14, color: AppDesignSystem.iconLight),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 11, color: AppDesignSystem.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
          border: Border.all(
              color: selected ? color : AppDesignSystem.borderMedium),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppDesignSystem.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final Map<String, dynamic> record;
  final Color resultColor;
  final IconData resultIcon;
  final String Function(String?) fmtTs;
  final String Function(String?) typeLabel;

  const _RecordTile({
    required this.record,
    required this.resultColor,
    required this.resultIcon,
    required this.fmtTs,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final rawResult = (record['result'] as String? ?? '').toLowerCase();
    final isManualReview = rawResult == 'manual_review';
    final result = isManualReview ? 'VALID' : rawResult.toUpperCase();
    final idNumber = record['id_number_scanned'] as String? ?? '—';
    final name = record['beneficiary_name'] as String? ?? '—';
    final type = typeLabel(record['beneficiary_type_detected'] as String?);
    final ts = fmtTs(record['verified_at'] as String?);
    final manual = record['manually_entered'] == true;
    final confidence = record['ocr_confidence_score'];
    final confNum = confidence == null
        ? null
        : confidence is num
            ? confidence
            : num.tryParse(confidence.toString());
    final confStr = confNum != null ? '${confNum.toStringAsFixed(0)}%' : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundWhite,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Result icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(resultIcon, color: resultColor, size: 18),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppDesignSystem.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: resultColor.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(AppDesignSystem.radiusXS),
                        ),
                        child: Text(
                          result,
                          style: GoogleFonts.ibmPlexMono(
                              fontSize: 9.5,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w700,
                              color: resultColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    idNumber,
                    style: GoogleFonts.ibmPlexMono(
                        fontSize: 11, color: AppDesignSystem.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip(type, Icons.badge_outlined),
                      if (manual) ...[
                        const SizedBox(width: 6),
                        _chip('Manual', Icons.edit_outlined,
                            color: AppDesignSystem.statusSuspicious),
                      ],
                      if (confStr != null) ...[
                        const SizedBox(width: 6),
                        _chip('Quality: $confStr', Icons.text_fields),
                      ],
                      if (isManualReview) ...[
                        const SizedBox(width: 6),
                        _chip('Manual Review', Icons.remove_red_eye_outlined,
                            color: AppDesignSystem.statusManualReview),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ts,
                    style: TextStyle(
                        fontSize: 10, color: AppDesignSystem.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon,
      {Color color = AppDesignSystem.textSecondary}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
        border: Border.all(
            color: AppDesignSystem.statusInvalid.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppDesignSystem.statusInvalid, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 12, color: AppDesignSystem.statusInvalid)),
          ),
        ],
      ),
    );
  }
}
