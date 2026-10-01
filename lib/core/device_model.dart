class DeviceInfo {
  final String id;
  final String model;
  final String androidVersion;
  final String ipAddress;
  final String port;
  final int batteryLevel;
  final bool isConnected;
  final DateTime connectedAt;

  DeviceInfo({
    required this.id,
    required this.model,
    required this.androidVersion,
    required this.ipAddress,
    required this.port,
    this.batteryLevel = 0,
    this.isConnected = true,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  DeviceInfo copyWith({
    String? id,
    String? model,
    String? androidVersion,
    String? ipAddress,
    String? port,
    int? batteryLevel,
    bool? isConnected,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      model: model ?? this.model,
      androidVersion: androidVersion ?? this.androidVersion,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isConnected: isConnected ?? this.isConnected,
      connectedAt: connectedAt,
    );
  }

  /// Display name — model name or ID fallback
  String get displayName => model.isNotEmpty ? model : id;

  /// Short IP for display
  String get shortId => '$ipAddress:$port';

  @override
  String toString() => 'DeviceInfo($id, $model, $ipAddress:$port)';
}
