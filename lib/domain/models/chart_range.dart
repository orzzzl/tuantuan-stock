/// Time span of a price chart.
///
/// Each range defines the chart's 0% baseline (the waterline): [day] uses the
/// previous regular-session close; every other range uses the close at the
/// start of the period.
enum ChartRange { day, week, month, quarter, ytd, year }
