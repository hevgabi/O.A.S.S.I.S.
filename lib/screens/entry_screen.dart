import 'package:flutter/material.dart';
import 'visitor_chat_screen.dart';

class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  static const Color black = Colors.black;
  static const Color fieldGray = Color(0xFFEEEEEE);
  static const Color buttonGray = Color(0xFFC4C4C4);
  static const Color borderGray = Color(0xFF666666);

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
                          TextField(
                            keyboardType: TextInputType.emailAddress,
                            decoration: _fieldDecoration('Email'),
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
                          TextField(
                            obscureText: true,
                            decoration: _fieldDecoration('Password'),
                          ),
                          const SizedBox(height: 34),
                          SizedBox(
                            height: 58,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                disabledBackgroundColor: buttonGray,
                                disabledForegroundColor: black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 58,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const VisitorChatScreen(),
                                  ),
                                );
                              },
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

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 18, color: Colors.black45),
      filled: true,
      fillColor: fieldGray,
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
    );
  }
}
