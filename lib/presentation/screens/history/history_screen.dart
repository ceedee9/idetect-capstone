// =============================================================================
// FILE: lib/presentation/screens/history/history_screen.dart
// REQ-2.16.5: Establishment staff compliance report — date range filter,
//             summary counts (VALID/SUSPICIOUS/INVALID), paginated log.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _pageSize = 20;
  static const Color _primary = Color(0xFF002E6B);
  static const Color _validColor = Color(0xFF16A34A);
  static const Color _suspiciousColor = Color(0xFFD97706);
  static const Color _invalidColor = Color(0xFFDC2626);

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
      _totalRecords = pagination['total'] as int? ?? 0;
      _totalPages = pagination['pages'] as int? ?? 1;
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
      if (result == 'valid')
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
        return _validColor;
      case 'suspicious':
        return _suspiciousColor;
      case 'invalid':
        return _invalidColor;
      default:
        return Colors.grey;
    }
  }

  IconData _resultIcon(String r) {
    switch (r.toLowerCase()) {
      case 'valid':
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Verification History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                      Icon(Icons.history,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No verification records found.',
                        style: TextStyle(color: Colors.grey.shade500),
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
          const Text(
            'Compliance Summary',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              letterSpacing: 0.3,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined,
                  size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              const Text(
                'Filter by date range & result',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151)),
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
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500),
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
                  icon: const Icon(Icons.search, size: 14),
                  label: const Text('Apply', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
            icon: const Icon(Icons.chevron_left),
            color: _primary,
          ),
          Text(
            'Page $_currentPage of $_totalPages',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151)),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () => _load(page: _currentPage + 1, replace: true)
                : null,
            icon: const Icon(Icons.chevron_right),
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500),
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
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : const Color(0xFFD1D5DB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF6B7280),
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
    final result = (record['result'] as String? ?? '').toUpperCase();
    final idNumber = record['id_number_scanned'] as String? ?? '—';
    final name = record['beneficiary_name'] as String? ?? '—';
    final type = typeLabel(record['beneficiary_type_detected'] as String?);
    final ts = fmtTs(record['verified_at'] as String?);
    final manual = record['manually_entered'] == true;
    final confidence = record['ocr_confidence_score'];
    final confStr = confidence != null
        ? '${(confidence as num).toStringAsFixed(0)}%'
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
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
                              color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: resultColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          result,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: resultColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    idNumber,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip(type, Icons.badge_outlined),
                      if (manual) ...[
                        const SizedBox(width: 6),
                        _chip('Manual', Icons.edit_outlined,
                            color: const Color(0xFFD97706)),
                      ],
                      if (confStr != null) ...[
                        const SizedBox(width: 6),
                        _chip('OCR $confStr', Icons.text_fields),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ts,
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
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
      {Color color = const Color(0xFF6B7280)}) {
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
          ),
        ],
      ),
    );
  }
}
