// domain/models/connection_record.dart

class ConnectionRecord {
  final String ip;
  final String network;
  final DateTime time;
  final double transferGB;
  final bool isOnline;

  const ConnectionRecord({required this.ip, required this.network, required this.time, required this.transferGB, required this.isOnline});

  ConnectionRecord copyWith({String? ip, String? network, DateTime? time, double? transferGB, bool? isOnline}) =>
      ConnectionRecord(ip: ip ?? this.ip, network: network ?? this.network, time: time ?? this.time, transferGB: transferGB ?? this.transferGB, isOnline: isOnline ?? this.isOnline);

  Map<String, dynamic> toJson() => {'ip': ip, 'network': network, 'time': time.toIso8601String(), 'transferGB': transferGB};

  factory ConnectionRecord.fromJson(Map<String, dynamic> json) => ConnectionRecord(
    ip: json['ip']?.toString() ?? '',
    network: json['network']?.toString() ?? 'WLAN NODE',
    time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
    transferGB: (json['transferGB'] as num?)?.toDouble() ?? 0.0,
    isOnline: false,
  );
}
