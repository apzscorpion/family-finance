import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance_models.dart';
import '../services/live_notes_ws_service.dart';
import '../services/supabase_service.dart';

class FinanceProvider extends ChangeNotifier {
  // Category Definitions Dictionary
  static final Map<String, CategoryDef> categories = {
    'groceries': const CategoryDef(key: 'groceries', name: 'Groceries', icon: Icons.shopping_basket, color: Color(0xFF4ADE80)),
    'dining': const CategoryDef(key: 'dining', name: 'Dining', icon: Icons.restaurant, color: Color(0xFFF97316)),
    'transport': const CategoryDef(key: 'transport', name: 'Transport', icon: Icons.directions_car, color: Color(0xFFA855F7)),
    'fuel': const CategoryDef(key: 'fuel', name: 'Fuel', icon: Icons.local_gas_station, color: Color(0xFFEAB308)),
    'shopping': const CategoryDef(key: 'shopping', name: 'Shopping', icon: Icons.shopping_bag, color: Color(0xFFEC4899)),
    'bills': const CategoryDef(key: 'bills', name: 'Bills', icon: Icons.bolt, color: Color(0xFF3B82F6)),
    'health': const CategoryDef(key: 'health', name: 'Health', icon: Icons.medical_services, color: Color(0xFFEF4444)),
    'education': const CategoryDef(key: 'education', name: 'Education', icon: Icons.school, color: Color(0xFF06B6D4)),
    'event': const CategoryDef(
      key: 'event',
      name: 'Event & Wedding',
      icon: Icons.celebration,
      color: Color(0xFFF43F5E),
      subCategories: [
        SubCategoryDef(key: 'venue_booking', parentKey: 'event', name: 'Venue Booking'),
        SubCategoryDef(key: 'makeup', parentKey: 'event', name: 'Makeup & Beauty'),
        SubCategoryDef(key: 'hair_setting', parentKey: 'event', name: 'Hair Setting'),
        SubCategoryDef(key: 'clothing', parentKey: 'event', name: 'Clothing & Outfits'),
        SubCategoryDef(key: 'cash_withdrawal', parentKey: 'event', name: 'Cash Withdrawal (In Hand)'),
      ],
    ),
    'loan': const CategoryDef(key: 'loan', name: 'Loan & Credit Pool', icon: Icons.account_balance_wallet, color: Color(0xFF8B5CF6), isIncome: true),
    'salary': const CategoryDef(key: 'salary', name: 'Salary', icon: Icons.work, color: Color(0xFF34D399), isIncome: true),
    'business': const CategoryDef(key: 'business', name: 'Business', icon: Icons.store, color: Color(0xFF34D399), isIncome: true),
    'gift': const CategoryDef(key: 'gift', name: 'Gift', icon: Icons.card_giftcard, color: Color(0xFF34D399), isIncome: true),
    'pension': const CategoryDef(key: 'pension', name: 'Pension', icon: Icons.account_balance, color: Color(0xFF34D399), isIncome: true),
    'refund': const CategoryDef(key: 'refund', name: 'Refund', icon: Icons.replay, color: Color(0xFF34D399), isIncome: true),
  };

  static const List<Color> _memberPalette = [
    Color(0xFF9184D9),
    Color(0xFFEC4899),
    Color(0xFF3B82F6),
    Color(0xFFEAB308),
    Color(0xFF34D399),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
  ];

  // Budgets Definitions
  static final List<BudgetDef> budgets = [
    const BudgetDef(catKey: 'groceries', familyLimit: 12000, personalLimit: 5000),
    const BudgetDef(catKey: 'dining', familyLimit: 4000, personalLimit: 2000),
    const BudgetDef(catKey: 'shopping', familyLimit: 6000, personalLimit: 3000),
    const BudgetDef(catKey: 'fuel', familyLimit: 4000, personalLimit: 2500),
  ];

  // Auth & Real User State
  bool _isLoggedIn = false;
  String _currentUserName = '';
  String _userKey = 'default';
  String _familyCode = '';
  String _familyName = '';
  String _familyVerificationOtp = '';
  final List<FamilyLoginRequest> _familyLoginRequests = [];
  late final LiveNotesWsService _notesWs;

  // Real Family Members (Starts with ONLY the logged-in user, 0 opening balance)
  final List<FamilyMemberDef> _members = [];

  List<FamilyMemberDef> get members => _members.isNotEmpty
      ? _members
      : [
          FamilyMemberDef(
            id: 'me',
            name: _currentUserName.isNotEmpty ? _currentUserName : 'Me',
            rel: 'You',
            role: 'Owner',
            openingBalance: 0,
            color: const Color(0xFF9184D9),
            email: _userKey.contains('@') ? _userKey : '',
            isDisabled: false,
            isVerified: true,
          ),
        ];

  String get familyCode => _familyCode.isNotEmpty ? _familyCode : '--------';
  String get familyVerificationOtp =>
      _familyVerificationOtp.isNotEmpty ? _familyVerificationOtp : '------';
  List<FamilyLoginRequest> get familyLoginRequests =>
      List.unmodifiable(_familyLoginRequests);
  List<FamilyLoginRequest> get pendingFamilyLoginRequests =>
      _familyLoginRequests.where((r) => r.status == 'pending').toList();

  String get familyName => _familyName.isNotEmpty
      ? _familyName
      : (_currentUserName.isNotEmpty ? '$_currentUserName\'s Family' : 'My Family');

  String get currentUserInitial =>
      _currentUserName.isNotEmpty ? _currentUserName[0].toUpperCase() : 'U';

  bool get isNotesWsConnected => _notesWs.isConnected;
  List<String> get onlineNotePeers => _notesWs.onlinePeers;
  Map<String, String> get activeNoteEditors => _notesWs.activeEditorsByNote;
  String? activeEditorForNote(String noteId) => _notesWs.activeEditorForNote(noteId);

  FinanceProvider() {
    _notesWs = LiveNotesWsService(
      onRemoteNoteUpdated: _handleRemoteNoteUpdated,
      onRemoteNoteDeleted: _handleRemoteNoteDeleted,
      onRemoteFullSync: _handleRemoteFullSync,
      onRemoteFamilyLoginRequest: _handleRemoteFamilyLoginRequest,
      onRemoteMemberDisabledChanged: _handleRemoteMemberDisabledChanged,
      getLocalNotes: () => _notes,
      onStateChanged: () => notifyListeners(),
    );
    _checkInitialAuth();
  }

  static const List<String> walletAccounts = [
    'All',
    'Cash',
    'Salary',
    'Loan',
    'UPI',
    'Bank',
    'Card',
  ];

  String _selectedAccount = 'All';
  final Map<String, double> _accountOpeningBalances = {
    'Cash': 0.0,
    'Salary': 0.0,
    'Loan': 0.0,
    'UPI': 0.0,
    'Bank': 0.0,
    'Card': 0.0,
  };

  String get selectedAccount => _selectedAccount;
  Map<String, double> get accountOpeningBalances => Map.unmodifiable(_accountOpeningBalances);

  void setSelectedAccount(String account) {
    _selectedAccount = account;
    notifyListeners();
  }

  Future<void> setAccountOpeningBalance(String account, double amount) async {
    _accountOpeningBalances[account] = amount;
    await _saveUserWorkspace();
    notifyListeners();
    showToast('$account balance updated to ₹${amount.round()}');
  }

  Future<void> _checkInitialAuth() async {
    if (SupabaseService.isConfigured && SupabaseService.currentUser != null) {
      final user = SupabaseService.currentUser!;
      _isLoggedIn = true;
      _userKey = (user.email ?? user.id).toLowerCase();
      final meta = user.userMetadata;

      if (meta != null && meta['full_name'] != null && meta['full_name'].toString().trim().isNotEmpty) {
        _currentUserName = meta['full_name'].toString().trim();
      } else if (user.email != null && user.email!.isNotEmpty) {
        final prefix = user.email!.split('@')[0];
        _currentUserName = prefix[0].toUpperCase() + prefix.substring(1);
      } else {
        _currentUserName = 'User';
      }

      if (meta != null && meta['family_code'] != null && meta['family_code'].toString().trim().isNotEmpty) {
        _familyCode = meta['family_code'].toString().trim().toUpperCase();
      }
      if (meta != null && meta['family_name'] != null && meta['family_name'].toString().trim().isNotEmpty) {
        final fn = meta['family_name'].toString().trim();
        if (fn != 'Khan Family') {
          _familyName = fn;
        }
      }

      await _loadUserWorkspace();
    } else {
      final localSession = await SupabaseService.getActiveLocalSession();
      if (localSession != null && localSession.email.isNotEmpty) {
        _isLoggedIn = true;
        _userKey = localSession.email.toLowerCase();
        _currentUserName = localSession.fullName;
        _familyName = localSession.familyName;
        _familyCode = localSession.familyCode;
        await _loadUserWorkspace();
      } else {
        _isLoggedIn = false;
      }
    }
  }

  Future<void> _loadUserWorkspace() async {
    final prefs = await SharedPreferences.getInstance();

    final savedFamName = prefs.getString('ff_${_userKey}_family_name');
    final savedFamCode = prefs.getString('ff_${_userKey}_family_code');

    if ((savedFamName != null && savedFamName.isNotEmpty) && _familyName.isEmpty) {
      _familyName = savedFamName;
    }
    if (_familyName.isEmpty || _familyName == 'Khan Family') {
      _familyName = '$_currentUserName\'s Family';
    }

    if (savedFamCode != null && savedFamCode.isNotEmpty && _familyCode.isEmpty) {
      _familyCode = savedFamCode;
    }
    if (_familyCode.isEmpty) {
      _familyCode = generateUniqueFamilyCode();
      await prefs.setString('ff_${_userKey}_family_code', _familyCode);
      await SupabaseService.updateMetadata(
        fullName: _currentUserName,
        familyName: _familyName,
        familyCode: _familyCode,
      );
    }

    // Load per-account opening balances (Cash, Salary, Loan, UPI, Bank, Card)
    final acctBalJson = prefs.getString('ff_${_userKey}_account_balances');
    _accountOpeningBalances.updateAll((_, __) => 0.0);
    if (acctBalJson != null && acctBalJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(json.decode(acctBalJson));
        decoded.forEach((k, v) {
          _accountOpeningBalances[k] = (v as num?)?.toDouble() ?? 0.0;
        });
      } catch (_) {}
    }

    // Load real members created by this user
    final membersJson = prefs.getString('ff_${_userKey}_members');
    _members.clear();
    if (membersJson != null && membersJson.isNotEmpty) {
      try {
        final List decoded = json.decode(membersJson);
        for (var item in decoded) {
          _members.add(FamilyMemberDef.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (_) {}
    }

    // Ensure the logged-in user is always the first member with their real name
    if (_members.isEmpty) {
      _members.add(
        FamilyMemberDef(
          id: 'me',
          name: _currentUserName.isNotEmpty ? _currentUserName : 'Me',
          rel: 'You',
          role: 'Owner',
          openingBalance: 0,
          color: const Color(0xFF9184D9),
          email: _userKey.contains('@') ? _userKey : '',
          isDisabled: false,
          isVerified: true,
        ),
      );
    } else {
      _members[0] = _members[0].copyWith(
        name: _currentUserName.isNotEmpty ? _currentUserName : _members[0].name,
        rel: 'You',
        role: 'Owner',
        email: _userKey.contains('@') ? _userKey : _members[0].email,
        isDisabled: false,
        isVerified: true,
      );
    }

    // Check if this user has been disabled by the Family Owner for this family code
    if (_familyCode.isNotEmpty) {
      final disabled = await SupabaseService.isUserDisabledInFamily(
        email: _userKey,
        name: _currentUserName,
        familyCode: _familyCode,
      );
      if (disabled) {
        await logout();
        showToast('Your login access to $_familyCode has been disabled by the Family Owner.');
        return;
      }
      _familyVerificationOtp = await SupabaseService.getFamilyVerificationOtp(_familyCode);
      final reqs = await SupabaseService.getFamilyLoginRequests(_familyCode);
      _familyLoginRequests
        ..clear()
        ..addAll(reqs);
    }

    // Load real transactions created by this user
    final txnsJson = prefs.getString('ff_${_userKey}_transactions');
    _transactions.clear();
    if (txnsJson != null && txnsJson.isNotEmpty) {
      try {
        final List decoded = json.decode(txnsJson);
        for (var item in decoded) {
          _transactions.add(TransactionDef.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (_) {}
    }

    // Load real credit/debit cards created by this user
    final cardsJson = prefs.getString('ff_${_userKey}_cards');
    _cards.clear();
    if (cardsJson != null && cardsJson.isNotEmpty) {
      try {
        final List decoded = json.decode(cardsJson);
        for (var item in decoded) {
          _cards.add(CreditCardDef.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (_) {}
    }

    // Load recurring automatic credit card charges
    final autoChargesJson = prefs.getString('ff_${_userKey}_auto_charges');
    _autoCharges.clear();
    if (autoChargesJson != null && autoChargesJson.isNotEmpty) {
      try {
        final List decoded = json.decode(autoChargesJson);
        for (var item in decoded) {
          _autoCharges.add(AutoCardCharge.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (_) {}
    }

    // Load real shared notes (scoped to family room code first, fallback to user key)
    final roomNotesJson = prefs.getString('ff_family_${_familyCode}_notes');
    final userNotesJson = prefs.getString('ff_${_userKey}_notes');
    final notesJson = (roomNotesJson != null && roomNotesJson.isNotEmpty) ? roomNotesJson : userNotesJson;
    _notes.clear();
    if (notesJson != null && notesJson.isNotEmpty) {
      try {
        final List decoded = json.decode(notesJson);
        for (var item in decoded) {
          _notes.add(SharedNote.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (_) {}
    }

    // Automatically apply any due monthly auto-charges on cards
    await _checkAndApplyDueAutoCharges(silent: true);

    // Connect to live WebSocket channel for this family's shared notes
    await _notesWs.connect(
      familyCode: _familyCode,
      userName: _currentUserName.isNotEmpty ? _currentUserName : 'Member',
    );

    notifyListeners();
  }

  Future<void> _saveUserWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ff_${_userKey}_family_name', _familyName);
    await prefs.setString('ff_${_userKey}_family_code', _familyCode);
    await prefs.setString('ff_${_userKey}_account_balances', json.encode(_accountOpeningBalances));
    await prefs.setString(
      'ff_${_userKey}_members',
      json.encode(_members.map((m) => m.toJson()).toList()),
    );
    await prefs.setString(
      'ff_${_userKey}_transactions',
      json.encode(_transactions.map((t) => t.toJson()).toList()),
    );
    await prefs.setString(
      'ff_${_userKey}_cards',
      json.encode(_cards.map((c) => c.toJson()).toList()),
    );
    await prefs.setString(
      'ff_${_userKey}_auto_charges',
      json.encode(_autoCharges.map((a) => a.toJson()).toList()),
    );
    final encodedNotes = json.encode(_notes.map((n) => n.toJson()).toList());
    await prefs.setString('ff_${_userKey}_notes', encodedNotes);
    if (_familyCode.isNotEmpty) {
      await prefs.setString('ff_family_${_familyCode}_notes', encodedNotes);
    }
  }

  static String generateUniqueFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      buffer.write(chars[rnd.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  Future<void> setFamilyDetails({required String name, required String code}) async {
    if (name.trim().isNotEmpty) {
      _familyName = name.trim();
    }
    if (code.trim().isNotEmpty) {
      _familyCode = code.trim().toUpperCase();
    }
    _familyVerificationOtp = await SupabaseService.getFamilyVerificationOtp(_familyCode);
    await _saveUserWorkspace();
    await SupabaseService.updateMetadata(
      familyName: _familyName,
      familyCode: _familyCode,
    );
    await _notesWs.connect(
      familyCode: _familyCode,
      userName: _currentUserName.isNotEmpty ? _currentUserName : 'Member',
    );
    notifyListeners();
  }

  Future<void> joinFamilyWithCode(String code, {String? familyName}) async {
    if (code.trim().length >= 6) {
      final cleanCode = code.trim().toUpperCase();
      final disabled = await SupabaseService.isUserDisabledInFamily(
        email: _userKey,
        name: _currentUserName,
        familyCode: cleanCode,
      );
      if (disabled) {
        showToast('Access Denied: Your login is disabled in family $cleanCode');
        return;
      }
      _familyCode = cleanCode;
      if (familyName != null && familyName.trim().isNotEmpty) {
        _familyName = familyName.trim();
      }
      _familyVerificationOtp = await SupabaseService.getFamilyVerificationOtp(_familyCode);
      await _saveUserWorkspace();
      await SupabaseService.updateMetadata(
        familyName: _familyName,
        familyCode: _familyCode,
      );
      await _notesWs.connect(
        familyCode: _familyCode,
        userName: _currentUserName.isNotEmpty ? _currentUserName : 'Member',
      );
      notifyListeners();
      showToast('Joined Family Workspace ($_familyCode)');
    }
  }

  Future<void> rotateFamilyVerificationOtp() async {
    if (_familyCode.isEmpty) return;
    _familyVerificationOtp = await SupabaseService.regenerateFamilyVerificationOtp(_familyCode);
    notifyListeners();
    showToast('New Family Verification OTP: $_familyVerificationOtp');
  }

  Future<void> addFamilyMember({
    required String name,
    required String rel,
    String role = 'Member',
    String email = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final cleanEmail = email.trim().toLowerCase();
    final id = '${cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    final color = _memberPalette[_members.length % _memberPalette.length];
    final otp = SupabaseService.generateSixDigitCode();
    _members.add(
      FamilyMemberDef(
        id: id,
        name: cleanName,
        rel: rel.trim().isNotEmpty ? rel.trim() : 'Family',
        role: role,
        openingBalance: 0,
        color: color,
        email: cleanEmail,
        isDisabled: false,
        isVerified: true,
        memberOtp: otp,
      ),
    );
    if (_familyCode.isNotEmpty) {
      await SupabaseService.markUserVerifiedInFamily(
        email: cleanEmail.isNotEmpty ? cleanEmail : cleanName,
        name: cleanName,
        familyCode: _familyCode,
      );
      await SupabaseService.setUserDisabledInFamily(
        email: cleanEmail,
        name: cleanName,
        familyCode: _familyCode,
        disabled: false,
      );
    }
    await _saveUserWorkspace();
    notifyListeners();
    showToast('$cleanName added · Login OTP: $otp');
  }

  Future<void> toggleMemberDisabled(String memberId) async {
    if (memberId == 'me') return;
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx < 0) return;
    final member = _members[idx];
    final nextDisabled = !member.isDisabled;
    _members[idx] = member.copyWith(isDisabled: nextDisabled);

    if (_familyCode.isNotEmpty) {
      await SupabaseService.setUserDisabledInFamily(
        email: member.email,
        name: member.name,
        familyCode: _familyCode,
        disabled: nextDisabled,
      );
    }
    _notesWs.broadcastMemberDisabledChanged(
      email: member.email,
      name: member.name,
      disabled: nextDisabled,
    );
    await _saveUserWorkspace();
    notifyListeners();
    showToast(
      nextDisabled
          ? '${member.name}\'s family login has been DISABLED'
          : '${member.name}\'s family login has been ENABLED',
    );
  }

  Future<void> regenerateMemberOtp(String memberId) async {
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx < 0) return;
    final newOtp = SupabaseService.generateSixDigitCode();
    _members[idx] = _members[idx].copyWith(memberOtp: newOtp);
    await _saveUserWorkspace();
    notifyListeners();
    showToast('New Login OTP for ${_members[idx].name}: $newOtp');
  }

  Future<void> approveFamilyLoginRequest(FamilyLoginRequest req) async {
    final idx = _familyLoginRequests.indexWhere((r) => r.id == req.id);
    if (idx >= 0) {
      _familyLoginRequests[idx] = req.copyWith(status: 'approved');
    }
    await SupabaseService.saveFamilyLoginRequests(_familyCode, _familyLoginRequests);
    await SupabaseService.markUserVerifiedInFamily(
      email: req.email,
      name: req.name,
      familyCode: _familyCode,
    );
    await SupabaseService.setUserDisabledInFamily(
      email: req.email,
      name: req.name,
      familyCode: _familyCode,
      disabled: false,
    );

    // Ensure they appear in the family member list as verified & active
    final existingIdx = _members.indexWhere(
      (m) =>
          (req.email.isNotEmpty && m.email.toLowerCase() == req.email.toLowerCase()) ||
          m.name.toLowerCase() == req.name.toLowerCase(),
    );
    if (existingIdx >= 0) {
      _members[existingIdx] = _members[existingIdx].copyWith(
        isDisabled: false,
        isVerified: true,
        email: req.email.isNotEmpty ? req.email : _members[existingIdx].email,
      );
    } else {
      final color = _memberPalette[_members.length % _memberPalette.length];
      _members.add(
        FamilyMemberDef(
          id: '${req.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}',
          name: req.name,
          rel: 'Family',
          role: 'Member',
          openingBalance: 0,
          color: color,
          email: req.email,
          isDisabled: false,
          isVerified: true,
          memberOtp: req.verificationOtp,
        ),
      );
    }

    _notesWs.broadcastFamilyJoinDecision(
      requestId: req.id,
      email: req.email,
      approved: true,
    );
    await _saveUserWorkspace();
    notifyListeners();
    showToast('Verified & approved ${req.name} for family login');
  }

  Future<void> rejectAndBlockFamilyLoginRequest(FamilyLoginRequest req) async {
    final idx = _familyLoginRequests.indexWhere((r) => r.id == req.id);
    if (idx >= 0) {
      _familyLoginRequests[idx] = req.copyWith(status: 'rejected');
    }
    await SupabaseService.saveFamilyLoginRequests(_familyCode, _familyLoginRequests);
    await SupabaseService.setUserDisabledInFamily(
      email: req.email,
      name: req.name,
      familyCode: _familyCode,
      disabled: true,
    );
    _notesWs.broadcastFamilyJoinDecision(
      requestId: req.id,
      email: req.email,
      approved: false,
    );
    _notesWs.broadcastMemberDisabledChanged(
      email: req.email,
      name: req.name,
      disabled: true,
    );
    notifyListeners();
    showToast('Blocked ${req.name} from using your family login');
  }

  Future<void> removeFamilyMember(String id) async {
    if (id == 'me') return;
    _members.removeWhere((m) => m.id == id);
    if (_ctx == id) _ctx = 'family';
    await _saveUserWorkspace();
    notifyListeners();
    showToast('Member removed');
  }

  Future<void> clearAllData() async {
    _transactions.clear();
    _smsQueue.clear();
    _approvals.clear();
    _notes.clear();
    _fundPools.clear();
    _cards.clear();
    _autoCharges.clear();
    _accountOpeningBalances.updateAll((_, __) => 0.0);
    _selectedAccount = 'All';
    if (_members.isNotEmpty) {
      final me = _members.first;
      _members
        ..clear()
        ..add(FamilyMemberDef(
          id: 'me',
          name: me.name,
          rel: 'You',
          role: 'Owner',
          openingBalance: 0,
          color: me.color,
        ));
    }
    await _saveUserWorkspace();
    notifyListeners();
    showToast('All workspace data cleared');
  }

  // State Variables
  int _activeTab = 0; // 0 = Home, 1 = Activity, 2 = Insights, 3 = Family
  String _ctx = 'family'; // 'family', 'me', or member.id
  String _period = '30d'; // '7d' or '30d'
  bool _balanceHidden = false;
  String? _subPage;
  String? _toastMessage;
  Timer? _toastTimer;

  // Filter State for Activity Screen
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'expense', 'income'
  String? _filterCatKey;
  int _alertThreshold = 80; // 70%, 80%, 90%

  // Settings Toggles
  bool autoSms = true;
  bool smartCat = true;
  bool reviewSms = true;
  bool skipPromo = true;

  bool notifBudget = true;
  bool notifFamily = true;
  bool notifApprovals = true;
  bool notifDaily = false;

  // Working Data Lists - 100% clean & empty by default
  final List<TransactionDef> _transactions = [];
  final List<SmsQueueItem> _smsQueue = [];
  final List<ApprovalItem> _approvals = [];
  final List<SharedNote> _notes = [];
  final List<FundPool> _fundPools = [];
  final List<CreditCardDef> _cards = [];
  final List<AutoCardCharge> _autoCharges = [];

  List<CreditCardDef> get cards => List.unmodifiable(_cards);
  List<AutoCardCharge> get autoCharges => List.unmodifiable(_autoCharges);

  CreditCardDef? cardById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return _cards.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Calculates live credit used for a specific card:
  /// openingUsed + card expenses - card refunds/bill payments
  double cardUsedAmount(String cardId) {
    final card = cardById(cardId);
    if (card == null) return 0.0;
    final isPrimaryCard = _cards.isNotEmpty && _cards.first.id == cardId;

    double txnDelta = 0.0;
    for (final t in _transactions) {
      final matchesExplicitCard = t.cardId == cardId;
      final matchesByTitleLast4 = t.cardId == null &&
          t.method.toLowerCase() == 'card' &&
          card.last4.isNotEmpty &&
          t.title.contains(card.last4);
      final matchesFallbackPrimary = t.cardId == null &&
          t.method.toLowerCase() == 'card' &&
          _cards.length == 1 &&
          isPrimaryCard;

      if (matchesExplicitCard || matchesByTitleLast4 || matchesFallbackPrimary) {
        if (t.type == 'expense') {
          txnDelta += t.amount;
        } else {
          txnDelta -= t.amount;
        }
      }
    }
    return (card.openingUsed + txnDelta).clamp(0.0, double.infinity);
  }

  double cardAvailableCredit(String cardId) {
    final card = cardById(cardId);
    if (card == null) return 0.0;
    return (card.creditLimit - cardUsedAmount(cardId)).clamp(0.0, card.creditLimit);
  }

  double cardUtilizationPct(String cardId) {
    final card = cardById(cardId);
    if (card == null || card.creditLimit <= 0) return 0.0;
    return (cardUsedAmount(cardId) / card.creditLimit * 100.0).clamp(0.0, 999.0);
  }

  List<TransactionDef> transactionsForCard(String cardId) {
    final card = cardById(cardId);
    final isPrimaryCard = _cards.isNotEmpty && _cards.first.id == cardId;
    return _transactions.where((t) {
      if (t.cardId == cardId) return true;
      if (t.cardId == null && t.method.toLowerCase() == 'card') {
        if (card != null && card.last4.isNotEmpty && t.title.contains(card.last4)) return true;
        if (_cards.length == 1 && isPrimaryCard) return true;
      }
      return false;
    }).toList();
  }

  double get totalCreditLimit {
    if (_cards.isEmpty) {
      return _accountOpeningBalances['Card'] ?? 0.0;
    }
    return _cards.fold(0.0, (sum, c) => sum + c.creditLimit);
  }

  double get totalCreditUsed {
    if (_cards.isEmpty) {
      return _transactions
          .where((t) => (scopeMemberId == null || t.memberId == scopeMemberId) && t.method.toLowerCase() == 'card')
          .fold(0.0, (sum, t) => sum + (t.type == 'expense' ? t.amount : -t.amount))
          .clamp(0.0, double.infinity);
    }
    final cardSum = _cards.fold(0.0, (sum, c) => sum + cardUsedAmount(c.id));
    // Also include any unlinked 'Card' transactions when multiple cards exist
    final unlinkedCardSpend = _cards.length > 1
        ? _transactions
            .where((t) =>
                t.cardId == null &&
                t.method.toLowerCase() == 'card' &&
                !_cards.any((c) => c.last4.isNotEmpty && t.title.contains(c.last4)))
            .fold(0.0, (sum, t) => sum + (t.type == 'expense' ? t.amount : -t.amount))
        : 0.0;
    return (cardSum + unlinkedCardSpend).clamp(0.0, double.infinity);
  }

  double get totalAvailableCredit {
    if (_cards.isEmpty) {
      final limit = _accountOpeningBalances['Card'] ?? 0.0;
      return (limit - totalCreditUsed).clamp(0.0, double.infinity);
    }
    return (totalCreditLimit - totalCreditUsed).clamp(0.0, totalCreditLimit);
  }

  double get totalCreditUtilizationPct {
    final limit = totalCreditLimit;
    if (limit <= 0) return 0.0;
    return (totalCreditUsed / limit * 100.0).clamp(0.0, 999.0);
  }

  Future<void> addOrUpdateCard(CreditCardDef card) async {
    final idx = _cards.indexWhere((c) => c.id == card.id);
    if (idx >= 0) {
      _cards[idx] = card;
    } else {
      _cards.add(card);
    }
    await _saveUserWorkspace();
    notifyListeners();
    showToast('${card.shortLabel} saved');
  }

  Future<void> deleteCard(String cardId) async {
    _cards.removeWhere((c) => c.id == cardId);
    _autoCharges.removeWhere((a) => a.cardId == cardId);
    await _saveUserWorkspace();
    notifyListeners();
    showToast('Card removed');
  }

  /// Pay off part or all of a credit card's used balance
  Future<void> payCardBill({
    required String cardId,
    required double amount,
    String payFromAccount = 'Bank',
  }) async {
    final card = cardById(cardId);
    if (card == null || amount <= 0) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // 1. Record a credit card bill payment (income/credit on the card so cardUsedAmount decreases)
    _transactions.insert(
      0,
      TransactionDef(
        id: nowMs,
        daysAgo: 0,
        title: '${card.shortLabel} Bill Paid',
        catKey: 'refund',
        amount: amount,
        type: 'income',
        memberId: 'me',
        method: 'Card',
        origin: 'manual',
        time: 'Now',
        cardId: cardId,
      ),
    );

    // 2. If paid from Bank/UPI/Cash, record the outflow from that account
    if (payFromAccount != 'None' && payFromAccount != 'Card') {
      _transactions.insert(
        0,
        TransactionDef(
          id: nowMs + 1,
          daysAgo: 0,
          title: 'CC Bill · ${card.shortLabel}',
          catKey: 'bills',
          amount: amount,
          type: 'expense',
          memberId: 'me',
          method: payFromAccount,
          origin: 'manual',
          time: 'Now',
        ),
      );
    }

    await _saveUserWorkspace();
    notifyListeners();
    showToast('Paid ₹${amount.round()} towards ${card.shortLabel}');
  }

  Future<void> addAutoCardCharge(AutoCardCharge charge) async {
    final idx = _autoCharges.indexWhere((a) => a.id == charge.id);
    if (idx >= 0) {
      _autoCharges[idx] = charge;
    } else {
      _autoCharges.add(charge);
    }
    await _checkAndApplyDueAutoCharges(silent: true);
    await _saveUserWorkspace();
    notifyListeners();
    showToast('Auto-charge "${charge.title}" saved');
  }

  Future<void> toggleAutoCardCharge(String id) async {
    final idx = _autoCharges.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _autoCharges[idx] = _autoCharges[idx].copyWith(isActive: !_autoCharges[idx].isActive);
    await _saveUserWorkspace();
    notifyListeners();
  }

  Future<void> deleteAutoCardCharge(String id) async {
    _autoCharges.removeWhere((a) => a.id == id);
    await _saveUserWorkspace();
    notifyListeners();
    showToast('Auto-charge removed');
  }

  Future<int> _checkAndApplyDueAutoCharges({bool silent = false}) async {
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    int appliedCount = 0;

    for (int i = 0; i < _autoCharges.length; i++) {
      final ac = _autoCharges[i];
      if (!ac.isActive) continue;
      if (ac.lastAppliedMonth == currentMonthKey) continue;
      if (now.day >= ac.dayOfMonth) {
        final card = cardById(ac.cardId);
        final cardLabel = card != null ? ' (${card.shortLabel})' : '';
        _transactions.insert(
          0,
          TransactionDef(
            id: DateTime.now().millisecondsSinceEpoch + appliedCount,
            daysAgo: 0,
            title: '${ac.title}$cardLabel',
            catKey: ac.catKey,
            amount: ac.amount,
            type: 'expense',
            memberId: card?.holderMemberId ?? 'me',
            method: 'Card',
            origin: 'auto_card',
            time: 'Auto · Day ${ac.dayOfMonth}',
            cardId: ac.cardId,
          ),
        );
        _autoCharges[i] = ac.copyWith(lastAppliedMonth: currentMonthKey);
        appliedCount++;
      }
    }
    if (appliedCount > 0) {
      await _saveUserWorkspace();
      if (!silent) {
        showToast('$appliedCount automatic card charge(s) applied');
      }
    }
    return appliedCount;
  }

  Future<void> triggerAutoChargeNow(AutoCardCharge ac) async {
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final card = cardById(ac.cardId);
    _transactions.insert(
      0,
      TransactionDef(
        id: now.millisecondsSinceEpoch,
        daysAgo: 0,
        title: ac.title,
        catKey: ac.catKey,
        amount: ac.amount,
        type: 'expense',
        memberId: card?.holderMemberId ?? 'me',
        method: 'Card',
        origin: 'auto_card',
        time: 'Auto Charge',
        cardId: ac.cardId,
      ),
    );
    final idx = _autoCharges.indexWhere((a) => a.id == ac.id);
    if (idx >= 0) {
      _autoCharges[idx] = ac.copyWith(lastAppliedMonth: currentMonthKey);
    }
    await _saveUserWorkspace();
    notifyListeners();
    showToast('${ac.title} (₹${ac.amount.round()}) charged to ${card?.shortLabel ?? 'Card'}');
  }

  /// Automatically parses 1 or more bank/credit-card SMS alerts, emails, or statement lines.
  /// Matches or auto-creates the card in Total Card List, updates credit limit/available limit if present,
  /// and automatically logs the credit card usage!
  Future<int> autoParseBankOrCardAlert(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return 0;

    // Split into blocks if multiple SMS/lines were pasted or imported
    final blocks = text
        .split(RegExp(r'\n\s*\n|\r?\n(?=.*(?:Rs\.?|INR|₹)\s*[\d,]+)'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    int count = 0;
    for (final block in (blocks.isEmpty ? [text] : blocks)) {
      final parsed = _parseSingleCardAlertBlock(block);
      if (parsed == null) continue;

      final String bank = parsed['bank'] as String;
      final String last4 = parsed['last4'] as String;
      final double amount = parsed['amount'] as double;
      final String merchant = parsed['merchant'] as String;
      final String catKey = parsed['catKey'] as String;
      final String txnType = parsed['type'] as String; // 'expense' or 'income'
      final double? availLimit = parsed['availLimit'] as double?;
      final double? totalLimit = parsed['totalLimit'] as double?;
      final String network = parsed['network'] as String;

      // Find or auto-create the CreditCardDef
      CreditCardDef? targetCard;
      if (last4.isNotEmpty) {
        try {
          targetCard = _cards.firstWhere((c) => c.last4 == last4);
        } catch (_) {}
      }
      if (targetCard == null && _cards.isNotEmpty) {
        try {
          targetCard = _cards.firstWhere((c) => c.bankName.toLowerCase() == bank.toLowerCase());
        } catch (_) {}
      }

      if (targetCard == null) {
        // Auto-create this card in the user's Total Card List!
        final inferredLimit = totalLimit ??
            (availLimit != null ? (availLimit + amount) : 100000.0);
        final palette = [0xFF312E81, 0xFF0F766E, 0xFF7C2D12, 0xFF1E3A8A, 0xFF4C1D95, 0xFF831843];
        targetCard = CreditCardDef(
          id: 'card_${DateTime.now().millisecondsSinceEpoch}_$count',
          bankName: bank,
          cardName: 'Credit Card',
          last4: last4.isNotEmpty ? last4 : '${1000 + (_cards.length * 137) % 8999}',
          network: network,
          cardType: 'Credit',
          creditLimit: inferredLimit,
          openingUsed: 0.0,
          colorHex: palette[_cards.length % palette.length],
        );
        _cards.add(targetCard);
      } else if (totalLimit != null || availLimit != null) {
        final idx = _cards.indexWhere((c) => c.id == targetCard!.id);
        if (idx >= 0) {
          final newLimit = totalLimit ?? _cards[idx].creditLimit;
          _cards[idx] = _cards[idx].copyWith(creditLimit: newLimit);
          targetCard = _cards[idx];
        }
      }

      _transactions.insert(
        0,
        TransactionDef(
          id: DateTime.now().millisecondsSinceEpoch + count,
          daysAgo: 0,
          title: merchant,
          catKey: catKey,
          amount: amount,
          type: txnType,
          memberId: targetCard.holderMemberId,
          method: 'Card',
          origin: 'auto_card',
          time: 'Auto SMS',
          cardId: targetCard.id,
        ),
      );
      count++;
    }

    if (count > 0) {
      await _saveUserWorkspace();
      notifyListeners();
      showToast('Auto-recorded $count card transaction(s) & updated credit usage');
    }
    return count;
  }

  Map<String, dynamic>? _parseSingleCardAlertBlock(String block) {
    final lower = block.toLowerCase();

    // Extract amount (supports Rs. 1,250.00 / INR 1250 / ₹1,250)
    final amtMatch = RegExp(
      r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(block);

    double? amount;
    if (amtMatch != null) {
      amount = double.tryParse(amtMatch.group(1)!.replaceAll(',', ''));
    } else {
      // Fallback for CSV/table row: look for standalone number
      final numMatch = RegExp(r'\b(\d{2,7}(?:\.\d{1,2})?)\b').firstMatch(block);
      if (numMatch != null) {
        amount = double.tryParse(numMatch.group(1)!);
      }
    }
    if (amount == null || amount <= 0) return null;

    // Extract available / total credit limit if mentioned
    double? availLimit;
    final availMatch = RegExp(
      r'(?:avl|avail|available)\s*(?:cr|credit)?\s*(?:lmt|limit)[:\s-]*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(block);
    if (availMatch != null) {
      availLimit = double.tryParse(availMatch.group(1)!.replaceAll(',', ''));
    }

    double? totalLimit;
    final totMatch = RegExp(
      r'(?:total|credit)\s*(?:lmt|limit)[:\s-]*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(block);
    if (totMatch != null) {
      totalLimit = double.tryParse(totMatch.group(1)!.replaceAll(',', ''));
    }

    // Extract last 4 digits of card
    String last4 = '';
    final last4Match = RegExp(
      r'(?:ending(?:\s+in|\s+with)?|xx+|\*{2,}|••+|card\s*no\.?\s*)\s*(\d{4})\b',
      caseSensitive: false,
    ).firstMatch(block);
    if (last4Match != null) {
      last4 = last4Match.group(1)!;
    }

    // Detect bank name
    String bank = 'Bank';
    if (lower.contains('hdfc')) {
      bank = 'HDFC Bank';
    } else if (lower.contains('sbi')) {
      bank = 'SBI Card';
    } else if (lower.contains('icici')) {
      bank = 'ICICI Bank';
    } else if (lower.contains('axis')) {
      bank = 'Axis Bank';
    } else if (lower.contains('kotak')) {
      bank = 'Kotak Bank';
    } else if (lower.contains('amex') || lower.contains('american express')) {
      bank = 'Amex';
    } else if (lower.contains('onecard') || lower.contains('one card')) {
      bank = 'OneCard';
    } else if (lower.contains('idfc')) {
      bank = 'IDFC First';
    } else if (lower.contains('indus')) {
      bank = 'IndusInd';
    } else if (lower.contains('rbl')) {
      bank = 'RBL Bank';
    } else if (lower.contains('yes')) {
      bank = 'Yes Bank';
    } else if (lower.contains('au ')) {
      bank = 'AU Bank';
    } else if (lower.contains('bob') || lower.contains('baroda')) {
      bank = 'BOB Card';
    }

    String network = 'Visa';
    if (lower.contains('rupay')) {
      network = 'RuPay';
    } else if (lower.contains('master')) {
      network = 'Mastercard';
    } else if (lower.contains('amex')) {
      network = 'Amex';
    }

    // Detect merchant
    String merchant = 'Card Purchase';
    final merchMatch = RegExp(
      r'(?:at|to|in\s+favor\s+of|merchant)\s+([A-Za-z0-9&\s._-]{2,28}?)(?:\s+on\b|\s+for\b|\s+avl\b|\.|$)',
      caseSensitive: false,
    ).firstMatch(block);
    if (merchMatch != null) {
      merchant = merchMatch.group(1)!.trim();
    } else {
      final knownMerchants = {
        'swiggy': 'Swiggy',
        'zomato': 'Zomato',
        'amazon': 'Amazon',
        'flipkart': 'Flipkart',
        'myntra': 'Myntra',
        'uber': 'Uber',
        'ola': 'Ola',
        'bigbasket': 'BigBasket',
        'blinkit': 'Blinkit',
        'zepto': 'Zepto',
        'dmart': 'DMart',
        'netflix': 'Netflix',
        'jio': 'Jio',
        'airtel': 'Airtel',
        'irctc': 'IRCTC',
        'shell': 'Shell Fuel',
        'hpcl': 'HPCL Fuel',
        'iocl': 'IndianOil',
      };
      for (final e in knownMerchants.entries) {
        if (lower.contains(e.key)) {
          merchant = e.value;
          break;
        }
      }
    }

    // Detect category
    String catKey = 'shopping';
    if (lower.contains('swiggy') || lower.contains('zomato') || lower.contains('restaurant') || lower.contains('food') || lower.contains('cafe')) {
      catKey = 'dining';
    } else if (lower.contains('uber') || lower.contains('ola') || lower.contains('irctc') || lower.contains('flight')) {
      catKey = 'transport';
    } else if (lower.contains('fuel') || lower.contains('petrol') || lower.contains('shell') || lower.contains('hpcl') || lower.contains('iocl')) {
      catKey = 'fuel';
    } else if (lower.contains('bigbasket') || lower.contains('blinkit') || lower.contains('zepto') || lower.contains('dmart') || lower.contains('grocer')) {
      catKey = 'groceries';
    } else if (lower.contains('netflix') || lower.contains('airtel') || lower.contains('jio') || lower.contains('bill') || lower.contains('electricity')) {
      catKey = 'bills';
    } else if (lower.contains('hospital') || lower.contains('apollo') || lower.contains('pharmacy')) {
      catKey = 'health';
    }

    final isCreditOrRefund = lower.contains('refund') ||
        lower.contains('reversed') ||
        lower.contains('cashback') ||
        (lower.contains('credited') && !lower.contains('debited'));

    return {
      'bank': bank,
      'last4': last4,
      'amount': amount,
      'merchant': merchant,
      'catKey': catKey,
      'type': isCreditOrRefund ? 'income' : 'expense',
      'availLimit': availLimit,
      'totalLimit': totalLimit,
      'network': network,
    };
  }

  List<SharedNote> get notes {
    final sorted = List<SharedNote>.from(_notes);
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAtMs.compareTo(a.updatedAtMs);
    });
    return sorted;
  }

  List<FundPool> get fundPools => _fundPools;

  void _handleRemoteNoteUpdated(SharedNote remoteNote, String editorName) {
    final index = _notes.indexWhere((n) => n.id == remoteNote.id);
    if (index >= 0) {
      if (remoteNote.updatedAtMs >= _notes[index].updatedAtMs) {
        _notes[index] = remoteNote;
      }
    } else {
      _notes.insert(0, remoteNote);
    }
    _saveUserWorkspace();
    notifyListeners();
  }

  void _handleRemoteNoteDeleted(String noteId, String sender) {
    _notes.removeWhere((n) => n.id == noteId);
    _saveUserWorkspace();
    notifyListeners();
  }

  void _handleRemoteFullSync(List<SharedNote> remoteNotes, String sender) {
    bool changed = false;
    for (final remote in remoteNotes) {
      final idx = _notes.indexWhere((n) => n.id == remote.id);
      if (idx < 0) {
        _notes.add(remote);
        changed = true;
      } else if (remote.updatedAtMs > _notes[idx].updatedAtMs) {
        _notes[idx] = remote;
        changed = true;
      }
    }
    if (changed) {
      _saveUserWorkspace();
      notifyListeners();
    }
  }

  void _handleRemoteFamilyLoginRequest(FamilyLoginRequest req) async {
    if (_familyCode.isEmpty) return;
    _familyLoginRequests.removeWhere((r) => r.email.toLowerCase() == req.email.toLowerCase());
    _familyLoginRequests.insert(0, req);
    await SupabaseService.saveFamilyLoginRequests(_familyCode, _familyLoginRequests);
    notifyListeners();
    showToast('Security Alert: ${req.name} requested to use your Family Login');
  }

  void _handleRemoteMemberDisabledChanged(String email, String name, bool disabled) async {
    final myEmail = _userKey.trim().toLowerCase();
    final myName = _currentUserName.trim().toLowerCase();
    final matchesMe = (email.isNotEmpty && email.toLowerCase() == myEmail) ||
        (name.isNotEmpty && name.toLowerCase() == myName);
    if (matchesMe && disabled) {
      await logout();
      showToast('Your access to this family login was disabled by the Family Owner.');
      return;
    }
    final idx = _members.indexWhere(
      (m) =>
          (email.isNotEmpty && m.email.toLowerCase() == email.toLowerCase()) ||
          (name.isNotEmpty && m.name.toLowerCase() == name.toLowerCase()),
    );
    if (idx >= 0 && _members[idx].id != 'me') {
      _members[idx] = _members[idx].copyWith(isDisabled: disabled);
      await _saveUserWorkspace();
      notifyListeners();
    }
  }

  Future<void> saveNote(SharedNote note, {bool broadcast = true}) async {
    final updated = note.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final index = _notes.indexWhere((n) => n.id == updated.id);
    if (index >= 0) {
      _notes[index] = updated;
    } else {
      _notes.insert(0, updated);
    }
    if (broadcast) {
      _notesWs.broadcastNoteEdit(updated);
    }
    await _saveUserWorkspace();
    notifyListeners();
  }

  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
    _notesWs.broadcastNoteDelete(noteId);
    await _saveUserWorkspace();
    notifyListeners();
  }

  Future<void> togglePinNote(String noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index < 0) return;
    final toggled = _notes[index].copyWith(
      isPinned: !_notes[index].isPinned,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _notes[index] = toggled;
    _notesWs.broadcastNoteEdit(toggled);
    await _saveUserWorkspace();
    notifyListeners();
  }

  void notifyNoteTyping(String noteId) {
    _notesWs.broadcastTyping(noteId);
  }

  Future<void> reconnectNotesWs() async {
    await _notesWs.connect(
      familyCode: _familyCode,
      userName: _currentUserName.isNotEmpty ? _currentUserName : 'Member',
    );
    notifyListeners();
  }

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String get currentUserName => _currentUserName;

  int get activeTab => _activeTab;
  String get ctx => _ctx;
  String get period => _period;
  bool get balanceHidden => _balanceHidden;
  String? get subPage => _subPage;
  String? get toastMessage => _toastMessage;

  Future<void> setLoggedIn(
    bool loggedIn, {
    String? userName,
    String? userKey,
    String? familyName,
    String? familyCode,
    bool clearWorkspaceOnNewAccount = false,
  }) async {
    _isLoggedIn = loggedIn;
    if (userName != null && userName.trim().isNotEmpty) {
      _currentUserName = userName.trim();
    }
    if (userKey != null && userKey.trim().isNotEmpty) {
      _userKey = userKey.trim().toLowerCase();
    } else if (SupabaseService.currentUser != null) {
      final u = SupabaseService.currentUser!;
      _userKey = (u.email ?? u.id).toLowerCase();
    } else if (_currentUserName.isNotEmpty) {
      _userKey = _currentUserName.toLowerCase();
    }

    if (clearWorkspaceOnNewAccount) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ff_${_userKey}_members');
      await prefs.remove('ff_${_userKey}_transactions');
      await prefs.remove('ff_${_userKey}_notes');
      await prefs.remove('ff_${_userKey}_account_balances');
      await prefs.remove('ff_${_userKey}_cards');
      await prefs.remove('ff_${_userKey}_auto_charges');
      _transactions.clear();
      _notes.clear();
      _smsQueue.clear();
      _approvals.clear();
      _fundPools.clear();
      _cards.clear();
      _autoCharges.clear();
      _accountOpeningBalances.updateAll((_, __) => 0.0);
    }

    if (familyName != null && familyName.trim().isNotEmpty && familyName.trim() != 'Khan Family') {
      _familyName = familyName.trim();
    }
    if (familyCode != null && familyCode.trim().isNotEmpty) {
      _familyCode = familyCode.trim().toUpperCase();
    }

    await _loadUserWorkspace();

    if (familyName != null && familyName.trim().isNotEmpty && familyName.trim() != 'Khan Family') {
      _familyName = familyName.trim();
    }
    if (familyCode != null && familyCode.trim().isNotEmpty) {
      _familyCode = familyCode.trim().toUpperCase();
    }
    await _saveUserWorkspace();
    notifyListeners();
  }

  Future<void> logout() async {
    await _notesWs.disconnect();
    await SupabaseService.signOut();
    _isLoggedIn = false;
    _activeTab = 0;
    _subPage = null;
    _ctx = 'family';
    _selectedAccount = 'All';
    notifyListeners();
  }

  String get searchQuery => _searchQuery;
  String get filterType => _filterType;
  String? get filterCatKey => _filterCatKey;
  int get alertThreshold => _alertThreshold;

  List<TransactionDef> get transactions => _transactions;
  List<SmsQueueItem> get smsQueue => _smsQueue;
  List<ApprovalItem> get approvals => _approvals;

  // Filtered Scope Getters
  String? get scopeMemberId => _ctx == 'family' ? null : _ctx;

  bool isTxnInScope(TransactionDef t) {
    if (scopeMemberId == null) return true;
    return t.memberId == scopeMemberId;
  }

  bool _matchesAccount(TransactionDef t, String account) {
    if (account == 'All') return true;
    final m = t.method.toLowerCase();
    final c = t.catKey.toLowerCase();
    final target = account.toLowerCase();
    if (target == 'salary') {
      return m == 'salary' || c == 'salary';
    }
    if (target == 'loan') {
      return m == 'loan' || c == 'loan';
    }
    return m == target;
  }

  /// Calculates the live balance for a specific account/method ('Cash', 'Salary', 'Loan', 'UPI', 'Bank', 'Card', or 'All')
  double accountBalance(String account) {
    if (account == 'Card' && _cards.isNotEmpty) {
      // For 'Card', return total available credit across all cards in Total Card List
      return totalAvailableCredit;
    }

    if (account == 'All') {
      final activeMembers = members;
      final memberOpening = scopeMemberId == null
          ? activeMembers.fold(0.0, (sum, m) => sum + m.openingBalance)
          : activeMembers.firstWhere((m) => m.id == scopeMemberId, orElse: () => activeMembers.first).openingBalance;
      final walletOpening = _accountOpeningBalances.values.fold(0.0, (sum, v) => sum + v);
      final netFlow = _transactions
          .where((t) => scopeMemberId == null || t.memberId == scopeMemberId)
          .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
      return memberOpening + walletOpening + netFlow;
    }

    final opening = _accountOpeningBalances[account] ?? 0.0;
    final netFlow = _transactions
        .where((t) => (scopeMemberId == null || t.memberId == scopeMemberId) && _matchesAccount(t, account))
        .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
    return opening + netFlow;
  }

  int get maxDays => _period == '7d' ? 7 : 30;

  List<TransactionDef> get scopedTransactions {
    return _transactions
        .filterInScope(scopeMemberId, maxDays)
        .where((t) => _matchesAccount(t, _selectedAccount))
        .toList();
  }

  double get totalIncome {
    return scopedTransactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    return scopedTransactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
  }

  double get trackedBalance {
    return accountBalance(_selectedAccount);
  }

  int get notifBadgeCount {
    int count = 0;
    if (_approvals.isNotEmpty) count++;
    if (pendingFamilyLoginRequests.isNotEmpty) count++;
    if (_smsQueue.isNotEmpty && autoSms) count++;
    return count;
  }

  // Setters & Actions
  void setTab(int index) {
    _activeTab = index;
    _subPage = null;
    notifyListeners();
  }

  void setContext(String contextId) {
    _ctx = contextId;
    notifyListeners();
  }

  void setPeriod(String periodCode) {
    _period = periodCode;
    notifyListeners();
  }

  void toggleBalanceHidden() {
    _balanceHidden = !_balanceHidden;
    notifyListeners();
  }

  void openSubPage(String pageName) {
    _subPage = pageName;
    notifyListeners();
  }

  void setSubPage(String? pageName) {
    _subPage = pageName;
    notifyListeners();
  }

  void closeSubPage() {
    _subPage = null;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setFilterType(String type) {
    _filterType = type;
    notifyListeners();
  }

  void setFilterCategory(String? catKey) {
    _filterCatKey = catKey;
    notifyListeners();
  }

  void setAlertThreshold(int threshold) {
    _alertThreshold = threshold;
    notifyListeners();
  }

  void showToast(String message) {
    _toastTimer?.cancel();
    _toastMessage = message;
    notifyListeners();
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      _toastMessage = null;
      notifyListeners();
    });
  }

  // Transaction Operations
  Future<void> addTransaction(TransactionDef txn) async {
    _transactions.insert(0, txn);
    await _saveUserWorkspace();
    notifyListeners();
  }

  Future<void> confirmSmsItem(SmsQueueItem item) async {
    _smsQueue.removeWhere((s) => s.id == item.id);
    final isCardItem = item.cardId != null ||
        (item.cardLast4 != null && item.cardLast4!.isNotEmpty) ||
        item.snippet.toLowerCase().contains('card');
    final newTxn = TransactionDef(
      id: DateTime.now().millisecondsSinceEpoch,
      daysAgo: 0,
      title: item.merchant,
      catKey: item.catKey,
      amount: item.amount,
      type: 'expense',
      memberId: 'me',
      method: isCardItem ? 'Card' : 'UPI',
      origin: 'sms',
      time: 'Now',
      cardId: item.cardId ?? (_cards.isNotEmpty && isCardItem ? _cards.first.id : null),
    );
    _transactions.insert(0, newTxn);
    await _saveUserWorkspace();
    showToast('${item.merchant} ₹${item.amount.toInt()} added');
    notifyListeners();
  }

  void ignoreSmsItem(SmsQueueItem item) {
    _smsQueue.removeWhere((s) => s.id == item.id);
    showToast('Ignored · won\'t be added');
    notifyListeners();
  }

  Future<void> approveItem(ApprovalItem item) async {
    _approvals.removeWhere((a) => a.id == item.id);
    final activeMembers = members;
    final fromMember = activeMembers.firstWhere(
      (m) => m.id == item.fromMemberId,
      orElse: () => activeMembers.first,
    );

    if (item.kind == 'Edit' && item.txnId != null && item.changes != null) {
      final index = _transactions.indexWhere((t) => t.id == item.txnId);
      if (index != -1) {
        final old = _transactions[index];
        final newAmt = (item.changes!['amt'] as num).toDouble();
        _transactions[index] = TransactionDef(
          id: old.id,
          daysAgo: old.daysAgo,
          title: old.title,
          catKey: old.catKey,
          amount: newAmt,
          type: old.type,
          memberId: old.memberId,
          method: old.method,
          origin: old.origin,
          time: old.time,
          cardId: old.cardId,
        );
      }
    } else if (item.kind == 'New' && item.newTxn != null) {
      _transactions.insert(0, item.newTxn!);
    }

    await _saveUserWorkspace();
    showToast('Approved · ${fromMember.name} will be notified');
    notifyListeners();
  }

  void rejectItem(ApprovalItem item) {
    _approvals.removeWhere((a) => a.id == item.id);
    showToast('Request rejected');
    notifyListeners();
  }
}

extension TransactionListExtensions on List<TransactionDef> {
  List<TransactionDef> filterInScope(String? memberId, int maxDays) {
    return where((t) => (memberId == null || t.memberId == memberId) && t.daysAgo < maxDays).toList();
  }
}
