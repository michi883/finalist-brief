"""Stage 1: source acquisition.

Collects everything later stages may cite, and nothing else:

- the Devpost writeup, tagline, team and "built with" list;
- the repository exactly as it was at the last commit before the deadline,
  exported with `git archive` into the workspace (later commits are counted,
  never read);
- the demo video, its captions when the host provides them, and one frame
  every few seconds at exact timestamps.

Output: .cache/<id>/sources.json, repo/, demo.mp4, frames/
"""

import math
import os
import re
import shutil
import subprocess
import sys
import tarfile
import io

from common import (
    DEADLINE, PILOT, ensure_dir, read_json, stage_path, workspace, write_json,
)

MAX_FRAMES = 40
FRAME_SIZE = (800, 450)


def devpost_record(sid):
    devpost = read_json(os.path.join(PILOT, 'data', 'devpost.json'))
    for submission in devpost['submissions']:
        if submission['id'] == sid:
            return submission
    raise SystemExit(f'{sid} is not in the pilot sample')


def git(repo, *args):
    return subprocess.run(['git', '-C', repo, *args], capture_output=True,
                          text=True, check=True).stdout.strip()


def repository(sid, url):
    clone = os.path.join(PILOT, '.cache', 'repos', sid)
    if not os.path.exists(clone):
        subprocess.run(['git', 'clone', '-q', '--filter=blob:none', url, clone],
                       check=True, env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'})
    git(clone, 'fetch', '-q', 'origin')
    head = git(clone, 'rev-parse', 'origin/HEAD')
    sha = git(clone, 'rev-list', '-1', f'--before={DEADLINE}', head)
    if not sha:
        return {'url': url, 'status': 'noCommitBeforeDeadline'}
    after = git(clone, 'rev-list', '--count', f'{sha}..{head}')
    target = workspace(sid, 'repo')
    if os.path.exists(target):
        shutil.rmtree(target)
    archive = subprocess.run(['git', '-C', clone, 'archive', sha],
                             capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(ensure_dir(target), filter='data')
    return {
        'url': url,
        'status': 'public',
        'sha': sha[:12],
        'date': git(clone, 'show', '-s', '--format=%cI', sha),
        'commitsAfterDeadline': int(after),
        'path': target,
    }


def watch_url(embed):
    if 'youtube' in embed:
        return 'https://www.youtube.com/watch?v=' + embed.rsplit('/', 1)[1]
    if 'vimeo' in embed:
        return 'https://vimeo.com/' + embed.rsplit('/', 1)[1]
    return embed


def yt_dlp(*args):
    return subprocess.run(
        ['yt-dlp', '--extractor-args', 'youtube:player_client=android', *args],
        capture_output=True, text=True)


def parse_vtt(path):
    """Caption cues as [{start, end, text}], with rolling duplicates removed."""
    def seconds(stamp):
        h, m, s = stamp.replace(',', '.').split(':')
        return int(h) * 3600 + int(m) * 60 + float(s)

    cues, seen = [], set()
    with open(path, encoding='utf-8') as f:
        blocks = f.read().split('\n\n')
    for block in blocks:
        match = re.search(r'([\d:.]+) --> ([\d:.]+)', block)
        if not match:
            continue
        lines = block[match.end():].split('\n')[1:]  # skip cue settings
        for line in lines:
            text = re.sub(r'<[^>]+>', '', line).strip()
            if text and text not in seen:
                seen.add(text)
                cues.append({'start': round(seconds(match[1]), 1),
                             'end': round(seconds(match[2]), 1), 'text': text})
    return cues


def demo(sid, embed):
    if not embed:
        return {'status': 'notLinked'}
    url = watch_url(embed)
    video = workspace(sid, 'demo.mp4')
    reused = os.path.join(PILOT, '.cache', 'videos', f'{sid}.mp4')
    if not os.path.exists(video):
        if os.path.exists(reused):
            shutil.copy(reused, video)
        else:
            result = yt_dlp('-f', 'mp4/best', '-o', video, url)
            if result.returncode != 0 or not os.path.exists(video):
                # The demo is linked but could not be fetched: not the same
                # as having no demo, which main() refuses to pass on.
                return {'status': 'downloadFailed', 'url': url,
                        'error': result.stderr[-300:]}
    duration = float(subprocess.run(
        ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
         '-of', 'csv=p=0', video], capture_output=True, text=True).stdout)

    # Captions: the author's own first, the host's speech recognition
    # otherwise. Which one was used is recorded, since automatic captions
    # can mishear names.
    captions, kind = [], None
    for kind, flag in (('author', '--write-subs'), ('automatic', '--write-auto-subs')):
        subs = workspace(sid, f'subs-{kind}')
        if not os.path.exists(subs):
            yt_dlp('--skip-download', flag, '--sub-langs', 'en', '--sub-format',
                   'vtt', '-o', os.path.join(ensure_dir(subs), 'demo'), url)
        files = sorted(f for f in os.listdir(subs) if f.endswith('.vtt'))
        if files:
            captions = parse_vtt(os.path.join(subs, files[0]))
            break
    else:
        kind = None

    step = max(3, math.ceil(duration / MAX_FRAMES))
    frames = []
    directory = ensure_dir(workspace(sid, 'frames'))
    w, h = FRAME_SIZE
    for t in range(1, int(duration), step):
        path = os.path.join(directory, f't{t:04d}.jpg')
        if not os.path.exists(path):
            subprocess.run([
                'ffmpeg', '-v', 'error', '-ss', str(t), '-i', video,
                '-frames:v', '1', '-q:v', '4', '-vf',
                f'scale={w}:{h}:force_original_aspect_ratio=decrease,'
                f'pad={w}:{h}:(ow-iw)/2:(oh-ih)/2:color=black', path,
            ], check=True)
        frames.append({'t': t, 'path': path})
    return {'status': 'available', 'url': url, 'duration': round(duration, 1),
            'step': step, 'frames': frames, 'captions': captions,
            'captionKind': kind}


def manual_download_help(sid, d):
    """How a person fetches a demo the pipeline cannot download anonymously.

    Vimeo refuses anonymous clients, so this step is human-assisted: the
    person downloads the video once, with their own browser session, into
    the pilot's video cache, which demo() reuses on the next run. Browser
    cookies never become part of the pipeline itself."""
    target = os.path.join(PILOT, '.cache', 'videos', f'{sid}.mp4')
    return '\n'.join([
        f'{sid}: the pilot recorded the demo as available, but acquisition failed '
        f'({d["status"]}, {d.get("url")}):',
        (d.get('error') or '').strip(),
        '',
        'Stopped before any model call. Download the demo once by hand to:',
        f'  {target}',
        'for example with your own browser session (used for this one download only):',
        f"  yt-dlp --cookies-from-browser chrome -f 'bv*+ba/b' --merge-output-format mp4 "
        f"-o '{target}' '{d.get('url')}'",
        f'then re-run: python3 run.py {sid} --no-publish',
    ])


def pilot_live_checks(sid):
    """The pilot's link check of each live link: url, http, status."""
    signals = read_json(os.path.join(PILOT, 'data', 'deterministic.json'))
    return signals['submissions'].get(sid, {}).get('live', [])


def pilot_demo_status(sid):
    """The demo status the pilot's link check recorded (e.g. 'available')."""
    signals = read_json(os.path.join(PILOT, 'data', 'deterministic.json'))
    return signals['submissions'].get(sid, {}).get('demo', {}).get('status')


def main(sid):
    record = devpost_record(sid)
    links = record['links']
    print(f'· acquiring {sid}')
    sources = {
        'id': sid,
        'title': record['title'],
        'tagline': record['tagline'],
        'team': record['team'],
        'builtWith': record['builtWith'],
        'devpostUrl': record['devpostUrl'],
        'writeup': record['writeup'],
        'live': links.get('live', []),
        # Whether each link answered when the pilot checked it, so a review
        # never calls a dead link a live deployment.
        'liveChecks': pilot_live_checks(sid),
        'repo': repository(sid, links['repo']) if links.get('repo')
        else {'status': 'notLinked'},
        'demo': demo(sid, links.get('video')),
    }
    d = sources['demo']
    pilot = pilot_demo_status(sid)
    if d['status'] == 'downloadFailed' and pilot in ('private', 'unavailable'):
        # The link check already found the video private or gone: that is a
        # fact about the submission, not a download problem.
        d = sources['demo'] = {'status': pilot, 'url': d['url']}
    if d['status'] != 'available' and pilot == 'available':
        # Later stages would otherwise write a review that says there is no
        # demo. Stop before sources.json exists for this run.
        path = stage_path(sid, 'sources')
        if os.path.exists(path):
            os.remove(path)
        raise SystemExit(manual_download_help(sid, d))
    write_json(stage_path(sid, 'sources'), sources)
    print(f"  repo {sources['repo'].get('sha')} · demo {d.get('duration')}s, "
          f"{len(d.get('frames', []))} frames, {len(d.get('captions', []))} caption cues")


if __name__ == '__main__':
    main(sys.argv[1])
