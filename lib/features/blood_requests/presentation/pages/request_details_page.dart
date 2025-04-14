// lib/features/blood_requests/presentation/pages/request_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/request_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'dart:async';
// Import for launching calls (uncomment when implementing _contactRequester)
// import 'package:url_launcher/url_launcher.dart';

// --- Blood Type Compatibility Logic ---
bool isBloodTypeCompatible(String? donorType, String? recipientType) {
  if (donorType == null ||
      recipientType == null ||
      !_isValidBloodType(donorType) ||
      !_isValidBloodType(recipientType)) {
    print(
        "Invalid blood types for compatibility check: Donor=$donorType, Recipient=$recipientType");
    return false;
  }
  if (donorType == 'O-') return true;
  if (recipientType == 'AB+') return true;

  bool donorIsRhNegative = donorType.endsWith('-');
  bool recipientIsRhPositive = recipientType.endsWith('+');
  // Rh- cannot receive Rh+
  if (!donorIsRhNegative && !recipientIsRhPositive) {
    return false;
  }

  String donorABO = donorType.replaceAll(RegExp(r'[+-]'), '');
  String recipientABO = recipientType.replaceAll(RegExp(r'[+-]'), '');

  if (donorABO == 'O') return true; // O ABO compatible with all
  if (donorABO == 'A' && (recipientABO == 'A' || recipientABO == 'AB'))
    return true;
  if (donorABO == 'B' && (recipientABO == 'B' || recipientABO == 'AB'))
    return true;
  if (donorABO == 'AB' && recipientABO == 'AB') return true;

  return false; // Default incompatible
}

bool _isValidBloodType(String type) =>
    RegExp(r'^(A|B|AB|O)[+-]$').hasMatch(type);
// --- End Compatibility Logic ---

class RequestDetailsPage extends StatefulWidget {
  final String requestId;
  const RequestDetailsPage({super.key, required this.requestId});

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage> {
  final RequestService _requestService = RequestService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserProfileService _profileService = UserProfileService();
  late Future<DocumentSnapshot<Map<String, dynamic>>> _requestDetailsFuture;
  bool _isDeleting = false;
  bool _isOfferingHelp = false;
  bool _hasAlreadyOffered =
      false; // TODO: Implement check for existing offers on init
  bool _isAcceptingOrRejecting = false;
  Map<String, dynamic>? _currentUserProfileData;

  @override
  void initState() {
    super.initState();
    _requestDetailsFuture = _requestService.getRequestDetails(widget.requestId);
    // Consider adding _checkIfAlreadyOffered() here if needed
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

  String _formatTimestamp(Timestamp? timestamp, {bool detailed = false}) {
    if (timestamp == null) return 'Unknown date';
    final DateTime date = timestamp.toDate().toLocal();
    if (detailed) {
      return DateFormat.yMMMMd().add_jm().format(date);
    } else {
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
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.0, color: Colors.grey[700]),
          const SizedBox(width: 12.0),
          Text(
            '$label: ',
            style:
                TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not Set',
              style: TextStyle(
                  fontSize: 15,
                  color:
                      value.isNotEmpty ? Colors.grey[900] : Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
  // --- End Helper methods ---

  // --- Action Methods ---
  Future<void> _contactRequester(String? phoneNumber) async {
    print('Contact Requester TBD: $phoneNumber');
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact number unavailable.')));
      return;
    }
    // TODO: Implement url_launcher
    // final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    // if (await canLaunchUrl(launchUri)) { await launchUrl(launchUri); }
    // else { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch call to $phoneNumber'))); }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call functionality TBD: $phoneNumber')));
  }

  Future<void> _offerHelp(Map<String, dynamic> requestData) async {
    if (_isOfferingHelp || _hasAlreadyOffered) return;
    final String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Please log in."), backgroundColor: Colors.orange));
      return;
    }
    if (requestData['requesterUserId'] == currentUserId) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cannot offer on own request.")));
      return;
    }
    setState(() {
      _isOfferingHelp = true;
    });
    try {
      final userDoc = await _profileService.getUserProfile(currentUserId);
      if (!userDoc.exists || userDoc.data() == null)
        throw Exception("Your profile data not found.");
      _currentUserProfileData = userDoc.data()!;
      final String? donorBloodType = _currentUserProfileData!['bloodType'];
      final bool isDonorAvailable =
          _currentUserProfileData!['isAvailableToDonate'] ?? false;
      final String? requiredBloodType = requestData['requiredBloodType'];
      if (!isDonorAvailable)
        throw Exception("'Available to Donate' must be ON first.");
      if (donorBloodType == null || requiredBloodType == null)
        throw Exception("Blood types missing for compatibility check.");
      if (!isBloodTypeCompatible(donorBloodType, requiredBloodType))
        throw Exception(
            "Your blood type ($donorBloodType) is not compatible with $requiredBloodType.");
      final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text("Confirm Offer"),
                content: Text(
                    "Offer to donate $donorBloodType for this $requiredBloodType request?"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("Cancel")),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text("Confirm Offer")),
                ],
              ));
      if (confirm != true) {
        setState(() {
          _isOfferingHelp = false;
        });
        return;
      }
      print("Adding offer to Firestore...");
      final offerData = {
        'donorId': currentUserId,
        'donorName': _currentUserProfileData!['name'] ?? 'Anonymous',
        'donorBloodType': donorBloodType,
        'offerTimestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      };
      await FirebaseFirestore.instance
          .collection('bloodRequests')
          .doc(widget.requestId)
          .collection('offers')
          .add(offerData);
      if (mounted) {
        setState(() {
          _hasAlreadyOffered = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Offer submitted!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      print("Error Offering Help: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Offer Error: ${e.toString().replaceFirst("Exception: ", "")}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted)
        setState(() {
          _isOfferingHelp = false;
        });
    }
  }

  Future<void> _deleteRequest() async {
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Confirm Deletion'),
              content: const Text('Delete this request? Cannot be undone.'),
              actions: <Widget>[
                TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false)),
                TextButton(
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    onPressed: () => Navigator.of(context).pop(true)),
              ],
            ));
    if (confirm == true) {
      if (!mounted) return;
      setState(() {
        _isDeleting = true;
      });
      try {
        await _requestService.deleteBloodRequest(widget.requestId);
        print("Request deleted.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Request deleted."),
              backgroundColor: Colors.green));
          await Future.delayed(const Duration(milliseconds: 50));
          if (mounted) Navigator.of(context).pop();
          print("Details page popped.");
        }
      } catch (e) {
        print("Error deleting: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "Delete Error: ${e.toString().replaceFirst("Exception: ", "")}"),
              backgroundColor: Colors.red));
        }
      } finally {
        if (mounted)
          setState(() {
            _isDeleting = false;
          });
      }
    }
  }

  Future<void> _acceptOfferAction(String offerId, String donorId) async {
    if (_isAcceptingOrRejecting || _isDeleting || _isOfferingHelp) return;
    setState(() => _isAcceptingOrRejecting = true);
    print("UI: Attempting to accept offer $offerId...");
    try {
      await _requestService.acceptOffer(widget.requestId, offerId, donorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Offer accepted! Request fulfilled."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e) {
      print("UI Error accepting offer: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Accept Error: ${e.toString().replaceFirst("Exception: ", "")}"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isAcceptingOrRejecting = false);
    }
  }

  Future<void> _rejectOfferAction(String offerId) async {
    if (_isAcceptingOrRejecting || _isDeleting || _isOfferingHelp) return;
    setState(() => _isAcceptingOrRejecting = true);
    print("UI: Attempting to reject offer $offerId...");
    try {
      await _requestService.rejectOffer(widget.requestId, offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Offer rejected."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      print("UI Error rejecting offer: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Reject Error: ${e.toString().replaceFirst("Exception: ", "")}"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isAcceptingOrRejecting = false);
    }
  }
  // --- End Action Methods ---

  // --- Helper Widget for Offers Section ---
  Widget _buildOffersSection(String currentRequestId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Pending Offers Received',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const Divider(height: 10, thickness: 1),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _requestService.getOffersStream(currentRequestId),
            builder: (context, offerSnapshot) {
              if (offerSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Loading offers...")));
              }
              if (offerSnapshot.hasError) {
                return Center(
                    child: Text("Error loading offers: ${offerSnapshot.error}",
                        style: TextStyle(color: Colors.red)));
              }
              if (!offerSnapshot.hasData || offerSnapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No pending offers received yet.",
                      style: TextStyle(color: Colors.grey)),
                ));
              }
              final offers = offerSnapshot.data!.docs;
              return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: offers.length,
                  itemBuilder: (context, index) {
                    final offerDoc = offers[index];
                    final offerData = offerDoc.data();
                    final String donorName =
                        offerData['donorName'] ?? 'Unknown Donor';
                    final String donorBloodType =
                        offerData['donorBloodType'] ?? 'N/A';
                    final Timestamp? offerTime =
                        offerData['offerTimestamp'] as Timestamp?;
                    final String donorId = offerData['donorId'] ?? '';

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Icon(Icons.person_outline, size: 20),
                            backgroundColor: Colors.blue[50]),
                        title: Text("$donorName ($donorBloodType)"),
                        subtitle: Text(
                            "Offered: ${_formatTimestamp(offerTime, detailed: true)}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check_circle,
                                  color: Colors.green[700]),
                              tooltip: "Accept Offer",
                              onPressed: _isAcceptingOrRejecting ||
                                      _isDeleting ||
                                      _isOfferingHelp
                                  ? null
                                  : () =>
                                      _acceptOfferAction(offerDoc.id, donorId),
                            ),
                            IconButton(
                              icon: Icon(Icons.cancel, color: Colors.red[700]),
                              tooltip: "Reject Offer",
                              onPressed: _isAcceptingOrRejecting ||
                                      _isDeleting ||
                                      _isOfferingHelp
                                  ? null
                                  : () => _rejectOfferAction(offerDoc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  });
            }),
      ],
    );
  }
  // --- End Offers Section Helper ---

  // --- Helper Widget for Accepted Offer Section ---
  Widget _buildAcceptedOfferSection(String donorId) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _profileService.getUserProfile(donorId),
        builder: (context, donorSnapshot) {
          if (donorSnapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Loading donor details..."),
            );
          }
          if (donorSnapshot.hasError ||
              !donorSnapshot.hasData ||
              !donorSnapshot.data!.exists) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Could not load accepted donor details.",
                  style: TextStyle(color: Colors.orange[800])),
            );
          }

          final donorData = donorSnapshot.data!.data()!;
          final String donorName = donorData['name'] ?? 'Name Not Provided';
          final String donorPhone =
              donorData['phoneNumber'] ?? 'Phone Not Provided';

          return Card(
            color: Colors.green[50],
            elevation: 2,
            margin: const EdgeInsets.only(top: 24.0, bottom: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Request Fulfilled!",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text("Accepted offer from:",
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  _buildDetailRow(Icons.person_pin_circle_outlined,
                      'Donor Name', donorName),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.phone_enabled_outlined, 'Donor Contact',
                      donorPhone),
                  const SizedBox(height: 12),
                  if (donorPhone != 'Phone Not Provided')
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.phone_forwarded),
                        label: const Text("Call Donor"),
                        onPressed: () => _contactRequester(donorPhone),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white),
                      ),
                    )
                ],
              ),
            ),
          );
        });
  }
  // --- End Accepted Offer Section Helper ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _requestDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
                appBar: AppBar(title: const Text('Loading...')),
                body: const Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return Scaffold(
                appBar: AppBar(title: const Text("Error")),
                body: Center(
                  child: Text(
                    'Could not load request details.\n${snapshot.error ?? 'Request not found.'}',
                    textAlign: TextAlign.center,
                  ),
                ));
          }

          final requestData = snapshot.data!.data()!;
          final String patientInfo = requestData['patientIdentifier'] ?? 'N/A';
          final String bloodType = requestData['requiredBloodType'] ?? 'N/A';
          final int units = requestData['unitsNeeded'] ?? 0;
          final String urgency = requestData['urgencyLevel'] ?? 'Unknown';
          final String hospitalName =
              requestData['hospitalName'] ?? 'Unknown Hospital';
          final String hospitalAddress =
              requestData['hospitalAddress'] ?? 'No address provided';
          final String contactPerson = requestData['contactPerson'] ?? 'N/A';
          final String contactNumber = requestData['contactNumber'] ?? '';
          final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
          final String status = requestData['status'] ?? 'Unknown';
          final String? requesterUserId = requestData['requesterUserId'];
          final String? currentUserId = _auth.currentUser?.uid;
          final bool isRequester = (requesterUserId != null &&
              currentUserId != null &&
              requesterUserId == currentUserId);
          final bool canOfferHelp = !isRequester;
          final String? acceptedDonorId = requestData['acceptedDonorId']
              as String?; // Get accepted donor ID

          return Scaffold(
            appBar: AppBar(
              title: const Text('Request Details'),
              actions: [
                // Show delete button only if requester AND request is still Open
                if (isRequester && status == 'Open')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete Request',
                    onPressed: _isDeleting ? null : _deleteRequest,
                  ),
              ],
            ),
            body: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // --- Request Overview Card (Fully Expanded) ---
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Chip(
                                      label: Text(bloodType,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18)),
                                      avatar: const Icon(Icons.bloodtype,
                                          color: Colors.redAccent, size: 20),
                                      backgroundColor: Colors.red[50]),
                                  Chip(
                                      label: Text(urgency,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      backgroundColor:
                                          _getUrgencyColor(urgency),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('$units Unit(s) Required',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              _buildDetailRow(Icons.info_outline,
                                  'Patient Info', patientInfo),
                              const SizedBox(height: 6),
                              _buildDetailRow(Icons.access_time, 'Requested On',
                                  _formatTimestamp(createdAt, detailed: true)),
                              const SizedBox(height: 6),
                              _buildDetailRow(Icons.label_important_outline,
                                  'Status', status), // Display current status
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // --- Hospital Details (Fully Expanded) ---
                      Text('Hospital Information',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Divider(height: 10, thickness: 1),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                          Icons.local_hospital_outlined, 'Name', hospitalName),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.location_on_outlined, 'Address',
                          hospitalAddress),
                      const SizedBox(height: 20),
                      // --- Contact Info (Fully Expanded) ---
                      Text('Contact Information',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Divider(height: 10, thickness: 1),
                      const SizedBox(height: 10),
                      _buildDetailRow(Icons.account_circle_outlined, 'Person',
                          contactPerson),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                          Icons.phone_outlined,
                          'Number',
                          contactNumber.isNotEmpty
                              ? contactNumber
                              : 'Not Provided'),
                      const SizedBox(height: 30),
                      // --- Action Buttons (Fully Expanded & Conditional) ---
                      if (status ==
                          'Open') // Only show action buttons if request is open
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.phone_forwarded_outlined),
                              label: const Text('Contact'),
                              onPressed: _isDeleting ||
                                      _isOfferingHelp ||
                                      _isAcceptingOrRejecting ||
                                      contactNumber.isEmpty
                                  ? null
                                  : () => _contactRequester(contactNumber),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: contactNumber.isNotEmpty
                                      ? Colors.blueAccent
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                            ),
                            ElevatedButton.icon(
                              icon:
                                  const Icon(Icons.volunteer_activism_outlined),
                              label: Text(_hasAlreadyOffered
                                  ? 'Offered'
                                  : 'Offer Help'),
                              onPressed: _isDeleting ||
                                      _isOfferingHelp ||
                                      _isAcceptingOrRejecting ||
                                      _hasAlreadyOffered ||
                                      !canOfferHelp
                                  ? null
                                  : () => _offerHelp(requestData),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _hasAlreadyOffered
                                      ? Colors.grey
                                      : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                            ),
                          ],
                        )
                      else // Show status message if not open
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                              child: Text(
                            "This request is $status.",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700]),
                          )),
                        ),
                      const SizedBox(height: 24),

                      // --- Conditionally Show Offers OR Accepted Donor Info ---
                      if (isRequester) // Only requesters see this section
                        if (status == 'Fulfilled' && acceptedDonorId != null)
                          _buildAcceptedOfferSection(
                              acceptedDonorId) // Show accepted donor
                        else if (status == 'Open')
                          _buildOffersSection(
                              widget.requestId), // Show pending offers if open

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // Loading Overlay
                if (_isDeleting || _isOfferingHelp || _isAcceptingOrRejecting)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
} // End _RequestDetailsPageState
