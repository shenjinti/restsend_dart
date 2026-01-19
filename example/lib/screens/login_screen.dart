import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _endpointController = TextEditingController(text: 'https://chat.ruzhila.cn');
  bool _isLoading = false;
  bool _isGuestMode = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<ChatProvider>();
    
    try {
      await provider.init(_endpointController.text);

      if (_isGuestMode) {
        await provider.guestLogin(_usernameController.text);
      } else {
        await provider.login(_usernameController.text, _passwordController.text);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/conversations');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  'Restsend Demo',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Endpoint field
                TextFormField(
                  controller: _endpointController,
                  decoration: const InputDecoration(
                    labelText: 'Server Endpoint',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cloud),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter server endpoint';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mode switch
                SwitchListTile(
                  title: const Text('Guest Mode'),
                  subtitle: Text(_isGuestMode ? 'Login as guest' : 'Login with password'),
                  value: _isGuestMode,
                  onChanged: (value) {
                    setState(() => _isGuestMode = value);
                  },
                ),
                const SizedBox(height: 16),

                // Username field
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: _isGuestMode ? 'Guest ID' : 'Username',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter ${_isGuestMode ? "guest ID" : "username"}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field (only for non-guest mode)
                if (!_isGuestMode)
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (!_isGuestMode && (value == null || value.isEmpty)) {
                        return 'Please enter password';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 24),

                // Login button
                FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
