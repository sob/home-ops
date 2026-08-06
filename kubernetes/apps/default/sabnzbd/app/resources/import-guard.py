#!/usr/bin/env python3
"""
SABnzbd post-processing script — reject bad releases before the *arr imports.

Runs after unpack and before Sonarr/Radarr pick the job up. Exiting non-zero
makes SABnzbd mark the job Failed, which the *arr sees as a failed download and
handles the way it already handles any other failure: blocklist the release and
search for a replacement. No new moving parts in that path.

Why this exists
---------------
On 2026-08-05 three "movies" in the library turned out to be Blu-ray disc rips
where only a single playlist title had been imported:

  Zootopia 2 (2025)        12m48s of a 1h48m film   4.98 GB   00036.m2ts
  Independence Day (1996)  25.9m  of a 2h25m film   9.46 GB   .m2ts
  Minions: Rise of Gru     25.2m  of a 1h27m film  16.66 GB   COMPLETE.BLURAY

All three were real 4K HEVC video, so nothing flagged them — Radarr recorded a
successful import and moved on. They were only found by chance. Radarr tagged
them quality "Unknown" because .m2ts does not parse, which is the tell.

A fourth, aspyre-sample-101dalmatians.avi, was a 13 MB sample registered as the
feature.

Deliberately no ffprobe
-----------------------
The sabnzbd image ships python3 but no ffmpeg/ffprobe/mediainfo. Rather than
maintain a custom image, every check here is either structural (directory
layout, extensions, sizes) or parses the container header directly. That covers
all four cases above without another dependency to keep current.

SABnzbd passes: argv[1]=final dir, argv[2]=nzb name, argv[3]=clean job name,
argv[4]=report number, argv[5]=category, argv[6]=group, argv[7]=status.
"""

import os
import struct
import sys

VIDEO_EXT = {".mkv", ".mp4", ".avi", ".m2ts", ".ts", ".m4v", ".wmv", ".mpg", ".mpeg"}

# Directories that only exist inside a ripped disc image.
DISC_DIRS = {"BDMV", "VIDEO_TS", "AUDIO_TS", "CERTIFICATE", "STREAM", "PLAYLIST"}

# Smallest plausible real release, per category. Anything under this is a
# sample, a trailer, or a stray extra. Generous on purpose — the goal is to
# catch obvious junk, not to second-guess legitimately short content.
MIN_BYTES = {"movies": 300 * 1024 * 1024, "tv": 40 * 1024 * 1024}
MIN_BYTES_DEFAULT = 40 * 1024 * 1024

# Minimum runtime where we can read it cheaply. Movies under 30 minutes are
# effectively always a disc title or an extra. TV is left low because runtimes
# genuinely vary (shorts, specials, kids' animation).
MIN_MINUTES = {"movies": 30, "tv": 5}


def fail(msg):
    """Exit non-zero so SABnzbd marks the job failed and the *arr blocklists it."""
    print(f"[import-guard] REJECT: {msg}")
    sys.exit(1)


def ok(msg):
    print(f"[import-guard] pass: {msg}")
    sys.exit(0)


def mkv_duration_seconds(path):
    """
    Read Duration out of an MKV/WebM EBML header.

    Only scans the first 64 KiB, which is where the SegmentInfo lives in every
    normally-muxed file. Returns None if anything looks unfamiliar — this is a
    best-effort signal, never a reason to reject on its own.
    """
    try:
        with open(path, "rb") as fh:
            head = fh.read(65536)
    except OSError:
        return None

    # 0x4489 = Duration (float, seconds scaled by TimecodeScale)
    # 0x2AD7B1 = TimecodeScale (nanoseconds per tick, default 1_000_000 = 1ms)
    scale = 1_000_000
    idx = head.find(b"\x2a\xd7\xb1")
    if idx != -1 and idx + 4 < len(head):
        size = head[idx + 3] & 0x7F
        if 0 < size <= 8 and idx + 4 + size <= len(head):
            scale = int.from_bytes(head[idx + 4 : idx + 4 + size], "big") or scale

    idx = head.find(b"\x44\x89")
    if idx == -1 or idx + 3 > len(head):
        return None
    size = head[idx + 2] & 0x7F
    start = idx + 3
    try:
        if size == 4:
            ticks = struct.unpack(">f", head[start : start + 4])[0]
        elif size == 8:
            ticks = struct.unpack(">d", head[start : start + 8])[0]
        else:
            return None
    except struct.error:
        return None

    seconds = ticks * scale / 1_000_000_000
    # Sanity-bound it; a bad parse should look like nothing rather than like junk.
    return seconds if 0 < seconds < 86400 else None


def main():
    job_dir = sys.argv[1] if len(sys.argv) > 1 else ""
    job_name = sys.argv[3] if len(sys.argv) > 3 else "(unknown)"
    category = (sys.argv[5] if len(sys.argv) > 5 else "").strip().lower()

    if not job_dir or not os.path.isdir(job_dir):
        # Nothing to inspect. Let SABnzbd's own handling decide.
        ok(f"no job directory to inspect ({job_dir!r})")

    videos = []
    disc_markers = set()
    for root, dirs, files in os.walk(job_dir):
        for d in dirs:
            if d.upper() in DISC_DIRS:
                disc_markers.add(d.upper())
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext in VIDEO_EXT:
                full = os.path.join(root, f)
                try:
                    videos.append((os.path.getsize(full), full, ext))
                except OSError:
                    continue

    # 1. Ripped disc image. The *arr will import one playlist title out of this
    #    and call it the film. This is what produced all three 2026-08-05 cases.
    if disc_markers:
        fail(
            f"{job_name}: disc image structure ({', '.join(sorted(disc_markers))}) — "
            "the *arr would import a single playlist title, not the feature"
        )

    if not videos:
        ok(f"{job_name}: no video files to check (likely music, books or subtitles)")

    videos.sort(reverse=True)
    largest_size, largest_path, largest_ext = videos[0]

    # 2. Raw transport streams outside a disc dir — same failure, flatter layout.
    #    Multiple .m2ts means a title set; a lone .m2ts means a single extracted
    #    title, which is how Independence Day ended up at 26 minutes.
    m2ts = [v for v in videos if v[2] in (".m2ts", ".ts")]
    if m2ts and len(m2ts) == len(videos):
        fail(
            f"{job_name}: {len(m2ts)} raw transport stream(s) and no muxed video — "
            "extracted disc title rather than a release"
        )

    # 3. Too small to be the thing it claims to be.
    floor = MIN_BYTES.get(category, MIN_BYTES_DEFAULT)
    if largest_size < floor:
        fail(
            f"{job_name}: largest video is {largest_size / 1024 / 1024:.0f} MB, "
            f"below the {floor / 1024 / 1024:.0f} MB floor for category "
            f"{category or 'unset'!r} — sample or trailer"
        )

    # 4. Runtime, where the container makes it cheap to read.
    if largest_ext in (".mkv", ".webm"):
        seconds = mkv_duration_seconds(largest_path)
        min_minutes = MIN_MINUTES.get(category)
        if seconds is not None and min_minutes and seconds < min_minutes * 60:
            fail(
                f"{job_name}: largest video runs {seconds / 60:.1f} min, under the "
                f"{min_minutes} min floor for category {category or 'unset'!r} — "
                "extra, trailer or partial rip"
            )

    ok(
        f"{job_name}: {len(videos)} video file(s), largest "
        f"{largest_size / 1024 / 1024 / 1024:.2f} GB {largest_ext}"
    )


if __name__ == "__main__":
    main()
