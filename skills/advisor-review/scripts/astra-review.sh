#!/bin/bash
# usage: astra-review.sh [--detach] <workdir> <brief-file> <out-file> [effort]
#
# One fresh, independent review by Codex on GPT-6 Astra. The reviewer can read files and
# run commands, with approvals and the sandbox bypassed; the rules tell it not to change
# anything. Every call is a new Codex session, never a resume, so the reviewer has never
# seen the work. The user's config.toml is not loaded and the session is not saved;
# installed skills may still be visible to it, so the rules and a guard in these scripts
# stop it from starting a review of its own.
#   effort: low | medium | high (default) | xhigh | max
#   writes: <out-file> (the review), <out-file>.log (run log), <out-file>.done ("exit <code> <HH:MMZ>")
#   --detach: return at once and let the review run in the background; poll <out-file>.done
set -u
# Resolve symlinks so the rules file is found when the script is called through a link.
self="$0"
while [ -L "$self" ]; do
  link=$(readlink "$self")
  case "$link" in /*) self="$link";; *) self="$(dirname "$self")/$link";; esac
done
here="$(cd "$(dirname "$self")" && pwd -P)"
usage() { echo "usage: $0 [--detach] <workdir> <brief-file> <out-file> [effort]" >&2; }
# A reviewer must never start another review (its CLI gets this marker in its environment).
if [ -n "${ADVISOR_REVIEW_ACTIVE:-}" ]; then
  echo "already inside an advisor review; a reviewer must not start another review" >&2; exit 2
fi
detach=0; run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --detach) detach=1; shift;;
    --run) run=1; shift;;
    --*) echo "unknown option: $1" >&2; usage; exit 2;;
    *) break;;
  esac
done
if [ $# -lt 3 ] || [ $# -gt 4 ]; then usage; exit 2; fi
workdir=$1; brief=$2; out=$3; effort=${4:-high}
case "$effort" in low|medium|high|xhigh|max) ;; *) echo "bad effort: $effort" >&2; exit 2;; esac
[ -d "$workdir" ] || { echo "no such directory: $workdir" >&2; exit 2; }
{ [ -f "$brief" ] && [ -r "$brief" ] && [ -s "$brief" ]; } || { echo "brief must be a readable, non-empty file: $brief" >&2; exit 2; }
{ [ -f "$here/reviewer-rules.md" ] && [ -r "$here/reviewer-rules.md" ] && [ -s "$here/reviewer-rules.md" ]; } || { echo "reviewer-rules.md is missing from $here; refusing to launch a reviewer without its rules" >&2; exit 2; }
case "$out" in /*) ;; *) out="$PWD/$out";; esac
case "$brief" in /*) ;; *) brief="$PWD/$brief";; esac
# The output files must not be the brief or the rules file (same path, symlink or hard link):
# they are truncated below.
for target in "$out" "$out.log" "$out.done"; do
  for input in "$brief" "$here/reviewer-rules.md"; do
    if [ "$target" = "$input" ] || [ "$target" -ef "$input" ]; then
      echo "out-file collides with an input file: $target is $input; the review was not started" >&2; exit 2
    fi
  done
done
# Fail now, not in the background, if the output location is not writable.
if ! { mkdir -p "$(dirname "$out")" && : >"$out.log" && rm -f "$out.done" && : >"$out"; } 2>/dev/null; then
  echo "cannot write $out (and its .log and .done files); the review was not started" >&2; exit 2
fi

if [ $detach -eq 1 ] && [ $run -eq 0 ]; then
  rm -f "$out" "$out.done"
  nohup bash "$here/$(basename "$self")" --run "$workdir" "$brief" "$out" "$effort" >/dev/null 2>&1 &
  echo "launched Astra review ($effort) at $(date -u +%H:%MZ); poll $out.done"
  exit 0
fi

rm -f "$out" "$out.done"
# CODEX_BIN overrides; otherwise the `codex` on PATH, then ~/.local/bin/codex.
codex_bin=${CODEX_BIN:-$(command -v codex || true)}
[ -n "$codex_bin" ] || { [ -x "$HOME/.local/bin/codex" ] && codex_bin="$HOME/.local/bin/codex"; }
# fail <code> <message>: record the reason in the log and the .done file, then exit.
fail() { echo "$2" | tee -a "$out.log" >&2; echo "exit $1 $(date -u +%H:%MZ)" >"$out.done"; exit "$1"; }
{ [ -n "$codex_bin" ] && command -v "$codex_bin" >/dev/null 2>&1; } || fail 127 "codex CLI not found: ${codex_bin:-codex}"
case "$codex_bin" in /*) ;; */*) codex_bin="$PWD/$codex_bin";; esac
# Model, effort and speed are pinned here and the user config is ignored (auth is still read).
# Assemble the whole prompt first; nothing is launched unless that worked.
prompt=$(mktemp "${TMPDIR:-/tmp}/advisor-review.XXXXXX") || fail 2 "cannot create a temporary prompt file"
cat "$here/reviewer-rules.md" "$brief" >"$prompt" 2>>"$out.log" || { rm -f "$prompt"; fail 2 "cannot read the rules or the brief"; }
  ADVISOR_REVIEW_ACTIVE=1 "$codex_bin" exec -C "$workdir" \
  -m gpt-6-astra -c "model_reasoning_effort=\"$effort\"" --disable fast_mode \
  --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
  --ignore-user-config --ephemeral \
  -o "$out" - <"$prompt" >>"$out.log" 2>&1
code=$?
rm -f "$prompt"
echo "exit $code $(date -u +%H:%MZ)" >"$out.done"
size=0; [ -f "$out" ] && size=$(wc -c <"$out" | tr -d ' ')
echo "Astra review ($effort) finished: exit $code, $size bytes in $out"
exit $code
