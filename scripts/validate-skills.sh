#!/usr/bin/env bash
# Validate all SKILL.md files in skills/ for frontmatter correctness.
# Usage: ./scripts/validate-skills.sh

set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "$0")/../skills" && pwd)"
ERRORS=0
CHECKED=0

red()   { printf '\033[0;31m%s\033[0m\n' "$1"; }
green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[0;33m%s\033[0m\n' "$1"; }

check_fail() {
  red "  FAIL: $1"
  ERRORS=$((ERRORS + 1))
}

check_warn() {
  yellow "  WARN: $1"
}

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"

  if [[ ! -f "$skill_file" ]]; then
    check_fail "$skill_name: SKILL.md not found"
    continue
  fi

  CHECKED=$((CHECKED + 1))
  echo "Checking $skill_name..."

  # Extract frontmatter (between --- markers)
  frontmatter=$(awk '/^---$/{n++; next} n==1' "$skill_file")

  # Check required fields
  if ! echo "$frontmatter" | grep -q '^name:'; then
    check_fail "$skill_name: missing 'name' field"
  else
    fm_name=$(echo "$frontmatter" | grep '^name:' | head -1 | sed 's/^name: *//')
    if [[ "$fm_name" != "$skill_name" ]]; then
      check_fail "$skill_name: name '$fm_name' does not match directory name '$skill_name'"
    fi
  fi

  if ! echo "$frontmatter" | grep -q '^description:'; then
    check_fail "$skill_name: missing 'description' field"
  else
    # Extract full description (may be multiline with >-)
    desc=$(awk '/^---$/{n++; next} n==1' "$skill_file" | awk '
      /^description:/{found=1; sub(/^description: *>-? */, ""); if(length($0)>0) printf "%s ", $0; next}
      found && /^  /{sub(/^  +/, ""); printf "%s ", $0; next}
      found{exit}
    ')
    desc_len=${#desc}

    if [[ $desc_len -gt 1024 ]]; then
      check_fail "$skill_name: description is $desc_len chars (max 1024)"
    fi

    if echo "$desc" | grep -q '<+'; then
      check_fail "$skill_name: description contains XML-style angle brackets (<+...>)"
    fi
  fi

  if ! echo "$frontmatter" | grep -q 'author:'; then
    check_fail "$skill_name: missing 'metadata.author' field"
  fi

  if ! echo "$frontmatter" | grep -q 'version:'; then
    check_fail "$skill_name: missing 'metadata.version' field"
  fi

  if ! echo "$frontmatter" | grep -q 'mcp-server:'; then
    check_fail "$skill_name: missing 'metadata.mcp-server' field"
  fi

  if ! echo "$frontmatter" | grep -q '^license:'; then
    check_fail "$skill_name: missing 'license' field"
  fi

  if ! echo "$frontmatter" | grep -q '^compatibility:'; then
    check_fail "$skill_name: missing 'compatibility' field"
  fi

  # Check body has Instructions section
  if ! grep -q '^## Instructions' "$skill_file"; then
    check_warn "$skill_name: no '## Instructions' section found"
  fi

  # Check body has Troubleshooting section
  if ! grep -q '^## Troubleshooting' "$skill_file" && ! grep -q '^## Error Handling' "$skill_file"; then
    check_warn "$skill_name: no '## Troubleshooting' or '## Error Handling' section found"
  fi

  # Check body has Examples section
  if ! grep -q '^## Examples' "$skill_file"; then
    check_warn "$skill_name: no '## Examples' section found"
  fi
done

echo ""
echo "================================"
echo "Checked $CHECKED skills, found $ERRORS errors"
echo "================================"

if [[ $ERRORS -gt 0 ]]; then
  red "Validation failed with $ERRORS error(s)"
  exit 1
else
  green "All skills passed validation"
  exit 0
fi
