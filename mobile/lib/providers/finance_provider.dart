import 'dart:async';
import 'package:flutter/material.dart';
import '../models/finance_models.dart';
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

  // Members List
  static final List<FamilyMemberDef> members = [
    const FamilyMemberDef(id: 'asif', name: 'Asif', rel: 'You', role: 'Owner', openingBalance: 62000, color: Color(0xFF9184D9)),
    const FamilyMemberDef(id: 'sara', name: 'Sara', rel: 'Wife', role: 'Admin', openingBalance: 41000, color: Color(0xFFEC4899)),
    const FamilyMemberDef(id: 'imran', name: 'Imran', rel: 'Brother', role: 'Member', openingBalance: 18500, color: Color(0xFF3B82F6)),
    const FamilyMemberDef(id: 'yusuf', name: 'Yusuf', rel: 'Father', role: 'Member', openingBalance: 55000, color: Color(0xFFEAB308)),
    const FamilyMemberDef(id: 'zara', name: 'Zara', rel: 'Daughter', role: 'Member', openingBalance: 6200, color: Color(0xFF34D399)),
  ];

  // Budgets Definitions
  static final List<BudgetDef> budgets = [
    const BudgetDef(catKey: 'groceries', familyLimit: 12000, personalLimit: 5000),
    const BudgetDef(catKey: 'dining', familyLimit: 4000, personalLimit: 2000),
    const BudgetDef(catKey: 'shopping', familyLimit: 6000, personalLimit: 3000),
    const BudgetDef(catKey: 'fuel', familyLimit: 4000, personalLimit: 2500),
  ];

  // Auth State
  bool _isLoggedIn = false;
  String _currentUserName = '';
  String _familyCode = 'K9L2M4X7';
  String _familyName = 'Khan Family';

  String get familyCode => _familyCode;
  String get familyName => _familyName;

  FinanceProvider() {
    _checkInitialAuth();
  }

  void _checkInitialAuth() {
    if (SupabaseService.isConfigured && SupabaseService.currentUser != null) {
      _isLoggedIn = true;
      final meta = SupabaseService.currentUser?.userMetadata;
      if (meta != null && meta['full_name'] != null && meta['full_name'].toString().isNotEmpty) {
        _currentUserName = meta['full_name'].toString();
      } else if (SupabaseService.currentUser?.email != null) {
        _currentUserName = SupabaseService.currentUser!.email!.split('@')[0];
      } else {
        _currentUserName = 'User';
      }
      if (meta != null && meta['family_code'] != null) {
        _familyCode = meta['family_code'].toString();
      }
      if (meta != null && meta['family_name'] != null) {
        _familyName = meta['family_name'].toString();
      }
    } else {
      _isLoggedIn = false;
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

  void setFamilyDetails({required String name, required String code}) {
    _familyName = name;
    _familyCode = code.toUpperCase();
    notifyListeners();
  }

  void joinFamilyWithCode(String code) {
    if (code.trim().length >= 6) {
      _familyCode = code.trim().toUpperCase();
      notifyListeners();
      showToast('Joined Family Workspace ($familyCode)');
    }
  }

  void clearAllData() {
    _transactions.clear();
    _smsQueue.clear();
    _approvals.clear();
    notifyListeners();
    showToast('All transaction data cleared');
  }

  void loadDemoData() {
    _transactions.clear();
    _transactions.addAll([
      const TransactionDef(id: 1, daysAgo: 0, title: 'Rapido ride', catKey: 'transport', amount: 186, type: 'expense', memberId: 'asif', method: 'UPI', origin: 'sms', time: '10:45 AM'),
      const TransactionDef(id: 2, daysAgo: 0, title: 'BigBasket', catKey: 'groceries', amount: 2340, type: 'expense', memberId: 'sara', method: 'UPI', origin: 'sms', time: '9:12 AM'),
      const TransactionDef(id: 3, daysAgo: 1, title: 'Swiggy · dinner', catKey: 'dining', amount: 864, type: 'expense', memberId: 'asif', method: 'Card', origin: 'sms', time: '8:40 PM'),
      const TransactionDef(id: 4, daysAgo: 1, title: 'Indian Oil', catKey: 'fuel', amount: 2000, type: 'expense', memberId: 'imran', method: 'Card', origin: 'sms', time: '6:15 PM'),
      const TransactionDef(id: 5, daysAgo: 1, title: 'Salary · October', catKey: 'salary', amount: 92000, type: 'income', memberId: 'asif', method: 'Bank', origin: 'sms', time: '9:00 AM'),
    ]);
    notifyListeners();
    showToast('Sample demo data loaded');
  }

  // State Variables
  int _activeTab = 0; // 0 = Home, 1 = Activity, 2 = Insights, 3 = Family
  String _ctx = 'family'; // 'family', 'me', 'sara', 'imran', 'yusuf', 'zara'
  String _period = '30d'; // '7d' or '30d'
  bool _balanceHidden = false;
  String? _subPage; // null, 'sms', 'settings', 'notifs'
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

  // Working Data Lists - Clean empty by default for real user data
  final List<TransactionDef> _transactions = [];

  final List<SmsQueueItem> _smsQueue = [];

  final List<ApprovalItem> _approvals = [];

  final List<SharedNote> _notes = [
    const SharedNote(
      id: 'n1',
      title: 'Wedding & Event Expenses',
      content: 'Loan amount credited: ₹2,00,000.\n- Venue Booking: ₹75,000 (Paid by Asif)\n- Makeup & Hair Setting: ₹25,000 (Sara)\n- Clothing: ₹30,000 (Family)',
      lastEditedBy: 'Sara',
      lastEditedTime: '15m ago',
    ),
    const SharedNote(
      id: 'n2',
      title: 'Home Renovation Checklist',
      content: 'Electrician: ₹850 paid by Sara.\nPaint materials: ₹4,200 pending approval.',
      lastEditedBy: 'Asif',
      lastEditedTime: '2h ago',
    ),
  ];

  final List<FundPool> _fundPools = [
    const FundPool(
      id: 'p1',
      title: 'Wedding Loan Pool',
      poolType: 'Loan',
      totalAmount: 200000,
      spentAmount: 130000,
      createdDate: '01 Oct 2026',
    ),
    const FundPool(
      id: 'p2',
      title: 'Home Construction Fund',
      poolType: 'Savings Pool',
      totalAmount: 500000,
      spentAmount: 120000,
      createdDate: '15 Sep 2026',
    ),
  ];

  List<SharedNote> get notes => _notes;
  List<FundPool> get fundPools => _fundPools;

  void saveNote(SharedNote note) {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      _notes[index] = note;
    } else {
      _notes.insert(0, note);
    }
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

  void setLoggedIn(bool loggedIn, {String? userName}) {
    _isLoggedIn = loggedIn;
    if (userName != null && userName.isNotEmpty) {
      _currentUserName = userName;
    }
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
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
  String? get scopeMemberId => _ctx == 'family' ? null : (_ctx == 'me' ? 'asif' : _ctx);

  bool isTxnInScope(TransactionDef t) {
    if (scopeMemberId == null) return true;
    return t.memberId == scopeMemberId;
  }

  int get maxDays => _period == '7d' ? 7 : 30;

  List<TransactionDef> get scopedTransactions {
    return _transactions.filterInScope(scopeMemberId, maxDays);
  }

  double get totalIncome {
    return scopedTransactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    return scopedTransactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
  }

  double get trackedBalance {
    final baseOpening = scopeMemberId == null
        ? members.fold(0.0, (sum, m) => sum + m.openingBalance)
        : members.firstWhere((m) => m.id == scopeMemberId, orElse: () => members.first).openingBalance;

    final netFlow = _transactions
        .where((t) => scopeMemberId == null || t.memberId == scopeMemberId)
        .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));

    return baseOpening + netFlow;
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
  void addTransaction(TransactionDef txn) {
    _transactions.insert(0, txn);
    notifyListeners();
  }

  void confirmSmsItem(SmsQueueItem item) {
    _smsQueue.removeWhere((s) => s.id == item.id);
    final newTxn = TransactionDef(
      id: DateTime.now().millisecondsSinceEpoch,
      daysAgo: 0,
      title: item.merchant,
      catKey: item.catKey,
      amount: item.amount,
      type: 'expense',
      memberId: 'asif',
      method: 'UPI',
      origin: 'sms',
      time: 'Now',
    );
    _transactions.insert(0, newTxn);
    showToast('${item.merchant} ₹${item.amount.toInt()} added');
    notifyListeners();
  }

  void ignoreSmsItem(SmsQueueItem item) {
    _smsQueue.removeWhere((s) => s.id == item.id);
    showToast('Ignored · won\'t be added');
    notifyListeners();
  }

  void approveItem(ApprovalItem item) {
    _approvals.removeWhere((a) => a.id == item.id);
    final fromMember = members.firstWhere((m) => m.id == item.fromMemberId, orElse: () => members.first);

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
