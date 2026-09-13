import '../../../core/api/api_client.dart';
import '../../../core/config/terminal_config_repository.dart';

class RegisteredDevice {
  const RegisteredDevice({
    required this.id,
    required this.name,
    required this.posRole,
  });

  final String id;
  final String name;
  final String posRole;

  factory RegisteredDevice.fromJson(Map<String, dynamic> json) {
    return RegisteredDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      posRole: json['pos_role']?.toString() ?? 'standalone',
    );
  }
}

class DeviceApiService {
  DeviceApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<RegisteredDevice>> fetchDevices() async {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    final body = await _client.get('/stores/$storeId/devices');
    final data = body['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((item) => RegisteredDevice.fromJson(Map<String, dynamic>.from(item)))
        .where((device) => device.id.isNotEmpty)
        .toList();
  }

  Future<RegisteredDevice> register({
    required String name,
    required String identifier,
    required String posRole,
    String? masterDeviceId,
    String? masterHost,
    String? platform,
    String? appVersion,
  }) async {
    final storeId = TerminalConfigRepository.instance.config.storeId;
    final body = await _client.post(
      '/stores/$storeId/devices/register',
      body: {
        'name': name,
        'identifier': identifier,
        'pos_role': posRole,
        'device_type': 'pos',
        'category': 'pos',
        if (masterDeviceId != null && masterDeviceId.isNotEmpty) 'master_device_id': masterDeviceId,
        if (masterHost != null && masterHost.isNotEmpty) 'master_host': masterHost,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
        if (appVersion != null && appVersion.isNotEmpty) 'app_version': appVersion,
      },
    );
    final data = body['data'];
    if (data is Map) {
      return RegisteredDevice.fromJson(Map<String, dynamic>.from(data));
    }
    return RegisteredDevice.fromJson(body);
  }
}
