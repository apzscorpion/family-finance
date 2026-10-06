import 'package:flutter/foundation.dart';

/// Full-screen pages that slide over the tab content, matching the design's
/// `isPage` overlay rather than pushing a new route.
enum V3Page { detected, cards, notifications, settings, notes, prayer, prayerSettings }

/// Shell navigation, kept separate from [V3State] so a screen can move the
/// shell without the data layer knowing anything about navigation.
class V3Nav extends ChangeNotifier {
  int _tab = 0;
  V3Page? _page;

  int get tab => _tab;
  V3Page? get page => _page;

  void goTab(int i) {
    if (_tab == i && _page == null) return;
    _tab = i;
    _page = null;
    notifyListeners();
  }

  void goPage(V3Page p) {
    _page = p;
    notifyListeners();
  }

  void closePage() {
    if (_page == null) return;
    _page = null;
    notifyListeners();
  }

  String titleFor(V3Page p) => switch (p) {
        V3Page.detected => 'Detected payments',
        V3Page.cards => 'Cards & accounts',
        V3Page.notifications => 'Notifications',
        V3Page.settings => 'Settings',
        V3Page.notes => 'Family notes',
        V3Page.prayer => 'Prayer times',
        V3Page.prayerSettings => 'Prayer settings',
      };
}
