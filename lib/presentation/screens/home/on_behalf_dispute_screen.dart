import 'package:flutter/material.dart';
import '../../../core/constants/app_design_system.dart';
import '../../../services/api_service.dart';

/// Lets an establishment file a dispute for a beneficiary who cannot use
/// the app. The beneficiary asks the establishment (in person, by phone,
/// or in writing); the establishment records that request here (A-10).
class OnBehalfDisputeScreen extends StatefulWidget {
  const OnBehalfDisputeScreen({super.key});

  @override
  State<OnBehalfDisputeScreen> createState() => _OnBehalfDisputeScreenState();
}

class _OnBehalfDisputeScreenState extends State<OnBehalfDisputeScreen> {
  static const _navy = AppDesignSystem.primaryBlue;

  // business_refusal is excluded: it describes the establishment's own refusal.
  static const Map<String, String> _disputeTypes = {
    'wrong_denial': 'Wrong denial',
    'unauthorized_use': 'Unauthorized use',
    'incorrect_db_info': 'Incorrect database info',
    'other': 'Other',
  };

  static const Map<String, String> _requestChannels = {
    'in_person': 'In person',
    'phone': 'By phone',
    'written': 'Written request',
  };

  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _explanationCtrl = TextEditingController();
  DateTime? _birthdate;
  String _disputeType = 'wrong_denial';
  String _requestChannel = 'in_person';
  bool _submitting = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _explanationCtrl.dispose();
    super.dispose();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 60),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthdate == null) {
      _showMessage('Please select the beneficiary\'s birthdate.');
      return;
    }

    setState(() => _submitting = true);
    final result = await ApiService.submitOnBehalfDispute(
      idNumber: _idCtrl.text.trim(),
      birthdate: _isoDate(_birthdate!),
      disputeType: _disputeType,
      explanation: _explanationCtrl.text.trim(),
      requestChannel: _requestChannel,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['error'] != null) {
      _showMessage(result['error'].toString());
      return;
    }

    final reference = result['dispute']?['reference_no']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispute filed'),
        content: Text(
          reference.isEmpty
              ? 'The dispute was filed for the beneficiary.'
              : 'The dispute was filed for the beneficiary.\n\nReference: $reference',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final birthdateText =
        _birthdate == null ? 'Select birthdate' : _isoDate(_birthdate!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Dispute for Beneficiary'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Use this when a beneficiary cannot file the dispute in the app. '
                'Confirm the beneficiary\'s ID number and birthdate, then record '
                'how they asked for the filing.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Beneficiary ID number',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'ID number is required.' : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickBirthdate,
                icon: const Icon(Icons.cake_outlined),
                label: Text(birthdateText),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _disputeType,
                decoration: const InputDecoration(
                  labelText: 'Dispute type',
                  border: OutlineInputBorder(),
                ),
                items: _disputeTypes.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _disputeType = v ?? _disputeType),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _requestChannel,
                decoration: const InputDecoration(
                  labelText: 'How did the beneficiary ask?',
                  border: OutlineInputBorder(),
                ),
                items: _requestChannels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _requestChannel = v ?? _requestChannel),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _explanationCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required.'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Dispute'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
