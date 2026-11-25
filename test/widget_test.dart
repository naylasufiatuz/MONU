import 'package:flutter_test/flutter_test.dart';
import 'package:monu/models/alert_event.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/device_snapshot.dart';

void main() {
  test('AlertEvent fireEmergency title and message verification', () {
    final alert = AlertEvent(
      id: 1,
      kind: AlertKind.fireEmergency,
      level: SensorLevel.warning,
      startedAt: DateTime.now(),
      sensorId: 'thermocouple',
      value: 65.5,
      thresholdValue: 50.0,
    );

    expect(alert.title, contains('DARURAT'));
    expect(alert.message, contains('pompa air'));
    expect(alert.isActive, isTrue);
  });

  test('DeviceSnapshot parses fire_detected properly', () {
    final snapshot = DeviceSnapshot.fromEsp32Map('monu-esp32-01', {
      'device_id': 'monu-esp32-01',
      'device_name': 'MONU ESP32 Node',
      'status': 'online',
      'fire_detected': true,
      'pump_status': true,
      'thermocouple': {
        'temperature': 58.0,
        'status': 'FIRE_ALERT',
        'fire_detected': true,
      },
    });

    expect(snapshot.fireDetected, isTrue);
    expect(snapshot.pumpActive, isTrue);
    expect(snapshot.valueOf('thermocouple'), 58.0);
  });
}
