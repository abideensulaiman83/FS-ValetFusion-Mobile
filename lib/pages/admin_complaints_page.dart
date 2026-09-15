// lib/pages/admin_complaints_page.dart
//
// Staff/admin side of the complaint desk (LOCATION_ADMIN / SUPER_ADMIN) - acknowledge, then
// close with optional resolution notes. Reached from the AppLayout drawer.
import 'package:flutter/material.dart';
import '../services/complaint_service.dart';

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
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Future<void> _acknowledge(Complaint c) async {
    try {
      await _complaintService.acknowledge(c.id);
      _showSnack('Marked as seen.');
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
        title: const Text('Close Complaint'),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Resolution notes (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Close Complaint')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _complaintService.close(c.id, resolutionNotes: notesController.text.trim());
      _showSnack('Complaint closed.');
      _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.red;
      case 'ACKNOWLEDGED':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('All')),
              PopupMenuItem(value: 'OPEN', child: Text('Open')),
              PopupMenuItem(value: 'ACKNOWLEDGED', child: Text('Acknowledged')),
              PopupMenuItem(value: 'CLOSED', child: Text('Closed')),
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
                            child: Text('No complaints${_filterStatus != null ? ' with status $_filterStatus' : ''}',
                                style: TextStyle(color: Colors.grey.shade600)),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
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
                                    label: Text(c.status, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                    backgroundColor: _statusColor(c.status),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${c.mobile}${c.place != null && c.place!.isNotEmpty ? ' - ${c.place}' : ''}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              Text(c.message),
                              if (c.resolutionNotes != null && c.resolutionNotes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Resolution: ${c.resolutionNotes}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                              ],
                              if (c.status != 'CLOSED') ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (c.status == 'OPEN')
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _acknowledge(c),
                                          child: const Text('Acknowledge'),
                                        ),
                                      ),
                                    if (c.status == 'OPEN') const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _close(c),
                                        child: const Text('Close'),
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
