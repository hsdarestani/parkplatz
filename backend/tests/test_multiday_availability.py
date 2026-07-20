from datetime import datetime, time
from types import SimpleNamespace
from zoneinfo import ZoneInfo

from app.services.availability import matching_rule, matching_rules
from app.services.booking import MAX_BOOKING_HOURS

BERLIN = ZoneInfo("Europe/Berlin")


def _rule(weekday: int, start: time = time(0, 0), end: time = time(23, 59)):
    return SimpleNamespace(
        weekday=weekday,
        start_time=start,
        end_time=end,
        active=True,
        price_override_cents=None,
    )


def test_three_day_range_is_covered_by_each_calendar_day() -> None:
    start = datetime(2026, 7, 20, 10, 0, tzinfo=BERLIN)
    end = datetime(2026, 7, 23, 10, 0, tzinfo=BERLIN)
    rules = [_rule(day) for day in range(7)]

    matched = matching_rules(rules, start, end)

    assert matched is not None
    assert len(matched) == 4
    assert [rule.weekday for rule in matched] == [0, 1, 2, 3]


def test_multi_day_range_fails_when_one_day_is_not_available() -> None:
    start = datetime(2026, 7, 20, 10, 0, tzinfo=BERLIN)
    end = datetime(2026, 7, 23, 10, 0, tzinfo=BERLIN)
    rules = [_rule(day) for day in (0, 1, 3)]

    assert matching_rules(rules, start, end) is None


def test_single_day_helper_remains_compatible() -> None:
    start = datetime(2026, 7, 20, 10, 0, tzinfo=BERLIN)
    end = datetime(2026, 7, 20, 18, 0, tzinfo=BERLIN)
    monday = _rule(0, time(8, 0), time(20, 0))

    assert matching_rule([monday], start, end) is monday


def test_booking_limit_is_thirty_days() -> None:
    assert MAX_BOOKING_HOURS == 720
