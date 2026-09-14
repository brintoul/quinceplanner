# TODO

- **Fill in missing Spanish translations.** Several features (onboarding wizard, checklist reminders, and some older Guest List/Budget strings) were added with English-only literals — they exist in `QuincePlanner/Localizable.xcstrings` but have no `es` translation yet. Fill these in via Xcode's String Catalog editor (or ask Claude to do it).

  To list what's currently missing:
  ```bash
  python3 -c "
  import json
  data = json.load(open('QuincePlanner/Localizable.xcstrings'))
  missing = [k for k, v in data['strings'].items() if 'es' not in v.get('localizations', {})]
  print(len(missing), 'keys missing an es translation')
  for k in sorted(missing):
      print(' -', k)
  "
  ```
