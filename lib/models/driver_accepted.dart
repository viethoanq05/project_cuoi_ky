class DriverAccepted {
  final String orderId;
  final String driverId;
  final String status;

  DriverAccepted({
    required this.orderId,
    required this.driverId,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'driverId': driverId,
      'status': status,
    };
  }

  factory DriverAccepted.fromMap(Map<String, dynamic> map) {
    return DriverAccepted(
      orderId: map['orderId'] ?? '',
      driverId: map['driverId'] ?? '',
      status: map['status'] ?? '',
    );
  }
}
