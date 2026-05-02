// domain/models/remote_command.dart

class RemoteCommand {
  final String type;
  final String action;
  final dynamic value;

  const RemoteCommand(this.type, this.action, [this.value]);

  Map<String, dynamic> toJson() => {'type': type, 'action': action, if (value != null) 'value': value};

  factory RemoteCommand.fromJson(Map<String, dynamic> json) => RemoteCommand(json['type']?.toString() ?? '', json['action']?.toString() ?? '', json['value']);
}
