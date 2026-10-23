import 'package:test/test.dart';
import 'package:xirr/xirr.dart';

void main() {
  test('date is normalised to UTC midnight', () {
    final f = CashFlow(DateTime(2024, 5, 17, 13, 45, 12), -10);
    expect(f.date, DateTime.utc(2024, 5, 17));
    expect(f.date.isUtc, isTrue);
  });

  test('UTC input keeps its calendar day', () {
    expect(CashFlow(DateTime.utc(2024, 5, 17, 23, 59), 1).date,
        DateTime.utc(2024, 5, 17));
  });

  test('value semantics', () {
    final a = CashFlow(DateTime(2024, 1, 1), 5);
    final b = CashFlow(DateTime.utc(2024, 1, 1), 5);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == CashFlow(DateTime(2024, 1, 2), 5), isFalse);
    expect(a == CashFlow(DateTime(2024, 1, 1), 6), isFalse);
    expect(a == Object(), isFalse);
    expect({a, b}.length, 1);
  });

  test('copyWith', () {
    final a = CashFlow(DateTime(2024, 1, 1), 5);
    expect(a.copyWith(amount: 7).amount, 7);
    expect(a.copyWith(amount: 7).date, a.date);
    expect(
        a.copyWith(date: DateTime(2025, 2, 3)).date, DateTime.utc(2025, 2, 3));
    expect(a.copyWith(), a);
  });

  test('toString', () {
    expect(CashFlow(DateTime(2024, 1, 9), -2.5).toString(),
        'CashFlow(2024-01-09, -2.5)');
  });
}
