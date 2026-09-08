import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'user_model.dart';

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
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLoginMode = true;
  String _selectedUserType = 'user';

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

    setState(() => _isLoading = true);

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
        await FirebaseDatabase.instance.ref('users').child(userId).set({
          'uid': userId,
          'email': email,
          'userType': _selectedUserType,
        });
      }

      setState(() => _errorMessage = null);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = widget.isEnglish
            ? e.message ?? 'Auth failed'
            : 'فشل التحقق';
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
                  const SizedBox(height: 32),
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
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
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
