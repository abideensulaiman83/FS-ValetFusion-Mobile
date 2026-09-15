// lib/pages/feedback_page.dart
//
// Public complaint form - no login required, matching the guest-tracking pattern elsewhere in
// the app. Guarded only by a simple math captcha (see CaptchaService on the backend) so a
// frustrated guest doesn't have to register just to report an issue.
import 'package:flutter/material.dart';
import '../services/complaint_service.dart';
import 'complaint_status_page.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _complaintService = ComplaintService();

  final _companyCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _placeController = TextEditingController();
  final _messageController = TextEditingController();
  final _captchaAnswerController = TextEditingController();

  CaptchaChallenge? _captcha;
  bool _loadingCaptcha = false;
  bool _submitting = false;
  bool _submitted = false;
  Complaint? _submittedComplaint;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  @override
  void dispose() {
    _companyCodeController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _placeController.dispose();
    _messageController.dispose();
    _captchaAnswerController.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    setState(() => _loadingCaptcha = true);
    try {
      final challenge = await _complaintService.getCaptcha();
      setState(() => _captcha = challenge);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loadingCaptcha = false);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_captcha == null) {
      _showSnack('Verification is still loading - please wait a moment.', error: true);
      return;
    }
    final answer = int.tryParse(_captchaAnswerController.text.trim());
    if (answer == null) {
      _showSnack('Please answer the verification question with a number.', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final complaint = await _complaintService.submit(
        companyCode: _companyCodeController.text.trim(),
        customerName: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        place: _placeController.text.trim(),
        message: _messageController.text.trim(),
        captchaToken: _captcha!.token,
        captchaAnswer: answer,
      );
      setState(() {
        _submittedComplaint = complaint;
        _submitted = true;
      });
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
      _captchaAnswerController.clear();
      _loadCaptcha();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback & Complaints'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ComplaintStatusPage()),
            ),
            child: const Text('Check Status'),
          ),
        ],
      ),
      body: SafeArea(
        child: _submitted ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() {
    final complaint = _submittedComplaint;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 72),
            const SizedBox(height: 16),
            const Text('Thank you', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              "We've received your report and the team will follow up.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (complaint != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Text('Your reference number', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('#${complaint.id}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Save this to check your report\'s status later',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
            if (complaint != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ComplaintStatusPage(
                      initialCompanyCode: _companyCodeController.text.trim(),
                      initialReference: complaint.id,
                      initialMobile: _mobileController.text.trim(),
                    ),
                  )),
                  child: const Text('Check Status'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tell us what went wrong. Your report goes straight to the property team.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyCodeController,
              decoration: const InputDecoration(
                labelText: 'Property Code *',
                hintText: 'From your ticket or the valet stand',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your Name *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _placeController,
              decoration: const InputDecoration(
                labelText: 'Place / Hotel',
                hintText: 'e.g. Lobby, Level 2 parking',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'What happened? *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _loadingCaptcha
                        ? const Text('Loading verification...')
                        : Text(
                            'Verify: ${_captcha?.question ?? '-'} = ?',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                  IconButton(
                    onPressed: _loadingCaptcha ? null : _loadCaptcha,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'New question',
                  ),
                  SizedBox(
                    width: 70,
                    child: TextFormField(
                      controller: _captchaAnswerController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
