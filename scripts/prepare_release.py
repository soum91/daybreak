"""Prepare factual notes before publishing, keeping root changelog aligned."""
import os
from pathlib import Path

number = int(os.environ['BUILD_NUMBER'])
version = f'0.1.{number}'
notes = Path('release-notes/current.md').read_text().strip()
sha = os.environ['GITHUB_SHA']
body = notes + f'\n\nSource commit: https://github.com/soum91/daybreak/commit/{sha}\n'
Path('dist').mkdir(exist_ok=True)
Path('dist/release-notes.md').write_text(body)
changelog = Path('CHANGELOG.md')
existing = changelog.read_text()
heading = f'## {version}'
if heading not in existing.splitlines():
    prefix = '# Changelog\n'
    rest = existing.removeprefix(prefix).lstrip()
    if rest.startswith('## Unreleased\n'):
        following = rest.find('\n## ', len('## Unreleased\n'))
        rest = rest[following + 1:] if following >= 0 else ''
    changelog.write_text(f'{prefix}\n{heading}\n\n{body}\n{rest}')
