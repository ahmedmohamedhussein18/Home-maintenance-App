import 'package:firebase_database/firebase_database.dart';

/// نوع المستخدم: مستخدم عادي أو فني
enum UserType { user, technician }

class AppUser {
  final String uid;
  final String name;
  final String phone;
  final UserType userType;
  final double? latitude;
  final double? longitude;
  final double rating; // متوسط تقييم الفني (0 لو مفيش تقييمات لسه)
  final int ratingCount; // عدد التقييمات
  final bool isAvailable; // متاح دلوقتي ولا لأ (للفني بس)
  final String? specialty; // تخصص الفني (تكييف، سباكة، كهرباء... إلخ)

  AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.userType,
    this.latitude,
    this.longitude,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.isAvailable = true,
    this.specialty,
  });

  bool get isTechnician => userType == UserType.technician;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'phone': phone,
    'userType': userType.name,
    'latitude': latitude,
    'longitude': longitude,
    'rating': rating,
    'ratingCount': ratingCount,
    'isAvailable': isAvailable,
    'specialty': specialty,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      userType: (json['userType'] as String?) == 'technician'
          ? UserType.technician
          : UserType.user,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      specialty: json['specialty'] as String?,
    );
  }

  AppUser copyWith({
    String? name,
    String? phone,
    UserType? userType,
    double? latitude,
    double? longitude,
    double? rating,
    int? ratingCount,
    bool? isAvailable,
    String? specialty,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      isAvailable: isAvailable ?? this.isAvailable,
      specialty: specialty ?? this.specialty,
    );
  }
}

/// خدمة بسيطة للتعامل مع بيانات المستخدم في Firebase Realtime Database
class UserService {
  static final DatabaseReference _usersRef = FirebaseDatabase.instance.ref(
    'users',
  );

  static Future<void> saveUser(AppUser user) async {
    await _usersRef.child(user.uid).set(user.toJson());
  }

  static Future<AppUser?> getUser(String uid) async {
    final snapshot = await _usersRef.child(uid).get();
    if (!snapshot.exists) return null;
    final map = Map<String, dynamic>.from(snapshot.value as Map);
    return AppUser.fromJson(map);
  }

  static Future<void> updateLocation(
    String uid,
    double latitude,
    double longitude,
  ) async {
    await _usersRef.child(uid).update({
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  static Future<void> updateAvailability(String uid, bool isAvailable) async {
    await _usersRef.child(uid).update({'isAvailable': isAvailable});
  }

  /// يجيب كل الفنيين المتاحين حالياً
  static Future<List<AppUser>> getAvailableTechnicians() async {
    final snapshot = await _usersRef.get();
    final List<AppUser> technicians = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      data.forEach((key, value) {
        final map = Map<String, dynamic>.from(value as Map);
        final user = AppUser.fromJson(map);
        if (user.isTechnician && user.isAvailable) {
          technicians.add(user);
        }
      });
    }
    return technicians;
  }
}
