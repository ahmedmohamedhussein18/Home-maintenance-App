import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const HomeMaintenanceApp());
}

class HomeMaintenanceApp extends StatefulWidget {
  const HomeMaintenanceApp({super.key});

  @override
  State<HomeMaintenanceApp> createState() => _HomeMaintenanceAppState();
}

class _HomeMaintenanceAppState extends State<HomeMaintenanceApp> {
  bool isDarkMode = false;
  bool isEnglish = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: isEnglish ? 'Home Maintenance' : 'صيانة البيت',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: AppRoot(
        isDarkMode: isDarkMode,
        isEnglish: isEnglish,
        onThemeChanged: (value) => setState(() => isDarkMode = value),
        onLanguageChanged: (value) => setState(() => isEnglish = value),
      ),
    );
  }
}

// ---------------------- APP ROOT (HOME SCREEN + SPLASH OVERLAY) ----------------------
// The splash is an overlay on top of the real home screen (not a separate
// route), so toggling dark mode / language always reaches the live screen.

class AppRoot extends StatefulWidget {
  final bool isDarkMode;
  final bool isEnglish;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<bool> onLanguageChanged;

  const AppRoot({
    super.key,
    required this.isDarkMode,
    required this.isEnglish,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with SingleTickerProviderStateMixin {
  bool _showSplash = true;
  late final AnimationController _controller;
  late final Animation<double> _fadeInAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _hideSplashAfterDelay();
  }

  Future<void> _hideSplashAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MaintenanceHomeScreen(
          isDarkMode: widget.isDarkMode,
          isEnglish: widget.isEnglish,
          onThemeChanged: widget.onThemeChanged,
          onLanguageChanged: widget.onLanguageChanged,
        ),
        IgnorePointer(
          ignoring: !_showSplash,
          child: AnimatedOpacity(
            opacity: _showSplash ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: _SplashContent(
              isEnglish: widget.isEnglish,
              fadeAnimation: _fadeInAnimation,
              scaleAnimation: _scaleAnimation,
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashContent extends StatelessWidget {
  final bool isEnglish;
  final Animation<double> fadeAnimation;
  final Animation<double> scaleAnimation;

  const _SplashContent({
    required this.isEnglish,
    required this.fadeAnimation,
    required this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primary,
      child: SizedBox.expand(
        child: Center(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.home_repair_service,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isEnglish ? 'Welcome' : 'مرحباً بك',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEnglish ? 'Home Maintenance App' : 'تطبيق صيانة البيت',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------- MODELS ----------------------

class MaintenanceItem {
  final String title;
  final DateTime targetDate;
  final double cost;

  MaintenanceItem({
    required this.title,
    required this.targetDate,
    required this.cost,
  });

  int get remainingDays {
    final now = DateTime.now();
    final difference = targetDate
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return difference < 0 ? 0 : difference;
  }

  IconData get icon {
    final t = title.toLowerCase();
    if (t.contains('ثلاج') || t.contains('fridge')) return Icons.kitchen;
    if (t.contains('تكييف') || t.contains('ac')) return Icons.ac_unit;
    if (t.contains('فلتر') || t.contains('water')) return Icons.water_drop;
    if (t.contains('سيار') || t.contains('car') || t.contains('زيت')) {
      return Icons.directions_car;
    }
    if (t.contains('غسال') || t.contains('washer')) {
      return Icons.local_laundry_service;
    }
    if (t.contains('سخان') || t.contains('heater')) return Icons.hot_tub;
    if (t.contains('كهرب') || t.contains('electric')) return Icons.flash_on;
    return Icons.devices;
  }

  Color get color {
    final t = title.toLowerCase();
    if (t.contains('ثلاج') || t.contains('fridge')) return Colors.teal;
    if (t.contains('تكييف') || t.contains('ac')) return Colors.blue;
    if (t.contains('فلتر') || t.contains('water')) return Colors.orange;
    if (t.contains('سيار') || t.contains('car')) return Colors.green;
    if (t.contains('غسال') || t.contains('washer')) return Colors.indigo;
    if (t.contains('سخان') || t.contains('heater')) return Colors.deepOrange;
    return Colors.purple;
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'targetDate': targetDate.toIso8601String(),
    'cost': cost,
  };

  factory MaintenanceItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceItem(
      title: json['title'] as String,
      targetDate: DateTime.parse(json['targetDate'] as String),
      cost: (json['cost'] as num).toDouble(),
    );
  }
}

class EmergencyContact {
  final String title;
  final String phone;

  EmergencyContact({required this.title, required this.phone});

  Map<String, dynamic> toJson() => {'title': title, 'phone': phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      title: json['title'] as String,
      phone: json['phone'] as String,
    );
  }
}

// ---------------------- STORAGE ----------------------

class StorageService {
  static const _itemsKey = 'maintenance_items';
  static const _contactsKey = 'emergency_contacts';

  static Future<void> saveItems(List<MaintenanceItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final list = items.map((e) => e.toJson()).toList();
    await prefs.setString(_itemsKey, jsonEncode(list));
  }

  static Future<List<MaintenanceItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_itemsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => MaintenanceItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = contacts.map((e) => e.toJson()).toList();
    await prefs.setString(_contactsKey, jsonEncode(list));
  }

  static Future<List<EmergencyContact>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ---------------------- HOME SCREEN ----------------------

class MaintenanceHomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final bool isEnglish;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<bool> onLanguageChanged;

  const MaintenanceHomeScreen({
    super.key,
    required this.isDarkMode,
    required this.isEnglish,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  State<MaintenanceHomeScreen> createState() => _MaintenanceHomeScreenState();
}

class _MaintenanceHomeScreenState extends State<MaintenanceHomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  List<MaintenanceItem> items = [];
  List<EmergencyContact> contacts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final loadedItems = await StorageService.loadItems();
    final loadedContacts = await StorageService.loadContacts();
    setState(() {
      items = loadedItems;
      contacts = loadedContacts;
      _sortItems();
      _isLoading = false;
    });
  }

  void _sortItems() {
    items.sort((a, b) => a.remainingDays.compareTo(b.remainingDays));
  }

  Future<void> _persistItems() async {
    _sortItems();
    await StorageService.saveItems(items);
  }

  Future<void> _persistContacts() async {
    await StorageService.saveContacts(contacts);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish
                  ? 'Could not call $phoneNumber'
                  : 'تعذر إجراء الاتصال بالرقم $phoneNumber',
            ),
          ),
        );
      }
    }
  }

  // ---------------------- DEVICE DIALOG (ADD / EDIT) ----------------------

  void _showDeviceDialog({MaintenanceItem? existing, int? index}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final costController = TextEditingController(
      text: existing != null ? existing.cost.toString() : '',
    );
    DateTime? selectedDate = existing?.targetDate;
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? (widget.isEnglish
                          ? 'Add Device'
                          : 'إضافة موعد صيانة جديد')
                    : (widget.isEnglish ? 'Edit Device' : 'تعديل الجهاز'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: widget.isEnglish
                            ? 'Device / Service Name'
                            : 'اسم الجهاز أو الخدمة (مثل: ثلاجة، تكييف)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: widget.isEnglish ? 'Cost' : 'التكلفة (جنيه)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedDate == null
                                ? (widget.isEnglish
                                      ? 'No date chosen'
                                      : 'لم يتم اختيار موعد')
                                : '${widget.isEnglish ? 'Date:' : 'الموعد:'} '
                                      '${selectedDate!.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Text(
                            widget.isEnglish ? 'Pick Date' : 'اختر اليوم',
                          ),
                        ),
                      ],
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.isEnglish ? 'Cancel' : 'إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final costValue = double.tryParse(
                      costController.text.trim().replaceAll(',', '.'),
                    );

                    if (title.isEmpty) {
                      setDialogState(() {
                        errorText = widget.isEnglish
                            ? 'Please enter a device name'
                            : 'من فضلك اكتب اسم الجهاز';
                      });
                      return;
                    }
                    if (costController.text.trim().isNotEmpty &&
                        costValue == null) {
                      setDialogState(() {
                        errorText = widget.isEnglish
                            ? 'Cost must be a number'
                            : 'التكلفة لازم تكون رقم';
                      });
                      return;
                    }
                    if (selectedDate == null) {
                      setDialogState(() {
                        errorText = widget.isEnglish
                            ? 'Please pick a date'
                            : 'من فضلك اختر موعد الصيانة';
                      });
                      return;
                    }

                    final newItem = MaintenanceItem(
                      title: title,
                      targetDate: selectedDate!,
                      cost: costValue ?? 0.0,
                    );

                    setState(() {
                      if (existing != null && index != null) {
                        items[index] = newItem;
                      } else {
                        items.add(newItem);
                      }
                    });
                    _persistItems();
                    Navigator.pop(context);
                  },
                  child: Text(widget.isEnglish ? 'Save' : 'حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteItem(int index) {
    final removedItem = items[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isEnglish ? 'Delete Device?' : 'حذف الجهاز؟'),
        content: Text(
          widget.isEnglish
              ? 'Are you sure you want to delete "${removedItem.title}"?'
              : 'متأكد إنك عايز تمسح "${removedItem.title}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isEnglish ? 'Cancel' : 'إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                items.removeAt(index);
              });
              _persistItems();
              _showUndoSnackBar(
                message: widget.isEnglish ? 'Device deleted' : 'تم حذف الجهاز',
                onUndo: () {
                  setState(() {
                    items.insert(index, removedItem);
                  });
                  _persistItems();
                },
              );
            },
            child: Text(
              widget.isEnglish ? 'Delete' : 'حذف',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showUndoSnackBar({
    required String message,
    required VoidCallback onUndo,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: widget.isEnglish ? 'UNDO' : 'تراجع',
          onPressed: onUndo,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ---------------------- CONTACT DIALOG (ADD / EDIT) ----------------------

  void _showContactDialog({EmergencyContact? existing, int? index}) {
    final nameController = TextEditingController(text: existing?.title ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? (widget.isEnglish
                          ? 'Add Emergency Contact'
                          : 'إضافة جهة طوارئ جديدة')
                    : (widget.isEnglish ? 'Edit Contact' : 'تعديل جهة الاتصال'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: widget.isEnglish
                          ? 'Worker / Service Name'
                          : 'اسم الفني أو الخدمة',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: widget.isEnglish
                          ? 'Phone Number'
                          : 'رقم الهاتف',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.isEnglish ? 'Cancel' : 'إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty || phone.isEmpty) {
                      setDialogState(() {
                        errorText = widget.isEnglish
                            ? 'Please fill in both fields'
                            : 'من فضلك املأ الاسم ورقم الهاتف';
                      });
                      return;
                    }
                    final phoneRegex = RegExp(r'^[0-9+\s]{7,15}$');
                    if (!phoneRegex.hasMatch(phone)) {
                      setDialogState(() {
                        errorText = widget.isEnglish
                            ? 'Enter a valid phone number'
                            : 'رقم الهاتف غير صحيح';
                      });
                      return;
                    }

                    final newContact = EmergencyContact(
                      title: name,
                      phone: phone,
                    );

                    setState(() {
                      if (existing != null && index != null) {
                        contacts[index] = newContact;
                      } else {
                        contacts.add(newContact);
                      }
                    });
                    _persistContacts();
                    Navigator.pop(context);
                  },
                  child: Text(widget.isEnglish ? 'Save' : 'حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteContact(int index) {
    final removedContact = contacts[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isEnglish ? 'Delete Contact?' : 'حذف جهة الاتصال؟'),
        content: Text(
          widget.isEnglish
              ? 'Are you sure you want to delete "${removedContact.title}"?'
              : 'متأكد إنك عايز تمسح "${removedContact.title}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isEnglish ? 'Cancel' : 'إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                contacts.removeAt(index);
              });
              _persistContacts();
              _showUndoSnackBar(
                message: widget.isEnglish
                    ? 'Contact deleted'
                    : 'تم حذف جهة الاتصال',
                onUndo: () {
                  setState(() {
                    contacts.insert(index, removedContact);
                  });
                  _persistContacts();
                },
              );
            },
            child: Text(
              widget.isEnglish ? 'Delete' : 'حذف',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- BUILD ----------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    double totalCost = items.fold(0, (sum, item) => sum + item.cost);

    final List<Widget> pages = [
      _buildDevicesPage(totalCost),
      _buildEmergencyPage(),
      _buildSettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? (widget.isEnglish ? 'Maintenance Log' : 'سجل الصيانة والأجهزة')
              : (_currentIndex == 1
                    ? (widget.isEnglish
                          ? 'Emergency Contacts'
                          : 'طوارئ الصيانة السريعة')
                    : (widget.isEnglish ? 'Settings' : 'الإعدادات')),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showDeviceDialog(),
              icon: const Icon(Icons.add),
              label: Text(widget.isEnglish ? 'Add Device' : 'إضافة جهاز'),
            )
          : (_currentIndex == 1
                ? FloatingActionButton.extended(
                    onPressed: () => _showContactDialog(),
                    icon: const Icon(Icons.person_add),
                    label: Text(
                      widget.isEnglish ? 'Add Contact' : 'إضافة جهة اتصال',
                    ),
                  )
                : null),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home),
            label: widget.isEnglish ? 'Devices' : 'الأجهزة',
          ),
          NavigationDestination(
            icon: const Icon(Icons.phone_in_talk),
            label: widget.isEnglish ? 'Emergency' : 'الطوارئ',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings),
            label: widget.isEnglish ? 'Settings' : 'الإعدادات',
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesPage(double totalCost) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.devices_other,
        title: widget.isEnglish ? 'No devices yet' : 'مفيش أجهزة مضافة',
        subtitle: widget.isEnglish
            ? 'Tap "Add Device" to start tracking maintenance'
            : 'دوس على "إضافة جهاز" عشان تبدأ تتابع الصيانة',
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer
                .withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isEnglish ? 'Total Cost:' : 'إجمالي تكاليف الصيانة:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${totalCost.toStringAsFixed(0)} L.E',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              int days = item.remainingDays;

              String statusText = days <= 3
                  ? (widget.isEnglish
                        ? 'Urgent ($days days left)'
                        : 'عاجل (متبقي $days أيام)')
                  : (widget.isEnglish
                        ? 'Stable ($days days left)'
                        : 'مستقر (متبقي $days يوم)');
              Color statusColor = days <= 3 ? Colors.red : Colors.green;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        _showDeviceDialog(existing: item, index: index),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: item.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.icon, color: item.color, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cost: ${item.cost.toStringAsFixed(0)} L.E',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blueGrey,
                                      size: 20,
                                    ),
                                    onPressed: () => _showDeviceDialog(
                                      existing: item,
                                      index: index,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _confirmDeleteItem(index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyPage() {
    if (contacts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.contact_phone,
        title: widget.isEnglish ? 'No contacts yet' : 'مفيش جهات اتصال',
        subtitle: widget.isEnglish
            ? 'Tap "Add Contact" to add technicians you trust'
            : 'دوس على "إضافة جهة اتصال" عشان تضيف الفنيين اللي تثق فيهم',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.engineering, color: Colors.blue),
            ),
            title: Text(
              contact.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(contact.phone),
            onTap: () => _showContactDialog(existing: contact, index: index),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: () => _makePhoneCall(contact.phone),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _confirmDeleteContact(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: Text(
            widget.isEnglish ? 'Dark Mode' : 'الوضع الداكن',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          secondary: const Icon(Icons.dark_mode),
          value: widget.isDarkMode,
          onChanged: widget.onThemeChanged,
        ),
        const Divider(),
        SwitchListTile(
          title: Text(
            widget.isEnglish ? 'English Language' : 'اللغة الإنجليزية',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          secondary: const Icon(Icons.language),
          value: widget.isEnglish,
          onChanged: widget.onLanguageChanged,
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
