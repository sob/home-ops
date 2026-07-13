vcl 4.1;

# Poster / cover-art caching layer for the *arr apps. Only /MediaCover/*
# GET traffic is routed here from the gateway; everything else bypasses
# Varnish entirely, so this proxy is never on the critical path for the UI
# or API. Responses are already served by Sonarr/Radarr as
# "Cache-Control: public, max-age=1y" with no Set-Cookie, so they are safe
# to share across users; posters carry a ?lastWrite= cache-buster, so a
# long TTL cannot serve stale art.

backend radarr {
    .host = "radarr.default.svc.cluster.local";
    .port = "80";
}

backend sonarr {
    .host = "sonarr.default.svc.cluster.local";
    .port = "80";
}

sub vcl_recv {
    # Pick the backend by hostname (the gateway preserves the Host header).
    if (req.http.host ~ "(?i)^radarr\.") {
        set req.backend_hint = radarr;
    } else if (req.http.host ~ "(?i)^sonarr\.") {
        set req.backend_hint = sonarr;
    } else {
        return (synth(404, "No backend for host"));
    }

    # Safety net: only image assets should ever reach us, but pass anything
    # else straight through uncached just in case.
    if (req.url !~ "^/MediaCover/") {
        return (pass);
    }
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Posters are identical for every user. Keep auth headers/cookies on the
    # wire so the backend still authorises a cache miss, but force a lookup
    # keyed only on host+URL (the built-in "Cookie => pass" rule is skipped
    # because we return hash explicitly).
    return (hash);
}

sub vcl_backend_response {
    if (bereq.url ~ "^/MediaCover/") {
        if (beresp.status == 200) {
            unset beresp.http.set-cookie;
            set beresp.ttl = 30d;
            set beresp.grace = 7d;
            set beresp.keep = 7d;
        } else {
            # Never cache 401/404/5xx image responses.
            set beresp.uncacheable = true;
            set beresp.ttl = 5s;
        }
    }
}

sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
    set resp.http.X-Cache-Hits = obj.hits;
}
