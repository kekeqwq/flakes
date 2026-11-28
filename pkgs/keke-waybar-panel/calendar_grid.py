"""Month arithmetic for the centered Waybar calendar grid."""

import calendar
from datetime import date, timedelta


def shift_month(day, offset):
    index = (day.year - 1) * 12 + day.month - 1 + offset
    if not 0 <= index < 9999 * 12:
        return day
    year, month = divmod(index, 12)
    return date(year + 1, month + 1, min(day.day, calendar.monthrange(year + 1, month + 1)[1]))


def days_for_month(day):
    """Six rows, Sunday first, with adjacent-month dates where representable."""
    first = day.replace(day=1)
    start = first.toordinal() - (first.weekday() + 1) % 7
    return [date.fromordinal(n) if 1 <= n <= date.max.toordinal() else None
            for n in range(start, start + 42)]


# The grid handles keyboard arrows as well as pointer selection.
def shift_day(day, offset):
    try:
        return day + timedelta(days=offset)
    except OverflowError:
        return day
