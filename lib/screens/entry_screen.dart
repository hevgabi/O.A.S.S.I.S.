import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _loginError;
  bool _isSigningIn = false;
  bool _hidePassword = true;
  String? _emailError;
  String? _passwordError;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static const Color black = Colors.black;
  static const Color fieldGray = Color(0xFFEEEEEE);
  static const Color buttonGray = Color(0xFFC4C4C4);
  static const Color borderGray = Color(0xFF666666);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSigningIn) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final emailError = email.isEmpty
        ? 'Enter your email address.'
        : !_emailPattern.hasMatch(email)
        ? 'Enter a valid email, like name@mail.com.'
        : null;
    final passwordError = password.isEmpty ? 'Enter your password.' : null;
    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
        _loginError = null;
      });
      return;
    }

    setState(() {
      _isSigningIn = true;
      _emailError = null;
      _passwordError = null;
      _loginError = null;
    });

    final result = await AuthService.instance.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    final user = result.user;
    if (!result.isSuccess || user == null) {
      if (result.failure == AuthFailure.accountNotActivated) {
        await Navigator.of(context).pushNamed(
          AppRoutes.activateAccount,
          arguments: result.email ?? _emailController.text.trim(),
        );
        if (!mounted) return;
      }
      setState(() {
        _isSigningIn = false;
        _loginError = _messageFor(result.failure);
      });
      return;
    }

    final destination = user.role == AppUserRole.admin
        ? AppRoutes.knowledgeBase
        : AppRoutes.studentChat;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  String _messageFor(AuthFailure? failure) => switch (failure) {
    AuthFailure.accountNotActivated =>
      'Activate your provisioned Student account before signing in.',
    AuthFailure.accountDisabled =>
      'This account is disabled. Contact an administrator for help.',
    AuthFailure.invalidActivationCode =>
      'That activation code is not valid. Try again or contact support.',
    AuthFailure.network =>
      'We could not reach the service. Check your connection and try again.',
    AuthFailure.backend =>
      'The service is unavailable. Please try again later.',
    AuthFailure.signedOut => 'Your session ended. Please sign in again.',
    _ => 'Incorrect email or password.',
  };

  void _continueAsVisitor() {
    AuthService.instance.signOut();
    Navigator.of(context).pushNamed(AppRoutes.visitorChat);
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password help'),
        content: const Text(
          'Account recovery will be connected to the approved backend. For now, contact the administrator who provisioned your Student account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _clearErrors() {
    if (_emailError != null || _passwordError != null || _loginError != null) {
      setState(() {
        _emailError = null;
        _passwordError = null;
        _loginError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'OASSIS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: compact ? 48 : 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              height: 1.05,
                              color: black,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Campus Companion',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.4,
                              color: black,
                            ),
                          ),
                          SizedBox(height: compact ? 42 : 64),
                          const Text(
                            'Welcome',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: black,
                            ),
                          ),
                          SizedBox(height: compact ? 36 : 48),
                          const Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            label: 'Email address',
                            textField: true,
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => _clearErrors(),
                              decoration: _fieldDecoration(
                                'Email',
                                errorText: _emailError,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            label: 'Password',
                            textField: true,
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => _clearErrors(),
                              onSubmitted: (_) => _signIn(),
                              decoration: _fieldDecoration(
                                'Password',
                                errorText: _passwordError,
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: 34),
                          SizedBox(
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _isSigningIn ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonGray,
                                foregroundColor: black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                _isSigningIn ? 'Signing in...' : 'Sign in',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (_loginError != null) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _loginError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: black),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 58,
                            child: OutlinedButton(
                              onPressed: _continueAsVisitor,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: black,
                                side: const BorderSide(
                                  color: black,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Continue as visitor',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    String hint, {
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 2,
      errorStyle: const TextStyle(
        color: black,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(fontSize: 18, color: Colors.black45),
      filled: true,
      fillColor: fieldGray,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: borderGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: borderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: black, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: black, width: 1.5),
      ),
    );
  }
}
