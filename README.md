# xirr

[![pub package](https://img.shields.io/pub/v/xirr.svg)](https://pub.dev/packages/xirr)
[![pub points](https://img.shields.io/pub/points/xirr)](https://pub.dev/packages/xirr/score)
[![CI](https://github.com/Rishav1995-roy/xirr/actions/workflows/ci.yml/badge.svg)](https://github.com/Rishav1995-roy/xirr/actions/workflows/ci.yml)
![coverage](https://img.shields.io/badge/line%20coverage-100%25-brightgreen)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

![xirr: a 12-month SIP and its XIRR in Dart](https://raw.githubusercontent.com/Rishav1995-roy/xirr/main/doc/hero.png)

**XIRR, XNPV, CAGR and SIP returns for Dart and Flutter.** Excel-compatible,
numerically robust, fully customisable, zero dependencies.

`xirr` answers the question every investing app has to answer: *"what annual
return did my money earn when I put it in and took it out on irregular
dates?"* It is the number you see next to a mutual fund, stock or SIP as
"XIRR", and it is the same value as Excel's and Google Sheets' `XIRR`.

```dart
import 'package:xirr/xirr.dart';

final flows = [
  CashFlow(DateTime(2023, 1, 1), -10000), // invested
  CashFlow(DateTime(2024, 1, 1), 11500),  // current value
];
print(formatRate(xirr(flows))); // 15.00%
```

## Why this package

* **It does not fall over.** Hand-rolled Newton loops diverge on very high or
  negative returns, long horizons and flows that start with an inflow.
  `xirr` starts with Newton-Raphson and automatically falls back to Brent's
  method on a bracketed root, so you get an answer, or a clear typed error,
  never a silent `NaN` or an endless loop.
* **Excel-compatible by default.** Actual/365, same equation, same result
  (verified against Microsoft's documented example and an independent
  bisection in the test suite).
* **Customisable.** Day-count conventions (including your own), solver choice,
  guess, tolerance, iteration limit and rate bounds.
* **Built for investing apps.** SIP schedule generator (month-end safe),
  portfolio helper (invested, current value, gain, absolute return, XIRR),
  CAGR and annualised return.
* **Pure Dart, no dependencies.** Works in Flutter on Android, iOS, web
  (JS and WASM), macOS, Windows and Linux, and in server-side Dart.
  `xirr_flutter`, the other XIRR package on pub.dev, has been unmaintained
  since 2023.
* **Fast.** 10,000 cash flows solve in a few milliseconds.
* **Well tested.** 140+ tests, 100 % line coverage, cross-checked against an
  independent reference solver.

## Features

| | |
|---|---|
| `xirr`, `tryXirr`, `xirrDetailed` | Internal rate of return for dated cash flows |
| `xnpv` | Net present value at a rate, optional valuation date |
| `cagr`, `absoluteReturn`, `annualizedReturn` | Simple return maths |
| `sipSchedule` | SIP instalments: daily, business-daily, weekly, fortnightly, monthly, quarterly, half-yearly, yearly |
| `Investment`, `Portfolio` | Transactions plus current value to invested, gain, absolute return and XIRR |
| `XirrOptions` | Guess, tolerance, max iterations, day count, solver method, rate bounds |
| `DayCount` | `actual365`, `actual360`, `actualActual`, or `DayCount.custom(...)` |
| `formatRate` | Locale-free rate formatting |
| `XirrException` | Typed, sealed errors you can `switch` over |

## Install

```sh
dart pub add xirr
```

or in `pubspec.yaml`:

```yaml
dependencies:
  xirr: ^0.0.1
```

Requires Dart 3.6 or newer (Flutter 3.27+).

## Quick start

### Basic XIRR

Negative amounts are money you paid out, positive amounts are money you
received. Only the calendar day matters; times and time zones are ignored.

```dart
final flows = [
  CashFlow(DateTime(2008, 1, 1), -10000),
  CashFlow(DateTime(2008, 3, 1), 2750),
  CashFlow(DateTime(2008, 10, 30), 4250),
  CashFlow(DateTime(2009, 2, 15), 3250),
  CashFlow(DateTime(2009, 4, 1), 2750),
];

final rate = xirr(flows);          // 0.37336253351883...
print(formatRate(rate));           // 37.34%
print(xnpv(rate, flows));          // ~0
```

This is the example from Microsoft's Excel documentation (result 0.373362535).

### SIP and mutual fund returns

```dart
final instalments = sipSchedule(
  amount: 10000,
  start: DateTime(2022, 1, 31),   // Jan 31, Feb 28, Mar 31, Apr 30, ...
  count: 24,
);

final fund = Investment(
  transactions: [
    for (final f in instalments) InvestmentTransaction.sip(f.date, -f.amount),
    InvestmentTransaction.redemption(DateTime(2023, 6, 15), 50000),
  ],
  currentValue: 232000,
  valuationDate: DateTime(2024, 3, 31),
);

final s = fund.summary();
print(s.invested);                      // 240000.0
print(s.gain);                          // 42000.0
print(formatRate(s.absoluteReturn!));   // 17.50%
print(formatRate(s.xirr!));             // 16.00%
```

![Monthly SIP outflows and the final value, XIRR 21.45%](https://raw.githubusercontent.com/Rishav1995-roy/xirr/main/doc/cashflows.png)

The chart shows a 12-month SIP of 5,000 (`sipSchedule(amount: 5000, start: DateTime(2024, 1, 5), count: 12)`) valued at 66,800 on 5 Jan 2025: XIRR 21.45%.

Transaction types: `purchase`, `sip`, `switchIn` (money in) and `redemption`,
`dividend`, `switchOut` (money out). Combine several funds with
`Portfolio([fundA, fundB])`.

### Customisation

```dart
const options = XirrOptions(
  guess: 0.15,                       // starting point (default 0.1)
  tolerance: 1e-12,                  // rate precision (default 1e-10)
  maxIterations: 200,                // default 100
  dayCount: DayCount.actualActual,   // default DayCount.actual365
  method: SolverMethod.brent,        // auto | newton | brent | bisection
  minRate: -0.99,                    // search bounds (default -0.999999999 ... 1e9)
  maxRate: 100,
);
final rate = xirr(flows, options: options);
```

Bring your own day count:

```dart
final thirty360 = DayCount.custom('30/360', (a, b) {
  final d1 = a.day > 30 ? 30 : a.day;
  final d2 = b.day > 30 && d1 == 30 ? 30 : b.day;
  return (360 * (b.year - a.year) + 30 * (b.month - a.month) + (d2 - d1)) / 360;
});
xirr(flows, options: XirrOptions(dayCount: thirty360));
```

Business days, holidays and SIP adjustment are configurable too:

```dart
sipSchedule(
  amount: 5000,
  start: DateTime(2024, 6, 1),                  // a Saturday
  count: 12,
  adjustment: BusinessDayAdjustment.following,  // process on Monday
  isBusinessDay: (d) => d.weekday < 6 && !myHolidays.contains(d),
);
```

Formatting never depends on a locale:

```dart
formatRate(0.12345);                        // 12.35%
formatRate(0.0321, decimalSeparator: ',');  // 3,21%
formatRate(0.05, showPlus: true);           // +5.00%
formatRate(0.1, asPercent: false);          // 0.10
```

### Error handling

```dart
try {
  xirr(flows);
} on NoSignChangeException {
  // all flows have the same sign
} on InsufficientCashFlowsException {
  // fewer than two non-zero flows
} on InvalidCashFlowException catch (e) {
  // NaN or infinite amount at index e.index
} on NonConvergenceException {
  // no rate in the allowed range satisfies the flows
}

final maybe = tryXirr(flows); // null instead of an exception
```

`XirrException` is a sealed class, so a `switch` over it is checked for
exhaustiveness by the compiler.

### Diagnostics

```dart
final r = xirrDetailed(flows);
print(r.rate);          // the answer
print(r.converged);     // false instead of throwing when no root was found
print(r.iterations);    // solver iterations used
print(r.method);        // newton or brent: who actually produced the answer
print(r.residual);      // NPV at the answer, ~0
print(r.cashFlowCount); // flows used after merging same-day flows
```

## API at a glance

| Function / class | Purpose |
|---|---|
| `double xirr(flows, {options})` | XIRR, throws `XirrException` |
| `double? tryXirr(flows, {options})` | XIRR or `null` |
| `XirrResult xirrDetailed(flows, {options})` | Rate plus iterations, method, residual, `converged` |
| `double xnpv(rate, flows, {dayCount, asOf})` | Net present value |
| `double cagr(start, end, startDate, endDate, {dayCount})` | `(end/start)^(1/years) - 1` |
| `double absoluteReturn(invested, current)` | `(current - invested) / invested` |
| `double annualizedReturn(total, startDate, endDate, {dayCount})` | `(1 + total)^(1/years) - 1` |
| `List<CashFlow> sipSchedule({amount, start, frequency, count, until, ...})` | SIP instalments |
| `Investment`, `Portfolio` | `totalInvested`, `totalWithdrawn`, `currentValue`, `gain`, `absoluteReturn`, `xirr()`, `tryXirr()`, `summary()` |
| `InvestmentTransaction` | `.purchase`, `.sip`, `.switchIn`, `.redemption`, `.dividend`, `.switchOut` |
| `String formatRate(rate, {decimals, asPercent, showPlus, decimalSeparator, percentSymbol})` | Display helper |
| `CashFlow(date, amount)` | One dated amount, date normalised to a UTC calendar day |
| `XirrOptions`, `SolverMethod`, `DayCount` | Customisation |

## Excel compatibility

With default options `xirr` solves the same equation as Excel and Google
Sheets:

```
sum( amount_i / (1 + rate) ^ ((date_i - date_0) / 365) ) = 0
```

Notes on the differences you may notice:

* Excel's documentation says it iterates until the result is accurate to
  0.000001 percent (1e-8) and returns `#NUM!` when that fails. `xirr` iterates
  to 1e-10 by default, so the last digits can differ, and it has a fallback
  solver for series where a plain Newton iteration does not converge.
* Excel treats the *first* flow as the start of the schedule. `xirr` sorts
  the flows and uses the earliest date. For valid Excel input these are the
  same.
* Flows on the same day are added together; zero amounts are ignored.

## Accuracy and convergence

The rate `r` is solved in log space (`x = ln(1 + r)`), where the present value
becomes a sum of exponentials `sum a_i * e^(-t_i * x)`. This keeps the
numbers finite for 200-year horizons and rates a hair above -100 %, and it
makes the function smooth over the whole search range.

1. **Newton-Raphson** starts from your guess. It usually needs 4 to 8 steps.
2. If it fails (flat slope, leaves the bounds, no convergence in 50 steps, or
   a poor end point) the solver walks outwards from the guess until the net
   present value changes sign, then runs **Brent's method** on that bracket.
   Brent's method cannot diverge once a sign change is bracketed.
3. If no sign change exists inside `[minRate, maxRate]` the call throws
   `NonConvergenceException` (or `xirrDetailed` reports `converged: false`).

Cash flows that change sign more than once can have several valid rates. The
result is the root nearest to `guess`; change the guess to look for others.

## FAQ

**Do I need Flutter?** No. It is pure Dart and works anywhere Dart runs.

**Why is my result 0.1 and not 10?** Rates are fractions. Use
`formatRate(rate)` to show `10.00%`.

**What sign do I use?** Money you pay is negative, money you receive is
positive. The current market value of a holding counts as a positive flow on
the valuation date.

**Which day count should I use?** Leave the default (`actual365`) to match
Excel and most investing apps. Choose `actualActual` if you want one calendar
year to equal exactly 1.0 even in leap years.

**Why `NoSignChangeException`?** A rate of return needs money going out and
coming back. If every amount has the same sign there is no solution.

**Are time zones a problem?** No. Dates are reduced to calendar days in the
constructor of `CashFlow`, so a local `DateTime` and the same day in UTC give
identical results across daylight-saving changes.

**Can I get the result for 1 000 000 % returns?** Yes, up to `maxRate`
(default 1e9, which is 10^11 percent).

## Contributing

Issues and pull requests are welcome at
<https://github.com/Rishav1995-roy/xirr>. Please run

```sh
dart format .
dart analyze --fatal-infos
dart test
```

before opening a pull request, and add a test for every behaviour change.

## Disclaimer

This package is a calculation library. Its results are for information only and are not financial, investment or tax advice. Check figures that matter against an independent source.

## License

MIT, see [LICENSE](LICENSE). Copyright (c) 2026 Rishav Deb Roy.
