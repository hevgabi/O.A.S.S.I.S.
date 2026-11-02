import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class ActivateAccountScreen extends StatefulWidget {
  const ActivateAccountScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ActivateAccountScreen> createState() => _ActivateAccountScreenState();
}

class _ActivateAccountScreenState extends State<ActivateAccountScreen> {
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isActivating = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _error = 'Choose a password with at least 8 characters.');
      return;
    }
    setState(() {
      _isActivating = true;
      _error = null;
    });
    final result = await AuthService.instance.activateStudent(
      email: _emailController.text,
      activationCode: _codeController.text.trim(),
      password: password,
    );
    if (!mounted) return;
    if (!result.isSuccess || result.user == null) {
      setState(() {
        _isActivating = false;
        _error = switch (result.failure) {
          AuthFailure.accountDisabled =>
            'This account is disabled. Contact an administrator for help.',
          AuthFailure.network => 'Check your connection and try again.',
          AuthFailure.backend =>
            'The service is unavailable. Please try again later.',
          _ => 'The email or activation code is not valid.',
        };
      });
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      result.user!.role == AppUserRole.student
          ? AppRoutes.studentChat
          : AppRoutes.entry,
      (route) => false,
    );
  }

  InputDecoration _decoration(String hint, {Widget? suffixIcon}) =>
      InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFEEEEEE),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activate Student Account')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set your password',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use the activation code supplied with your provisioned Student account.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration('Student email'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: _decoration('Activation code'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  decoration: _decoration(
                    'Choose password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isActivating ? null : _activate,
                  child: Text(
                    _isActivating ? 'Activating...' : 'Activate account',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to sign in'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Demo account: provisioned@mail.com\nDemo code: OASSIS-123',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
