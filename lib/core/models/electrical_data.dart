class ElectricalData {
  const ElectricalData({
    required this.voltage,
    required this.current,
    required this.power,
    required this.energy,
  });

  final double voltage;
  final double current;
  final double power;
  final double energy;

  factory ElectricalData.fromMap(Map<String, dynamic> map) {
    return ElectricalData(
      voltage: _toDouble(map['voltage']),
      current: _toDouble(map['current']),
      power: _toDouble(map['power']),
      energy: _toDouble(map['energy']),
    );
  }

  static ElectricalData empty() {
    return const ElectricalData(
      voltage: 0,
      current: 0,
      power: 0,
      energy: 0,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}
