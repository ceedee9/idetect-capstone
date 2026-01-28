// =============================================================================
// FILE: lib/presentation/screens/scan/result_screen.dart
// PURPOSE: Result screen with extracted ID data overlay
// FEATURES: Shows extracted details on camera background
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../services/parser_service.dart';
import '../../../data/datasources/local/local_database.dart';

/// Result screen showing extracted ID information with overlay
class ResultScreen extends StatefulWidget {
  final ParsedIDData parsedData;
  final String imagePath;
  final String idType;

  const ResultScreen({
    super.key,
    required this.parsedData,
    required this.imagePath,
    required this.idType,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSaving = false;

  Future<void> _saveToDatabase() async {
    setState(() => _isSaving = true);

    try {
      final database = LocalDatabase();
      await database.insertScannedID(
        fullName: widget.parsedData.fullName ?? '',
        idNumber: widget.parsedData.idNumber ?? '',
        age: widget.parsedData.age,
        sex: widget.parsedData.sex ?? '',
        dateIssued: widget.parsedData.dateIssued ?? '',
        controlNumber: widget.parsedData.controlNumber ?? '',
        imagePath: widget.imagePath,
        idType: widget.idType,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID saved successfully'),
            backgroundColor: Color(0xFF13BB11),
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background: Captured ID image
          Positioned.fill(
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 20),
                _buildIDPreviewCard(),
                const SizedBox(height: 24),
                _buildExtractedDetailsCard(),
                const Spacer(),
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            iconSize: 28,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
            ),
          ),
          const Text(
            'ID VERIFICATION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 48), // Spacer for centering
        ],
      ),
    );
  }

  Widget _buildIDPreviewCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(widget.imagePath),
          width: 340,
          height: 214,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildExtractedDetailsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'EXTRACTED DETAILS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF002E6B),
              letterSpacing: 1.2,
            ),
          ),
          const Divider(height: 24, thickness: 2),
          _buildDetailRow('NAME:', widget.parsedData.fullName ?? 'N/A'),
          const SizedBox(height: 12),
          _buildDetailRow(
            'AGE:',
            widget.parsedData.age != null
                ? '${widget.parsedData.age} Years Old'
                : 'N/A',
          ),
          const SizedBox(height: 12),
          _buildDetailRow('SEX:', widget.parsedData.sex ?? 'N/A'),
          const SizedBox(height: 12),
          _buildDetailRow(
            'DATE ISSUED:',
            widget.parsedData.dateIssued ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'CONTROL ID:',
            widget.parsedData.controlNumber ?? 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
      child: Center(
        child: SizedBox(
          width: 200,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveToDatabase,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002E6B),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Verify',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
