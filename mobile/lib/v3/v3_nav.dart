import 'package:flutter/foundation.dart';

/// Full-screen pages that slide over the tab content, matching the design's
/// `isPage` overlay rather than pushing a new route.
enum V3Page {
  detected,
  cards,
  notifications,
  settings,
  notes,
  prayer,
  prayerSettings,
  aiSettings,
}

/// Shell navigation, kept separate from [V3State] so a screen can move the
/// shell without the data layer knowing anything about navigation.
class V3Nav extends ChangeNotifier {
  int _tab = 0;
  final List<int> _tabHistory = [];
  final List<V3Page> _pageStack = [];
  final List<bool Function()> _backHandlers = [];

  int get tab => _tab;
  V3Page? get page => _pageStack.isEmpty ? null : _pageStack.last;
  List<V3Page> get pageStack => List.unmodifiable(_pageStack);

  /// Whether [V3Shell] should intercept the system back button/gesture instead
  /// of letting Android close the activity.
  bool get canGoBack =>
      _pageStack.isNotEmpty || _tabHistory.isNotEmpty || _tab != 0;

  void registerBackHandler(bool Function() handler) {
    if (!_backHandlers.contains(handler)) {
      _backHandlers.add(handler);
    }
  }

  void unregisterBackHandler(bool Function() handler) {
    _backHandlers.remove(handler);
  }

  void goTab(int i) {
    if (_tab == i && _pageStack.isEmpty) return;
    _pageStack.clear();
    if (_tab != i) {
      if (i == 0) {
        _tabHistory.clear();
      } else {
        _tabHistory.remove(i);
        _tabHistory.add(_tab);
      }
      _tab = i;
    }
    notifyListeners();
  }

  void goPage(V3Page p) {
    if (_pageStack.isNotEmpty && _pageStack.last == p) return;
    _pageStack.remove(p);
    _pageStack.add(p);
    notifyListeners();
  }

  void closePage() {
    if (_pageStack.isEmpty) return;
    _pageStack.removeLast();
    notifyListeners();
  }

  /// Handles an Android/system back press or back gesture.
  /// Returns true if the shell navigated back internally.
  bool handleBack() {
    for (var i = _backHandlers.length - 1; i >= 0; i--) {
      if (_backHandlers[i]()) {
        return true;
      }
    }
    if (_pageStack.isNotEmpty) {
      _pageStack.removeLast();
      notifyListeners();
      return true;
    }
    if (_tabHistory.isNotEmpty) {
      _tab = _tabHistory.removeLast();
      notifyListeners();
      return true;
    }
    if (_tab != 0) {
      _tab = 0;
      notifyListeners();
      return true;
    }
    return false;
  }

  String titleFor(V3Page p) => switch (p) {
        V3Page.detected => 'Detected payments',
        V3Page.cards => 'Cards & accounts',
        V3Page.notifications => 'Notifications',
        V3Page.settings => 'Settings',
        V3Page.notes => 'Family notes',
        V3Page.prayer => 'Prayer times',
        V3Page.prayerSettings => 'Prayer settings',
        V3Page.aiSettings => 'AI restructuring',
      };
}
