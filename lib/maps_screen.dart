import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapsScreen extends StatefulWidget {
  final bool isEnglish;

  const MapsScreen({super.key, required this.isEnglish});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  late GoogleMapController mapController;
  LatLng? _currentLocation;
  Set<Marker> markers = {};
  List<dynamic> technicians = [];
  bool _isLoading = true;
  String? _userType;

  // أنواع الخدمات
  final List<Map<String, String>> serviceTypes = [
    {'id': 'plumbing', 'en': 'Plumbing', 'ar': 'سباكة', 'icon': '🚰'},
    {'id': 'ac', 'en': 'Air Conditioning', 'ar': 'تكييف', 'icon': '❄️'},
    {
      'id': 'cooking',
      'en': 'Cooking Appliances',
      'ar': 'أجهزة الطبخ',
      'icon': '🔥',
    },
    {'id': 'washing', 'en': 'Washing Machine', 'ar': 'غسالة', 'icon': '🧺'},
    {'id': 'electricity', 'en': 'Electricity', 'ar': 'كهرباء', 'icon': '⚡'},
    {'id': 'other', 'en': 'Other', 'ar': 'أخرى', 'icon': '🔧'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      await _getUserType();
      await _getCurrentLocation();
      if (_userType == 'user') {
        await _loadTechnicians();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _getUserType() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref('users')
            .child(userId)
            .child('userType')
            .get();

        if (snapshot.exists) {
          setState(() {
            _userType = snapshot.value as String;
          });
        }
      }
    } catch (e) {
      print('Error getting user type: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied';
      }
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseDatabase.instance.ref('users').child(userId).update({
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
      }

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);

        markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: _currentLocation!,
            infoWindow: InfoWindow(
              title: widget.isEnglish ? 'Your Location' : 'موقعك الحالي',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
          ),
        );
      });
    } catch (e) {
      print('Error getting location: $e');
      throw 'Failed to get location: $e';
    }
  }

  Future<void> _loadTechnicians() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('users').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        final techs = <dynamic>[];

        data.forEach((key, value) {
          final user = value as Map;
          if (user['userType'] == 'technician') {
            techs.add({
              'id': key,
              'email': user['email'],
              'latitude': user['latitude'] ?? 30.0,
              'longitude': user['longitude'] ?? 31.0,
              'rating': user['rating'] ?? 0.0,
              'isAvailable': user['isAvailable'] ?? false,
            });
          }
        });

        setState(() {
          technicians = techs;
          _addTechnicianMarkers();
        });
      }
    } catch (e) {
      print('Error loading technicians: $e');
    }
  }

  void _addTechnicianMarkers() {
    for (var tech in technicians) {
      markers.add(
        Marker(
          markerId: MarkerId(tech['id']),
          position: LatLng(tech['latitude'], tech['longitude']),
          infoWindow: InfoWindow(
            title: tech['email'],
            snippet:
                '${widget.isEnglish ? 'Rating: ' : 'التقييم: '}${tech['rating']}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          onTap: () => _showTechnicianDetails(tech),
        ),
      );
    }
  }

  void _showTechnicianDetails(dynamic tech) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEnglish ? 'Technician Details' : 'تفاصيل الفني',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.isEnglish ? 'Email: ' : 'البريد: '}${tech['email']}',
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.isEnglish ? 'Rating: ' : 'التقييم: '}${tech['rating']} ⭐',
            ),
            const SizedBox(height: 8),
            Text(
              widget.isEnglish
                  ? (tech['isAvailable'] ? 'Available' : 'Not Available')
                  : (tech['isAvailable'] ? 'متوفر' : 'غير متوفر'),
              style: TextStyle(
                color: tech['isAvailable'] ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: tech['isAvailable']
                    ? () {
                        Navigator.pop(context);
                        _showServiceTypeDialog(tech);
                      }
                    : null,
                child: Text(
                  widget.isEnglish ? 'Request Service' : 'طلب الخدمة',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✨ هنا: اختيار نوع الخدمة
  void _showServiceTypeDialog(dynamic tech) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.isEnglish ? 'Select Service Type' : 'اختر نوع الخدمة',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: serviceTypes.length,
            itemBuilder: (context, index) {
              final service = serviceTypes[index];
              return ListTile(
                leading: Text(
                  service['icon']!,
                  style: const TextStyle(fontSize: 20),
                ),
                title: Text(
                  widget.isEnglish ? service['en']! : service['ar']!,
                  style: const TextStyle(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _requestService(tech, service['id']!, service);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isEnglish ? 'Cancel' : 'إلغاء'),
          ),
        ],
      ),
    );
  }

  // ✨ هنا: إرسال الطلب مع نوع الخدمة
  void _requestService(
    dynamic tech,
    String serviceTypeId,
    Map<String, String> service,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final requestId = '${DateTime.now().millisecondsSinceEpoch}';

      // احفظ الطلب في Firebase
      await FirebaseDatabase.instance
          .ref('service_requests')
          .child(requestId)
          .set({
            'requestId': requestId,
            'userId': userId,
            'technicianId': tech['id'],
            'technicianEmail': tech['email'],
            'serviceType': serviceTypeId, // البوتجاز، السخان، إلخ
            'serviceName': widget.isEnglish ? service['en'] : service['ar'],
            'serviceIcon': service['icon'],
            'status': 'pending', // pending, accepted, completed
            'userLocation': {
              'latitude': _currentLocation?.latitude,
              'longitude': _currentLocation?.longitude,
            },
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish
                  ? 'Service request sent to ${tech['email']}'
                  : 'تم إرسال طلب الخدمة إلى ${tech['email']}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish ? 'Error sending request' : 'خطأ في إرسال الطلب',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _userType == 'technician'
              ? (widget.isEnglish ? 'My Location' : 'موقعي')
              : (widget.isEnglish ? 'Find Technician' : 'ابحث عن فني'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentLocation == null
          ? Center(
              child: Text(
                widget.isEnglish
                    ? 'Unable to get location'
                    : 'تعذر الحصول على الموقع',
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: 15,
                  ),
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
                if (_userType == 'user')
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${technicians.where((t) => t['isAvailable']).length} ${widget.isEnglish ? 'technicians nearby' : 'فنيين قريبين'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _loadTechnicians,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(widget.isEnglish ? 'Refresh' : 'تحديث'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        widget.isEnglish
                            ? 'You are online and available for service requests'
                            : 'أنت متصل وجاهز لاستقبال طلبات الخدمة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
