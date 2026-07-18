from datetime import datetime, time

import pytest
from pydantic import ValidationError

from app.schemas.api import (
    HostAvailabilityBlockIn,
    HostAvailabilityRuleIn,
    HostAvailabilityScheduleIn,
)


def test_schedule_requires_each_weekday_once() -> None:
    rules = [
        HostAvailabilityRuleIn(
            weekday=weekday,
            start_time=time(8),
            end_time=time(18),
        )
        for weekday in range(7)
    ]

    schedule = HostAvailabilityScheduleIn(rules=rules)

    assert len(schedule.rules) == 7


def test_schedule_rejects_duplicate_weekday() -> None:
    rules = [
        HostAvailabilityRuleIn(
            weekday=0 if weekday == 6 else weekday,
            start_time=time(8),
            end_time=time(18),
        )
        for weekday in range(7)
    ]

    with pytest.raises(ValidationError):
        HostAvailabilityScheduleIn(rules=rules)


def test_block_requires_end_after_start() -> None:
    with pytest.raises(ValidationError):
        HostAvailabilityBlockIn(
            start_at=datetime(2026, 7, 20, 12),
            end_at=datetime(2026, 7, 20, 10),
        )
