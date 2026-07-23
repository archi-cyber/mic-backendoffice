import re

path = r"c:\Users\maint\Documents\Valdo\work\Molded\mic_backoffice\lib\core\localization\app_localizations.dart"
lines = open(path, encoding="utf-8").read().splitlines(keepends=True)

start = next(i for i, l in enumerate(lines) if "_literalValues" in l)
end = next(i for i, l in enumerate(lines) if "_fallbackPhraseReplacements" in l)

new_lines = lines[:start]
for i in range(start, end):
    line = lines[i]
    if "_selectedMemberIds" in line:
        continue
    if i > 1580 and "'Blocked from new task assignments':" in line and "'Blocked from new task assignments':" in "".join(lines[1390:1580]):
        continue
    # Escape interpolation in literal map lines only (indented entries)
    if line.strip().startswith("'") and ":" in line:
        line = line.replace("$e", r"\$e")
        line = line.replace("$guestEmail", r"\$guestEmail")
        line = line.replace("${e.toString()}", r"\${e.toString()}")
        line = line.replace("${currentPage + 1}", r"\${currentPage + 1}")
        line = line.replace("${maxPage + 1}", r"\${maxPage + 1}")
    new_lines.append(line)
new_lines.extend(lines[end:])

open(path, "w", encoding="utf-8").writelines(new_lines)
print("Fixed app_localizations.dart")
