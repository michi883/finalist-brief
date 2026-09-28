"""Secret redaction for judge-facing output.

A review may need to say that a key is hard-coded; it never needs to repeat
the key. After grounding has checked every citation against the original
source, this replaces secret-like literal values in all judge-facing text
(summary, labels, notes, quotes, questions, bases, dimension notes) with
[redacted]. Citation checking and verification never see redacted text.

Two deterministic rules:
1. Known credential formats, anywhere (Google API keys, OpenAI/Stripe-style
   sk- keys, GitHub tokens, AWS access key IDs, Slack tokens, JWTs, PEM
   private keys).
2. A quoted literal assigned to, or passed right after, a name whose parts
   include key, secret, token, password, iv, salt, credential and similar
   (`_encryptionKey = Key.fromUtf8('…')`, `"apiKey": "…"`).
3. A fallback value (after `??`, or a literal `return`) in a statement or
   function named for a key, secret, token, password, credential or
   encryption (`_getEncryptionKey() { return passwords['k'] ?? 'dev-key'; }`).
   Lookup names such as `passwords['k']` are not fallbacks and stay.
Every such value found in the code the generator was shown is also removed
from prose, so it cannot reappear in a note or a question.
"""

import re

FORMATS = [
    r'AIza[0-9A-Za-z_\-]{20,}',
    r'\bsk-(?:proj-|ant-)?[A-Za-z0-9_\-]{16,}',
    r'\b[rs]k_(?:live|test)_[A-Za-z0-9]{16,}',
    r'\bgh[pousr]_[A-Za-z0-9]{20,}',
    r'\bgithub_pat_[A-Za-z0-9_]{20,}',
    r'\bAKIA[0-9A-Z]{16}\b',
    r'\bxox[abprs]-[A-Za-z0-9\-]{10,}',
    r'\beyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}',
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)',
]
FORMAT = re.compile('|'.join(f'(?:{f})' for f in FORMATS))
SENSITIVE = {'key', 'keys', 'secret', 'secrets', 'token', 'tokens', 'password',
             'passwd', 'pwd', 'pass', 'iv', 'salt', 'credential', 'credentials',
             'apikey', 'pat', 'private', 'auth', 'bearer', 'signature', 'cipher'}
# A name, then within a short span an opening quote: `name = X('`, `name: '`,
# `"name": "`, `name('`. The literal may be cut off at the end of a quote.
ASSIGNED = re.compile(
    r"""(?P<name>[A-Za-z_][A-Za-z0-9_]*)['"]?\s*(?:[:=]|\()[^'"\n;]{0,40}?"""
    r"""(?P<q>['"])(?P<value>[^'"\n]{6,})(?:(?P=q)|$)""")
MASK = '[redacted]'
WORDS = re.compile(r'[a-z]+(?:[_.\- ][a-z0-9]+)*')
LOOKUP = re.compile(r'(?i)(?:get|read|load|fetch|lookup|env|environment|fromenvironment|'
                    r'passwords?|secrets?|config)\w*\s*\(\s*$')
PLACEHOLDER = re.compile(r'(?i)(your[_\- ]|paste|enter[_\- ]|<|x{3,}|placeholder|example|changeme|todo|replace)')


def name_parts(name):
    spaced = re.sub(r'([a-z0-9])([A-Z])', r'\1 \2', name).replace('_', ' ')
    return {p.lower() for p in spaced.split()}


def sensitive_literals(text):
    """(start, end, value) of secret-like literals in code or a quote."""
    found = []
    for m in ASSIGNED.finditer(text):
        value = m['value']
        # Interpolated strings and paths are not literal secrets.
        if '$' in value or '{' in value or value.startswith(('http', '/', 'assets')):
            continue
        # Not secrets: a subscript key (map['private']), a lookup argument
        # (getPassword('weatherApiKey')), a lookup name made of lowercase
        # words ('session_token', 'app_theme'), a message, a placeholder.
        # A returned value is judged by the fallback rule instead.
        before = text[m.start():m.start('q')]
        if text[m.start('q') - 1:m.start('q')] == '[' or LOOKUP.search(before) \
                or re.search(r'\breturn\b', before) or ' ' in value \
                or WORDS.fullmatch(value) or PLACEHOLDER.match(value) or MOCK.match(value) \
                or EMAIL.fullmatch(value):
            continue
        if name_parts(m['name']) & SENSITIVE:
            found.append((m.start('value'), m.end('value'), value))
    return found


FALLBACK = re.compile(r"""(?:\?\?|\breturn)\s*(?P<q>['"])(?P<value>[^'"\n]{6,})(?P=q)""")
CONTEXT_SENSITIVE = {'key', 'keys', 'secret', 'secrets', 'token', 'tokens', 'password',
                     'passwords', 'passwd', 'pwd', 'credential', 'credentials',
                     'encryption', 'encrypt', 'decrypt', 'cipher', 'apikey', 'salt', 'iv'}
FUNCTION = re.compile(
    r'^\s*(?:@\w+\s+)*(?:(?:static|final|const|async|private|public|override|def|'
    r'function|fun|func)\s+)*(?:[\w<>?,\[\]]+\s+)?(?P<name>[A-Za-z_]\w*)\s*\(')
KEYWORDS = {'if', 'for', 'while', 'switch', 'catch', 'return', 'print', 'await', 'throw',
            'assert', 'super', 'this', 'new', 'else'}
EMAIL = re.compile(r'[^@\s]+@[^@\s]+\.\w+')
MOCK = re.compile(r'(?i)(mock|dummy|fake|sample|test)[_\-]')
NUMBERING = re.compile(r'^ *\d+\| ?', re.M)


def fallback_literals(text):
    """(start, end, value) of fallback strings used as a key, token or
    password: the statement or its enclosing function carries the name."""
    found = []
    for m in FALLBACK.finditer(text):
        value = m['value']
        if '$' in value or '{' in value or value.startswith(('http', '/', 'assets')) \
                or PLACEHOLDER.match(value):
            continue
        # Messages, addresses and mock values are not secrets.
        if ' ' in value or EMAIL.fullmatch(value) or MOCK.match(value):
            continue
        # A function that returns a lookup name ('auth_token_v1') is not
        # returning a secret; a `??` fallback always counts.
        if m[0].startswith('return') and WORDS.fullmatch(value):
            continue
        statement = re.split(r'[;{}]', text[:m.start()])[-1]
        names = set(re.findall(r'[A-Za-z_]\w*', statement))
        for line in reversed(text[:m.start()].splitlines()[-25:]):
            fn = FUNCTION.match(line)
            if fn and fn['name'] not in KEYWORDS:
                names.add(fn['name'])
                break
        if any(name_parts(n) & CONTEXT_SENSITIVE for n in names):
            found.append((m.start('value'), m.end('value'), value))
    return found


def secrets_in(texts):
    """Every secret-like value in the given source texts."""
    values = set()
    for text in texts:
        text = NUMBERING.sub('', text)
        values.update(v for _, _, v in sensitive_literals(text))
        values.update(v for _, _, v in fallback_literals(text))
        values.update(m[0] for m in FORMAT.finditer(text))
    # These are also replaced in prose, so short, common or masked strings
    # ('Bearer', '000000', '••••') and placeholders are left out.
    return {v for v in values if len(v) >= 8 and re.search(r'[A-Za-z]', v)
            and re.search(r'[A-Za-z0-9]{4}', v) and not PLACEHOLDER.match(v)}


def redact_text(text, known):
    if not text:
        return text, 0
    count = 0
    spans = sorted(set(sensitive_literals(text)) | set(fallback_literals(text)))
    for start, end, _ in reversed(spans):
        text = text[:start] + MASK + text[end:]
        count += 1
    text, n = FORMAT.subn(MASK, text)
    count += n
    for value in sorted(known, key=len, reverse=True):
        if value in text:
            count += text.count(value)
            text = text.replace(value, MASK)
    return text, count


def redact_review(review, known):
    """Redacts every judge-facing string in a grounded review in place.
    Returns [(where, count)]."""
    log = []

    def walk(node, where):
        if isinstance(node, dict):
            for k, v in node.items():
                if isinstance(v, str) and k not in ('id', 'at', 'source', 'image', 'kind',
                                                   'status', 'topology', 'focus', 'lens'):
                    new, n = redact_text(v, known)
                    if n:
                        node[k] = new
                        log.append((f'{where}.{k}', n))
                else:
                    walk(v, f'{where}.{k}')
        elif isinstance(node, list):
            for i, v in enumerate(node):
                if isinstance(v, str):
                    new, n = redact_text(v, known)
                    if n:
                        node[i] = new
                        log.append((f'{where}[{i}]', n))
                else:
                    walk(v, f'{where}[{i}]')

    walk(review, 'review')
    return log


# ---------------------------------------------------------------- contacts
#
# Not secret redaction: a separate, narrow output rule. A review does not
# repeat a personal phone number or email address that a demo frame or the
# narration happened to show; it says "[phone number]" instead. Addresses the
# team put in its own code or writeup (mock data, a sender address) and
# placeholder domains stay. Frames and other raw evidence are not changed.

PHONE = re.compile(r'(?<![\w/])\+\d[\d \-().]{6,}\d(?!\w)|\(\d{3}\)\s?\d{3}[\s.\-]\d{4}\b|\b\d{3}[.\-]\d{3}[.\-]\d{4}\b')
EMAIL_ANY = re.compile(r'\b[\w.+\-]+@[\w\-]+(?:\.[\w\-]+)+\b')
PLACEHOLDER_DOMAINS = {'example.com', 'example.org', 'example.net', 'company.com', 'test.com',
                       'domain.com', 'email.com', 'mail.com'}


def contacts_allowed(texts):
    """Addresses and numbers the team published in its own code or writeup."""
    found = set()
    for text in texts:
        found.update(m[0].lower() for m in EMAIL_ANY.finditer(text))
        found.update(re.sub(r'\D', '', m[0]) for m in PHONE.finditer(text))
    return found


def mask_contacts_text(text, allowed):
    if not text:
        return text, 0
    count = 0

    def phone(m):
        nonlocal count
        if re.sub(r'\D', '', m[0]) in allowed:
            return m[0]
        count += 1
        return '[phone number]'

    def email(m):
        nonlocal count
        if m[0].lower() in allowed or m[0].split('@')[1].lower() in PLACEHOLDER_DOMAINS:
            return m[0]
        count += 1
        return '[email address]'

    text = EMAIL_ANY.sub(email, text)
    text = PHONE.sub(phone, text)
    return text, count


def mask_contacts(review, allowed):
    """Applies mask_contacts_text to every judge-facing string in place.
    Returns [(where, count)]."""
    log = []

    def walk(node, where):
        items = node.items() if isinstance(node, dict) else enumerate(node) if isinstance(node, list) else []
        for k, v in list(items):
            if isinstance(v, str):
                if isinstance(node, dict) and k in ('id', 'at', 'source', 'image', 'kind', 'status',
                                                    'topology', 'focus', 'lens'):
                    continue
                new, n = mask_contacts_text(v, allowed)
                if n:
                    node[k] = new
                    log.append((f'{where}.{k}', n))
            else:
                walk(v, f'{where}.{k}')

    walk(review, 'review')
    return log
