import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_design_system.dart';
import '../services/api_service.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  List<DisputeRecord>? _disputes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getMyDisputes();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _disputes = result.disputes;
      });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'open':
        return Colors.orange;
      case 'investigating':
        return AppDesignSystem.secondaryBlue;
      case 'resolved':
        return AppDesignSystem.statusValid;
      case 'rejected':
        return AppDesignSystem.statusInvalid;
      default:
        return AppDesignSystem.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppDesignSystem.primaryBlue,
              ),
            )
          : _disputes!.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppDesignSystem.primaryBlue,
              child: ListView.builder(
                padding: const EdgeInsets.all(
                  AppDesignSystem.screenPaddingHorizontal,
                ),
                itemCount: _disputes!.length,
                itemBuilder: (_, i) => _buildTile(_disputes![i]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewDispute,
        backgroundColor: AppDesignSystem.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New Dispute', style: AppDesignSystem.buttonMedium),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel, size: 64, color: AppDesignSystem.textTertiary),
          const SizedBox(height: AppDesignSystem.spaceSM),
          Text('No disputes filed', style: AppDesignSystem.bodyMedium),
          const SizedBox(height: AppDesignSystem.spaceXS),
          Text(
            'Tap the button below to file a new dispute',
            style: AppDesignSystem.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(DisputeRecord d) {
    final date = DateFormat('MMM d, yyyy').format(d.submittedAt);
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
        onTap: () => _showDetail(d),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatType(d.disputeType),
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
                      d.status.toUpperCase(),
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
                  color: AppDesignSystem.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatType(String t) {
    return t
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }

  void _showDetail(DisputeRecord d) {
    final formatted = DateFormat(
      'MMMM d, yyyy  •  h:mm a',
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
              'Dispute Details',
              style: AppDesignSystem.heading3.copyWith(
                color: AppDesignSystem.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Status
            Row(
              children: [
                const Text('Status: '),
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
                    d.status.toUpperCase(),
                    style: AppDesignSystem.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _detailRow('Type', _formatType(d.disputeType)),
            _detailRow('Filed', formatted),
            const SizedBox(height: 12),

            Text('Description', style: AppDesignSystem.heading4),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.backgroundLight,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
              ),
              child: Text(d.explanation, style: AppDesignSystem.bodyMedium),
            ),

            if (d.resolution != null) ...[
              const SizedBox(height: 16),
              Text('Resolution', style: AppDesignSystem.heading4),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesignSystem.statusValid.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusSM),
                ),
                child: Text(d.resolution!, style: AppDesignSystem.bodyMedium),
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
    String selectedType = 'wrong_denial';
    final descCtrl = TextEditingController();
    XFile? pickedFile;
    bool isUploading = false;
    String? uploadError;
    final types = [
      'wrong_denial',
      'unauthorized_use',
      'business_refusal',
      'incorrect_db_info',
    ];

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
                  'File a Dispute',
                  style: AppDesignSystem.heading3.copyWith(
                    color: AppDesignSystem.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                Text('Dispute Type', style: AppDesignSystem.heading4),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: types.map((t) {
                    final active = t == selectedType;
                    return ChoiceChip(
                      label: Text(_formatType(t)),
                      selected: active,
                      onSelected: (_) => setSheetState(() => selectedType = t),
                      selectedColor: AppDesignSystem.primaryBlue.withOpacity(
                        0.15,
                      ),
                      labelStyle: AppDesignSystem.bodySmall.copyWith(
                        color: active
                            ? AppDesignSystem.primaryBlue
                            : AppDesignSystem.textPrimary,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Text('Description', style: AppDesignSystem.heading4),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: AppDesignSystem.inputDecoration(
                    hintText: 'Describe your dispute...',
                  ),
                ),
                const SizedBox(height: 16),

                // ── Supporting document picker ──────────────────────────
                Text('Supporting Document', style: AppDesignSystem.heading4),
                const SizedBox(height: 4),
                Text(
                  'Optional — attach a photo of your ID, barangay cert, etc.',
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
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setSheetState(() => pickedFile = null),
                          color: AppDesignSystem.textSecondary,
                        ),
                      ],
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
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
                    label: const Text('Attach Photo / Document'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppDesignSystem.primaryBlue,
                      side: BorderSide(
                        color: AppDesignSystem.primaryBlue.withOpacity(0.4),
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
                  child: ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            final text = descCtrl.text.trim();
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a description'),
                                ),
                              );
                              return;
                            }

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
                                  uploadError =
                                      'Upload failed: ${uploadResult['error']}';
                                });
                                return;
                              }
                              docPath = uploadResult['path'] as String?;
                            }

                            Navigator.pop(ctx);
                            final result = await ApiService.submitDispute(
                              disputeType: selectedType,
                              explanation: text,
                              supportingDocPath: docPath,
                            );
                            if (result['error'] == null) {
                              _load();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Dispute submitted'),
                                    backgroundColor:
                                        AppDesignSystem.statusValid,
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result['error'].toString()),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        : Text(
                            'Submit Dispute',
                            style: AppDesignSystem.buttonMedium,
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
