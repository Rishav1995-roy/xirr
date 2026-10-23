/// Calendar-day helpers shared by the package. Everything here works on
/// UTC, date-only values so that time zones and daylight-saving transitions
/// can never shift a day.
library;

/// Returns the calendar day of [value] as a UTC midnight [DateTime].
///
/// The year, month and day are read exactly as the caller sees them (local
/// fields for a local [DateTime], UTC fields for a UTC one), so a local
/// `2024-03-31 23:30` and a UTC `2024-03-31 00:00` are both March 31.
DateTime dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// Number of whole calendar days from [start] to [end] (negative when [end]
/// is earlier). Both arguments must already be date-only UTC values.
int daysBetween(DateTime start, DateTime end) => end.difference(start).inDays;

/// Whether [year] is a Gregorian leap year.
bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// Number of days in [month] (1-12) of [year].
int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Adds [months] to [start], keeping the day of month where possible and
/// clamping to the last day of shorter months (Jan 31 + 1 month = Feb 28/29).
///
/// Always computed from the original [start] so that clamping never drifts
/// (Jan 31 + 2 months = Mar 31, not Mar 28).
DateTime addMonths(DateTime start, int months) {
  final total = start.year * 12 + (start.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final day = start.day < daysInMonth(year, month)
      ? start.day
      : daysInMonth(year, month);
  return DateTime.utc(year, month, day);
}

/// Adds [days] calendar days to the date-only UTC value [start].
DateTime addDays(DateTime start, int days) =>
    DateTime.utc(start.year, start.month, start.day + days);

/// Formats [date] as `YYYY-MM-DD`.
String isoDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}
