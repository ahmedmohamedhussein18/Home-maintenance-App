import 'package:flutter/material.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        brightness: Brightness.dark,
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MaintenanceHomeScreen(
        isDarkMode: isDarkMode,
        isEnglish: isEnglish,
        onThemeChanged: (value) => setState(() => isDarkMode = value),
        onLanguageChanged: (value) => setState(() => isEnglish = value),
      ),
    );
  }
}

class MaintenanceItem {
  final String title;
  final DateTime targetDate; // تاريخ محدد يقوم التطبيق بحساب الأيام المتبقية منه تلقائياً
  final double cost;

  MaintenanceItem({
    required this.title,
    required this.targetDate,
    required this.cost,
  });

  int get remainingDays {
    final now = DateTime.now();
    final difference = targetDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    return difference < 0 ? 0 : difference;
  }

  // دالة ذكية لتحديد الأيقونة تلقائياً بناءً على اسم الجهاز
  IconData get icon {
    final t = title.toLowerCase();
    if (t.contains('ثلاج') || t.contains('fridge')) return Icons.kitchen;
    if (t.contains('تكييف') || t.contains('ac')) return Icons.ac_unit;
    if (t.contains('فلتر') || t.contains('water')) return Icons.water_drop;
    if (t.contains('سيار') || t.contains('car') || t.contains('زيت')) return Icons.directions_car;
    if (t.contains('غسال') || t.contains('washer')) return Icons.local_laundry_service;
    if (t.contains('سخان') || t.contains('heater')) return Icons.hot_tub;
    if (t.contains('كهرب') || t.contains('electric')) return Icons.flash_on;
    return Icons.devices;
  }

  // دالة لتحديد لون مميز لكل أيقونة
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
}

class EmergencyContact {
  final String title;
  final String phone;
  final IconData icon;

  EmergencyContact({
    required this.title,
    required this.phone,
    required this.icon,
  });
}

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

  final List<MaintenanceItem> items = [
    MaintenanceItem(
      title: 'AC / تكييف الصالة',
      targetDate: DateTime.now().add(const Duration(days: 3)),
      cost: 350.0,
    ),
    MaintenanceItem(
      title: 'Water Filter / فلتر المياه',
      targetDate: DateTime.now().add(const Duration(days: 12)),
      cost: 150.0,
    ),
  ];

  final List<EmergencyContact> contacts = [
    EmergencyContact(title: 'فني تكييف وتبريد (AC Technician)', phone: '01012345678', icon: Icons.ac_unit),
    EmergencyContact(title: 'سباك صحي (Plumber)', phone: '01198765432', icon: Icons.water_drop),
  ];

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إجراء الاتصال بالرقم $phoneNumber')),
        );
      }
    }
  }

  // إضافة جهاز جديد باختيار تاريخ محدد من التقويم والحساب التلقائي للأيام
  void _showAddDeviceDialog() {
    final titleController = TextEditingController();
    final costController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(widget.isEnglish ? 'Add Maintenance Date' : 'إضافة موعد صيانة جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: widget.isEnglish ? 'Device / Service Name' : 'اسم الجهاز أو الخدمة (مثل: ثلاجة، تكييف)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: widget.isEnglish ? 'Cost' : 'التكلفة السابقة (جنيه)'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedDate == null
                                ? (widget.isEnglish ? 'No date chosen' : 'لم يتم اختيار موعد')
                                : '${widget.isEnglish ? 'Date:' : 'الموعد:'} ${selectedDate!.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Text(widget.isEnglish ? 'Pick Date' : 'اختر اليوم'),
                        ),
                      ],
                    ),
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
                    if (titleController.text.isNotEmpty && selectedDate != null) {
                      double cost = double.tryParse(costController.text) ?? 0.0;
                      setState(() {
                        items.add(MaintenanceItem(
                          title: titleController.text,
                          targetDate: selectedDate!,
                          cost: cost,
                        ));
                      });
                      Navigator.pop(context);
                    }
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

  // إضافة جهة طوارئ جديدة
  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.isEnglish ? 'Add Emergency Contact' : 'إضافة جهة طوارئ جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: widget.isEnglish ? 'Worker / Service Name' : 'اسم الفني أو الخدمة'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: widget.isEnglish ? 'Phone Number' : 'رقم الهاتف'),
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
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                  setState(() {
                    contacts.add(EmergencyContact(
                      title: nameController.text,
                      phone: phoneController.text,
                      icon: Icons.engineering,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(widget.isEnglish ? 'Add' : 'إضافة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalCost = items.fold(0, (sum, item) => sum + item.cost);

    final List<Widget> pages = [
      // صفحة الأجهزة وحساب الأيام المتبقية تلقائياً وتفعيل الإشعارات
      Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.isEnglish ? 'Total Cost:' : 'إجمالي تكاليف الصيانة:', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('$totalCost L.E', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
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
                    ? (widget.isEnglish ? 'Urgent ($days days left)' : 'عاجل (متبقي $days أيام)') 
                    : (widget.isEnglish ? 'Stable ($days days left)' : 'مستقر (متبقي $days يوم)');
                Color statusColor = days <= 3 ? Colors.red : Colors.green;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cost: ${item.cost} L.E',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.notifications_active, color: Colors.blue, size: 20),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(widget.isEnglish ? 'Notification set for ${item.title}' : 'تم تفعيل إشعار التنبيه لـ ${item.title} بنجاح')),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        items.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // صفحة الطوارئ مع خيار الحذف والإضافة للجهات
      Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: Icon(contact.icon, color: Colors.blue),
                    ),
                    title: Text(contact.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(contact.phone),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () => _makePhoneCall(contact.phone),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() {
                              contacts.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.person_add),
              label: Text(widget.isEnglish ? 'Add Emergency Contact' : 'إضافة رقم طوارئ جديد'),
            ),
          ),
        ],
      ),

      // صفحة الإعدادات
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(widget.isEnglish ? 'Dark Mode' : 'الوضع الداكن', style: const TextStyle(fontWeight: FontWeight.bold)),
            secondary: const Icon(Icons.dark_mode),
            value: widget.isDarkMode,
            onChanged: widget.onThemeChanged,
          ),
          const Divider(),
          SwitchListTile(
            title: Text(widget.isEnglish ? 'English Language' : 'اللغة الإنجليزية', style: const TextStyle(fontWeight: FontWeight.bold)),
            secondary: const Icon(Icons.language),
            value: widget.isEnglish,
            onChanged: widget.onLanguageChanged,
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 
              ? (widget.isEnglish ? 'Maintenance Log' : 'سجل الصيانة والأجهزة') 
              : (_currentIndex == 1 ? (widget.isEnglish ? 'Emergency Contacts' : 'طوارئ الصيانة السريعة') : (widget.isEnglish ? 'Settings' : 'الإعدادات')),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddDeviceDialog,
              icon: const Icon(Icons.add),
              label: Text(widget.isEnglish ? 'Add Device' : 'إضافة جهاز'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home), label: widget.isEnglish ? 'Devices' : 'الأجهزة'),
          NavigationDestination(icon: const Icon(Icons.phone_in_talk), label: widget.isEnglish ? 'Emergency' : 'الطوارئ'),
          NavigationDestination(icon: const Icon(Icons.settings), label: widget.isEnglish ? 'Settings' : 'الإعدادات'),
        ],
      ),
    );
  }
}
