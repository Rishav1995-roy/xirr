/// Fast, robust XIRR, XNPV, CAGR and SIP return calculations in pure Dart.
///
/// The package answers one question: *what annual rate of return did money
/// earn when it moved on irregular dates?* That is Excel's `XIRR`, the number
/// every mutual fund and stock app shows next to a holding.
///
/// ```dart
/// import 'package:xirr/xirr.dart';
///
/// final flows = [
///   CashFlow(DateTime(2023, 1, 1), -10000),
///   CashFlow(DateTime(2024, 1, 1), 11500),
/// ];
/// print(formatRate(xirr(flows))); // 15.00%
/// ```
///
/// ## Main entry points
///
/// * [xirr], [tryXirr], [xirrDetailed]: the internal rate of return, tuned
///   with [XirrOptions] (guess, tolerance, [DayCount], [SolverMethod], bounds).
/// * [xnpv]: net present value at a given rate.
/// * [cagr], [absoluteReturn], [annualizedReturn]: simple return maths.
/// * [sipSchedule]: generate SIP instalments.
/// * [Investment], [Portfolio]: XIRR, invested amount, gain and absolute
///   return from a list of transactions plus the current value.
/// * [formatRate]: locale-free formatting.
///
/// The package has no dependencies and does not use `dart:io` or `dart:html`,
/// so it runs on every Flutter platform, on the web (JS and WASM) and on the
/// server.
library;

export 'src/cash_flow.dart' show CashFlow;
export 'src/day_count.dart' show DayCount, YearFractionFn;
export 'src/exceptions.dart'
    show
        InsufficientCashFlowsException,
        InvalidCashFlowException,
        NoSignChangeException,
        NonConvergenceException,
        XirrException;
export 'src/formatting.dart' show formatRate;
export 'src/investment.dart'
    show
        Investment,
        InvestmentSummary,
        InvestmentTransaction,
        Portfolio,
        TransactionType;
export 'src/options.dart' show SolverMethod, XirrOptions, XirrResult;
export 'src/returns.dart' show absoluteReturn, annualizedReturn, cagr;
export 'src/sip.dart'
    show BusinessDayAdjustment, BusinessDayPredicate, SipFrequency, sipSchedule;
export 'src/xirr_core.dart' show tryXirr, xirr, xirrDetailed, xnpv;
