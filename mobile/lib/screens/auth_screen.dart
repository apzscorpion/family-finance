import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  bool _joinExistingFamily = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();
  final _familyCodeCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMsg;
  late String _generatedCode;

  @override
  void initState() {
    super.initState();
    _generatedCode = FinanceProvider.generateUniqueFamilyCode();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _familyCtrl.dispose();
    _familyCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAuth(FinanceProvider provider) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() {
        _loading = false;
        _errorMsg = 'Please enter email and password.';
      });
      return;
    }

    try {
      final codeToUse = _joinExistingFamily
          ? _familyCodeCtrl.text.trim().toUpperCase()
          : _generatedCode;

      if (_isSignUp && _joinExistingFamily && codeToUse.length < 6) {
        setState(() {
          _loading = false;
          _errorMsg = 'Please enter a valid 6-8 character Family Invite Code.';
        });
        return;
      }

      final famName = _familyCtrl.text.trim().isEmpty ? 'Family Workspace' : _familyCtrl.text.trim();

      if (!SupabaseService.isConfigured) {
        // Fallback for demo mode before Supabase credentials are inserted
        await Future.delayed(const Duration(milliseconds: 600));
        provider.setFamilyDetails(name: famName, code: codeToUse);
        provider.setLoggedIn(true, userName: _nameCtrl.text.isNotEmpty ? _nameCtrl.text.trim() : 'User');
        if (mounted) {
          provider.showToast(_joinExistingFamily ? 'Joined Family ($codeToUse)!' : 'Created Family (Code: $codeToUse)!');
        }
        return;
      }

      if (_isSignUp) {
        final name = _nameCtrl.text.trim().isEmpty ? 'User' : _nameCtrl.text.trim();

        final res = await SupabaseService.signUp(
          email: email,
          password: pass,
          fullName: name,
          familyName: famName,
        );

        if (res?.user != null) {
          provider.setFamilyDetails(name: famName, code: codeToUse);
          provider.setLoggedIn(true, userName: name);
          if (mounted) provider.showToast('Account created! Family Code: $codeToUse');
        } else {
          setState(() => _errorMsg = 'Signup failed. Please try again.');
        }
      } else {
        final res = await SupabaseService.signIn(email: email, password: pass);
        if (res?.user != null) {
          final userName = res?.user?.userMetadata?['full_name'] ?? 'Member';
          provider.setLoggedIn(true, userName: userName);
          if (mounted) provider.showToast('Logged in successfully!');
        } else {
          setState(() => _errorMsg = 'Invalid email or password.');
        }
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nocturne App Icon Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [AppTheme.accent500, AppTheme.accent800],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.account_balance_wallet_outlined, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'Family Spend Tracker',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              const Text(
                'Collaborative finances for your household',
                style: TextStyle(fontSize: 13, color: AppTheme.textSubtle),
              ),
              const SizedBox(height: 32),

              // Auth Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF3F424D)),
                  boxShadow: const [AppTheme.shadowMd],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle Sign In vs Create Account
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSignUp = false),
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: !_isSignUp ? AppTheme.accent900 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: !_isSignUp ? AppTheme.accent : Colors.transparent),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: !_isSignUp ? AppTheme.accent100 : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSignUp = true),
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _isSignUp ? AppTheme.accent900 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: _isSignUp ? AppTheme.accent : Colors.transparent),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _isSignUp ? AppTheme.accent100 : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_isSignUp) ...[
                      _buildTextField(_nameCtrl, 'Your Full Name', Icons.person_outline),
                      const SizedBox(height: 12),
                      
                      // Choice: Create new family vs Join via code
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _joinExistingFamily = false),
                                child: Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: !_joinExistingFamily ? AppTheme.accent800 : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('New Family', style: TextStyle(fontSize: 11.5, color: !_joinExistingFamily ? Colors.white : AppTheme.textMuted)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _joinExistingFamily = true),
                                child: Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _joinExistingFamily ? AppTheme.accent800 : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('Join via Code', style: TextStyle(fontSize: 11.5, color: _joinExistingFamily ? Colors.white : AppTheme.textMuted)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (!_joinExistingFamily) ...[
                        _buildTextField(_familyCtrl, 'Family Name (e.g. Khan Household)', Icons.people_outline),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.key, size: 14, color: AppTheme.accent300),
                              const SizedBox(width: 8),
                              Text('Generated Family Code: ', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSubtle)),
                              Text(_generatedCode, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.accent100, letterSpacing: 1.2)),
                            ],
                          ),
                        ),
                      ] else ...[
                        _buildTextField(_familyCodeCtrl, 'Enter 8-digit Family Code (e.g. K9L2M4X7)', Icons.vibration, keyboardType: TextInputType.text),
                      ],
                      const SizedBox(height: 12),
                    ],

                    _buildTextField(_emailCtrl, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildTextField(_passCtrl, 'Password', Icons.lock_outline, obscureText: true),

                    if (_errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                    ],

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : () => _handleAuth(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.bg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                            : Text(_isSignUp ? (_joinExistingFamily ? 'Join Family Household' : 'Create Family Account') : 'Sign In to Workspace', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Demo mode pill indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      SupabaseService.isConfigured ? Icons.cloud_done : Icons.offline_bolt_outlined,
                      size: 14,
                      color: SupabaseService.isConfigured ? AppTheme.green : AppTheme.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      SupabaseService.isConfigured ? 'Connected to Supabase Cloud' : 'Cloud Setup Ready · Instant Demo Mode',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool obscureText = false, TextInputType? keyboardType}) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3F424D)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSubtle),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 14, color: AppTheme.text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSubtle),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
