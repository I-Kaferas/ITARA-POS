import 'dart:async';

import 'package:flutter/material.dart';

import '../data/notification_watch.dart';

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
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
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
      label: Text(_count > 9 ? '9+' : '$_count'),
      child: widget.child,
    );
  }
}
