import 'dart:async';
import 'dart:convert';
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
          ),
        ];

  String get familyCode => _familyCode.isNotEmpty ? _familyCode : '--------';
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
        ),
      );
    } else {
      _members[0] = FamilyMemberDef(
        id: 'me',
        name: _currentUserName.isNotEmpty ? _currentUserName : _members[0].name,
        rel: 'You',
        role: 'Owner',
        openingBalance: _members[0].openingBalance,
        color: _members[0].color,
      );
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
    final encodedNotes = json.encode(_notes.map((n) => n.toJson()).toList());
    await prefs.setString('ff_${_userKey}_notes', encodedNotes);
    if (_familyCode.isNotEmpty) {
      await prefs.setString('ff_family_${_familyCode}_notes', encodedNotes);
    }
  }

  static String generateUniqueFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      buffer.write(chars[(rnd + i * 37) % chars.length]);
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
      _familyCode = code.trim().toUpperCase();
      if (familyName != null && familyName.trim().isNotEmpty) {
        _familyName = familyName.trim();
      }
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

  Future<void> addFamilyMember({
    required String name,
    required String rel,
    String role = 'Member',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final id = '${cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    final color = _memberPalette[_members.length % _memberPalette.length];
    _members.add(
      FamilyMemberDef(
        id: id,
        name: cleanName,
        rel: rel.trim().isNotEmpty ? rel.trim() : 'Family',
        role: role,
        openingBalance: 0,
        color: color,
      ),
    );
    await _saveUserWorkspace();
    notifyListeners();
    showToast('$cleanName added to $familyName');
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
      _transactions.clear();
      _notes.clear();
      _smsQueue.clear();
      _approvals.clear();
      _fundPools.clear();
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
    final newTxn = TransactionDef(
      id: DateTime.now().millisecondsSinceEpoch,
      daysAgo: 0,
      title: item.merchant,
      catKey: item.catKey,
      amount: item.amount,
      type: 'expense',
      memberId: 'me',
      method: 'UPI',
      origin: 'sms',
      time: 'Now',
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
