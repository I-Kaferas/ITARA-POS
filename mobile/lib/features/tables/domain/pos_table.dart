class PosTable {
  const PosTable({
    required this.id,
    required this.name,
    this.zone = '',
    this.seats = 0,
    this.status = 'free',
  });

  final String id;
  final String name;
  final String zone;
  final int seats;
  final String status;
}
