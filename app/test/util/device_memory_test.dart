import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/device_memory.dart';

void main() {
  test('parses MemTotal from /proc/meminfo', () {
    const meminfo = 'MemTotal:        2461788 kB\n'
        'MemFree:           91420 kB\n'
        'MemAvailable:     612344 kB\n';
    expect(DeviceMemory.parseMemTotalKb(meminfo), 2461788);
  });

  test('returns null without a MemTotal line', () {
    expect(DeviceMemory.parseMemTotalKb('MemFree: 91420 kB\n'), isNull);
    expect(DeviceMemory.parseMemTotalKb(''), isNull);
  });

  test('a 2.5 GB TV is constrained, a 4 GB device and an unknown one are not',
      () {
    expect(DeviceMemory.isConstrainedTotal(2461788), isTrue);
    expect(DeviceMemory.isConstrainedTotal(3 * 1024 * 1024), isFalse);
    expect(DeviceMemory.isConstrainedTotal(3880000), isFalse);
    expect(DeviceMemory.isConstrainedTotal(null), isFalse);
  });

  test('debugSetTotalKb overrides the reading', () {
    DeviceMemory.debugSetTotalKb(2000000);
    expect(DeviceMemory.isConstrained, isTrue);
    DeviceMemory.debugSetTotalKb(8000000);
    expect(DeviceMemory.isConstrained, isFalse);
  });
}
