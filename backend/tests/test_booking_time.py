from datetime import datetime, timezone

from app.services.booking import normalize_booking_time


def test_naive_booking_time_is_interpreted_in_frankfurt() -> None:
    local_summer_time = datetime(2026, 7, 20, 18, 0)

    assert normalize_booking_time(local_summer_time) == datetime(
        2026,
        7,
        20,
        16,
        0,
        tzinfo=timezone.utc,
    )


def test_offset_aware_booking_time_keeps_the_same_instant() -> None:
    utc_time = datetime(2026, 7, 20, 16, 0, tzinfo=timezone.utc)

    assert normalize_booking_time(utc_time) == utc_time
