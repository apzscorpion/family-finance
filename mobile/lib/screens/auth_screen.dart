import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';
import '../services/live_notes_ws_service.dart';
import '../services/note_import_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  bool _isSignUp = false;
  bool _joinExistingFamily = false;

  // Step 2: 6-digit OTP & Family Verification state
  bool _awaitingOtpStep = false;
  bool _requiresFamilyVerification = false;
  bool _familyOwnerApprovedLive = false;
  String _generatedLoginOtp = '';
  String _activeIdentifier = '';
  String _displayContact = '';
  String _targetFamilyCode = '';
  String _resolvedFullName = '';
  String _resolvedFamilyName = '';
  String? _autoReadStatusMsg;
  FamilyLoginRequest? _pendingJoinRequest;
  LiveNotesWsService? _verificationWs;

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();
  final _familyCodeCtrl = TextEditingController();
  final _loginOtpCtrl = TextEditingController();
  final _familyVerifyOtpCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMsg;
  late String _generatedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generatedCode = FinanceProvider.generateUniqueFamilyCode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _verificationWs?.disconnect();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _familyCtrl.dispose();
    _familyCodeCtrl.dispose();
    _loginOtpCtrl.dispose();
    _familyVerifyOtpCtrl.dispose();
    super.dispose();
  }

  /// Auto-read 6-digit OTP when returning from SMS or Email app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingOtpStep) {
      _tryAutoReadOtpFromClipboard(silentIfEmpty: true);
    }
  }

  /// Reads clipboard for any 6-digit OTP copied from SMS or Email
  Future<void> _tryAutoReadOtpFromClipboard({bool silentIfEmpty = false, bool forFamilyOtp = false}) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text?.trim() ?? '';
      final extracted = SupabaseService.extractOtpFromText(raw);
      if (extracted != null && extracted.length == 6) {
        if (!mounted) return;
        setState(() {
          if (forFamilyOtp) {
            _familyVerifyOtpCtrl.text = extracted;
            _autoReadStatusMsg = 'Auto-read 6-digit Family OTP ($extracted) from SMS/Email clipboard';
          } else if (_loginOtpCtrl.text.trim().isEmpty || !silentIfEmpty) {
            _loginOtpCtrl.text = extracted;
            _autoReadStatusMsg = 'Auto-read 6-digit OTP ($extracted) from SMS/Email clipboard';
          }
          _errorMsg = null;
        });
      } else if (!silentIfEmpty && mounted) {
        setState(() {
          _errorMsg = 'No 6-digit OTP found in clipboard. Copy the SMS/Email message or use Test OTP 111111.';
        });
      }
    } catch (_) {}
  }

  /// Resolves the user's mandatory Phone or Email into a normalized identifier
  ({String? identifier, String display}) _resolvePhoneOrEmail() {
    final rawPhone = _phoneCtrl.text.trim();
    final rawEmail = _emailCtrl.text.trim().toLowerCase();
    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (rawEmail.isEmpty && digitsOnly.isEmpty) {
      return (identifier: null, display: '');
    }

    if (rawEmail.isNotEmpty && digitsOnly.isNotEmpty) {
      return (identifier: rawEmail, display: '$rawPhone · $rawEmail');
    } else if (rawEmail.isNotEmpty) {
      return (identifier: rawEmail, display: rawEmail);
    } else {
      return (identifier: 'phone_$digitsOnly@familyfinance.app', display: rawPhone);
    }
  }

  /// Step 1: Validate Phone or Email (either is mandatory), check disabled status, and send 6-digit Login OTP
  Future<void> _initiateOtpStep(FinanceProvider provider) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
      _autoReadStatusMsg = null;
    });

    final contact = _resolvePhoneOrEmail();
    final pass = _passCtrl.text.trim();

    if (contact.identifier == null) {
      setState(() {
        _loading = false;
        _errorMsg = 'Please enter either your Phone Number or Email Address (at least one is mandatory).';
      });
      return;
    }

    final digitsOnly = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (_emailCtrl.text.trim().isEmpty && digitsOnly.length < 7) {
      setState(() {
        _loading = false;
        _errorMsg = 'Please enter a valid Phone Number (or enter your Email Address).';
      });
      return;
    }

    if (pass.isEmpty) {
      setState(() {
        _loading = false;
        _errorMsg = 'Please enter a password.';
      });
      return;
    }

    final identifier = contact.identifier!;

    try {
      final manualCode = _familyCodeCtrl.text.trim().toUpperCase();
      final defaultName = _emailCtrl.text.trim().isNotEmpty
          ? _emailCtrl.text.trim().split('@')[0]
          : 'User ${digitsOnly.length >= 4 ? digitsOnly.substring(digitsOnly.length - 4) : digitsOnly}';
      final enteredName = _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : defaultName;
      final famName = _familyCtrl.text.trim().isNotEmpty
          ? _familyCtrl.text.trim()
          : '$enteredName\'s Family';

      if (_isSignUp && _joinExistingFamily && manualCode.length < 6) {
        setState(() {
          _loading = false;
          _errorMsg = 'Please enter a valid 6-8 character Family Invite Code.';
        });
        return;
      }

      // Check existing local account if signing in
      final localAcct = await SupabaseService.getLocalAccount(identifier);
      if (!_isSignUp && localAcct != null && localAcct.password != pass) {
        setState(() {
          _loading = false;
          _errorMsg = 'Incorrect password for ${contact.display}.';
        });
        return;
      }

      final resolvedName = (!_isSignUp && localAcct?.fullName.isNotEmpty == true)
          ? localAcct!.fullName
          : enteredName;
      final resolvedFamName = (!_isSignUp && localAcct?.familyName.isNotEmpty == true)
          ? localAcct!.familyName
          : famName;

      String targetCode;
      if (_isSignUp) {
        targetCode = _joinExistingFamily ? manualCode : _generatedCode;
      } else {
        targetCode = manualCode.length >= 6
            ? manualCode
            : (localAcct?.familyCode.isNotEmpty == true ? localAcct!.familyCode : _generatedCode);
      }

      // SECURITY CHECK 1: Is this user disabled by the Family Owner?
      final isDisabled = await SupabaseService.isUserDisabledInFamily(
        email: identifier,
        name: resolvedName,
        familyCode: targetCode,
      );
      if (isDisabled) {
        setState(() {
          _loading = false;
          _errorMsg =
              'Access Denied: Your login access to family workspace ($targetCode) has been disabled by the Family Owner.';
        });
        return;
      }

      // SECURITY CHECK 2: Determine if this login uses an existing Family Code that requires Family Owner Verification
      final isJoiningAnotherFamily = (_isSignUp && _joinExistingFamily) ||
          (!_isSignUp && manualCode.length >= 6 && localAcct?.familyCode != manualCode);
      final alreadyVerified = await SupabaseService.isUserVerifiedInFamily(
        email: identifier,
        familyCode: targetCode,
      );
      final needsFamilyVerification = isJoiningAnotherFamily && !alreadyVerified;

      // Generate 6-digit Login OTP
      final loginOtp = await SupabaseService.generateLoginOtp(identifier);

      FamilyLoginRequest? joinReq;
      if (needsFamilyVerification) {
        joinReq = await SupabaseService.createFamilyJoinRequest(
          name: resolvedName,
          email: contact.display,
          familyCode: targetCode,
        );
        await _connectVerificationWs(joinReq);
      }

      setState(() {
        _activeIdentifier = identifier;
        _displayContact = contact.display;
        _generatedLoginOtp = loginOtp;
        _targetFamilyCode = targetCode;
        _resolvedFullName = resolvedName;
        _resolvedFamilyName = resolvedFamName;
        _requiresFamilyVerification = needsFamilyVerification;
        _familyOwnerApprovedLive = false;
        _pendingJoinRequest = joinReq;
        _loginOtpCtrl.clear();
        _familyVerifyOtpCtrl.clear();
        _awaitingOtpStep = true;
        _loading = false;
      });

      // Automatically check if an SMS/Email OTP is already in the clipboard
      await _tryAutoReadOtpFromClipboard(silentIfEmpty: true);
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _connectVerificationWs(FamilyLoginRequest req) async {
    await _verificationWs?.disconnect();
    _verificationWs = LiveNotesWsService(
      onRemoteNoteUpdated: (_, _) {},
      onRemoteNoteDeleted: (_, _) {},
      onRemoteFullSync: (_, _) {},
      getLocalNotes: () => const [],
      onStateChanged: () {},
      onRemoteFamilyLoginDecision: (requestId, email, approved) async {
        if (!mounted) return;
        if (requestId == req.id ||
            email.toLowerCase() == _activeIdentifier.toLowerCase() ||
            email.toLowerCase() == _displayContact.toLowerCase()) {
          if (approved) {
            await SupabaseService.markUserVerifiedInFamily(
              email: _activeIdentifier,
              name: _resolvedFullName,
              familyCode: _targetFamilyCode,
            );
            setState(() {
              _familyOwnerApprovedLive = true;
              _errorMsg = null;
            });
          } else {
            setState(() {
              _errorMsg = 'The Family Owner rejected and blocked your login request.';
              _awaitingOtpStep = false;
            });
          }
        }
      },
    );
    await _verificationWs!.connect(
      familyCode: req.familyCode,
      userName: req.name,
    );
    _verificationWs!.broadcastFamilyJoinRequest(req);
  }

  /// Step 2: Verify 6-digit Login OTP (or 111111) + Family Verification OTP and complete login
  Future<void> _verifyAndCompleteAuth(FinanceProvider provider) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final identifier = _activeIdentifier;
    final pass = _passCtrl.text.trim();
    final extractedOtp = SupabaseService.extractOtpFromText(_loginOtpCtrl.text) ?? _loginOtpCtrl.text.trim();
    final extractedFamilyOtp =
        SupabaseService.extractOtpFromText(_familyVerifyOtpCtrl.text) ?? _familyVerifyOtpCtrl.text.trim();

    if (extractedOtp.length != 6) {
      setState(() {
        _loading = false;
        _errorMsg = 'Please enter or paste the 6-digit Login OTP (or use test OTP 111111).';
      });
      return;
    }

    try {
      // Re-check disabled status right before completing login
      final isDisabled = await SupabaseService.isUserDisabledInFamily(
        email: identifier,
        name: _resolvedFullName,
        familyCode: _targetFamilyCode,
      );
      if (isDisabled) {
        setState(() {
          _loading = false;
          _awaitingOtpStep = false;
          _errorMsg = 'Login blocked: Your account has been disabled by the Family Owner.';
        });
        return;
      }

      // Verify 6-digit Login OTP (accepts generated OTP or universal test OTP 111111)
      final otpValid = await SupabaseService.verifyLoginOtp(identifier, extractedOtp);
      if (!otpValid) {
        setState(() {
          _loading = false;
          _errorMsg = 'Invalid or expired 6-digit Login OTP. Try 111111 (test OTP) or request a new OTP.';
        });
        return;
      }

      // Verify Family Owner Verification if someone is using/joining an existing Family Code
      if (_requiresFamilyVerification && !_familyOwnerApprovedLive) {
        final alreadyApproved = await SupabaseService.isUserVerifiedInFamily(
          email: identifier,
          familyCode: _targetFamilyCode,
        );
        if (!alreadyApproved) {
          if (extractedFamilyOtp.length != 6) {
            setState(() {
              _loading = false;
              _errorMsg =
                  'Family Verification Required: Enter the Family Owner\'s 6-digit Security OTP (or test OTP 111111), or ask the Owner to tap "Approve".';
            });
            return;
          }
          final famOtpValid = await SupabaseService.verifyFamilyJoinOtp(
            familyCode: _targetFamilyCode,
            email: identifier,
            name: _resolvedFullName,
            enteredOtp: extractedFamilyOtp,
          );
          if (!famOtpValid) {
            setState(() {
              _loading = false;
              _errorMsg =
                  'Invalid Family Owner Security OTP. Check the 6-digit OTP on the Owner\'s Family tab (or use test OTP 111111).';
            });
            return;
          }
        }
      }

      await _verificationWs?.disconnect();

      if (_isSignUp) {
        final localRecord = await SupabaseService.saveLocalAccount(
          email: identifier,
          password: pass,
          fullName: _resolvedFullName,
          familyName: _resolvedFamilyName,
          familyCode: _targetFamilyCode,
          isOwner: !_joinExistingFamily,
        );

        await SupabaseService.signUp(
          email: identifier,
          password: pass,
          fullName: _resolvedFullName,
          familyName: localRecord.familyName,
          familyCode: localRecord.familyCode,
          isOwner: !_joinExistingFamily,
        );

        await provider.setLoggedIn(
          true,
          userName: localRecord.fullName,
          userKey: identifier,
          familyName: localRecord.familyName,
          familyCode: localRecord.familyCode,
          clearWorkspaceOnNewAccount: !_joinExistingFamily,
        );
        if (mounted) {
          provider.showToast('OTP Verified! Welcome to ${provider.familyName} (${provider.familyCode})');
        }
      } else {
        final res = await SupabaseService.signIn(email: identifier, password: pass);
        if (res?.user != null) {
          final meta = res?.user?.userMetadata;
          final userName = (meta?['full_name'] != null && meta!['full_name'].toString().trim().isNotEmpty)
              ? meta['full_name'].toString().trim()
              : _resolvedFullName;
          final savedFamName = meta?['family_name']?.toString().trim() ?? _resolvedFamilyName;
          final cloudFamilyCode = meta?['family_code']?.toString().trim().toUpperCase();
          final resolvedFamilyCode = _familyCodeCtrl.text.trim().length >= 6
              ? _targetFamilyCode
              : ((cloudFamilyCode?.length ?? 0) >= 6 ? cloudFamilyCode! : _targetFamilyCode);

          await SupabaseService.saveLocalAccount(
            email: identifier,
            password: pass,
            fullName: userName,
            familyName: savedFamName,
            familyCode: resolvedFamilyCode,
          );

          await provider.setLoggedIn(
            true,
            userName: userName,
            userKey: identifier,
            familyName: savedFamName,
            familyCode: resolvedFamilyCode,
          );
          if (mounted) {
            provider.showToast('OTP Verified! Welcome back, $userName!');
          }
        } else {
          final saved = await SupabaseService.saveLocalAccount(
            email: identifier,
            password: pass,
            fullName: _resolvedFullName,
            familyName: _resolvedFamilyName,
            familyCode: _targetFamilyCode,
          );

          await provider.setLoggedIn(
            true,
            userName: saved.fullName,
            userKey: identifier,
            familyName: saved.familyName,
            familyCode: saved.familyCode,
          );
          if (mounted) {
            provider.showToast('OTP Verified! Welcome, ${saved.fullName}!');
          }
        }
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendLoginOtp() async {
    if (_activeIdentifier.isEmpty) return;
    final newOtp = await SupabaseService.generateLoginOtp(_activeIdentifier);
    setState(() {
      _generatedLoginOtp = newOtp;
      _errorMsg = null;
    });
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
                'OTP-secured collaborative finances for your household',
                style: TextStyle(fontSize: 13, color: AppTheme.textSubtle),
              ),
              const SizedBox(height: 28),

              // Auth Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF3F424D)),
                  boxShadow: const [AppTheme.shadowMd],
                ),
                child: _awaitingOtpStep
                    ? _buildOtpVerificationStep(provider)
                    : _buildCredentialsStep(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialsStep(FinanceProvider provider) {
    return Column(
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
                  onTap: () => setState(() {
                    _isSignUp = false;
                    _errorMsg = null;
                  }),
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
                  onTap: () => setState(() {
                    _isSignUp = true;
                    _errorMsg = null;
                  }),
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
        const SizedBox(height: 18),

        if (_isSignUp) ...[
          _buildTextField(_nameCtrl, 'Your Full Name (e.g. Asif)', Icons.person_outline),
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
                      child: Text(
                        'Create My Family',
                        style: TextStyle(fontSize: 11.5, color: !_joinExistingFamily ? Colors.white : AppTheme.textMuted),
                      ),
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
                      child: Text(
                        'Join via Code',
                        style: TextStyle(fontSize: 11.5, color: _joinExistingFamily ? Colors.white : AppTheme.textMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (!_joinExistingFamily) ...[
            _buildTextField(_familyCtrl, 'Your Family Name (e.g. Asif\'s Family)', Icons.people_outline),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.key, size: 14, color: AppTheme.accent300),
                  const SizedBox(width: 8),
                  const Text('Your Unique Family Code: ', style: TextStyle(fontSize: 11.5, color: AppTheme.textSubtle)),
                  Text(
                    _generatedCode,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.accent100, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildTextField(_familyCodeCtrl, 'Enter 6-8 digit Family Code', Icons.vpn_key_outlined, keyboardType: TextInputType.text),
          ],
          const SizedBox(height: 12),
        ],

        // Mandatory Contact Notice: Either Phone OR Email is required
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Phone or Email',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent900,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Either Phone or Email is mandatory',
                style: TextStyle(fontSize: 10, color: AppTheme.accent200, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildTextField(
          _phoneCtrl,
          'Phone Number (e.g. +91 9876543210)',
          Icons.phone_iphone_outlined,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Divider(color: AppTheme.textSubtle.withOpacity(0.25), height: 1)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('OR / AND', style: TextStyle(fontSize: 10, color: AppTheme.textSubtle, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Divider(color: AppTheme.textSubtle.withOpacity(0.25), height: 1)),
          ],
        ),
        const SizedBox(height: 8),
        _buildTextField(
          _emailCtrl,
          'Email Address (e.g. name@email.com)',
          Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _passCtrl,
          'Password',
          Icons.lock_outline,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
        ),

        if (!_isSignUp) ...[
          const SizedBox(height: 12),
          _buildTextField(_familyCodeCtrl, 'Family Code (Optional · requires Owner OTP)', Icons.vpn_key_outlined, keyboardType: TextInputType.text),
        ],

        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.redBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.red.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.gpp_bad_outlined, size: 16, color: AppTheme.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Continue to 6-Digit OTP Verification Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : () => _initiateOtpStep(provider),
            icon: _loading
                ? const SizedBox.shrink()
                : const Icon(Icons.verified_user_outlined, size: 18),
            label: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                : Text(
                    _isSignUp
                        ? (_joinExistingFamily ? 'Send OTP & Request Family Access' : 'Send 6-Digit Login OTP')
                        : 'Send 6-Digit Login OTP',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpVerificationStep(FinanceProvider provider) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  _verificationWs?.disconnect();
                  setState(() {
                    _awaitingOtpStep = false;
                    _errorMsg = null;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Verify OTP (SMS / Email / Paste)',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.greenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'AUTO-READ ON',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Instant OTP + Universal Test OTP 111111 Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppTheme.balanceGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sms_outlined, size: 15, color: AppTheme.accent200),
                        SizedBox(width: 6),
                        Text(
                          'SMS / EMAIL OTP & TEST OTP',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accent200, letterSpacing: 0.6),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _resendLoginOtp,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(fontSize: 11, color: AppTheme.accent100, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _generatedLoginOtp,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _loginOtpCtrl.text = SupabaseService.testUniversalOtp;
                              if (_requiresFamilyVerification) {
                                _familyVerifyOtpCtrl.text = SupabaseService.testUniversalOtp;
                              }
                              _autoReadStatusMsg = 'Filled Universal Test OTP (111111)';
                              _errorMsg = null;
                            });
                          },
                          icon: const Icon(Icons.bolt, size: 13, color: AppTheme.green),
                          label: const Text('Use 111111', style: TextStyle(fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.green),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _loginOtpCtrl.text = _generatedLoginOtp;
                              _errorMsg = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.accent),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('Autofill', style: TextStyle(fontSize: 11, color: AppTheme.accent100)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sent to $_displayContact · Test OTP 111111 enabled for all accounts',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '1. Enter or Paste 6-Digit Login OTP',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
              InkWell(
                onTap: () => _tryAutoReadOtpFromClipboard(silentIfEmpty: false, forFamilyOtp: false),
                child: const Row(
                  children: [
                    Icon(Icons.content_paste_go, size: 13, color: AppTheme.accent200),
                    SizedBox(width: 4),
                    Text(
                      'Paste from SMS / Email',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.accent200, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildOtpField(
            controller: _loginOtpCtrl,
            hint: 'Enter 6-digit OTP (or 111111) or paste SMS/Email',
            onPastePressed: () => _tryAutoReadOtpFromClipboard(silentIfEmpty: false, forFamilyOtp: false),
          ),

          if (_autoReadStatusMsg != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: AppTheme.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _autoReadStatusMsg!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.green),
                  ),
                ),
              ],
            ),
          ],

          // Family Owner Verification when joining/using a Family Code
          if (_requiresFamilyVerification) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _familyOwnerApprovedLive ? AppTheme.greenBg : AppTheme.amberBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_familyOwnerApprovedLive ? AppTheme.green : AppTheme.amber).withOpacity(0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _familyOwnerApprovedLive ? Icons.verified : Icons.admin_panel_settings_outlined,
                        size: 18,
                        color: _familyOwnerApprovedLive ? AppTheme.green : AppTheme.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _familyOwnerApprovedLive
                              ? 'Family Owner Approved Your Login!'
                              : 'Family Login Verification ($_targetFamilyCode)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _familyOwnerApprovedLive ? AppTheme.green : AppTheme.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _familyOwnerApprovedLive
                        ? 'The Family Owner verified your access in real time. Tap Verify & Sign In below.'
                        : 'Because you are using Family Code $_targetFamilyCode, enter the 6-digit Family Security OTP from the Owner (or use test OTP 111111).',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.text, height: 1.35),
                  ),
                  if (!_familyOwnerApprovedLive && _pendingJoinRequest != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Owner OTP: ${_pendingJoinRequest!.verificationOtp} (or 111111)',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.amber),
                        ),
                        InkWell(
                          onTap: () {
                            NoteImportService.shareExternally(
                              text: 'Please approve my Family Spend Tracker login for code $_targetFamilyCode or share the Family Security OTP.',
                              title: 'Family Login Verification',
                            );
                          },
                          child: const Text(
                            'Ask Owner',
                            style: TextStyle(fontSize: 11, color: AppTheme.accent200, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!_familyOwnerApprovedLive) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '2. Family Owner\'s 6-Digit Security OTP',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                  ),
                  InkWell(
                    onTap: () => _tryAutoReadOtpFromClipboard(silentIfEmpty: false, forFamilyOtp: true),
                    child: const Text(
                      'Paste OTP',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.accent200, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildOtpField(
                controller: _familyVerifyOtpCtrl,
                hint: 'Owner\'s 6-digit Security OTP (or 111111)',
                onPastePressed: () => _tryAutoReadOtpFromClipboard(silentIfEmpty: false, forFamilyOtp: true),
              ),
            ],
          ],

          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.redBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.red.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : () => _verifyAndCompleteAuth(provider),
              icon: _loading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.lock_open_rounded, size: 18),
              label: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                  : const Text(
                      'Verify OTP & Sign In',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dedicated OTP input that supports SMS/Email autofill (`AutofillHints.oneTimeCode`),
  /// full-message copy-paste extraction, and a 1-tap Paste button.
  Widget _buildOtpField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onPastePressed,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pin_outlined, size: 18, color: AppTheme.accent200),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.oneTimeCode],
              enableInteractiveSelection: true,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
                letterSpacing: 2.0,
              ),
              onChanged: (val) {
                // If user pastes a full SMS/Email message containing a 6-digit code, auto-extract the 6 digits
                if (val.length > 6) {
                  final extracted = SupabaseService.extractOtpFromText(val);
                  if (extracted != null) {
                    controller.value = TextEditingValue(
                      text: extracted,
                      selection: TextSelection.collapsed(offset: extracted.length),
                    );
                    setState(() {
                      _autoReadStatusMsg = 'Extracted 6-digit OTP ($extracted) from pasted message';
                      _errorMsg = null;
                    });
                  }
                }
              },
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textSubtle,
                  letterSpacing: 0,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: onPastePressed,
            icon: const Icon(Icons.content_paste_rounded, size: 17, color: AppTheme.accent200),
            tooltip: 'Paste OTP from SMS / Email',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscureText = false,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
  }) {
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
              autofillHints: autofillHints,
              enableInteractiveSelection: true,
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
