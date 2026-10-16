import 'dart:async';

import 'package:flutter/material.dart';

import '../../settings/domain/cashier_preferences.dart';
import '../data/notification_watch.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class NotificationBadge extends StatefulWidget {
  const NotificationBadge({required this.child, super.key});

  final Widget child;

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    CashierPreferences.instance.addListener(_refresh);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    CashierPreferences.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!CashierPreferences.instance.notificationsEnabled) {
      if (!mounted) return;
      setState(() => _count = 0);
      return;
    }
    try {
      final items = await NotificationWatch.instance.snapshot();
      if (!mounted) return;
      setState(() => _count = items.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: _count > 0,
      label: Text(tr(_count > 9 ? '9+' : '$_count')),
      child: widget.child,
    );
  }
}
