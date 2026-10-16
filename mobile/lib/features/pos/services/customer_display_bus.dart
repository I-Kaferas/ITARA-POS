import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'pos_cart_engine.dart';

class CustomerDisplayLine {
  const CustomerDisplayLine({
    required this.name,
    required this.quantity,
    required this.price,
  });

  final String name;
  final int quantity;
  final int price;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
      };

  factory CustomerDisplayLine.fromJson(Map<String, dynamic> json) {
    return CustomerDisplayLine(
      name: json['name']?.toString().trim().isNotEmpty == true ? json['name'].toString() : 'Article',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomerDisplaySnapshot {
  const CustomerDisplaySnapshot({
    required this.brandName,
    required this.tagline,
    required this.customerName,
    required this.currencyCode,
    required this.total,
    required this.lines,
    this.locale = '',
    this.dark = false,
  });

  /// Language of the cashier app, so a second window can follow it.
  final String locale;

  /// Theme of the cashier app, for the same reason.
  final bool dark;
  final String brandName;
  final String tagline;
  final String customerName;
  final String currencyCode;
  final int total;
  final List<CustomerDisplayLine> lines;

  bool get isEmpty => lines.isEmpty;

  static const empty = CustomerDisplaySnapshot(
    brandName: 'ITARA',
    tagline: 'Better Business. Brighter Future.',
    customerName: 'Walk-in customer',
    currencyCode: 'USD',
    total: 0,
    lines: [],
  );

  Map<String, dynamic> toJson() => {
        'brand': brandName,
        'tagline': tagline,
        'customer': customerName,
        'currency': currencyCode,
        'total': total,
        'lines': [for (final line in lines) line.toJson()],
        if (locale.isNotEmpty) 'locale': locale,
        if (dark) 'dark': true,
      };

  factory CustomerDisplaySnapshot.fromMessage(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return CustomerDisplaySnapshot.fromJson(_stringKeyMap(decoded));
      } catch (_) {}
      return CustomerDisplaySnapshot.empty;
    }
    if (raw is Map) return CustomerDisplaySnapshot.fromJson(_stringKeyMap(raw));
    return CustomerDisplaySnapshot.empty;
  }

  factory CustomerDisplaySnapshot.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final lines = <CustomerDisplayLine>[];
    if (rawLines is List) {
      for (final item in rawLines) {
        if (item is Map) {
          lines.add(CustomerDisplayLine.fromJson(_stringKeyMap(item)));
        }
      }
    }
    String text(dynamic value, String fallback) {
      final next = value?.toString().trim() ?? '';
      return next.isEmpty ? fallback : next;
    }

    return CustomerDisplaySnapshot(
      brandName: text(json['brand'], 'ITARA'),
      tagline: text(json['tagline'], 'Better Business. Brighter Future.'),
      customerName: text(json['customer'], 'Walk-in customer'),
      currencyCode: text(json['currency'], 'USD'),
      total: (json['total'] as num?)?.toInt() ?? 0,
      lines: lines,
      locale: json['locale']?.toString().trim() ?? '',
      dark: json['dark'] == true,
    );
  }
}

class CustomerDisplayBus extends ChangeNotifier {
  CustomerDisplayBus._();

  static final CustomerDisplayBus instance = CustomerDisplayBus._();

  CustomerDisplaySnapshot snapshot = CustomerDisplaySnapshot.empty;

  void publish(CustomerDisplaySnapshot next) {
    snapshot = next;
    notifyListeners();
  }

  void publishCart(
    PosCartEngine cart, {
    required String brandName,
    required String currencyCode,
    String tagline = 'Better Business. Brighter Future.',
  }) {
    final customer = cart.customer?.name.trim() ?? '';
    publish(
      CustomerDisplaySnapshot(
        brandName: brandName.trim().isEmpty ? 'ITARA' : brandName.trim(),
        tagline: tagline.trim().isEmpty ? 'Better Business. Brighter Future.' : tagline.trim(),
        customerName: customer.isEmpty ? 'Walk-in customer' : customer,
        currencyCode: currencyCode.trim().isEmpty ? 'USD' : currencyCode.trim(),
        total: cart.total,
        lines: [
          for (final line in cart.lines)
            CustomerDisplayLine(
              name: line.displayName,
              quantity: line.quantity,
              price: (line.lineSubtotal - line.lineDiscountFixed).clamp(0, line.lineSubtotal),
            ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _stringKeyMap(Map raw) {
  return raw.map((key, value) => MapEntry(key.toString(), value));
}
