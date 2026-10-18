"""Builds app/assets/map/fixture.pmtiles: one z0 vector tile with one polygon over the Alps.

The polygon carries `fixture=c4-skeleton` in source layer `fixture`; the app queries for that
property to prove the tile it rendered came from this file and not from any remote source.

    python3 -m venv .venv && .venv/bin/pip install pmtiles==3.8.1 mapbox-vector-tile==2.2.0
    .venv/bin/python tools/fixtures/make_fixture_pmtiles.py app/assets/map/fixture.pmtiles
"""

import gzip
import math
import sys

import mapbox_vector_tile
from pmtiles.tile import Compression, TileType, zxy_to_tileid
from pmtiles.writer import write

WEST, SOUTH, EAST, NORTH = 5.0, 44.0, 9.0, 47.0
WORLD = 20037508.342789244


def mercator(lon, lat):
    x = lon * WORLD / 180
    y = math.log(math.tan((90 + lat) * math.pi / 360)) * WORLD / math.pi
    return x, y


def fixture_tile():
    corners = [mercator(lon, lat) for lon, lat in [(WEST, SOUTH), (EAST, SOUTH), (EAST, NORTH), (WEST, NORTH)]]
    ring = ", ".join(f"{x} {y}" for x, y in corners + corners[:1])
    layer = {
        "name": "fixture",
        "features": [{"geometry": f"POLYGON(({ring}))", "properties": {"fixture": "c4-skeleton"}}],
    }
    return mapbox_vector_tile.encode([layer], default_options={"quantize_bounds": (-WORLD, -WORLD, WORLD, WORLD)})


def e7(degrees):
    return int(degrees * 10_000_000)


def main(path):
    with write(path) as writer:
        writer.write_tile(zxy_to_tileid(0, 0, 0), gzip.compress(fixture_tile(), mtime=0))
        writer.finalize(
            {
                "tile_type": TileType.MVT,
                "tile_compression": Compression.GZIP,
                "min_lon_e7": e7(WEST),
                "min_lat_e7": e7(SOUTH),
                "max_lon_e7": e7(EAST),
                "max_lat_e7": e7(NORTH),
                "center_zoom": 5,
                "center_lon_e7": e7((WEST + EAST) / 2),
                "center_lat_e7": e7((SOUTH + NORTH) / 2),
            },
            {"name": "c4-fixture", "vector_layers": [{"id": "fixture", "fields": {"fixture": "String"}}]},
        )


if __name__ == "__main__":
    main(sys.argv[1])
