class HdmiPortModel {
  final String id;
  final String label;
  final int portNumber;
  final bool isConnected;
  final bool isActiveSignal; // true if connected and actively sending video/audio frames (state 0)
  final String customLabel;
  final String connectedDeviceName; // CEC detected name e.g. "Tata Play", "PlayStation"

  const HdmiPortModel({
    required this.id,
    required this.label,
    required this.portNumber,
    this.isConnected = true,
    this.isActiveSignal = false,
    this.customLabel = '',
    this.connectedDeviceName = '',
  });

  factory HdmiPortModel.fromMap(Map<String, dynamic> map) {
    return HdmiPortModel(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? 'HDMI',
      portNumber: map['port_number'] is int ? map['port_number'] as int : 0,
      isConnected: map['is_connected'] == true,
      isActiveSignal: map['is_active_signal'] == true,
      customLabel: map['custom_label']?.toString() ?? '',
      connectedDeviceName: map['connected_device_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'port_number': portNumber,
      'is_connected': isConnected,
      'is_active_signal': isActiveSignal,
      'custom_label': customLabel,
      'connected_device_name': connectedDeviceName,
    };
  }
}
