import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/pos/presentation/widgets/pos_product_grid.dart';

void main() {
  test('rewrites loopback storage URLs onto the configured API host', () {
    expect(
      resolvePosImageUrl(
        'http://127.0.0.1:8001/storage/tenant/products/photo.png',
        apiBaseUrl: 'http://192.168.1.20:8001/api/v1',
      ),
      'http://192.168.1.20:8001/storage/tenant/products/photo.png',
    );
    expect(
      resolvePosImageUrl(
        'http://localhost:8001/storage/tenant/products/photo.png',
        apiBaseUrl: 'http://10.0.2.2:8001/api/v1',
      ),
      'http://10.0.2.2:8001/storage/tenant/products/photo.png',
    );
  });

  test('keeps public CDN URLs and resolves relative storage paths', () {
    expect(
      resolvePosImageUrl(
        'https://cdn.example.com/products/photo.png',
        apiBaseUrl: 'http://192.168.1.20:8001/api/v1',
      ),
      'https://cdn.example.com/products/photo.png',
    );
    expect(
      resolvePosImageUrl(
        '/storage/tenant/products/photo.png',
        apiBaseUrl: 'http://192.168.1.20:8001/api/v1',
      ),
      'http://192.168.1.20:8001/storage/tenant/products/photo.png',
    );
  });
}
