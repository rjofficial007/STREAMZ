// domain/models/remote_command.dart

class RemoteCommand {
  final String type;
  final String action;
  final dynamic value;
  final String? targetId; // Targeted clientId
  final String? senderId; // Originator clientId

  const RemoteCommand(this.type, this.action, [this.value, this.targetId, this.senderId]);

  Map<String, dynamic> toJson() => {
    'type': type, 
    'action': action, 
    if (value != null) 'value': value, 
    if (targetId != null) 'targetId': targetId,
    if (senderId != null) 'senderId': senderId,
  };

  factory RemoteCommand.fromJson(Map<String, dynamic> json) => RemoteCommand(
    json['type']?.toString() ?? '', 
    json['action']?.toString() ?? '', 
    json['value'], 
    json['targetId']?.toString(),
    json['senderId']?.toString(),
  );
}
