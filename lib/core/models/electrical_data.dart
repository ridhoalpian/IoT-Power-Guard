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

  static ElectricalData aggregate(Iterable<ElectricalData> values) {
    var count = 0;
    var totalVoltage = 0.0;
    var totalCurrent = 0.0;
    var totalPower = 0.0;
    var totalEnergy = 0.0;

    for (final value in values) {
      count++;
      totalVoltage += value.voltage;
      totalCurrent += value.current;
      totalPower += value.power;
      totalEnergy += value.energy;
    }

    if (count == 0) {
      return empty();
    }

    return ElectricalData(
      voltage: totalVoltage / count,
      current: totalCurrent,
      power: totalPower,
      energy: totalEnergy,
    );
  }

  ElectricalData operator +(ElectricalData other) {
    return ElectricalData(
      voltage: voltage + other.voltage,
      current: current + other.current,
      power: power + other.power,
      energy: energy + other.energy,
    );
  }

  factory ElectricalData.fromMap(Map<String, dynamic> map) {
    return ElectricalData(
      voltage: _toDouble(map['voltage']),
      current: _toDouble(map['current']),
      power: _toDouble(map['power']),
      energy: _toDouble(map['energy']),
    );
  }

  static ElectricalData empty() {
    return const ElectricalData(voltage: 0, current: 0, power: 0, energy: 0);
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
