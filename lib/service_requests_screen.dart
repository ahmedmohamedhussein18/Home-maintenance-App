import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import 'request_chat_screen.dart';

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
  bool _showTrash = false;

  Future<void> _updateStatus(String requestId, String newStatus) async {
    await _requestsRef.child(requestId).update({
      'status': newStatus,
      'seenByUser': false,
    });
  }

  Future<void> _cancelRequest(String requestId, String reason) async {
    await _requestsRef.child(requestId).update({
      'status': 'cancelled',
      'cancelReason': reason,
      'seenByTechnician': false,
    });
  }

  void _showCancelDialog(String requestId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isEnglish ? 'Cancel Request?' : 'إلغاء الطلب؟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEnglish
                  ? 'Let the technician know why (optional):'
                  : 'ممكن تقوليلنا السبب (اختياري):',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: widget.isEnglish
                    ? 'e.g. Found another technician'
                    : 'مثلاً: لقيت فني تاني',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isEnglish ? 'Back' : 'رجوع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _cancelRequest(requestId, reasonController.text.trim());
            },
            child: Text(
              widget.isEnglish ? 'Cancel Request' : 'إلغاء الطلب',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRequest(String requestId) async {
    await _requestsRef.child(requestId).remove();
  }

  Future<void> _emptyTrash(List<Map<String, dynamic>> trashedItems) async {
    for (final item in trashedItems) {
      await _requestsRef.child(item['requestId']).remove();
    }
  }

  Future<void> _callNumber(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'N/A') return;
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<bool> _submitRating(
    String requestId,
    String technicianId,
    int stars,
  ) async {
    try {
      final techRef = FirebaseDatabase.instance
          .ref('users')
          .child(technicianId);
      final snapshot = await techRef.get();
      double currentRating = 0.0;
      int currentCount = 0;
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        currentCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
      }

      final newCount = currentCount + 1;
      final newRating = ((currentRating * currentCount) + stars) / newCount;

      await techRef.update({
        'rating': double.parse(newRating.toStringAsFixed(2)),
        'ratingCount': newCount,
      });

      await _requestsRef.child(requestId).update({'rated': true});
      return true;
    } catch (e) {
      debugPrint('Rating submission failed: $e');
      return false;
    }
  }

  void _showAddToDevicesDialog(Map<String, dynamic> req) {
    DateTime? selectedDate;
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(
              widget.isEnglish ? 'Add to My Devices' : 'أضف لسجل أجهزتي',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEnglish
                      ? 'This will add "${req['serviceName']}" to your maintenance log.'
                      : 'هيتم إضافة "${req['serviceName']}" لسجل صيانتك.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedDate == null
                            ? (widget.isEnglish
                                  ? 'Next maintenance date'
                                  : 'موعد الصيانة الجاية')
                            : selectedDate!.toLocal().toString().split(' ')[0],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime.now().add(
                            const Duration(days: 180),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Text(widget.isEnglish ? 'Pick' : 'اختر'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: widget.isEnglish
                        ? 'Cost (L.E) — optional'
                        : 'التكلفة (جنيه) — اختياري',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(widget.isEnglish ? 'Cancel' : 'إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId == null) return;

                  final itemId = DateTime.now().millisecondsSinceEpoch
                      .toString();
                  await FirebaseDatabase.instance
                      .ref('items')
                      .child(userId)
                      .child(itemId)
                      .set({
                        'id': itemId,
                        'userId': userId,
                        'title': req['serviceName'] ?? '',
                        'targetDate':
                            (selectedDate ??
                                    DateTime.now().add(
                                      const Duration(days: 180),
                                    ))
                                .toIso8601String(),
                        'cost':
                            double.tryParse(costController.text.trim()) ?? 0.0,
                        'imageBase64': null,
                      });

                  await _requestsRef.child(req['requestId']).update({
                    'linkedToDevices': true,
                  });

                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          widget.isEnglish
                              ? 'Added to your devices'
                              : 'تمت الإضافة لسجل أجهزتك',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: Text(widget.isEnglish ? 'Add' : 'إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRatingDialog(Map<String, dynamic> req) {
    int selectedStars = 5;
    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(
              widget.isEnglish ? 'Rate the Technician' : 'قيّم الفني',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isEnglish
                      ? 'How was your experience with ${req['technicianName']}?'
                      : 'إيه رأيك في تجربتك مع ${req['technicianName']}؟',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starValue = i + 1;
                    return IconButton(
                      onPressed: () =>
                          setDialogState(() => selectedStars = starValue),
                      icon: Icon(
                        starValue <= selectedStars
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text(widget.isEnglish ? 'Skip' : 'تخطي'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        final success = await _submitRating(
                          req['requestId'],
                          req['technicianId'],
                          selectedStars,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? (widget.isEnglish
                                          ? 'Thanks for your rating!'
                                          : 'شكرًا لتقييمك!')
                                    : (widget.isEnglish
                                          ? 'Failed to send rating. Check your connection and try again.'
                                          : 'فشل إرسال التقييم. تأكدي من الاتصال وحاولي تاني.'),
                              ),
                              backgroundColor: success
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.isEnglish ? 'Submit' : 'إرسال'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return widget.isEnglish ? 'Pending' : 'قيد الانتظار';
      case 'scheduled':
        return widget.isEnglish ? 'Scheduled' : 'محجوز';
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
      case 'scheduled':
        return Colors.purple;
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

        const finishedStatuses = ['declined', 'completed', 'cancelled'];
        final activeRequests = myRequests
            .where((r) => !finishedStatuses.contains(r['status']))
            .toList();
        final trashedRequests = myRequests
            .where((r) => finishedStatuses.contains(r['status']))
            .toList();

        final visibleRequests = _showTrash ? trashedRequests : activeRequests;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        '${widget.isEnglish ? 'Active' : 'نشطة'} (${activeRequests.length})',
                      ),
                      selected: !_showTrash,
                      onSelected: (_) => setState(() => _showTrash = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        '🗑️ ${widget.isEnglish ? 'Trash' : 'سلة المهملات'} (${trashedRequests.length})',
                      ),
                      selected: _showTrash,
                      onSelected: (_) => setState(() => _showTrash = true),
                    ),
                  ),
                ],
              ),
            ),
            if (_showTrash && trashedRequests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            widget.isEnglish
                                ? 'Empty Trash?'
                                : 'إفراغ سلة المهملات؟',
                          ),
                          content: Text(
                            widget.isEnglish
                                ? 'This will permanently delete ${trashedRequests.length} request(s).'
                                : 'هيتم حذف ${trashedRequests.length} طلب نهائيًا.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                widget.isEnglish ? 'Cancel' : 'إلغاء',
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                widget.isEnglish ? 'Delete All' : 'حذف الكل',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await _emptyTrash(trashedRequests);
                      }
                    },
                    icon: const Icon(
                      Icons.delete_forever,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: Text(
                      widget.isEnglish ? 'Empty Trash' : 'إفراغ السلة',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: visibleRequests.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showTrash
                                  ? Icons.delete_outline
                                  : Icons.assignment_outlined,
                              size: 72,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showTrash
                                  ? (widget.isEnglish
                                        ? 'Trash is empty'
                                        : 'سلة المهملات فاضية')
                                  : (isTechnician
                                        ? (widget.isEnglish
                                              ? 'No active requests'
                                              : 'مفيش طلبات نشطة')
                                        : (widget.isEnglish
                                              ? 'No active requests'
                                              : 'مفيش طلبات نشطة')),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (!_showTrash) ...[
                              const SizedBox(height: 8),
                              Text(
                                isTechnician
                                    ? (widget.isEnglish
                                          ? 'New requests from users will appear here'
                                          : 'طلبات المستخدمين الجديدة هتظهر هنا')
                                    : (widget.isEnglish
                                          ? 'Requests you send will appear here'
                                          : 'الطلبات اللي هتبعتيها هتظهر هنا'),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visibleRequests.length,
                      itemBuilder: (context, index) {
                        final req = visibleRequests[index];
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                              (widget.isEnglish
                                                  ? 'Service'
                                                  : 'خدمة'),
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
                                        color: _statusColor(status)
                                            .withOpacity(0.12),
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
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (status == 'cancelled' &&
                                      (req['cancelReason'] as String?)
                                              ?.isNotEmpty ==
                                          true) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '${widget.isEnglish ? 'Reason: ' : 'السبب: '}${req['cancelReason']}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ] else ...[
                                  Text(
                                    '${widget.isEnglish ? 'Technician: ' : 'الفني: '}${req['technicianName'] ?? ''}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '📱 ${req['technicianPhone'] ?? ''}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                if ((req['preferredTime'] as String?)
                                        ?.isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '🕐 ${widget.isEnglish ? 'Preferred time: ' : 'الوقت المطلوب: '}${req['preferredTime']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                if (isTechnician &&
                                    (status == 'pending' ||
                                        status == 'scheduled')) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _updateStatus(
                                            req['requestId'],
                                            'accepted',
                                          ),
                                          icon: const Icon(
                                            Icons.check,
                                            size: 18,
                                          ),
                                          label: Text(
                                            widget.isEnglish
                                                ? 'Accept'
                                                : 'قبول',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _updateStatus(
                                            req['requestId'],
                                            'declined',
                                          ),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          label: Text(
                                            widget.isEnglish
                                                ? 'Decline'
                                                : 'رفض',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (isTechnician &&
                                    status == 'accepted') ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _callNumber(req['userPhone']),
                                          icon: const Icon(
                                            Icons.phone,
                                            size: 18,
                                          ),
                                          label: Text(
                                            widget.isEnglish ? 'Call' : 'اتصال',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => RequestChatScreen(
                                                isEnglish: widget.isEnglish,
                                                requestId: req['requestId'],
                                                otherPartyName: widget.isEnglish
                                                    ? 'Customer'
                                                    : 'العميل',
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.chat_bubble_outline,
                                            size: 18,
                                          ),
                                          label: Text(
                                            widget.isEnglish ? 'Chat' : 'شات',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _updateStatus(
                                            req['requestId'],
                                            'completed',
                                          ),
                                          icon: const Icon(
                                            Icons.done_all,
                                            size: 18,
                                          ),
                                          label: Text(
                                            widget.isEnglish
                                                ? 'Complete'
                                                : 'إنهاء',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (!isTechnician &&
                                    (status == 'pending' ||
                                        status == 'scheduled')) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _showCancelDialog(req['requestId']),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: Text(
                                        widget.isEnglish
                                            ? 'Cancel Request'
                                            : 'إلغاء الطلب',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ),
                                ] else if (!isTechnician &&
                                    status == 'accepted') ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _callNumber(
                                            req['technicianPhone'],
                                          ),
                                          icon: const Icon(
                                            Icons.phone,
                                            size: 18,
                                          ),
                                          label: Text(
                                            widget.isEnglish ? 'Call' : 'اتصال',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => RequestChatScreen(
                                                isEnglish: widget.isEnglish,
                                                requestId: req['requestId'],
                                                otherPartyName:
                                                    req['technicianName'] ??
                                                    (widget.isEnglish
                                                        ? 'Technician'
                                                        : 'الفني'),
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.chat_bubble_outline,
                                            size: 18,
                                          ),
                                          label: Text(
                                            widget.isEnglish ? 'Chat' : 'شات',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (!isTechnician &&
                                    status == 'completed') ...[
                                  if (req['rated'] != true)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showRatingDialog(req),
                                        icon: const Icon(Icons.star, size: 18),
                                        label: Text(
                                          widget.isEnglish
                                              ? 'Rate Technician'
                                              : 'قيّم الفني',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber[700],
                                        ),
                                      ),
                                    ),
                                  if (req['rated'] != true &&
                                      req['linkedToDevices'] != true)
                                    const SizedBox(height: 8),
                                  if (req['linkedToDevices'] != true)
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _showAddToDevicesDialog(req),
                                        icon: const Icon(
                                          Icons.devices,
                                          size: 18,
                                        ),
                                        label: Text(
                                          widget.isEnglish
                                              ? 'Add to My Devices'
                                              : 'أضف لسجل أجهزتي',
                                        ),
                                      ),
                                    ),
                                ] else if (_showTrash) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _deleteRequest(req['requestId']),
                                      icon: const Icon(
                                        Icons.delete_forever,
                                        size: 18,
                                      ),
                                      label: Text(
                                        widget.isEnglish
                                            ? 'Delete Permanently'
                                            : 'حذف نهائي',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
