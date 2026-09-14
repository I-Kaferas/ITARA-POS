import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../accounting/presentation/accounting_screen.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../barcode/presentation/barcode_hub_screen.dart';
import '../../customers/presentation/customer_account_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../notifications/presentation/notification_badge.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../hospitality/presentation/hospitality_screen.dart';
import '../../production/presentation/production_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../services/presentation/services_screen.dart';
import '../../pos/presentation/pos_screen.dart';
import '../data/health_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _healthService = HealthService();
  Map<String, dynamic>? _health;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final health = await _healthService.checkHealth();
      setState(() {
        _health = health;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POS Terminal',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Version ${AppConfig.appVersion}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Text(
              'API Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Checking API connection...'),
                ],
              )
            else if (_health != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${_health!['status']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text('Service: ${_health!['service']}'),
                      Text('Version: ${_health!['version']}'),
                    ],
                  ),
                ),
              )
            else
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'API unreachable',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      if (_error != null) Text(_error!),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _checkHealth,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PosScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Caisse POS'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HospitalityScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.table_restaurant),
              label: const Text('Restaurant & hôtel'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ServicesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.handyman_outlined),
              label: const Text('Services'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProductionScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.restaurant),
              label: const Text('Production'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountingScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_outlined),
              label: const Text('Comptabilité'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReportsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('Rapports'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
              icon: const NotificationBadge(child: Icon(Icons.notifications_outlined)),
              label: const Text('Notifications'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BackupScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.backup_outlined),
              label: const Text('Sauvegardes'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomerAccountScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.card_membership_outlined),
              label: const Text('Fidélité et crédit'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ExpensesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Dépenses'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BarcodeHubScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Codes-barres'),
            ),
          ],
        ),
      ),
    );
  }
}
