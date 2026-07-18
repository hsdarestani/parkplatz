from datetime import datetime, time, timezone
from types import SimpleNamespace

from app.services.availability import matching_rule


def _rule(
    weekday: int,
    start: time,
    end: time,
    *,
    active: bool = True,
    price: int | None = None,
) -> SimpleNamespace:
    return SimpleNamespace(
        weekday=weekday,
        start_time=start,
        end_time=end,
        active=active,
        price_override_cents=price,
    )


def test_matching_rule_accepts_period_inside_weekday_schedule() -> None:
    rules = [_rule(0, time(8), time(18), price=450)]

    result = matching_rule(
        rules,  # type: ignore[arg-type]
        datetime(2026, 7, 20, 8, tzinfo=timezone.utc),
        datetime(2026, 7, 20, 10, tzinfo=timezone.utc),
    )

    assert result is rules[0]
    assert result.price_override_cents == 450


def test_matching_rule_rejects_disabled_or_outside_period() -> None:
    rules = [_rule(0, time(8), time(18), active=False)]

    result = matching_rule(
        rules,  # type: ignore[arg-type]
        datetime(2026, 7, 20, 8, tzinfo=timezone.utc),
        datetime(2026, 7, 20, 10, tzinfo=timezone.utc),
    )

    assert result is None


def test_matching_rule_rejects_booking_crossing_local_midnight() -> None:
    rules = [_rule(0, time(0), time(23, 59))]

    result = matching_rule(
        rules,  # type: ignore[arg-type]
        datetime(2026, 7, 20, 20, tzinfo=timezone.utc),
        datetime(2026, 7, 21, 1, tzinfo=timezone.utc),
    )

    assert result is None
