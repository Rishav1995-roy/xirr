import 'package:test/test.dart';
import 'package:xirr/xirr.dart';

import 'reference.dart';

void main() {
  group('Investment: lump sum', () {
    final inv = Investment(
      name: 'Fund A',
      transactions: [
        InvestmentTransaction.purchase(DateTime(2022, 1, 1), 10000)
      ],
      currentValue: 11000,
      valuationDate: DateTime(2023, 1, 1),
    );

    test('numbers', () {
      expect(inv.totalInvested, 10000);
      expect(inv.totalWithdrawn, 0);
      expect(inv.gain, 1000);
      expect(inv.absoluteReturn, closeTo(0.1, 1e-15));
      expect(inv.xirr(), closeTo(0.1, 1e-10)); // 365 days
      expect(inv.tryXirr(), closeTo(0.1, 1e-10));
      expect(inv.name, 'Fund A');
    });

    test('cash flows carry signs and the terminal value', () {
      final f = inv.cashFlows;
      expect(f.map((c) => c.amount), [-10000, 11000]);
      expect(f.last.date, DateTime.utc(2023, 1, 1));
    });

    test('summary', () {
      final s = inv.summary();
      expect(s.invested, 10000);
      expect(s.withdrawn, 0);
      expect(s.currentValue, 11000);
      expect(s.gain, 1000);
      expect(s.absoluteReturn, closeTo(0.1, 1e-15));
      expect(s.xirr, closeTo(0.1, 1e-10));
      expect(s.toString(), contains('InvestmentSummary'));
    });

    test('options are passed through', () {
      expect(
        inv.xirr(options: const XirrOptions(dayCount: DayCount.actual360)),
        isNot(closeTo(0.1, 1e-4)),
      );
      expect(
          inv
              .summary(
                  options: const XirrOptions(method: SolverMethod.bisection))
              .xirr,
          closeTo(0.1, 1e-8));
    });
  });

  group('Investment: SIP with redemption and dividend', () {
    final sip =
        sipSchedule(amount: 5000, start: DateTime(2022, 1, 10), count: 12);
    final txns = [
      for (final f in sip) InvestmentTransaction.sip(f.date, -f.amount),
      InvestmentTransaction.dividend(DateTime(2022, 9, 1), 800),
      InvestmentTransaction.redemption(DateTime(2023, 3, 1), 10000),
    ];
    final inv = Investment(
      transactions: txns.reversed, // order must not matter
      currentValue: 61000,
      valuationDate: DateTime(2023, 6, 30),
    );

    test('totals', () {
      expect(inv.totalInvested, 60000);
      expect(inv.totalWithdrawn, 10800);
      expect(inv.gain, 61000 + 10800 - 60000);
      expect(inv.absoluteReturn, closeTo(11800 / 60000, 1e-12));
    });

    test('transactions are sorted and unmodifiable', () {
      expect(inv.transactions.first.date, DateTime.utc(2022, 1, 10));
      expect(() => inv.transactions.add(txns.first), throwsUnsupportedError);
    });

    test('xirr matches the independent reference', () {
      expect(inv.xirr(), closeTo(refXirr(inv.cashFlows), 1e-9));
    });
  });

  group('Investment: edge cases', () {
    test('fully redeemed holding has no terminal flow', () {
      final inv = Investment(
        transactions: [
          InvestmentTransaction.purchase(DateTime(2022, 1, 1), 1000),
          InvestmentTransaction.redemption(DateTime(2023, 1, 1), 1200),
        ],
        currentValue: 0,
        valuationDate: DateTime(2023, 6, 1),
      );
      expect(inv.cashFlows.length, 2);
      expect(inv.xirr(), closeTo(0.2, 1e-10));
    });

    test('nothing invested: absolute return and xirr are null', () {
      final inv = Investment(
        transactions: const [],
        currentValue: 500,
        valuationDate: DateTime(2023, 1, 1),
      );
      expect(inv.absoluteReturn, isNull);
      expect(inv.tryXirr(), isNull);
      expect(inv.xirr, throwsA(isA<InsufficientCashFlowsException>()));
      final s = inv.summary();
      expect(s.absoluteReturn, isNull);
      expect(s.xirr, isNull);
      expect(s.gain, 500);
    });

    test('a loss gives a negative xirr', () {
      final inv = Investment(
        transactions: [
          InvestmentTransaction.purchase(DateTime(2022, 1, 1), 1000)
        ],
        currentValue: 800,
        valuationDate: DateTime(2023, 1, 1),
      );
      expect(inv.xirr(), closeTo(-0.2, 1e-10));
      expect(inv.gain, -200);
    });

    test('same-day purchase and sale merge', () {
      final inv = Investment(
        transactions: [
          InvestmentTransaction.purchase(DateTime(2022, 1, 1), 1000),
          InvestmentTransaction.purchase(DateTime(2022, 1, 1, 15), 500),
        ],
        currentValue: 1650,
        valuationDate: DateTime(2023, 1, 1),
      );
      expect(inv.xirr(), closeTo(0.1, 1e-10));
    });

    test('invalid input', () {
      final v = DateTime(2023, 1, 1);
      expect(
        () => Investment(
            transactions: const [], currentValue: -1, valuationDate: v),
        throwsA(isA<InvalidCashFlowException>()),
      );
      expect(
        () => Investment(
            transactions: const [], currentValue: double.nan, valuationDate: v),
        throwsA(isA<InvalidCashFlowException>()),
      );
      expect(
        () => Investment(
          transactions: [
            InvestmentTransaction.purchase(DateTime(2022, 1, 1), -5)
          ],
          currentValue: 1,
          valuationDate: v,
        ),
        throwsA(isA<InvalidCashFlowException>()),
      );
      expect(
        () => Investment(
          transactions: [
            InvestmentTransaction.purchase(DateTime(2023, 1, 2), 5)
          ],
          currentValue: 1,
          valuationDate: v,
        ),
        throwsA(isA<InvalidCashFlowException>()),
      );
    });
  });

  group('InvestmentTransaction', () {
    final d = DateTime(2024, 1, 1, 10);
    test('named constructors set the type', () {
      expect(
          InvestmentTransaction.purchase(d, 1).type, TransactionType.purchase);
      expect(InvestmentTransaction.sip(d, 1).type, TransactionType.sip);
      expect(
          InvestmentTransaction.switchIn(d, 1).type, TransactionType.switchIn);
      expect(InvestmentTransaction.redemption(d, 1).type,
          TransactionType.redemption);
      expect(
          InvestmentTransaction.dividend(d, 1).type, TransactionType.dividend);
      expect(InvestmentTransaction.switchOut(d, 1).type,
          TransactionType.switchOut);
    });

    test('signs', () {
      for (final t in TransactionType.values) {
        final tx = InvestmentTransaction(d, 7, t);
        expect(tx.signedAmount, t.isInvestment ? -7 : 7, reason: t.name);
        expect(tx.toCashFlow().amount, tx.signedAmount);
        expect(tx.date, DateTime.utc(2024, 1, 1));
      }
    });

    test('toString', () {
      expect(
        InvestmentTransaction.sip(DateTime(2024, 1, 5), 100).toString(),
        'InvestmentTransaction(2024-01-05, sip, 100.0)',
      );
    });
  });

  group('Portfolio', () {
    final a = Investment(
      transactions: [
        InvestmentTransaction.purchase(DateTime(2022, 1, 1), 1000)
      ],
      currentValue: 1100,
      valuationDate: DateTime(2023, 1, 1),
    );
    final b = Investment(
      transactions: [
        InvestmentTransaction.purchase(DateTime(2022, 1, 1), 3000),
        InvestmentTransaction.dividend(DateTime(2022, 7, 1), 100),
      ],
      currentValue: 3600,
      valuationDate: DateTime(2023, 1, 1),
    );
    final p = Portfolio([a, b]);

    test('aggregates', () {
      expect(p.investments.length, 2);
      expect(p.totalInvested, 4000);
      expect(p.totalWithdrawn, 100);
      expect(p.currentValue, 4700);
      expect(p.gain, 800);
      expect(p.absoluteReturn, closeTo(0.2, 1e-15));
      expect(p.cashFlows.length, 5);
      expect(p.xirr(), closeTo(refXirr(p.cashFlows), 1e-9));
      expect(p.tryXirr(), closeTo(p.xirr(), 1e-15));
    });

    test('summary', () {
      final s = p.summary();
      expect(s.invested, 4000);
      expect(s.xirr, closeTo(p.xirr(), 1e-15));
    });

    test('switching between two funds in one portfolio nets out', () {
      final from = Investment(
        transactions: [
          InvestmentTransaction.purchase(DateTime(2022, 1, 1), 1000),
          InvestmentTransaction.switchOut(DateTime(2022, 7, 1), 1050),
        ],
        currentValue: 0,
        valuationDate: DateTime(2023, 1, 1),
      );
      final to = Investment(
        transactions: [
          InvestmentTransaction.switchIn(DateTime(2022, 7, 1), 1050)
        ],
        currentValue: 1100,
        valuationDate: DateTime(2023, 1, 1),
      );
      final combined = Portfolio([from, to]);
      final direct = Investment(
        transactions: [
          InvestmentTransaction.purchase(DateTime(2022, 1, 1), 1000)
        ],
        currentValue: 1100,
        valuationDate: DateTime(2023, 1, 1),
      );
      expect(combined.xirr(), closeTo(direct.xirr(), 1e-10));
    });

    test('empty portfolio', () {
      final e = Portfolio(const []);
      expect(e.totalInvested, 0);
      expect(e.absoluteReturn, isNull);
      expect(e.tryXirr(), isNull);
      expect(e.summary().xirr, isNull);
    });
  });
}
