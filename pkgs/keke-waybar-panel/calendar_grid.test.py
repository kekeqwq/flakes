from datetime import date
import runpy
import sys
import unittest

module = runpy.run_path(sys.argv.pop(1))
days_for_month = module["days_for_month"]
shift_day = module["shift_day"]
shift_month = module["shift_month"]


class CalendarGridTest(unittest.TestCase):
    def test_sunday_first_with_previous_and_next_month(self):
        days = days_for_month(date(2026, 11, 28))
        self.assertEqual(len(days), 42)
        self.assertEqual(days[0], date(2026, 11, 1))
        self.assertEqual(days[27], date(2026, 11, 28))
        self.assertEqual(days[-1], date(2026, 12, 12))
        self.assertEqual(days_for_month(date(2026, 12, 1))[0], date(2026, 11, 29))

    def test_month_year_and_arrow_navigation(self):
        self.assertEqual(shift_month(date(2024, 1, 31), 1), date(2024, 2, 29))
        self.assertEqual(shift_month(date(2024, 2, 29), 12), date(2025, 2, 28))
        self.assertEqual(shift_month(date(2024, 1, 9), -1), date(2023, 12, 9))
        self.assertEqual(shift_day(date(2024, 2, 29), 1), date(2024, 3, 1))

    def test_date_limits(self):
        self.assertIsNone(days_for_month(date.min)[0])
        self.assertIsNone(days_for_month(date.max)[-1])
        self.assertEqual(shift_month(date.min, -1), date.min)
        self.assertEqual(shift_day(date.max, 7), date.max)


if __name__ == "__main__":
    unittest.main()
