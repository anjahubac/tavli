#!/usr/bin/env python3
"""Library-only gate for screens already moved to tavli_ui.

Files in MIGRATED use components from package:tavli_ui/tavli_ui.dart: no raw
Material widgets that the library replaces, and no hand-written numbers
(sizes, spacing, radii come from library tokens). Add a screen's files here
when its UI library card moves it to the library.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Card "UI biblioteka 7": Nalog i podešavanja.
MIGRATED = (
    'lib/features/account/account_dialogs.dart',
    'lib/features/settings/ai_keys_screen.dart',
    'lib/features/settings/appearance_screen.dart',
    'lib/features/settings/profile_account_section.dart',
    'lib/features/settings/profile_screen.dart',
    'lib/features/settings/settings_page.dart',
    # Card "UI biblioteka 9": Nabavka.
    'lib/features/shopping/shopping_frame.dart',
    'lib/features/shopping/shopping_list_view.dart',
    'lib/features/shopping/shopping_screen.dart',
    # Card "UI biblioteka 10": Plan.
    'lib/features/planning/meal_entry_card.dart',
    'lib/features/planning/meal_entry_detail.dart',
    'lib/features/planning/plan_calendar.dart',
    'lib/features/planning/plan_screen.dart',
    # Domaćinstvo: pozivnica i pridruživanje (spec 008, FR-005/FR-006).
    'lib/features/account/household_setup_screen.dart',
    'lib/features/account/household_share_screen.dart',
    'lib/features/account/household_widgets.dart',
    'lib/features/settings/household_edit_dialog.dart',
    'lib/features/settings/profile_household_section.dart',
)

# Material widgets with a library replacement (Tavli* component or helper).
RAW_WIDGETS = (
    'AlertDialog', 'AppBar', 'BackButton', 'BottomSheet', 'Card',
    'Checkbox', 'CheckboxListTile', 'Chip', 'ChoiceChip', 'CircleAvatar',
    'CircularProgressIndicator', 'Divider', 'DropdownButton',
    'DropdownButtonFormField', 'ElevatedButton', 'FilledButton', 'FilterChip',
    'FloatingActionButton', 'IconButton', 'InkResponse', 'InkWell',
    'LinearProgressIndicator', 'ListTile', 'Material', 'NavigationBar',
    'NavigationRail', 'OutlinedButton', 'PopupMenuButton', 'Radio',
    'RadioListTile', 'SegmentedButton', 'SimpleDialog', 'SnackBar', 'Switch',
    'SwitchListTile', 'TextButton', 'TextField', 'TextFormField', 'Tooltip',
    'VerticalDivider', 'showModalBottomSheet',
)
WIDGET = re.compile(r'(?<![\w.$])(' + '|'.join(RAW_WIDGETS) + r')\s*(?:<[^>]*>)?\s*[(.]')
# Number literals except 0 and 1 (indexes, counts, `split(' ').first`).
NUMBER = re.compile(r'(?<![\w.$])(?:\d+\.\d+|\d+)(?![\w.])')
ALLOWED_NUMBERS = {'0', '1'}


def strip_strings_and_comments(source: str) -> str:
    """Blank out comments and string literals, keeping line breaks."""
    out = []
    i = 0
    n = len(source)
    while i < n:
        ch = source[i]
        if source.startswith('//', i):
            end = source.find('\n', i)
            end = n if end == -1 else end
            i = end
            continue
        if source.startswith('/*', i):
            end = source.find('*/', i + 2)
            end = n if end == -1 else end + 2
            out.append(re.sub(r'[^\n]', ' ', source[i:end]))
            i = end
            continue
        if ch in '\'"':
            quote = source[i:i + 3] if source[i:i + 3] in ("'''", '"""') else ch
            raw = i > 0 and source[i - 1] == 'r'
            j = i + len(quote)
            kept = [' ' * len(quote)]
            depth = 0
            while j < n:
                if depth:
                    # Kod u `${...}` ostaje vidljiv proveri.
                    if source[j] == '{':
                        depth += 1
                    elif source[j] == '}':
                        depth -= 1
                    kept.append(source[j] if depth else ' ')
                    j += 1
                    continue
                if not raw and source[j] == '\\':
                    kept.append('  ')
                    j += 2
                    continue
                if not raw and source.startswith('${', j):
                    depth = 1
                    kept.append('  ')
                    j += 2
                    continue
                if source.startswith(quote, j):
                    kept.append(' ' * len(quote))
                    j += len(quote)
                    break
                kept.append('\n' if source[j] == '\n' else ' ')
                j += 1
            out.append(''.join(kept))
            i = j
            continue
        out.append(ch)
        i += 1
    return ''.join(out)


def violations(source: str):
    """Yield (line, message) for raw widgets and hand-written numbers."""
    code = strip_strings_and_comments(source)
    for match in WIDGET.finditer(code):
        line = code.count('\n', 0, match.start()) + 1
        yield line, f'sirov Material widget {match.group(1)}; koristi komponentu iz tavli_ui'
    for match in NUMBER.finditer(code):
        if match.group(0) in ALLOWED_NUMBERS:
            continue
        line = code.count('\n', 0, match.start()) + 1
        yield line, f'ručni broj {match.group(0)}; koristi token iz tavli_ui'


def check(root: Path, files=MIGRATED):
    errors = []
    for rel in files:
        path = root / rel
        if not path.is_file():
            errors.append(f'{rel}: ne postoji (ažuriraj MIGRATED)')
            continue
        for line, message in violations(path.read_text(encoding='utf-8')):
            errors.append(f'{rel}:{line}: {message}')
    return errors


def main():
    errors = check(ROOT)
    for e in errors:
        print(e)
    if errors:
        print(f'Preseljeni ekrani: {len(errors)} greška(e).')
        return 1
    print('Preseljeni ekrani: OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
