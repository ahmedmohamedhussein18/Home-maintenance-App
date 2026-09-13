import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TechnicianProfileScreen extends StatefulWidget {
  final bool isEnglish;

  const TechnicianProfileScreen({super.key, required this.isEnglish});

  @override
  State<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _otherSpecialtyController;
  bool _isLoading = true;

  final List<Map<String, String>> specializations = [
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

  List<String> selectedSpecializations = [];
  bool _isSaving = false;
  double _rating = 0.0;
  int _ratingCount = 0;
  String _originalPhone = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _otherSpecialtyController = TextEditingController();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref('users')
            .child(userId)
            .get();

        if (snapshot.exists) {
          final data = snapshot.value as Map;
          setState(() {
            _nameController.text = data['name'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _originalPhone = data['phone'] ?? '';
            _rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
            _ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
            _otherSpecialtyController.text = data['otherSpecialty'] ?? '';
            selectedSpecializations = List<String>.from(
              data['specializations'] ?? [],
            );
          });
        }
      }
    } catch (e) {
      // Non-fatal: form just stays empty.
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish ? 'Please enter your name' : 'من فضلك أدخل اسمك',
          ),
        ),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish ? 'Please enter your phone' : 'من فضلك أدخل رقمك',
          ),
        ),
      );
      return;
    }

    if (!RegExp(r'^01[0-9]{9}$').hasMatch(_phoneController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish
                ? 'Phone number must be 11 digits and start with 01'
                : 'رقم الهاتف لازم يكون 11 رقم ويبدأ بـ 01',
          ),
        ),
      );
      return;
    }

    if (selectedSpecializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish
                ? 'Please select at least one specialization'
                : 'من فضلك اختر تخصص واحد على الأقل',
          ),
        ),
      );
      return;
    }

    if (selectedSpecializations.contains('other') &&
        _otherSpecialtyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish
                ? 'Please describe your "Other" specialty'
                : 'من فضلك اكتب شغلانتك في خانة "أخرى"',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final newPhone = _phoneController.text.trim();

        if (newPhone != _originalPhone) {
          try {
            await FirebaseDatabase.instance
                .ref('phone_index')
                .child(newPhone)
                .set(userId);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.isEnglish
                        ? 'This phone number is already registered to another account'
                        : 'رقم الهاتف ده متسجل بحساب تاني بالفعل',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            setState(() => _isSaving = false);
            return;
          }
          if (_originalPhone.isNotEmpty) {
            await FirebaseDatabase.instance
                .ref('phone_index')
                .child(_originalPhone)
                .remove();
          }
        }

        await FirebaseDatabase.instance.ref('users').child(userId).update({
          'name': _nameController.text.trim(),
          'phone': newPhone,
          'specializations': selectedSpecializations,
          'otherSpecialty': selectedSpecializations.contains('other')
              ? _otherSpecialtyController.text.trim()
              : '',
        });

        _originalPhone = newPhone;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEnglish
                    ? 'Profile updated successfully'
                    : 'تم تحديث الملف بنجاح',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish ? 'Error saving profile' : 'خطأ في حفظ الملف',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEnglish ? 'My Profile' : 'ملفي الشخصي'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_ratingCount > 0)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text(
                              '${_rating.toStringAsFixed(1)} ',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.isEnglish
                                  ? '($_ratingCount ratings)'
                                  : '($_ratingCount تقييم)',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.isEnglish
                              ? 'No ratings yet'
                              : 'لسه مفيش تقييمات',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    Text(
                      widget.isEnglish ? 'Full Name' : 'الاسم الكامل',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: widget.isEnglish
                            ? 'Enter your full name'
                            : 'أدخل اسمك الكامل',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      widget.isEnglish ? 'Phone Number' : 'رقم الهاتف',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: widget.isEnglish
                            ? 'Enter your phone number'
                            : 'أدخل رقم هاتفك',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      widget.isEnglish ? 'Your Specializations' : 'تخصصاتك',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.isEnglish
                          ? 'Select all the services you provide'
                          : 'اختر جميع الخدمات التي تقدمها',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: specializations.map((spec) {
                        final isSelected = selectedSpecializations.contains(
                          spec['id'],
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedSpecializations.remove(spec['id']);
                                } else {
                                  selectedSpecializations.add(spec['id']!);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey,
                                  width: 2,
                                ),
                                color: isSelected
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    spec['icon']!,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.isEnglish
                                          ? spec['en']!
                                          : spec['ar']!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.blue,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (selectedSpecializations.contains('other')) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.isEnglish
                            ? 'Describe your specialty'
                            : 'اكتب شغلانتك بالظبط',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _otherSpecialtyController,
                        decoration: InputDecoration(
                          hintText: widget.isEnglish
                              ? 'e.g. Furniture assembly, Painting...'
                              : 'مثلاً: تركيب أثاث، دهانات...',
                          prefixIcon: const Icon(Icons.edit),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                widget.isEnglish ? 'Save Profile' : 'حفظ الملف',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otherSpecialtyController.dispose();
    super.dispose();
  }
}
