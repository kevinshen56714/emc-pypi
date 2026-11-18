import json
import re
import subprocess
from datetime import date, timedelta
from pathlib import Path
from urllib.request import urlopen

DOWNLOAD_PAGE = 'https://montecarlo.sourceforge.net/emc/Download.html'


def renewal_reason(release, today):
    expiry = date.fromisoformat(release['valid_until'])
    if expiry <= today + timedelta(days=60):
        return f'The bundled EMC build expires on {expiry}.'

    with urlopen(DOWNLOAD_PAGE, timeout=30) as response:
        page = response.read().decode('utf-8')
    names = set(re.findall(r'href="[^"]*/(emc_[^"/]+\.tgz)"', page))
    if not names:
        raise RuntimeError('No EMC archive links found on the download page')
    bundled = {url.rsplit('/', 1)[1] for url in release['archives']}
    if names != bundled:
        return 'The official archive list has changed.\n\n' + '\n'.join(
            sorted(names))


if __name__ == '__main__':
    release = json.loads(Path(__file__).with_name('upstream.json').read_text())
    reason = renewal_reason(release, date.today())
    if reason:
        title = f"Renew bundled EMC build {release['build']}"
        issues = subprocess.check_output([
            'gh', 'issue', 'list', '--state', 'open', '--search',
            f'in:title "{title}"', '--json', 'title'
        ])
        if not any(issue['title'] == title for issue in json.loads(issues)):
            subprocess.run([
                'gh', 'issue', 'create', '--title', title, '--body',
                f'{reason}\n\n[Official EMC downloads]({DOWNLOAD_PAGE})'
            ],
                           check=True)
