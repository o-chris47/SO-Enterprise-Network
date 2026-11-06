#!/usr/bin/env bash
# Repository checks, run locally with `bash scripts/check-repo.sh` and in CI.
#   1. No password hashes or passwords in configs/ (sanitise before committing).
#   2. Every relative link in the Markdown files points at a file that exists.
#   3. Every screenshot in screenshots/ is referenced from README.md.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

# 1. Secrets: any secret/password line that is not the <redacted> placeholder
if grep -rnE '(^|[[:space:]])(secret|password)[[:space:]]+[0-9]*[[:space:]]*[^[:space:]<]' configs \
     | grep -v '<redacted>'; then
  echo "ERROR: unredacted password or hash found in configs/ (replace with <redacted>)"
  fail=1
fi

# 2. Relative Markdown links
while IFS= read -r -d '' md; do
  dir=$(dirname "$md")
  while IFS= read -r target; do
    target=${target%%#*}
    case "$target" in
      ""|http://*|https://*|mailto:*) continue ;;
    esac
    if [ ! -e "$dir/$target" ]; then
      echo "ERROR: $md links to missing file: $target"
      fail=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$md" | sed -E 's/^\]\(//; s/\)$//')
done < <(find . -name '*.md' -not -path './.git/*' -print0)

# 3. Screenshots referenced from the README
for f in screenshots/*.png; do
  if ! grep -qF "screenshots/$(basename "$f")" README.md; then
    echo "ERROR: $f is not referenced in README.md"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then echo "All repository checks passed."; fi
exit "$fail"
