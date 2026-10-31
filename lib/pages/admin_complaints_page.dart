// lib/pages/admin_complaints_page.dart
//
// Staff/admin side of the complaint desk (LOCATION_ADMIN / SUPER_ADMIN) - acknowledge, then
// close with optional resolution notes. Reached from the AppLayout drawer.
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../services/complaint_service.dart';
import '../theme/app_theme.dart';

class AdminComplaintsPage extends StatefulWidget {
  const AdminComplaintsPage({super.key});

  @override
  State<AdminComplaintsPage> createState() => _AdminComplaintsPageState();
}

class _AdminComplaintsPageState extends State<AdminComplaintsPage> {
  final _complaintService = ComplaintService();
  bool _loading = true;
  List<Complaint> _complaints = [];
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final complaints = await _complaintService.listComplaints(status: _filterStatus);
      setState(() => _complaints = complaints);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? context.vf.danger : context.vf.success,
    ));
  }

  Future<void> _acknowledge(Complaint c) async {
    try {
      await _complaintService.acknowledge(c.id);
      if (!mounted) return;
      _showSnack(tr(context, 'Marked as seen.'));
      _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _close(Complaint c) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(dialogContext, 'Close Complaint')),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: tr(dialogContext, 'Resolution notes (optional)'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(tr(dialogContext, 'Cancel'))),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(tr(dialogContext, 'Close Complaint'))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _complaintService.close(c.id, resolutionNotes: notesController.text.trim());
      if (!mounted) return;
      _showSnack(tr(context, 'Complaint closed.'));
      _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return context.vf.danger;
      case 'ACKNOWLEDGED':
        return context.vf.warning;
      default:
        return context.vf.success;
    }
  }

  /// Display label for a complaint status code (the code itself stays English for the API).
  String _statusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return tr(context, 'Open');
      case 'ACKNOWLEDGED':
        return tr(context, 'Acknowledged');
      case 'CLOSED':
        return tr(context, 'Closed');
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Complaints')),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: tr(context, 'Filter'),
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _load();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: null, child: Text(tr(context, 'All'))),
              PopupMenuItem(value: 'OPEN', child: Text(_statusLabel('OPEN'))),
              PopupMenuItem(value: 'ACKNOWLEDGED', child: Text(_statusLabel('ACKNOWLEDGED'))),
              PopupMenuItem(value: 'CLOSED', child: Text(_statusLabel('CLOSED'))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _complaints.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: Center(
                            child: Text(
                                _filterStatus != null
                                    ? tr(context, 'No complaints with status {status}', {'status': _statusLabel(_filterStatus!)})
                                    : tr(context, 'No complaints'),
                                style: TextStyle(color: context.vf.textSecondary)),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _complaints.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final c = _complaints[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.vf.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.vf.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(c.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  Chip(
                                    // white on the status-coloured chip (both themes)
                                    label: Text(_statusLabel(c.status), style: const TextStyle(fontSize: 11, color: Colors.white)),
                                    backgroundColor: _statusColor(c.status),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${c.mobile}${c.place != null && c.place!.isNotEmpty ? ' - ${c.place}' : ''}',
                                  style: TextStyle(fontSize: 12, color: context.vf.textSecondary)),
                              const SizedBox(height: 8),
                              Text(c.message),
                              if (c.resolutionNotes != null && c.resolutionNotes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(tr(context, 'Resolution: {notes}', {'notes': c.resolutionNotes}),
                                    style: TextStyle(fontSize: 12, color: context.vf.textSecondary, fontStyle: FontStyle.italic)),
                              ],
                              if (c.status != 'CLOSED') ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (c.status == 'OPEN')
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _acknowledge(c),
                                          child: Text(tr(context, 'Acknowledge')),
                                        ),
                                      ),
                                    if (c.status == 'OPEN') const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _close(c),
                                        child: Text(tr(context, 'Close')),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
