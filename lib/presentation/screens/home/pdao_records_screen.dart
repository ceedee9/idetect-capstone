// =============================================================================
// FILE: lib/presentation/screens/home/pdao_records_screen.dart
// PURPOSE: PDAO records list with search and filter
// FEATURES: Search, sort, pagination, real verification status display
// =============================================================================

import 'package:flutter/material.dart';
import '../../../data/datasources/local/local_database.dart';
import '../../../services/api_service.dart';

class PDAORecordsScreen extends StatefulWidget {
  const PDAORecordsScreen({super.key});

  @override
  State<PDAORecordsScreen> createState() => _PDAORecordsScreenState();
}

class _PDAORecordsScreenState extends State<PDAORecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'Newest';
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  bool _isLoading = true;
  int _currentPage = 1;
  final int _itemsPerPage = 6;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final database = LocalDatabase();
      final establishmentId = ApiService.currentUser?['id']?.toString();
      final allRecords =
          await database.getAllScannedIDs(establishmentId: establishmentId);

      // Filter for PDAO records only (idType == 'pwd')
      final pdaoRecords =
          allRecords.where((r) => r['idType'] == 'pwd').toList();

      setState(() {
        _records = pdaoRecords;
        _filteredRecords = pdaoRecords;
        _isLoading = false;
      });
      _applySort();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading records: $e')),
        );
      }
    }
  }

  void _applySort() {
    setState(() {
      if (_sortBy == 'Newest') {
        _filteredRecords.sort(
            (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      } else {
        _filteredRecords.sort(
            (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
      }
    });
  }

  void _filterRecords(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRecords = _records;
      } else {
        _filteredRecords = _records.where((record) {
          final controlId =
              (record['controlNumber'] ?? '').toString().toLowerCase();
          final name = (record['fullName'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return controlId.contains(searchLower) || name.contains(searchLower);
        }).toList();
      }
      _currentPage = 1;
    });
    _applySort();
  }

  List<Map<String, dynamic>> _getPaginatedRecords() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredRecords.length) return [];
    return _filteredRecords.sublist(
      startIndex,
      endIndex > _filteredRecords.length ? _filteredRecords.length : endIndex,
    );
  }

  int get _totalPages => (_filteredRecords.length / _itemsPerPage).ceil();

  // ---------------------------------------------------------------------------
  // Priority 3 fix: read the real verification status that was stored when
  // the record was saved, instead of guessing from the control number digits.
  // ---------------------------------------------------------------------------
  String _getRecordStatus(Map<String, dynamic> record) {
    final raw = (record['verificationStatus'] ?? '').toString();

    switch (raw.toLowerCase()) {
      case 'valid':
        return 'Valid';
      case 'invalid':
        return 'Invalid';
      case 'suspicious':
      case 'flagged':
        return 'Flagged';
      case 'manualreview':
      case 'manual_review':
        return 'Pending';
      case 'error':
        return 'Error';
      default:
        // Graceful fallback for records saved before the status field existed.
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndFilter(),
            _buildTableHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildRecordsList(),
            ),
            _buildPagination(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset('assets/images/idetect_logo.png',
              height: 60, fit: BoxFit.contain),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF002E6B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PDAO',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Text('2025',
              style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _filterRecords,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Search by name or control ID',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Text('Sort by : ',
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                Expanded(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: ['Newest', 'Oldest']
                        .map((v) =>
                            DropdownMenuItem<String>(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _sortBy = v);
                        _applySort();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: const Row(
        children: [
          Expanded(
              flex: 2,
              child: Text('Control ID',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Expanded(
              flex: 3,
              child: Text('Name',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Expanded(
              flex: 2,
              child: Text('Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    final paginatedRecords = _getPaginatedRecords();
    if (paginatedRecords.isEmpty) {
      return const Center(
          child: Text('No records found',
              style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: paginatedRecords.length,
      itemBuilder: (context, index) => _buildRecordRow(paginatedRecords[index]),
    );
  }

  Widget _buildRecordRow(Map<String, dynamic> record) {
    final controlId = record['controlNumber'] ?? 'N/A';
    final name = record['fullName'] ?? 'Unknown';
    final status = _getRecordStatus(record);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(controlId, style: const TextStyle(fontSize: 14))),
          Expanded(
              flex: 3,
              child: Text(name,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _buildStatusBadge(status)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'valid':
        statusColor = const Color(0xFF13BB11);
        break;
      case 'invalid':
        statusColor = const Color(0xFFD32F2F);
        break;
      case 'flagged':
        statusColor = Colors.orange.shade700;
        break;
      case 'pending':
        statusColor = Colors.blueGrey;
        break;
      case 'error':
        statusColor = Colors.red.shade900;
        break;
      default:
        statusColor = Colors.grey;
    }
    return Text(status,
        style: TextStyle(
            color: statusColor, fontWeight: FontWeight.bold, fontSize: 14));
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              ..._buildPageNumbers(),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
          Text(
            'Showing data 1 to $_itemsPerPage of ${_filteredRecords.length} entries',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pages = [];
    for (int i = 1; i <= _totalPages && i <= 4; i++) {
      pages.add(_buildPageButton(i));
    }
    if (_totalPages > 4) {
      pages.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(fontSize: 18))));
      pages.add(_buildPageButton(_totalPages));
    }
    return pages;
  }

  Widget _buildPageButton(int pageNumber) {
    final isSelected = pageNumber == _currentPage;
    return GestureDetector(
      onTap: () => setState(() => _currentPage = pageNumber),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF002E6B) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
              color:
                  isSelected ? const Color(0xFF002E6B) : Colors.grey.shade300),
        ),
        child: Center(
          child: Text('$pageNumber',
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                  icon: Icons.home_outlined,
                  label: 'HOME',
                  onTap: () =>
                      Navigator.popUntil(context, (route) => route.isFirst)),
              _buildScanButton(),
              _buildNavItem(
                  icon: Icons.history, label: 'HISTORY', onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: Colors.grey),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return InkWell(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
            color: Color(0xFF002E6B), shape: BoxShape.circle),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.credit_card,
                color: Color(0xFF002E6B), size: 24),
          ),
        ),
      ),
    );
  }
}
