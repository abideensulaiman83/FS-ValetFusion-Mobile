// lib/pages/complaint_status_page.dart
//
// Lets a guest check back on a complaint they submitted earlier - no account needed, just the
// reference number (the complaint id, shown on the submission success screen) plus the mobile
// number they used, matching how the complaint itself was filed anonymously.
import 'package:flutter/material.dart';
import '../services/complaint_service.dart';

class ComplaintStatusPage extends StatefulWidget {
  final String? initialCompanyCode;
  final int? initialReference;
  final String? initialMobile;

  const ComplaintStatusPage({
    super.key,
    this.initialCompanyCode,
    this.initialReference,
    this.initialMobile,
  });

  @override
  State<ComplaintStatusPage> createState() => _ComplaintStatusPageState();
}

class _ComplaintStatusPageState extends State<ComplaintStatusPage> {
  final _complaintService = ComplaintService();
  final _formKey = GlobalKey<FormState>();

  late final _companyCodeController = TextEditingController(text: widget.initialCompanyCode);
  late final _referenceController = TextEditingController(text: widget.initialReference?.toString());
  late final _mobileController = TextEditingController(text: widget.initialMobile);

  bool _loading = false;
  Complaint? _result;
  String? _error;

  @override
  void dispose() {
    _companyCodeController.dispose();
    _referenceController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _complaintService.checkStatus(
        companyCode: _companyCodeController.text.trim(),
        reference: int.parse(_referenceController.text.trim()),
        mobile: _mobileController.text.trim(),
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.red;
      case 'ACKNOWLEDGED':
        return Colors.orange;
      case 'CLOSED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'OPEN':
        return 'Received - the team hasn\'t reviewed it yet.';
      case 'ACKNOWLEDGED':
        return 'The team has seen your report and is working on it.';
      case 'CLOSED':
        return 'Resolved.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check Complaint Status')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter your reference number and the mobile number you reported with.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyCodeController,
                  decoration: const InputDecoration(labelText: 'Property Code *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referenceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reference Number *', prefixText: '#', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (int.tryParse(v.trim()) == null) return 'Numbers only';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(labelText: 'Mobile Number *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _check,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Check Status'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _statusColor(_result!.status).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(_result!.status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              backgroundColor: _statusColor(_result!.status),
                            ),
                            const Spacer(),
                            Text('#${_result!.id}', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(_statusMessage(_result!.status), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Text('Your report: "${_result!.message}"', style: TextStyle(color: Colors.grey.shade700)),
                        if (_result!.resolutionNotes != null && _result!.resolutionNotes!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text('Resolution: ${_result!.resolutionNotes}', style: TextStyle(color: Colors.green.shade800)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
