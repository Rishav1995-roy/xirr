import 'package:test/test.dart';
import 'package:xirr/xirr.dart';

void main() {
  test('defaults', () {
    expect(formatRate(0.12345), '12.35%');
    expect(formatRate(-0.5), '-50.00%');
    expect(formatRate(0), '0.00%');
  });

  test('decimals', () {
    expect(formatRate(0.12345, decimals: 0), '12%');
    expect(formatRate(0.123456, decimals: 4), '12.3456%');
  });

  test('plain fraction', () {
    expect(formatRate(0.1, asPercent: false), '0.10');
    expect(formatRate(0.1, asPercent: false, decimals: 3), '0.100');
  });

  test('separator and symbol are not locale dependent', () {
    expect(formatRate(0.0321, decimalSeparator: ','), '3,21%');
    expect(formatRate(0.0321, percentSymbol: ' %'), '3.21 %');
    expect(formatRate(0.0321, decimals: 0, decimalSeparator: ','), '3%');
  });

  test('sign handling', () {
    expect(formatRate(0.05, showPlus: true), '+5.00%');
    expect(formatRate(-0.05, showPlus: true), '-5.00%');
    expect(formatRate(0, showPlus: true), '0.00%');
    expect(formatRate(-0.00001), '0.00%');
    expect(formatRate(0.00001, showPlus: true), '0.00%');
  });

  test('non-finite values', () {
    expect(formatRate(double.nan), 'NaN');
    expect(formatRate(double.infinity), 'Infinity');
    expect(formatRate(double.negativeInfinity), '-Infinity');
  });

  test('decimals range', () {
    expect(() => formatRate(0.1, decimals: -1), throwsRangeError);
    expect(() => formatRate(0.1, decimals: 21), throwsRangeError);
  });
}
