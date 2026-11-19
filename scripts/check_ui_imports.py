#!/usr/bin/env python3
"""Public entry gate: app code imports tavli_ui only through package:tavli_ui/tavli_ui.dart."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Dart code outside the package itself; the package may use its own src/.
APP_ROOTS = ('lib', 'test', 'integration_test', 'tool')
DIRECTIVE = re.compile(r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''', re.M)
ALLOWED = 'package:tavli_ui/tavli_ui.dart'


def violations(path: Path, source: str):
    """Yield (line, uri) for every directive that bypasses the public entry."""
    for match in DIRECTIVE.finditer(source):
        uri = match.group(1)
        private = uri.startswith('package:tavli_ui/') and uri != ALLOWED
        reaches_in = 'packages/tavli_ui/' in uri
        if private or reaches_in:
            yield source.count('\n', 0, match.start()) + 1, uri


def check(root: Path):
    errors = []
    for folder in APP_ROOTS:
        base = root / folder
        if not base.is_dir():
            continue
        for path in sorted(base.rglob('*.dart')):
            source = path.read_text(encoding='utf-8')
            for line, uri in violations(path, source):
                rel = path.relative_to(root)
                errors.append(f'{rel}:{line}: uvozi "{uri}"; koristi samo {ALLOWED}')
    return errors


def main():
    errors = check(ROOT)
    for e in errors:
        print(e)
    if errors:
        print(f'Javni ulaz tavli_ui: {len(errors)} greška(e).')
        return 1
    print('Javni ulaz tavli_ui: OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
