/// Formats a rate such as `0.1234` for display, without depending on any
/// locale.
///
/// * [asPercent] (default `true`): multiply by 100 and append [percentSymbol],
///   giving `12.34%`. With `false` the plain fraction is shown (`0.1234`).
/// * [decimals]: digits after the decimal point (default `2`, range 0-20).
/// * [showPlus]: prefix positive values with `+` (handy for gains).
/// * [decimalSeparator]: use `','` for European style output.
/// * [percentSymbol]: `'%'` by default; `' %'` gives a spaced symbol.
///
/// `NaN` and infinite values are returned as `NaN`, `Infinity` or
/// `-Infinity`. A value that rounds to zero never shows a minus sign.
///
/// ```dart
/// formatRate(0.12345);                       // 12.35%
/// formatRate(-0.5, decimals: 0);             // -50%
/// formatRate(0.1, asPercent: false);         // 0.10
/// formatRate(0.0321, decimalSeparator: ','); // 3,21%
/// ```
String formatRate(
  double rate, {
  int decimals = 2,
  bool asPercent = true,
  bool showPlus = false,
  String decimalSeparator = '.',
  String percentSymbol = '%',
}) {
  RangeError.checkValueInInterval(decimals, 0, 20, 'decimals');
  if (rate.isNaN) return 'NaN';
  if (rate.isInfinite) return rate.isNegative ? '-Infinity' : 'Infinity';
  final value = asPercent ? rate * 100 : rate;
  var text = value.toStringAsFixed(decimals);
  if (text.startsWith('-') && double.parse(text) == 0) {
    text = text.substring(1);
  }
  if (showPlus && !text.startsWith('-') && double.parse(text) != 0) {
    text = '+$text';
  }
  if (decimalSeparator != '.') {
    text = text.replaceFirst('.', decimalSeparator);
  }
  return asPercent ? '$text$percentSymbol' : text;
}
