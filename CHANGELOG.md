## 0.0.1

Initial release.

- `xirr`, `tryXirr` and `xirrDetailed` with an Excel-compatible default.
- `xnpv` with an optional valuation date.
- Solvers: Newton-Raphson with automatic fallback to Brent, plus plain
  `newton`, `brent` and `bisection` modes.
- Day counts: `actual365`, `actual360`, `actualActual` and user-defined ones.
- Typed exceptions (`XirrException` and subclasses).
- `cagr`, `absoluteReturn`, `annualizedReturn`.
- `sipSchedule` generator with month-end handling and business-day options.
- `Investment` and `Portfolio` helpers for XIRR, invested amount, gain and
  absolute return.
- `formatRate` helper that does not force a locale.
