/// US-Eastern wall-clock helpers for the CN feeds' timestamps: Tencent quote
/// field 30 (`2026-07-07 16:00:01`, report §4.1) and Sina `gb_` fields 24/25
/// (`Jul 07 07:59PM EDT`, report §4.2).
library;

final _clockTime = RegExp(r'\b(\d{1,2}):(\d{2})(AM|PM)\b');
final _monthDay = RegExp(
  r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d{1,2})\b',
);
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Converts an Eastern wall-clock [wall] (only its date/time components are
/// read) to the UTC instant. DST per the US rule: second Sunday of March
/// 02:00 through first Sunday of November 02:00.
DateTime easternToUtc(DateTime wall) {
  final components = DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );
  return components.add(Duration(hours: _isEasternDst(components) ? 4 : 5));
}

/// Converts a UTC instant to its US-Eastern wall-clock components.
DateTime utcToEastern(DateTime instant) {
  final utc = instant.toUtc();
  final daylightWall = utc.subtract(const Duration(hours: 4));
  if (_isEasternDst(daylightWall)) return daylightWall;
  return utc.subtract(const Duration(hours: 5));
}

/// Whether [instant] falls in the Blue Ocean ATS window: Sunday through
/// Thursday, 20:00 inclusive to 04:00 exclusive, in US Eastern time.
///
/// The window is intentionally based on Eastern wall-clock components, not a
/// UTC calendar date, because it crosses midnight and follows DST.
bool isOvernightSession(DateTime instant) {
  final eastern = utcToEastern(instant);
  final minutes = eastern.hour * 60 + eastern.minute;
  const start = 20 * 60;
  const end = 4 * 60;

  return switch (eastern.weekday) {
    DateTime.sunday => minutes >= start,
    DateTime.monday ||
    DateTime.tuesday ||
    DateTime.wednesday ||
    DateTime.thursday => minutes < end || minutes >= start,
    DateTime.friday => minutes < end,
    DateTime.saturday => false,
    _ => false,
  };
}

/// Minutes since Eastern midnight of a Sina `MMM dd hh:mmA z` timestamp, or
/// null when unparseable — the pre/post window test for the extended chip.
int? easternMinutesOfDay(String timestamp) {
  final match = _clockTime.firstMatch(timestamp);
  if (match == null) return null;
  final hour12 = int.parse(match.group(1)!) % 12;
  final hour = match.group(3) == 'PM' ? hour12 + 12 : hour12;
  return hour * 60 + int.parse(match.group(2)!);
}

/// Full Eastern wall-clock components (month, day, time) of a Sina
/// `MMM dd hh:mmA z` timestamp, or null when unparseable. The stamp carries
/// no year, so the caller supplies [year]; callers that must not trust a
/// stale stamp compare the result's calendar date themselves.
DateTime? easternSinaWall(String timestamp, {required int year}) {
  final monthDay = _monthDay.firstMatch(timestamp);
  final minutes = easternMinutesOfDay(timestamp);
  if (monthDay == null || minutes == null) return null;
  return DateTime.utc(
    year,
    _months.indexOf(monthDay.group(1)!) + 1,
    int.parse(monthDay.group(2)!),
    minutes ~/ 60,
    minutes % 60,
  );
}

bool _isEasternDst(DateTime wallComponents) {
  final start = _nthSunday(
    wallComponents.year,
    DateTime.march,
    2,
  ).add(const Duration(hours: 2));
  final end = _nthSunday(
    wallComponents.year,
    DateTime.november,
    1,
  ).add(const Duration(hours: 2));
  return !wallComponents.isBefore(start) && wallComponents.isBefore(end);
}

DateTime _nthSunday(int year, int month, int n) {
  final first = DateTime.utc(year, month, 1);
  final firstSunday = 1 + (DateTime.sunday - first.weekday) % 7;
  return DateTime.utc(year, month, firstSunday + 7 * (n - 1));
}
