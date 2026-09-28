"""Step 1: select the pilot sample and parse each Devpost submission page.

The sample is the first SAMPLE_SIZE gallery slugs ordered by SHA-1, so it is
reproducible and independent of gallery order, prizes, likes or comments.
Winner badges and like counts are deliberately never recorded.

Output: data/devpost.json
"""

import hashlib
import os
import re

from common import (
    DATA, GALLERY, SAMPLE_SIZE, CHECKED, fetch, html_to_text, write_json,
)


def gallery_slugs():
    slugs = []
    page = 1
    while True:
        body = fetch(f'{GALLERY}?page={page}', f'gallery_{page}.html')
        found = re.findall(r'link-to-software" href="([^"]+)"', body)
        if not found:
            return slugs
        slugs += [url.rstrip('/').rsplit('/', 1)[1] for url in found]
        page += 1


def parse_submission(slug):
    url = f'https://devpost.com/software/{slug}'
    page = fetch(url, f'{slug}.html')
    title = html_to_text(re.search(r'id="app-title"[^>]*>(.*?)</h1>', page, re.S)[1])
    tagline = re.search(r'<p class="large">\s*(.*?)\s*</p>', page, re.S)
    # Start after the opening tag's `>`: pages without a media gallery use
    # this block as the writeup directly.
    left = page.split('id="app-details-left"')[1].split('>', 1)[1].split('id="built-with"')[0]
    # The writeup follows the media gallery. Headings are kept as `## ` lines
    # so later steps know which section each sentence belongs to.
    gallery = re.search(r'id="gallery".*?</ul>\s*</div>', left, re.S)
    body = left[gallery.end():] if gallery else left
    body = re.sub(
        r'<h[1-6][^>]*>(.*?)</h[1-6]>',
        lambda m: f'\n## {html_to_text(m[1])}\n', body, flags=re.S,
    )
    writeup = re.sub(r'\s*<div\s*$', '', html_to_text(body)).strip()

    built = page.split('id="built-with"')[1].split('</div>')[0] if 'id="built-with"' in page else ''
    built_with = [html_to_text(t) for t in re.findall(r'<span class="cp-tag[^"]*">(.*?)</span>', built, re.S)]

    links_block = re.search(r'data-role="software-urls".*?</ul>', page, re.S)
    links = re.findall(r'href="([^"]+)"', links_block[0]) if links_block else []
    # The rules require a repository link; some teams put it in the writeup.
    repo_links = [l for l in links if 'github.com' in l or 'gitlab.com' in l]
    if not repo_links:
        repo_links = [
            u for u in re.findall(r'https?://github\.com/[\w.-]+/[\w.-]+', left)
        ]
    repo = repo_links[0].removesuffix('.git').rstrip('/') if repo_links else None
    live = [l for l in links if l not in repo_links]

    video = re.search(
        r'(https://www\.youtube\.com/embed/[\w-]+|https://player\.vimeo\.com/video/\d+)',
        page,
    )
    team_block = page.split('id="app-team"')[1].split('</section>')[0] if 'id="app-team"' in page else ''
    team = list(dict.fromkeys(
        html_to_text(n) for n in re.findall(r'class="user-profile-link"[^>]*>([^<]+)</a>', team_block)
        if n.strip()
    ))
    return {
        'id': slug,
        'title': title,
        'tagline': html_to_text(tagline[1]) if tagline else '',
        'devpostUrl': url,
        'team': team,
        'builtWith': built_with,
        'links': {
            'repo': repo,
            'live': live,
            'video': video[1] if video else None,
        },
        'writeup': writeup,
    }


def main():
    slugs = gallery_slugs()
    ordered = sorted(slugs, key=lambda s: hashlib.sha1(s.encode()).hexdigest())
    sample = ordered[:SAMPLE_SIZE]
    submissions = [parse_submission(slug) for slug in sample]
    write_json(os.path.join(DATA, 'devpost.json'), {
        'gallery': GALLERY,
        'fieldSize': len(slugs),
        'checked': CHECKED,
        'sample': (
            f'All {len(slugs)} gallery submissions, ordered by SHA-1 of their slug. '
            'Prizes, likes and gallery order are never read.'
            if len(sample) == len(slugs) else
            f'The first {SAMPLE_SIZE} of {len(slugs)} gallery slugs ordered by '
            'SHA-1. Prizes, likes and gallery order are never read.'
        ),
        'submissions': submissions,
    })
    print(f'{len(slugs)} in gallery; wrote {len(submissions)} submissions')


if __name__ == '__main__':
    main()
