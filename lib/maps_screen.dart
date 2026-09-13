import 'dart:async';

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
  GoogleMapController? mapController;
  LatLng? _currentLocation;
  Set<Marker> markers = {};
  List<dynamic> technicians = [];
  bool _isLoading = true;
  String? _userType;
  bool _isAvailable = false;
  String? _errorMessage;
  String? _selectedFilter;
  StreamSubscription<Position>? _positionStream;

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

  String _specializationLabel(String id, {String? otherSpecialty}) {
    if (id == 'other' &&
        otherSpecialty != null &&
        otherSpecialty.trim().isNotEmpty) {
      return '🔧 $otherSpecialty';
    }
    final match = serviceTypes.firstWhere(
      (s) => s['id'] == id,
      orElse: () => {'en': id, 'ar': id, 'icon': '🔧'},
    );
    return '${match['icon']} ${widget.isEnglish ? match['en'] : match['ar']}';
  }

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    _errorMessage = null;
    try {
      await _getUserType();
      await _getCurrentLocation();
      if (_userType == 'technician') {
        await _getTechnicianAvailability();
        _startLiveLocationUpdates();
      } else {
        await _loadTechnicians();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _startLiveLocationUpdates() {
    _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 50, // update only after moving ~50 meters
          ),
        ).listen((position) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId == null) return;
          FirebaseDatabase.instance.ref('users').child(userId).update({
            'latitude': position.latitude,
            'longitude': position.longitude,
          });
          if (mounted) {
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
            });
          }
        });
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
          _userType = snapshot.value as String?;
        }
      }
    } catch (e) {
      // Non-fatal: defaults to regular user view.
    }
  }

  Future<void> _getTechnicianAvailability() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref('users')
            .child(userId)
            .child('isAvailable')
            .get();

        if (snapshot.exists) {
          _isAvailable = snapshot.value as bool? ?? false;
        }
      }
    } catch (e) {
      // Non-fatal.
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw widget.isEnglish
          ? 'Location services are disabled.'
          : 'خدمة تحديد الموقع غير مفعّلة.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw widget.isEnglish
            ? 'Location permissions are denied'
            : 'تم رفض إذن الموقع';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw widget.isEnglish
          ? 'Location permissions are permanently denied'
          : 'تم رفض إذن الموقع بشكل دائم';
    }

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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  double _calculateDistance(LatLng userLocation, LatLng techLocation) {
    return Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          techLocation.latitude,
          techLocation.longitude,
        ) /
        1000;
  }

  Future<void> _loadTechnicians() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('users').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        final techs = <dynamic>[];

        data.forEach((key, value) {
          final user = value as Map;
          final name = (user['name'] as String?)?.trim() ?? '';
          final specs = List<String>.from(
            (user['specializations'] as List?) ?? [],
          );
          final hasCompletedProfile = name.isNotEmpty && specs.isNotEmpty;

          if (user['userType'] == 'technician' && hasCompletedProfile) {
            techs.add({
              'id': key,
              'name': name,
              'email': user['email'],
              'phone': user['phone'] ?? 'N/A',
              'specializations': specs,
              'otherSpecialty': user['otherSpecialty'] as String? ?? '',
              'latitude': (user['latitude'] as num?)?.toDouble() ?? 30.0,
              'longitude': (user['longitude'] as num?)?.toDouble() ?? 31.0,
              'rating': user['rating'] ?? 0.0,
              'isAvailable': user['isAvailable'] ?? false,
            });
          }
        });

        if (_currentLocation != null) {
          techs.sort((a, b) {
            double distA = _calculateDistance(
              _currentLocation!,
              LatLng(a['latitude'], a['longitude']),
            );
            double distB = _calculateDistance(
              _currentLocation!,
              LatLng(b['latitude'], b['longitude']),
            );
            return distA.compareTo(distB);
          });
        }

        setState(() {
          technicians = techs;
          _addTechnicianMarkers();
        });
      }
    } catch (e) {
      // Non-fatal: technician list stays empty, map still shows.
    }
  }

  void _addTechnicianMarkers() {
    for (var tech in technicians) {
      markers.add(
        Marker(
          markerId: MarkerId(tech['id']),
          position: LatLng(tech['latitude'], tech['longitude']),
          infoWindow: InfoWindow(
            title: tech['name'],
            snippet:
                '${widget.isEnglish ? 'Rating: ' : 'التقييم: '}${tech['rating']}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }
  }

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
                  if (tech['isAvailable'] == true) {
                    _requestService(tech, service['id']!, service);
                  } else {
                    _showPreferredTimeDialog(tech, service['id']!, service);
                  }
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

  void _showPreferredTimeDialog(
    dynamic tech,
    String serviceTypeId,
    Map<String, String> service,
  ) {
    final timeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isEnglish ? 'Schedule a Visit' : 'احجزي ميعاد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEnglish
                  ? '${tech['name']} is busy right now. When would work for you? The technician will contact you to confirm.'
                  : '${tech['name']} مشغول دلوقتي. إيه الوقت اللي يناسبك؟ الفني هيكلمك يتفقوا معاكِ.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: timeController,
              decoration: InputDecoration(
                hintText: widget.isEnglish
                    ? 'e.g. Tomorrow morning, this evening...'
                    : 'مثلاً: بكرة الصبح، النهاردة بالليل...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isEnglish ? 'Cancel' : 'إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final preferredTime = timeController.text.trim();
              if (preferredTime.isEmpty) return;
              Navigator.pop(context);
              _requestService(
                tech,
                serviceTypeId,
                service,
                preferredTime: preferredTime,
              );
            },
            child: Text(widget.isEnglish ? 'Send' : 'إرسال'),
          ),
        ],
      ),
    );
  }

  void _requestService(
    dynamic tech,
    String serviceTypeId,
    Map<String, String> service, {
    String? preferredTime,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final requestId = '${DateTime.now().millisecondsSinceEpoch}';

      String userPhone = 'N/A';
      String userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      if (userId != null) {
        final userSnapshot = await FirebaseDatabase.instance
            .ref('users')
            .child(userId)
            .get();
        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map;
          userPhone = userData['phone'] as String? ?? 'N/A';
        }
      }

      await FirebaseDatabase.instance
          .ref('service_requests')
          .child(requestId)
          .set({
            'requestId': requestId,
            'userId': userId,
            'userPhone': userPhone,
            'userEmail': userEmail,
            'technicianId': tech['id'],
            'technicianName': tech['name'],
            'technicianPhone': tech['phone'],
            'technicianEmail': tech['email'],
            'serviceType': serviceTypeId,
            'serviceName': widget.isEnglish ? service['en'] : service['ar'],
            'serviceIcon': service['icon'],
            'status': preferredTime != null ? 'scheduled' : 'pending',
            'preferredTime': preferredTime,
            'userLocation': {
              'latitude': _currentLocation?.latitude,
              'longitude': _currentLocation?.longitude,
            },
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'seenByTechnician': false,
            'seenByUser': false,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              preferredTime != null
                  ? (widget.isEnglish
                        ? 'Appointment request sent to ${tech['name']}'
                        : 'تم إرسال طلب الحجز إلى ${tech['name']}')
                  : (widget.isEnglish
                        ? 'Service request sent to ${tech['name']}'
                        : 'تم إرسال طلب الخدمة إلى ${tech['name']}'),
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

  Future<void> _toggleAvailability() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final newState = !_isAvailable;
        await FirebaseDatabase.instance.ref('users').child(userId).update({
          'isAvailable': newState,
        });

        setState(() => _isAvailable = newState);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newState
                    ? (widget.isEnglish
                          ? '🟢 You are now available'
                          : '🟢 أنت الآن متاح')
                    : (widget.isEnglish
                          ? '🔴 You are now offline'
                          : '🔴 أنت الآن غير متاح'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish
                  ? 'Error updating status'
                  : 'خطأ في تحديث الحالة',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentLocation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                widget.isEnglish
                    ? 'Unable to get location'
                    : 'تعذر الحصول على الموقع',
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _initializeMap();
                },
                child: Text(widget.isEnglish ? 'Retry' : 'إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return _userType == 'technician'
        ? _buildTechnicianView()
        : _buildUserView();
  }

  // ✨ واجهة المستخدم العادي
  Widget _buildUserView() {
    final filteredTechnicians = _selectedFilter == null
        ? technicians
        : technicians
              .where(
                (t) => (t['specializations'] as List).contains(_selectedFilter),
              )
              .toList();

    return Column(
      children: [
        Expanded(
          flex: 55,
          child: GoogleMap(
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
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(widget.isEnglish ? 'All' : 'الكل'),
                  selected: _selectedFilter == null,
                  onSelected: (_) => setState(() => _selectedFilter = null),
                ),
              ),
              ...serviceTypes.map((s) {
                final isSelected = _selectedFilter == s['id'];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      '${s['icon']} ${widget.isEnglish ? s['en'] : s['ar']}',
                    ),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedFilter = s['id']),
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          flex: 40,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.blue,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isEnglish
                          ? '${filteredTechnicians.where((t) => t['isAvailable']).length} Available'
                          : '${filteredTechnicians.where((t) => t['isAvailable']).length} متاحين',
                      style: const TextStyle(
                        color: Colors.white,
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
              Expanded(
                child: filteredTechnicians.isEmpty
                    ? Center(
                        child: Text(
                          widget.isEnglish
                              ? 'No technicians found'
                              : 'لا يوجد فنيين',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredTechnicians.length,
                        itemBuilder: (context, index) {
                          final tech = filteredTechnicians[index];
                          final distance = _currentLocation != null
                              ? _calculateDistance(
                                  _currentLocation!,
                                  LatLng(tech['latitude'], tech['longitude']),
                                )
                              : 0.0;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tech['isAvailable']
                                    ? Colors.green
                                    : Colors.grey,
                                width: 2,
                              ),
                              color: index == 0
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.white,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: tech['isAvailable']
                                    ? Colors.green
                                    : Colors.grey,
                                child: Text(
                                  tech['isAvailable'] ? '🟢' : '🔴',
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              title: Text(
                                tech['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📱 ${tech['phone']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '⭐ ${tech['rating']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '📍 ${distance.toStringAsFixed(1)} ${widget.isEnglish ? 'km' : 'كم'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  if ((tech['specializations'] as List)
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: (tech['specializations'] as List)
                                          .map(
                                            (specId) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _specializationLabel(
                                                  specId as String,
                                                  otherSpecialty:
                                                      tech['otherSpecialty']
                                                          as String?,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _showServiceTypeDialog(tech),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tech['isAvailable']
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                child: Text(
                                  tech['isAvailable']
                                      ? (widget.isEnglish ? 'Request' : 'طلب')
                                      : (widget.isEnglish
                                            ? 'Schedule'
                                            : 'احجز'),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✨ واجهة الفني
  Widget _buildTechnicianView() {
    return Stack(
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
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: ElevatedButton(
            onPressed: _toggleAvailability,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAvailable ? Colors.green : Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _isAvailable
                  ? (widget.isEnglish ? '🟢 Available' : '🟢 متاح')
                  : (widget.isEnglish ? '🔴 Offline' : '🔴 غير متاح'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    mapController?.dispose();
    super.dispose();
  }
}
