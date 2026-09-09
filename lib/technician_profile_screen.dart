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
  bool _isLoading = true;

  // التخصصات المتاحة
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
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
            selectedSpecializations = List<String>.from(
              data['specializations'] ?? [],
            );
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
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

    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish ? 'Please enter your phone' : 'من فضلك أدخل رقمك',
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

    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseDatabase.instance.ref('users').child(userId).update({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'specializations': selectedSpecializations,
        });

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
                    // الاسم
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

                    // الهاتف
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

                    // التخصصات
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

                    // قائمة التخصصات
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

                    const SizedBox(height: 32),

                    // زر الحفظ
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
    super.dispose();
  }
}
