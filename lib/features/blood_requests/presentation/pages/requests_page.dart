// lib/features/blood_requests/presentation/pages/requests_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/create_request_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});
  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage>
    with SingleTickerProviderStateMixin {
  final RequestService _requestService = RequestService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  String? _currentUserId;

  // --- Filter State ---
  String? _filterBloodType;
  String? _filterUrgency;
  // --- End Filter State ---

  // Define lists for filter dropdowns
  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];
  final List<String> _urgencyLevels = ['Critical', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUserId = _auth.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Show Filter Dialog Method ---
  Future<void> _showFilterDialog() async {
    String? tempBloodType = _filterBloodType;
    String? tempUrgency = _filterUrgency;
    await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            // Allows dialog state updates
            return AlertDialog(
              title: Text("Filter Requests"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: tempBloodType,
                      hint: Text("Any Blood Type"),
                      decoration: InputDecoration(labelText: "Blood Type"),
                      items: [
                        DropdownMenuItem<String>(
                            value: null, child: Text("Any")),
                        ..._bloodTypes
                            .map((type) => DropdownMenuItem(
                                value: type, child: Text(type)))
                            .toList(),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => tempBloodType = value),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tempUrgency,
                      hint: Text("Any Urgency"),
                      decoration: InputDecoration(labelText: "Urgency Level"),
                      items: [
                        DropdownMenuItem<String>(
                            value: null, child: Text("Any")),
                        ..._urgencyLevels
                            .map((level) => DropdownMenuItem(
                                value: level, child: Text(level)))
                            .toList(),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => tempUrgency = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterBloodType = null;
                      _filterUrgency = null;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text("Clear Filters"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterBloodType = tempBloodType;
                      _filterUrgency = tempUrgency;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text("Apply"),
                ),
              ],
            );
          });
        });
  }
  // --- End Filter Dialog ---

  @override
  Widget build(BuildContext context) {
    bool filtersActive = _filterBloodType != null || _filterUrgency != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Requests'),
        actions: [
          IconButton(
            icon: Icon(
              filtersActive ? Icons.filter_list_alt : Icons.filter_list,
              color:
                  filtersActive ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: 'Filter Requests',
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Open'),
            Tab(text: 'My Requests'),
          ],
          labelColor: Colors.redAccent,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.redAccent,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pass filters to the All Open list
          _buildRequestList(
            stream: _requestService.getBloodRequestsStream(
              bloodTypeFilter: _filterBloodType,
              urgencyLevelFilter: _filterUrgency,
            ),
            listKey: const PageStorageKey('allRequestsFiltered'),
          ),
          // My Requests list doesn't use the filters
          _buildRequestList(
            stream: _requestService.getBloodRequestsStream(
                ownerUserId: _currentUserId),
            listKey: const PageStorageKey('myRequests'),
            showEmptyMessage: "You haven't created any requests yet.",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (context) => const CreateRequestPage())),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        tooltip: 'Create New Request',
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- Reusable Widget to build the list ---
  Widget _buildRequestList(
      {/* ... parameters ... */ required Stream<
              QuerySnapshot<Map<String, dynamic>>>
          stream,
      required PageStorageKey listKey,
      String showEmptyMessage = 'No open blood requests found.'}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      key: listKey,
      builder: (context, snapshot) {
        // ... Loading/Error/Empty checks ...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print("Error loading requests: ${snapshot.error}");
          return Center(
              child: Text('Error loading requests: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                showEmptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }
        final requests = snapshot.data!.docs;
        // ... ListView.separated ...
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
          itemCount: requests.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            final requestDoc = requests[index];
            final requestData = requestDoc.data();
            final String bloodType = requestData['requiredBloodType'] ?? 'N/A';
            final String hospital = requestData['hospitalName'] ?? 'Unknown';
            final String urgency = requestData['urgencyLevel'] ?? 'Unknown';
            final int units = requestData['unitsNeeded'] ?? 0;
            final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              elevation: 1.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.0)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: _getUrgencyColor(urgency).withOpacity(0.15),
                  child: Text(
                    bloodType,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getUrgencyColor(urgency),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                title: Text(hospital,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text('${units} Unit(s) Needed • Urgency: $urgency'),
                trailing: Text(_formatTimestamp(createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          RequestDetailsPage(requestId: requestDoc.id)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Helper methods ---
  Color _getUrgencyColor(String? urgency) {
    switch (urgency) {
      case 'Critical':
        return Colors.red.shade700;
      case 'High':
        return Colors.orange.shade700;
      case 'Medium':
        return Colors.yellow.shade800;
      case 'Low':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    final DateTime date = timestamp.toDate().toLocal();
    final Duration difference = DateTime.now().difference(date);
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }
} // End _RequestsPageState
