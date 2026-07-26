from __future__ import annotations

from typing import Any

import pytest
from fastapi import HTTPException

from app.api import routing_routes


class _Response:
    def __init__(self, payload: dict[str, Any], *, fails: bool = False) -> None:
        self.payload = payload
        self.fails = fails

    def raise_for_status(self) -> None:
        if self.fails:
            raise RuntimeError("upstream unavailable")

    def json(self) -> dict[str, Any]:
        return self.payload


class _Client:
    def __init__(self, response: _Response) -> None:
        self.response = response
        self.request: tuple[str, dict[str, Any], dict[str, str]] | None = None

    async def __aenter__(self) -> _Client:
        return self

    async def __aexit__(self, *_args: object) -> None:
        return None

    async def get(
        self,
        url: str,
        *,
        params: dict[str, Any],
        headers: dict[str, str],
    ) -> _Response:
        self.request = (url, params, headers)
        return self.response


def _install_client(monkeypatch: pytest.MonkeyPatch, response: _Response) -> _Client:
    client = _Client(response)
    monkeypatch.setattr(
        routing_routes.httpx,
        "AsyncClient",
        lambda *, timeout: client,
    )
    return client


@pytest.mark.asyncio
async def test_walking_route_returns_only_real_upstream_values(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client = _install_client(
        monkeypatch,
        _Response(
            {
                "code": "Ok",
                "routes": [
                    {
                        "distance": 1234.4,
                        "duration": 789.6,
                        "geometry": {
                            "coordinates": [
                                [8.65, 50.11],
                                [8.66, 50.12],
                                ["invalid"],
                            ]
                        },
                    }
                ],
            }
        ),
    )

    result = await routing_routes.walking_route(
        from_lat=50.11,
        from_lng=8.65,
        to_lat=50.12,
        to_lng=8.66,
    )

    assert result == {
        "distance_meters": 1234,
        "duration_seconds": 790,
        "geometry": [
            {"latitude": 50.11, "longitude": 8.65},
            {"latitude": 50.12, "longitude": 8.66},
        ],
        "source": "OpenStreetMap pedestrian routing",
    }
    assert client.request is not None
    url, params, headers = client.request
    assert "8.65,50.11;8.66,50.12" in url
    assert params["geometries"] == "geojson"
    assert "FREIRAUM/" in headers["User-Agent"]
    assert "parkplatz@aplus-solution.de" in headers["User-Agent"]


@pytest.mark.asyncio
async def test_walking_route_returns_404_when_upstream_has_no_route(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _install_client(monkeypatch, _Response({"code": "NoRoute", "routes": []}))

    with pytest.raises(HTTPException) as error:
        await routing_routes.walking_route(
            from_lat=50.11,
            from_lng=8.65,
            to_lat=50.12,
            to_lng=8.66,
        )

    assert error.value.status_code == 404
    assert error.value.detail["code"] == "walking_route_not_found"


@pytest.mark.asyncio
async def test_walking_route_returns_503_instead_of_fabricating_an_estimate(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _install_client(monkeypatch, _Response({}, fails=True))

    with pytest.raises(HTTPException) as error:
        await routing_routes.walking_route(
            from_lat=50.11,
            from_lng=8.65,
            to_lat=50.12,
            to_lng=8.66,
        )

    assert error.value.status_code == 503
    assert error.value.detail["code"] == "walking_route_unavailable"
