from app.db import seed as seed_module
from app.db.archive_demo_seed import DEMO_SLUGS


def test_production_never_allows_demo_seed(monkeypatch):
    monkeypatch.setattr(seed_module.settings, "environment", "production")
    assert seed_module.demo_seed_allowed() is False


def test_non_production_can_seed_ci_inventory(monkeypatch):
    monkeypatch.setattr(seed_module.settings, "environment", "test")
    assert seed_module.demo_seed_allowed() is True


def test_cleanup_covers_every_legacy_demo_slug():
    assert {row[0] for row in seed_module.SPACES} == DEMO_SLUGS
