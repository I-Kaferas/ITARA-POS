import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cashier preferences edited from the settings page (theme and language
/// stay on their own controllers; paper size stays on the terminal config).
class CashierPreferences extends ChangeNotifier {
  CashierPreferences._();

  static final instance = CashierPreferences._();

  static const _textKey = 'cashier_print_text_level';
  static const _notificationsKey = 'cashier_notifications';
  static const _notificationChannelsKey = 'cashier_notification_channels';
  static const _autoLockKey = 'cashier_auto_lock_minutes';
  static const _standardPosKey = 'cashier_standard_pos';
  static const _hiddenMenusKey = 'cashier_hidden_menus';

  /// Navigation menus, in display order.
  static const menuKeys = ['overview', 'pos', 'orders', 'kitchen', 'tables', 'shifts'];
  static const restaurantMenus = {'kitchen', 'tables'};

  /// Notification channels shown on the settings page, all on by default.
  static const notificationChannels = [
    'orders',
    'stock',
    'devices',
    'call_ringtone',
    'call_vibration',
    'sync',
    'general',
  ];

  /// The navigation must keep at least this many menus (bottom bar minimum).
  static const minVisibleMenus = 2;

  static const textLabels = ['Défaut', 'Moyen', 'Grand', 'XL', 'XXL'];
  static const autoLockChoices = [0, 1, 2, 5, 10];

  int printTextLevel = 1;
  bool notificationsEnabled = true;
  Set<String> enabledNotificationChannels = {...notificationChannels};
  int autoLockMinutes = 0;
  bool standardPos = false;
  Set<String> hiddenMenus = {};

  bool notificationChannelEnabled(String key) =>
      notificationsEnabled && enabledNotificationChannels.contains(key);

  bool menuAvailable(String key) => !(standardPos && restaurantMenus.contains(key));

  bool menuVisible(String key) => menuAvailable(key) && !hiddenMenus.contains(key);

  int get visibleMenuCount => menuKeys.where(menuVisible).length;

  double get printTextScale => switch (printTextLevel) {
    2 => 1.15,
    3 => 1.35,
    4 => 1.55,
    5 => 1.8,
    _ => 1.0,
  };

  /// Font size for receipts / invoices / kitchen tickets.
  static double text(double size) => size * instance.printTextScale;

  /// Vertical rhythm that grows with the text level so tickets do not feel cramped.
  static double space(double size) => size * instance.printTextScale;

  String get printTextCaption {
    final index = (printTextLevel - 1).clamp(0, textLabels.length - 1);
    return 'Niveau $printTextLevel — ${textLabels[index]}';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    printTextLevel = (prefs.getInt(_textKey) ?? 1).clamp(1, 5);
    notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    final channels = prefs.getStringList(_notificationChannelsKey);
    enabledNotificationChannels = channels == null
        ? {...notificationChannels}
        : channels.where(notificationChannels.contains).toSet();
    autoLockMinutes = prefs.getInt(_autoLockKey) ?? 0;
    if (!autoLockChoices.contains(autoLockMinutes)) autoLockMinutes = 0;
    standardPos = prefs.getBool(_standardPosKey) ?? false;
    final hidden = prefs.getStringList(_hiddenMenusKey);
    hiddenMenus = hidden?.toSet() ?? {};
    if (!standardPos) hiddenMenus.removeAll(restaurantMenus);
    notifyListeners();
  }

  Future<void> setPrintTextLevel(int level) async {
    final next = level.clamp(1, 5);
    if (next == printTextLevel) return;
    printTextLevel = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_textKey, printTextLevel);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (value == notificationsEnabled) return;
    notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  Future<void> setNotificationChannel(String key, bool enabled) async {
    if (!notificationChannels.contains(key)) return;
    final currently = enabledNotificationChannels.contains(key);
    if (currently == enabled) return;
    if (enabled) {
      enabledNotificationChannels.add(key);
    } else {
      enabledNotificationChannels.remove(key);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _notificationChannelsKey,
      enabledNotificationChannels.toList(),
    );
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    final next = autoLockChoices.contains(minutes) ? minutes : 0;
    if (next == autoLockMinutes) return;
    autoLockMinutes = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockKey, next);
  }

  Future<void> setStandardPos(bool value) async {
    if (value == standardPos) return;
    standardPos = value;
    if (!value) hiddenMenus.removeAll(restaurantMenus);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_standardPosKey, value);
    await prefs.setStringList(_hiddenMenusKey, hiddenMenus.toList());
  }

  Future<void> setMenuVisible(String key, bool visible) async {
    if (!menuKeys.contains(key) || menuVisible(key) == visible) return;
    if (!visible && visibleMenuCount <= minVisibleMenus) return;
    if (visible) {
      hiddenMenus.remove(key);
    } else {
      hiddenMenus.add(key);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenMenusKey, hiddenMenus.toList());
  }
}
