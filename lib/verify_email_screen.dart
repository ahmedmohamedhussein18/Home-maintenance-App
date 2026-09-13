import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  final bool isEnglish;
  final VoidCallback onVerified;

  const VerifyEmailScreen({
    super.key,
    required this.isEnglish,
    required this.onVerified,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isSending = false;
  bool _isPolling = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startListeningForVerification();
  }

  @override
  void dispose() {
    _isPolling = false; // بيوقف الـ loop لما الشاشة تتقفل
    super.dispose();
  }

  // ✅ الطريقة الجديدة: auto-check كل نص ثانية بدل ما المستخدم يدوس زرار
  void _startListeningForVerification() {
    _isPolling = true;

    Future.doWhile(() async {
      if (!mounted || !_isPolling) return false;

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted || !_isPolling) return false;

      try {
        await FirebaseAuth.instance.currentUser?.reload();
      } catch (_) {
        // لو حصل خطأ في الـ reload، منوقفش الـ loop، نكمل نحاول
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        _isPolling = false;
        widget.onVerified();
        return false; // وقف الـ loop
      }
      return true; // استمر
    });
  }

  // الزرار اليدوي لسه موجود لو المستخدم عاوز يتأكد بنفسه فورًا
  Future<void> _checkVerified() async {
    setState(() => _isChecking = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        _isPolling = false;
        widget.onVerified();
      } else {
        setState(() {
          _message = widget.isEnglish
              ? 'Email not verified yet. Please check your inbox.'
              : 'الإيميل لسه مش متأكد. من فضلك افتحي بريدك.';
        });
      }
    } catch (e) {
      setState(() {
        _message = widget.isEnglish
            ? 'Something went wrong. Try again.'
            : 'حصلت مشكلة. حاولي تاني.';
      });
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() {
        _message = widget.isEnglish
            ? 'Verification email sent again.'
            : 'تم إعادة إرسال رابط التأكيد.';
      });
    } catch (e) {
      setState(() {
        _message = widget.isEnglish
            ? 'Failed to resend. Try again shortly.'
            : 'فشل إعادة الإرسال. حاولي بعد شوية.';
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEnglish ? 'Verify Your Email' : 'أكّدي بريدك الإلكتروني',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _isPolling = false;
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_unread, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                widget.isEnglish
                    ? 'We sent a verification link to:'
                    : 'بعتنا رابط تأكيد إلى:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                widget.isEnglish
                    ? 'Open the link — this page will update automatically.'
                    : 'افتحي الرابط، والصفحة هتتحدث لوحدها.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              if (_message != null) ...[
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.blue),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerified,
                  child: _isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.isEnglish
                              ? "I've Verified — Continue"
                              : 'أكّدت الإيميل — كمّلي',
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSending ? null : _resendEmail,
                child: Text(
                  widget.isEnglish
                      ? 'Resend Verification Email'
                      : 'إعادة إرسال رابط التأكيد',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
