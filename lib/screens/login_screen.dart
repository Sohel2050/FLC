import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/screens/home_screen.dart';
import 'package:flutter_chess_app/screens/forgot_password_screen.dart';
import 'package:flutter_chess_app/screens/sign_up_screen.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:provider/provider.dart';
import '../widgets/play_mode_button.dart';
import '../services/user_service.dart';
import '../services/sign_in_results.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UserService _userService = UserService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return; // Prevent multiple submissions
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final result = await _userService.signIn(
        _emailController.text,
        _passwordController.text,
      );

      if (mounted) {
        if (result is SignInSuccess) {
          // Navigate directly to home screen - app launch ad will be handled there
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen(user: result.user)),
            (route) => false,
          );
        } else if (result is SignInEmailNotVerified) {
          await _showEmailVerificationDialog(result.email);
        } else if (result is SignInError) {
          AnimatedDialog.show(
            context: context,
            title: 'Login Failed',
            child: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showEmailVerificationDialog(String email) async {
    bool showResendButton = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AnimatedDialog(
                title: 'Verify Email',

                actions: [
                  if (showResendButton)
                    TextButton(
                      onPressed: () async {
                        try {
                          await _userService.resendEmailVerification();
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Verification email sent to $email',
                                ),
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            AnimatedDialog.show(
                              context: context,
                              title: 'Resend Failed',
                              child: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          }
                        }
                      },
                      child: const Text('Resend Verification'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please verify your email address before logging in.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your inbox at $email for a verification link.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!showResendButton)
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            showResendButton = true;
                          });
                        },
                        child: const Text('Didn\'t receive the email?'),
                      ),
                    if (showResendButton) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'If you didn\'t receive the verification email, you can request a new one.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email cannot be empty';
    }
    try {
      _userService.isValidEmail(value);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('ArgumentError: ', '');
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password cannot be empty';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo and Title
                    Icon(
                      Icons.sports_esports,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'FLC Chess',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Play chess anywhere, anytime',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Login Form
                    TextFormField(
                      controller: _emailController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 24),

                    // Forgot Password Link
                    if (!_isLoading)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),

                    // Login Button
                    _isLoading
                        ? const CircularProgressIndicator()
                        : MainAppButton(
                          text: 'Login',
                          icon: Icons.login,
                          onPressed: _login,
                          isFullWidth: true,
                        ),
                    const SizedBox(height: 16),

                    // Guest Button
                    if (!_isLoading)
                      MainAppButton(
                        text: 'Play as Guest',
                        icon: Icons.person_outline,
                        onPressed: () async {
                          final userProvider = context.read<UserProvider>();
                          final guestUser =
                              await _userService.signInAnonymously();
                          userProvider.setUser(guestUser);
                          // Navigate to home and replace the current screen
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => HomeScreen(user: guestUser),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        isPrimary: false,
                        isFullWidth: true,
                      ),
                    const SizedBox(height: 24),

                    // Register Link
                    if (!_isLoading)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Don\'t have an account? Register here',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
