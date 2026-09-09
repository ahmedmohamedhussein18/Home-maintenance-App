import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceRequestsScreen extends StatefulWidget {
  final bool isEnglish;
  final String? userType;

  const ServiceRequestsScreen({
    super.key,
    required this.isEnglish,
    required this.userType,
  });

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen> {
  final DatabaseReference _requestsRef = FirebaseDatabase.instance.ref(
    'service_requests',
  );

  Future<void> _updateStatus(String requestId, String newStatus) async {
    await _requestsRef.child(requestId).update({
      'status': newStatus,
      'seenByUser': false,
    });
  }

  Future<void> _cancelRequest(String requestId) async {
    await _requestsRef.child(requestId).update({'status': 'cancelled'});
  }

  Future<void> _callNumber(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'N/A') return;
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return widget.isEnglish ? 'Pending' : 'قيد الانتظار';
      case 'accepted':
        return widget.isEnglish ? 'Accepted' : 'مقبول';
      case 'declined':
        return widget.isEnglish ? 'Declined' : 'مرفوض';
      case 'completed':
        return widget.isEnglish ? 'Completed' : 'تم الإنجاز';
      case 'cancelled':
        return widget.isEnglish ? 'Cancelled' : 'ملغي';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'declined':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isTechnician = widget.userType == 'technician';

    return StreamBuilder<DatabaseEvent>(
      stream: _requestsRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<Map<String, dynamic>> allRequests = [];
        final data = snapshot.data?.snapshot.value;
        if (data != null && data is Map) {
          data.forEach((key, value) {
            final map = Map<String, dynamic>.from(value as Map);
            map['requestId'] = key;
            allRequests.add(map);
          });
        }

        final myRequests = allRequests.where((r) {
          return isTechnician
              ? r['technicianId'] == userId
              : r['userId'] == userId;
        }).toList();

        myRequests.sort((a, b) {
          final aTime = a['createdAt'] as int? ?? 0;
          final bTime = b['createdAt'] as int? ?? 0;
          return bTime.compareTo(aTime);
        });

        if (myRequests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 72,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isTechnician
                        ? (widget.isEnglish
                              ? 'No requests yet'
                              : 'مفيش طلبات لسه')
                        : (widget.isEnglish
                              ? 'No service requests yet'
                              : 'مفيش طلبات خدمة لسه'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTechnician
                        ? (widget.isEnglish
                              ? 'Requests from users will appear here'
                              : 'طلبات المستخدمين هتظهر هنا')
                        : (widget.isEnglish
                              ? 'Requests you send to technicians will appear here'
                              : 'الطلبات اللي هتبعتيها للفنيين هتظهر هنا'),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myRequests.length,
          itemBuilder: (context, index) {
            final req = myRequests[index];
            final status = req['status'] as String? ?? 'pending';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              req['serviceIcon'] ?? '🔧',
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              req['serviceName'] ??
                                  (widget.isEnglish ? 'Service' : 'خدمة'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isTechnician) ...[
                      Text(
                        widget.isEnglish
                            ? 'Requested by a customer'
                            : 'طلب من عميل',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ] else ...[
                      Text(
                        '${widget.isEnglish ? 'Technician: ' : 'الفني: '}${req['technicianName'] ?? ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📱 ${req['technicianPhone'] ?? ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (isTechnician && status == 'pending') ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _updateStatus(req['requestId'], 'accepted'),
                              icon: const Icon(Icons.check, size: 18),
                              label: Text(widget.isEnglish ? 'Accept' : 'قبول'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _updateStatus(req['requestId'], 'declined'),
                              icon: const Icon(Icons.close, size: 18),
                              label: Text(widget.isEnglish ? 'Decline' : 'رفض'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isTechnician && status == 'accepted') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _updateStatus(req['requestId'], 'completed'),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: Text(
                            widget.isEnglish
                                ? 'Mark as Completed'
                                : 'تعليم كمنجز',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                    ] else if (!isTechnician && status == 'pending') ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelRequest(req['requestId']),
                          icon: const Icon(Icons.close, size: 18),
                          label: Text(
                            widget.isEnglish ? 'Cancel Request' : 'إلغاء الطلب',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ] else if (!isTechnician && status == 'accepted') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _callNumber(req['technicianPhone']),
                          icon: const Icon(Icons.phone, size: 18),
                          label: Text(
                            widget.isEnglish
                                ? 'Call Technician'
                                : 'اتصال بالفني',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
