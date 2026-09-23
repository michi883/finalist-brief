#!/usr/bin/env python3
"""One-off: build the cached briefing video from the golden fixture.

Reads  finalist_brief_server/assets/demo/golden_brief.json (+ submissions.json)
       finalist_brief_server/.cache/videos/<slug>.mp4      (tool/fetch_demo_videos.sh)
       .env                                                (GEMINI_API_KEY, for narration)
Writes finalist_brief_server/web/static/briefs/<videoFile>
       and updates videoDurationSec in golden_brief.json.

Every intermediate is cached under finalist_brief_server/.cache/ by a hash of
its inputs, so re-running after editing one narration line only redoes that
line. Nothing here runs inside the app (PLAN.md §10).
"""
import base64, hashlib, json, os, pathlib, subprocess, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERVER = ROOT / "finalist_brief_server"
CACHE = SERVER / ".cache"
ASSETS = SERVER / "assets"
OUT_DIR = SERVER / "web" / "static" / "briefs"
RENDER_CARD = ROOT / "tool" / "render_card.swift"

TTS_MODEL = "gemini-2.5-flash-preview-tts"
TTS_VOICE = "Kore"
TTS_STYLE = "Read this as a calm, clear briefing narrator at a natural pace: "
TITLE_CARD_SEC = 3.0
CARD_TAIL_SEC = 0.5      # silence after narration on intro/outro cards
EXCERPT_TAIL_SEC = 0.8   # footage that keeps playing after narration ends
BG_DUCK = 0.12           # original demo audio level under narration

V_ENC = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "22", "-pix_fmt", "yuv420p", "-r", "30"]
A_ENC = ["-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-ac", "2"]


def run(cmd, **kw):
    subprocess.run(cmd, check=True, **kw)


def sha(*parts):
    return hashlib.sha1("\x1f".join(parts).encode()).hexdigest()[:16]


def duration(path):
    out = subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)])
    return float(out.strip())


def env_key():
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("GEMINI_API_KEY="):
            return line.split("=", 1)[1].strip()
    sys.exit("GEMINI_API_KEY missing from .env")


def narration(text):
    """Gemini TTS → 24 kHz mono WAV, cached by text+voice+model."""
    path = CACHE / "narration" / f"{sha(text, TTS_VOICE, TTS_MODEL)}.wav"
    if path.exists():
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    body = {
        "contents": [{"parts": [{"text": TTS_STYLE + text}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": TTS_VOICE}}},
        },
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{TTS_MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"x-goog-api-key": env_key(), "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.load(resp)
    part = data["candidates"][0]["content"]["parts"][0]["inlineData"]
    rate = part["mimeType"].split("rate=")[1] if "rate=" in part["mimeType"] else "24000"
    pcm = path.with_suffix(".pcm")
    pcm.write_bytes(base64.b64decode(part["data"]))
    run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", rate, "-ac", "1", "-i", pcm, path])
    pcm.unlink()
    print(f"  narration {path.name}  {duration(path):.1f}s  «{text[:48]}…»")
    return path


def normalized(slug):
    src = CACHE / "videos" / f"{slug}.mp4"
    if not src.exists():
        sys.exit(f"missing {src}; run tool/fetch_demo_videos.sh")
    out = CACHE / "videos" / f"{slug}.norm.mp4"
    if out.exists() and out.stat().st_mtime >= src.stat().st_mtime:
        return out
    run(["ffmpeg", "-v", "error", "-y", "-i", src,
         "-vf", "scale=1280:720:force_original_aspect_ratio=decrease,"
                "pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=#0f172a,fps=30,format=yuv420p",
         *V_ENC, *A_ENC, "-movflags", "+faststart", out])
    print(f"  normalized {slug}  {duration(out):.1f}s")
    return out


def card(kind, name, *texts):
    path = CACHE / "cards" / f"{name}-{sha(kind, *texts)}.png"
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        run(["swift", RENDER_CARD, kind, path, *texts])
    return path


def fades(d):
    return f"fade=t=in:st=0:d=0.4,fade=t=out:st={d - 0.5:.2f}:d=0.5"


def piece(name, key, build):
    """Render one concat piece once per input hash."""
    path = CACHE / "segments" / f"{name}-{key}.mp4"
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        build(path)
        print(f"  piece {name}  {duration(path):.1f}s")
    return path


def card_piece(name, png, wav):
    """Full-frame card with narration (or silent when wav is None)."""
    d = TITLE_CARD_SEC if wav is None else duration(wav) + CARD_TAIL_SEC
    key = sha(png.name, wav.name if wav else "silent", f"{d:.2f}")

    def build(out):
        audio = ["-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo"] if wav is None else ["-i", wav]
        run(["ffmpeg", "-v", "error", "-y", "-loop", "1", "-framerate", "30", "-i", png, *audio,
             "-filter_complex", f"[0:v]{fades(d)}[v];[1:a]apad[a]",
             "-map", "[v]", "-map", "[a]", "-t", f"{d:.2f}", *V_ENC, *A_ENC, out])
    return piece(name, key, build)


def excerpt_piece(name, src, start, end, lower_png, wav):
    d = max(duration(wav) + EXCERPT_TAIL_SEC, float(end - start))
    key = sha(src.name, str(start), f"{d:.2f}", lower_png.name, wav.name)

    def build(out):
        run(["ffmpeg", "-v", "error", "-y", "-ss", str(start), "-t", f"{d:.2f}", "-i", src,
             "-i", lower_png, "-i", wav,
             "-filter_complex",
             f"[0:v][1:v]overlay=0:0:format=auto,{fades(d)}[v];"
             f"[0:a]volume={BG_DUCK}[bg];[2:a]apad[nar];"
             f"[bg][nar]amix=inputs=2:duration=first:normalize=0[a]",
             "-map", "[v]", "-map", "[a]", "-t", f"{d:.2f}", *V_ENC, *A_ENC, out])
    return piece(name, key, build)


def main():
    golden_path = ASSETS / "demo" / "golden_brief.json"
    golden = json.loads(golden_path.read_text())
    subs = {s["slug"]: s for s in json.loads((ASSETS / "humor_genome" / "submissions.json").read_text())}
    n = len(subs)
    segments = sorted(golden["segments"], key=lambda s: s["position"])

    print("narration")
    intro_wav = narration(golden["intro"])
    outro_wav = narration(golden["outro"])
    seg_wavs = [narration(s["narration"]) for s in segments]

    print("pieces")
    pieces = [card_piece(
        "intro",
        card("card", "intro", "Finalist Brief", "Humor Genome: Build with Gemma",
             f"{n} submissions analyzed · {len(segments)} worth closer review",
             "Technical implementation · Demonstration · Quality of idea · Gemma usage"),
        intro_wav)]

    for i, (seg, wav) in enumerate(zip(segments, seg_wavs), start=1):
        sub = subs[seg["slug"]]
        title = sub["title"].split(":")[0].split("?")[0].strip() + ("?" if "?" in sub["title"] else "")
        pieces.append(card_piece(
            f"title-{seg['slug']}",
            card("card", f"title-{seg['slug']}", f"Worth closer review · {i} of {len(segments)}",
                 title, seg["whySurfaced"], sub["creator"]),
            None))
        video_evidence = next((e["detail"] for e in seg["evidence"] if e["source"] == "video"), "")
        pieces.append(excerpt_piece(
            f"excerpt-{seg['slug']}", normalized(seg["slug"]), seg["clipStartSec"], seg["clipEndSec"],
            card("lower", f"lower-{seg['slug']}", title, f"From the demo · {video_evidence}"),
            wav))

    pieces.append(card_piece(
        "outro",
        card("card", "outro", "Finalist Brief", "See the evidence in the app",
             "Why each project surfaced, area notes, and links to the exact demo moments and repo files.",
             f"{n - len(segments)} more submissions analyzed"),
        outro_wav))

    print("assemble")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    concat_list = CACHE / "segments" / "concat.txt"
    concat_list.write_text("".join(f"file '{p}'\n" for p in pieces))
    final = OUT_DIR / golden["videoFile"]
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", concat_list,
         *V_ENC, *A_ENC, "-movflags", "+faststart", final])
    total = duration(final)
    golden["videoDurationSec"] = round(total)
    golden_path.write_text(json.dumps(golden, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {final.relative_to(ROOT)}  {total:.1f}s  {final.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
