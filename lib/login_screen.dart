import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginScreen extends StatefulWidget {
  final bool isEnglish;
  final bool isDarkMode;
  final ValueChanged<bool> onLanguageChanged;
  final ValueChanged<bool> onThemeChanged;

  const LoginScreen({
    super.key,
    required this.isEnglish,
    required this.isDarkMode,
    required this.onLanguageChanged,
    required this.onThemeChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _phoneController;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _isLoginMode = true;
  String _selectedUserType = 'user';

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = widget.isEnglish
            ? 'Please fill all fields'
            : 'من فضلك املأ جميع الحقول';
      });
      return;
    }

    final emailPattern = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!emailPattern.hasMatch(email)) {
      setState(() {
        _errorMessage = widget.isEnglish
            ? 'Please enter a valid email address'
            : 'من فضلك أدخل بريدًا إلكترونيًا صحيحًا';
      });
      return;
    }

    if (!_isLoginMode) {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        setState(() {
          _errorMessage = widget.isEnglish
              ? 'Please enter your phone number'
              : 'من فضلك أدخل رقم هاتفك';
        });
        return;
      }
      if (!RegExp(r'^01[0-9]{9}$').hasMatch(phone)) {
        setState(() {
          _errorMessage = widget.isEnglish
              ? 'Phone number must be 11 digits and start with 01'
              : 'رقم الهاتف لازم يكون 11 رقم ';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      UserCredential userCredential;

      if (_isLoginMode) {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        final userId = userCredential.user!.uid;
        final phone = _phoneController.text.trim();

        // نتابع هل حجزنا الرقم فعليًا في phone_index عشان نعرف نرجع فيه
        // (rollback) لو أي خطوة بعده فشلت.
        bool phoneClaimed = false;

        try {
          final phoneSnapshot = await FirebaseDatabase.instance
              .ref('phone_index')
              .child(phone)
              .get();

          if (phoneSnapshot.exists) {
            // الرقم فعلاً متأخد بحساب تاني
            await userCredential.user!.delete();
            setState(() {
              _errorMessage = widget.isEnglish
                  ? 'This phone number is already registered to another account'
                  : 'رقم الهاتف ده متسجل بحساب تاني بالفعل';
            });
            return;
          }

          // الرقم متاح، نحجزه دلوقتي
          await FirebaseDatabase.instance
              .ref('phone_index')
              .child(phone)
              .set(userId);
          phoneClaimed = true;

          await FirebaseDatabase.instance.ref('users').child(userId).set({
            'uid': userId,
            'email': email,
            'phone': phone,
            'userType': _selectedUserType,
          });

          await userCredential.user!.sendEmailVerification();
        } catch (e) {
          // أي فشل هنا (صلاحيات، شبكة، فشل كتابة users، فشل إرسال الإيميل...)
          // لازم نرجع بالكامل: نمسح حجز الرقم لو اتحجز، ونمسح حساب الـ auth.
          if (phoneClaimed) {
            await FirebaseDatabase.instance
                .ref('phone_index')
                .child(phone)
                .remove();
          }
          await userCredential.user!.delete();
          setState(() {
            _errorMessage = widget.isEnglish
                ? 'Registration failed. Please try again.'
                : 'فشل التسجيل. حاول تاني.';
          });
          return;
        }
      }

      setState(() => _errorMessage = null);
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('FirebaseAuthException code: ${e.code} | message: ${e.message}');
      setState(() {
        _errorMessage = widget.isEnglish
            ? e.message ?? 'Auth failed'
            : (_authErrorMessageAr(e.code));
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // بترجع رسالة عربي واضحة حسب كود الخطأ الحقيقي بدل رسالة عامة واحدة
  // بتخفي السبب الحقيقي.
  String _authErrorMessageAr(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً، حاول بعد قليل';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت وحاول مرة أخرى';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      default:
        return 'فشل التحقق ($code)';
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = widget.isEnglish
            ? 'Enter your email above first, then tap "Forgot password?"'
            : 'اكتب إيميلك فوق الأول، وبعدين دوس "نسيت كلمة المرور؟"';
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _infoMessage = widget.isEnglish
            ? 'A password reset link was sent to $email'
            : 'تم إرسال رابط إعادة تعيين كلمة المرور إلى $email';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = widget.isEnglish
            ? e.message ?? 'Failed to send reset email'
            : 'فشل إرسال رابط الاسترجاع';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEnglish ? 'Home Maintenance' : 'صيانة البيت'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => widget.onLanguageChanged(!widget.isEnglish),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_repair_service, size: 80, color: Colors.blue),
                const SizedBox(height: 32),
                Text(
                  _isLoginMode
                      ? (widget.isEnglish ? 'Sign In' : 'تسجيل الدخول')
                      : (widget.isEnglish ? 'Create Account' : 'إنشاء حساب'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                if (!_isLoginMode) ...[
                  Text(
                    widget.isEnglish ? 'Account Type' : 'نوع الحساب',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedUserType = 'user'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _selectedUserType == 'user'
                                  ? Colors.blue
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedUserType == 'user'
                                    ? Colors.blue
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: _selectedUserType == 'user'
                                      ? Colors.white
                                      : Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.isEnglish ? 'User' : 'مستخدم عادي',
                                  style: TextStyle(
                                    color: _selectedUserType == 'user'
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedUserType = 'technician'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _selectedUserType == 'technician'
                                  ? Colors.orange
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedUserType == 'technician'
                                    ? Colors.orange
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.engineering,
                                  color: _selectedUserType == 'technician'
                                      ? Colors.white
                                      : Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.isEnglish ? 'Technician' : 'فني',
                                  style: TextStyle(
                                    color: _selectedUserType == 'technician'
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: widget.isEnglish
                          ? 'Phone Number'
                          : 'رقم الهاتف',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: widget.isEnglish ? 'Email' : 'البريد الإلكتروني',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: widget.isEnglish ? 'Password' : 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: true,
                ),
                if (_isLoginMode) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: Text(
                        widget.isEnglish
                            ? 'Forgot password?'
                            : 'نسيت كلمة المرور؟',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                if (_infoMessage != null)
                  Text(
                    _infoMessage!,
                    style: const TextStyle(color: Colors.green, fontSize: 14),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _authenticate,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            _isLoginMode
                                ? (widget.isEnglish
                                      ? 'Sign In'
                                      : 'تسجيل الدخول')
                                : (widget.isEnglish
                                      ? 'Create Account'
                                      : 'إنشاء حساب'),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                      _errorMessage = null;
                      _infoMessage = null;
                    });
                  },
                  child: Text(
                    _isLoginMode
                        ? (widget.isEnglish
                              ? "Don't have an account? Sign up"
                              : "ليس لديك حساب؟ أنشئ واحداً")
                        : (widget.isEnglish
                              ? "Already have an account? Sign in"
                              : "هل لديك حساب؟ تسجيل الدخول"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
