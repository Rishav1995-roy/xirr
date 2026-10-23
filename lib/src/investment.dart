import 'cash_flow.dart';
import 'dates.dart';
import 'exceptions.dart';
import 'options.dart';
import 'xirr_core.dart';

/// The kind of an [InvestmentTransaction]; it decides the direction of the
/// money.
enum TransactionType {
  /// Lump-sum purchase. Money goes in.
  purchase,

  /// A SIP instalment. Money goes in.
  sip,

  /// Units switched into this investment from another one. Money goes in.
  switchIn,

  /// Units sold. Money comes back.
  redemption,

  /// A dividend (IDCW) paid out in cash. Money comes back. A dividend that is
  /// reinvested is a [purchase] instead.
  dividend,

  /// Units switched out of this investment into another one. Money comes back.
  switchOut;

  /// `true` for the types where the investor pays money in.
  bool get isInvestment => this == purchase || this == sip || this == switchIn;
}

/// One transaction of an [Investment], stored as a positive [amount] plus a
/// [type] that decides the direction.
///
/// For a single fund or scheme, a switch-in counts as money invested and a
/// switch-out as money withdrawn. If you analyse both sides of a switch in one
/// [Portfolio] they cancel out, as they should.
final class InvestmentTransaction {
  /// Creates a transaction of [amount] (zero or positive) on the calendar day
  /// of [date].
  InvestmentTransaction(DateTime date, this.amount, this.type)
      : date = dateOnly(date);

  /// A lump-sum purchase.
  InvestmentTransaction.purchase(DateTime date, double amount)
      : this(date, amount, TransactionType.purchase);

  /// A SIP instalment.
  InvestmentTransaction.sip(DateTime date, double amount)
      : this(date, amount, TransactionType.sip);

  /// A switch into the investment.
  InvestmentTransaction.switchIn(DateTime date, double amount)
      : this(date, amount, TransactionType.switchIn);

  /// A redemption (sale).
  InvestmentTransaction.redemption(DateTime date, double amount)
      : this(date, amount, TransactionType.redemption);

  /// A cash dividend payout.
  InvestmentTransaction.dividend(DateTime date, double amount)
      : this(date, amount, TransactionType.dividend);

  /// A switch out of the investment.
  InvestmentTransaction.switchOut(DateTime date, double amount)
      : this(date, amount, TransactionType.switchOut);

  /// Calendar day (UTC, date-only).
  final DateTime date;

  /// Size of the transaction, zero or positive. The direction comes from
  /// [type].
  final double amount;

  /// What kind of transaction this is.
  final TransactionType type;

  /// The amount with the investor's sign: negative for money paid in,
  /// positive for money received.
  double get signedAmount => type.isInvestment ? -amount : amount;

  /// This transaction as a [CashFlow].
  CashFlow toCashFlow() => CashFlow(date, signedAmount);

  @override
  String toString() => 'InvestmentTransaction(${isoDate(date)}, '
      '${type.name}, $amount)';
}

/// Headline numbers of an [Investment] or [Portfolio].
final class InvestmentSummary {
  /// Creates a summary.
  const InvestmentSummary({
    required this.invested,
    required this.withdrawn,
    required this.currentValue,
    required this.gain,
    required this.absoluteReturn,
    required this.xirr,
  });

  /// Total money paid in (purchases, SIP instalments, switch-ins).
  final double invested;

  /// Total money already taken out (redemptions, dividends, switch-outs).
  final double withdrawn;

  /// Market value on the valuation date.
  final double currentValue;

  /// `currentValue + withdrawn - invested`.
  final double gain;

  /// `gain / invested` as a fraction, or `null` when nothing was invested.
  final double? absoluteReturn;

  /// Annualised return as a fraction, or `null` if it cannot be computed
  /// (see `Investment.tryXirr`).
  final double? xirr;

  @override
  String toString() => 'InvestmentSummary(invested: $invested, '
      'withdrawn: $withdrawn, currentValue: $currentValue, gain: $gain, '
      'absoluteReturn: $absoluteReturn, xirr: $xirr)';
}

/// A holding described by its transactions and its current market value, e.g.
/// one mutual fund folio.
///
/// ```dart
/// final fund = Investment(
///   transactions: [
///     InvestmentTransaction.purchase(DateTime(2023, 1, 10), 50000),
///     InvestmentTransaction.sip(DateTime(2023, 2, 10), 5000),
///     InvestmentTransaction.redemption(DateTime(2023, 9, 1), 10000),
///   ],
///   currentValue: 62000,
///   valuationDate: DateTime(2024, 1, 10),
/// );
/// print(fund.summary().xirr);
/// ```
///
/// The cash flows used for XIRR are every transaction (with its sign) plus the
/// [currentValue] as a final inflow on the [valuationDate], as if the holding
/// were sold that day.
final class Investment {
  /// Creates an investment.
  ///
  /// Throws [InvalidCashFlowException] if an amount or [currentValue] is
  /// negative or not finite, or a transaction is dated after [valuationDate].
  Investment({
    required Iterable<InvestmentTransaction> transactions,
    required this.currentValue,
    required DateTime valuationDate,
    this.name,
  })  : valuationDate = dateOnly(valuationDate),
        transactions = List.unmodifiable(
          (transactions.toList()..sort((a, b) => a.date.compareTo(b.date))),
        ) {
    _checkValue(currentValue, -1);
    for (var i = 0; i < this.transactions.length; i++) {
      final t = this.transactions[i];
      _checkValue(t.amount, i);
      if (t.date.isAfter(this.valuationDate)) {
        throw InvalidCashFlowException(i, t.amount);
      }
    }
  }

  /// Optional label, e.g. a scheme name. Not used in any calculation.
  final String? name;

  /// The transactions, sorted by date.
  final List<InvestmentTransaction> transactions;

  /// Market value on [valuationDate]. Use `0` for a fully redeemed holding.
  final double currentValue;

  /// The day [currentValue] refers to.
  final DateTime valuationDate;

  /// All cash flows: the transactions plus [currentValue] on [valuationDate]
  /// (omitted when `0`).
  List<CashFlow> get cashFlows => [
        for (final t in transactions) t.toCashFlow(),
        if (currentValue != 0) CashFlow(valuationDate, currentValue),
      ];

  /// Total money paid in.
  double get totalInvested => _sum(transactions, invested: true);

  /// Total money already taken out.
  double get totalWithdrawn => _sum(transactions, invested: false);

  /// `currentValue + totalWithdrawn - totalInvested`.
  double get gain => currentValue + totalWithdrawn - totalInvested;

  /// `gain / totalInvested`, or `null` when nothing was invested.
  double? get absoluteReturn =>
      totalInvested == 0 ? null : gain / totalInvested;

  /// The XIRR of [cashFlows]. Throws like `xirr`.
  double xirr({XirrOptions options = const XirrOptions()}) =>
      _xirr(cashFlows, options);

  /// The XIRR, or `null` if it cannot be computed.
  double? tryXirr({XirrOptions options = const XirrOptions()}) =>
      _tryXirr(cashFlows, options);

  /// All headline numbers at once; `xirr` is `null` when not computable.
  InvestmentSummary summary({XirrOptions options = const XirrOptions()}) =>
      InvestmentSummary(
        invested: totalInvested,
        withdrawn: totalWithdrawn,
        currentValue: currentValue,
        gain: gain,
        absoluteReturn: absoluteReturn,
        xirr: tryXirr(options: options),
      );
}

/// Several [Investment]s analysed as one, e.g. all funds of an investor.
///
/// Cash flows of all holdings are pooled, so the XIRR is the money-weighted
/// return of the whole portfolio.
final class Portfolio {
  /// Creates a portfolio from [investments].
  Portfolio(Iterable<Investment> investments)
      : investments = List.unmodifiable(investments);

  /// The holdings.
  final List<Investment> investments;

  /// All cash flows of all holdings.
  List<CashFlow> get cashFlows => [for (final i in investments) ...i.cashFlows];

  /// Total money paid in across holdings.
  double get totalInvested =>
      investments.fold(0.0, (s, i) => s + i.totalInvested);

  /// Total money taken out across holdings.
  double get totalWithdrawn =>
      investments.fold(0.0, (s, i) => s + i.totalWithdrawn);

  /// Sum of the current values.
  double get currentValue =>
      investments.fold(0.0, (s, i) => s + i.currentValue);

  /// `currentValue + totalWithdrawn - totalInvested`.
  double get gain => currentValue + totalWithdrawn - totalInvested;

  /// `gain / totalInvested`, or `null` when nothing was invested.
  double? get absoluteReturn =>
      totalInvested == 0 ? null : gain / totalInvested;

  /// The XIRR of the pooled cash flows. Throws like `xirr`.
  double xirr({XirrOptions options = const XirrOptions()}) =>
      _xirr(cashFlows, options);

  /// The XIRR, or `null` if it cannot be computed.
  double? tryXirr({XirrOptions options = const XirrOptions()}) =>
      _tryXirr(cashFlows, options);

  /// All headline numbers at once; `xirr` is `null` when not computable.
  InvestmentSummary summary({XirrOptions options = const XirrOptions()}) =>
      InvestmentSummary(
        invested: totalInvested,
        withdrawn: totalWithdrawn,
        currentValue: currentValue,
        gain: gain,
        absoluteReturn: absoluteReturn,
        xirr: tryXirr(options: options),
      );
}

void _checkValue(double v, int index) {
  if (!v.isFinite || v < 0) throw InvalidCashFlowException(index, v);
}

double _sum(Iterable<InvestmentTransaction> ts, {required bool invested}) {
  var total = 0.0;
  for (final t in ts) {
    if (t.type.isInvestment == invested) total += t.amount;
  }
  return total;
}

double _xirr(List<CashFlow> flows, XirrOptions options) =>
    xirr(flows, options: options);

double? _tryXirr(List<CashFlow> flows, XirrOptions options) =>
    tryXirr(flows, options: options);
