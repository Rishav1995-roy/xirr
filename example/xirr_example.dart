// ignore_for_file: avoid_print
import 'package:xirr/xirr.dart';

void main() {
  basic();
  sipWithRedemption();
  customisation();
  errorHandling();
}

/// The classic Excel XIRR example from Microsoft's documentation.
void basic() {
  final flows = [
    CashFlow(DateTime(2008, 1, 1), -10000),
    CashFlow(DateTime(2008, 3, 1), 2750),
    CashFlow(DateTime(2008, 10, 30), 4250),
    CashFlow(DateTime(2009, 2, 15), 3250),
    CashFlow(DateTime(2009, 4, 1), 2750),
  ];
  print('Excel example XIRR: ${formatRate(xirr(flows))}'); // 37.34%
}

/// A monthly SIP of 10,000 for 24 months, a part redemption, and the
/// current market value of what is left.
void sipWithRedemption() {
  final instalments = sipSchedule(
    amount: 10000,
    start: DateTime(2022, 1, 31), // month-end safe: Feb 28, Mar 31, ...
    count: 24,
  );

  final fund = Investment(
    name: 'Example Flexi Cap Fund',
    transactions: [
      for (final f in instalments) InvestmentTransaction.sip(f.date, -f.amount),
      InvestmentTransaction.redemption(DateTime(2023, 6, 15), 50000),
    ],
    currentValue: 232000,
    valuationDate: DateTime(2024, 3, 31),
  );

  final s = fund.summary();
  print('--- ${fund.name} ---');
  print('Invested      : ${s.invested}');
  print('Withdrawn     : ${s.withdrawn}');
  print('Current value : ${s.currentValue}');
  print('Gain          : ${s.gain}');
  print('Absolute      : ${formatRate(s.absoluteReturn!)}');
  print('XIRR          : ${formatRate(s.xirr!)}');
}

/// Options: day count, solver, tolerance, diagnostics.
void customisation() {
  final flows = [
    CashFlow(DateTime(2020, 1, 1), -100000),
    CashFlow(DateTime(2023, 1, 1), 150000),
  ];

  const strict = XirrOptions(
    dayCount: DayCount.actualActual,
    method: SolverMethod.brent,
    tolerance: 1e-12,
  );
  final result = xirrDetailed(flows, options: strict);
  print('Actual/Actual with Brent: ${formatRate(result.rate, decimals: 4)} '
      'after ${result.iterations} iterations (converged: ${result.converged})');

  // Your own day count, for example 30/360.
  final thirty360 = DayCount.custom('30/360', (a, b) {
    final d1 = a.day > 30 ? 30 : a.day;
    final d2 = b.day > 30 && d1 == 30 ? 30 : b.day;
    return (360 * (b.year - a.year) + 30 * (b.month - a.month) + (d2 - d1)) /
        360;
  });
  print(
      '30/360: ${formatRate(xirr(flows, options: XirrOptions(dayCount: thirty360)))}');
}

/// Typed exceptions, or `null` with tryXirr.
void errorHandling() {
  final onlyOutflows = [
    CashFlow(DateTime(2024, 1, 1), -100),
    CashFlow(DateTime(2024, 2, 1), -100),
  ];
  try {
    xirr(onlyOutflows);
  } on NoSignChangeException catch (e) {
    print('Cannot compute: ${e.message}');
  }
  print('tryXirr gives ${tryXirr(onlyOutflows)}');
}
