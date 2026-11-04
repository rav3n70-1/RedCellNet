// lib/features/admin/presentation/pages/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/core/widgets/common_widgets.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/donation_centers/data/models/donation_center.dart';
import 'package:red_cell_net_final/features/donation_centers/data/services/donation_center_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RequestService _requestService = RequestService();
  final DonationCenterService _centerService = DonationCenterService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Approve / Reject User Verification ---
  Future<void> _handleVerificationDecision(String userId, String userName, bool approve) async {
    String rejectionReason = 'Inconclusive or missing lab documentation';
    if (!approve) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController(text: rejectionReason);
          return AlertDialog(
            title: const Text("Reject Verification"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Provide reason for donor verification rejection:", style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(labelText: "Rejection Reason"),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
                onPressed: () {
                  rejectionReason = ctrl.text.trim();
                  Navigator.pop(ctx, true);
                },
                child: const Text("Confirm Rejection"),
              ),
            ],
          );
        },
      );
      if (proceed != true) return;
    }

    try {
      final supabase = SupabaseConfig.client;

      if (approve) {
        await supabase.from('profiles').update({
          'verification_status': 'verified',
          'is_verified_donor': true,
          'verified_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
      } else {
        await supabase.from('profiles').update({
          'verification_status': 'rejected',
          'is_verified_donor': false,
          'rejection_reason': rejectionReason,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
      }

      // Notification
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': approve ? 'Donor Verification Approved! 🛡️' : 'Verification Update',
        'body': approve
            ? 'Congratulations $userName! Your donor profile is now verified with the official shield badge.'
            : 'Your verification submission was reviewed: $rejectionReason.',
        'type': 'verification',
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? '$userName verified!' : 'Verification rejected.'),
            backgroundColor: approve ? AppColors.success : AppColors.critical,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.critical),
        );
      }
    }
  }

  // --- Resolve Report ---
  Future<void> _resolveReport(String reportId, String action, String targetId, String reportedType) async {
    try {
      final supabase = SupabaseConfig.client;
      if (action == 'dismiss') {
        await supabase.from('reports').update({
          'status': 'dismissed',
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', reportId);
      } else if (action == 'close_request') {
        await _requestService.cancelBloodRequest(targetId, reason: 'Removed by moderation');
        await supabase.from('reports').update({
          'status': 'action_taken',
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', reportId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report resolved.'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.critical),
        );
      }
    }
  }

  // --- Add Facility Dialog ---
  void _showAddFacilityDialog() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '9:00 AM - 5:00 PM');
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_location_alt_rounded, color: AppColors.secondary),
              SizedBox(width: 8),
              Text("Add Blood Center", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: dynamicSize,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Facility Name *")),
                const SizedBox(height: 8),
                TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: "Street Address *")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: latCtrl, decoration: const InputDecoration(labelText: "Latitude *"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: lngCtrl, decoration: const InputDecoration(labelText: "Longitude *"), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: hoursCtrl, decoration: const InputDecoration(labelText: "Operating Hours")),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Contact Phone")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: () async {
                final lat = double.tryParse(latCtrl.text.trim());
                final lng = double.tryParse(lngCtrl.text.trim());
                if (nameCtrl.text.trim().isEmpty || addrCtrl.text.trim().isEmpty || lat == null || lng == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("Please fill all required coordinates and names.")),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await SupabaseConfig.client.from('donation_centers').insert({
                    'name': nameCtrl.text.trim(),
                    'address': addrCtrl.text.trim(),
                    'latitude': lat,
                    'longitude': lng,
                    'operating_hours': hoursCtrl.text.trim(),
                    'contact_number': phoneCtrl.text.trim(),
                    'created_at': DateTime.now().toUtc().toIso8601String(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Donation center added successfully!"), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to save facility: $e"), backgroundColor: AppColors.critical),
                    );
                  }
                }
              },
              child: const Text("Save Facility"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Admin & Moderation'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Verifications'),
            Tab(text: 'Reports'),
            Tab(text: 'Facilities'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Metrics Overview Card
          _buildMetricsOverview(),

          // Main Tabs Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVerificationQueue(),
                _buildReportsQueue(),
                _buildFacilitiesManager(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Top Metrics Bar ---
  Widget _buildMetricsOverview() {
    final supabase = SupabaseConfig.client;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('profiles').stream(primaryKey: ['id']),
      builder: (context, userSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase.from('blood_requests').stream(primaryKey: ['id']),
          builder: (context, reqSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase.from('reports').stream(primaryKey: ['id']),
              builder: (context, repSnap) {
                final users = userSnap.data ?? [];
                final totalUsers = users.length;
                final verifiedUsers = users.where((d) => (d['verification_status'] ?? d['verificationStatus']) == 'verified').length;

                final requests = reqSnap.data ?? [];
                final activeRequests = requests.where((d) {
                  final s = d['status'];
                  return s == 'Open' || s == 'Partially Fulfilled';
                }).length;

                final reports = repSnap.data ?? [];
                final pendingReports = reports.where((d) => d['status'] == 'pending').length;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricCol('Users', '$totalUsers', AppColors.primary),
                      _metricCol('Verified', '$verifiedUsers', AppColors.success),
                      _metricCol('Active Req', '$activeRequests', AppColors.high),
                      _metricCol('Reports', '$pendingReports', AppColors.critical),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _metricCol(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }

  // --- Tab 1: Verification Queue ---
  Widget _buildVerificationQueue() {
    final supabase = SupabaseConfig.client;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .map((list) => list.where((u) => (u['verification_status'] ?? u['verificationStatus']) == 'pending').toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final pendingUsers = snapshot.data ?? [];

        if (pendingUsers.isEmpty) {
          return const EmptyStateView(
            icon: Icons.verified_user_outlined,
            title: 'No Pending Verifications',
            message: 'All donor verification submissions have been reviewed and processed.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingUsers.length,
          itemBuilder: (context, index) {
            final data = pendingUsers[index];
            final String userId = data['id']?.toString() ?? '';
            final name = data['name'] ?? 'Donor Candidate';
            final blood = data['blood_type'] ?? data['bloodType'] ?? 'N/A';
            final email = data['email'] ?? '';
            final phone = data['phone_number'] ?? data['phoneNumber'] ?? 'No phone';
            final city = data['location_city'] ?? data['locationCity'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BloodGroupBadge(bloodType: blood, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text("$email • $phone", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            if (city.isNotEmpty)
                              Text("City: $city", style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const VerificationBadge(status: 'pending', compact: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.critical),
                          onPressed: () => _handleVerificationDecision(userId, name, false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _handleVerificationDecision(userId, name, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Tab 2: Reports Queue ---
  Widget _buildReportsQueue() {
    final supabase = SupabaseConfig.client;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('reports')
          .stream(primaryKey: ['id'])
          .map((list) => list.where((r) => r['status'] == 'pending').toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const EmptyStateView(
            icon: Icons.shield_outlined,
            title: 'No Pending Reports',
            message: 'No active reports or abuse flags require moderation at this time.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final data = reports[index];
            final String reportId = data['id']?.toString() ?? '';
            final reason = data['reason'] ?? 'Flagged Content';
            final details = data['details'] ?? '';
            final reportedType = data['reported_type'] ?? data['reportedType'] ?? 'request';
            final targetId = data['target_id'] ?? data['targetId'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.critical.withValues(alpha: 0.3)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.criticalLight, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.report_problem_rounded, color: AppColors.critical, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reason, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            Text("Type: ${reportedType.toUpperCase()} • Target: $targetId", style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                      child: Text(details, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (reportedType == 'request')
                        Expanded(
                          child: OutlinedButton(
                            child: const Text('View Request'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => RequestDetailsPage(requestId: targetId)),
                              );
                            },
                          ),
                        ),
                      if (reportedType == 'request') const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          child: const Text('Dismiss'),
                          onPressed: () => _resolveReport(reportId, 'dismiss', targetId, reportedType),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
                          child: const Text('Take Action'),
                          onPressed: () => _resolveReport(reportId, 'close_request', targetId, reportedType),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Tab 3: Facilities Manager ---
  Widget _buildFacilitiesManager() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Verified Blood Centers", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text("Add Facility"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _showAddFacilityDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<DonationCenter>>(
            stream: _centerService.getDonationCentersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final centers = snapshot.data ?? [];

              if (centers.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.local_hospital_outlined,
                  title: 'No Facilities Recorded',
                  message: 'Tap "+ Add Facility" to register certified donation centers and blood banks.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: centers.length,
                itemBuilder: (context, index) {
                  final c = centers[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_hospital_rounded, color: AppColors.secondary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(c.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              if (c.operatingHours != null)
                                Text("Hours: ${c.operatingHours}", style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Delete Facility?"),
                                content: Text("Remove ${c.name}?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await SupabaseConfig.client.from('donation_centers').delete().eq('id', c.id);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error deleting center: $e"), backgroundColor: AppColors.critical),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static const MainAxisSize dynamicSize = MainAxisSize.min;
}
