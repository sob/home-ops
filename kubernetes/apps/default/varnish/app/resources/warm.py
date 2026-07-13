#!/usr/bin/env python3
"""Prime the Varnish poster cache.

Enumerates every movie/series via each *arr API, then re-requests its poster
*through Varnish* (Host header selects the backend) so the shared cache is hot
before anyone browses. Uses only the stdlib so the image needs no pip installs.
"""
import json
import os
import urllib.error
import urllib.request

DOMAIN = os.environ.get("DOMAIN", "56kbps.io")
VARNISH = os.environ.get("VARNISH_URL", "http://varnish.default.svc.cluster.local").rstrip("/")

APPS = [
    {
        "name": "radarr",
        "api": "http://radarr.default.svc.cluster.local/api/v3/movie",
        "key": os.environ.get("RADARR_API_KEY", ""),
        "host": f"radarr.{DOMAIN}",
    },
    {
        "name": "sonarr",
        "api": "http://sonarr.default.svc.cluster.local/api/v3/series",
        "key": os.environ.get("SONARR_API_KEY", ""),
        "host": f"sonarr.{DOMAIN}",
    },
]


def get_json(url, key):
    req = urllib.request.Request(url, headers={"X-Api-Key": key})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def variants(url):
    """The base poster plus the -500 grid size the web UI requests."""
    base, sep, qs = url.partition("?")
    out = [url]
    if base.endswith("poster.jpg"):
        sized = base[: -len("poster.jpg")] + "poster-500.jpg"
        out.append(sized + (sep + qs if qs else ""))
    return out


def fetch(app, path):
    req = urllib.request.Request(
        VARNISH + path,
        headers={"Host": app["host"], "X-Api-Key": app["key"]},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.headers.get("X-Cache", "?")
    except urllib.error.HTTPError as e:
        return f"HTTP {e.code}"
    except Exception as e:  # noqa: BLE001
        return f"ERR {e}"


def warm(app):
    if not app["key"]:
        print(f"[{app['name']}] no API key, skipping", flush=True)
        return
    try:
        items = get_json(app["api"], app["key"])
    except Exception as e:  # noqa: BLE001
        print(f"[{app['name']}] enumerate failed: {e}", flush=True)
        return

    hits = misses = errs = 0
    for item in items:
        for img in item.get("images", []):
            if img.get("coverType") != "poster":
                continue
            url = img.get("url") or ""
            if not url.startswith("/MediaCover/"):
                continue
            for path in variants(url):
                result = fetch(app, path)
                if result == "HIT":
                    hits += 1
                elif result == "MISS":
                    misses += 1
                else:
                    errs += 1
            break  # one poster per item
    print(
        f"[{app['name']}] warmed {len(items)} items: "
        f"{hits} hit / {misses} miss / {errs} err",
        flush=True,
    )


def main():
    for app in APPS:
        warm(app)


if __name__ == "__main__":
    main()
