class Device {
  const Device({
    required this.id,
    required this.name,
    this.role = 'slave',
    this.status = 'offline',
  });

  final String id;
  final String name;
  final String role;
  final String status;
}
