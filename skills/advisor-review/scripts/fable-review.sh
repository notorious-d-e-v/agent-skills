#!/bin/bash
# usage: fable-review.sh [--detach] <workdir> <brief-file> <out-file> [effort]
#
# One fresh, independent review by Claude Code on Fable 5.2. The reviewer can read files
# and run commands (code, tests, git, gh); it has no file-edit tools, no skills, no MCP
# servers and no auto-memory. No session is saved and none is resumed, so every call is a
# reviewer that has never seen the work.
#   effort: low | medium | high (default) | xhigh | max
#   writes: <out-file> (the review), <out-file>.log (stderr), <out-file>.done ("exit <code> <HH:MMZ>")
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
  echo "launched Fable review ($effort) at $(date -u +%H:%MZ); poll $out.done"
  exit 0
fi

rm -f "$out" "$out.done"
# CLAUDE_BIN overrides; otherwise the `claude` on PATH, then ~/.local/bin/claude.
claude_bin=${CLAUDE_BIN:-$(command -v claude || echo "$HOME/.local/bin/claude")}
# fail <code> <message>: record the reason in the log and the .done file, then exit.
fail() { echo "$2" | tee -a "$out.log" >&2; echo "exit $1 $(date -u +%H:%MZ)" >"$out.done"; exit "$1"; }
command -v "$claude_bin" >/dev/null 2>&1 || fail 127 "claude CLI not found: $claude_bin"
case "$claude_bin" in /*) ;; */*) claude_bin="$PWD/$claude_bin";; esac
cd "$workdir" || fail 2 "cannot enter $workdir"
# Env overrides that would change the model or effort, or mark this as a nested session, are cleared.
# Assemble the whole prompt first; nothing is launched unless that worked.
prompt=$(mktemp "${TMPDIR:-/tmp}/advisor-review.XXXXXX") || fail 2 "cannot create a temporary prompt file"
cat "$here/reviewer-rules.md" "$brief" >"$prompt" 2>>"$out.log" || { rm -f "$prompt"; fail 2 "cannot read the rules or the brief"; }
  env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_EFFORT_LEVEL -u ANTHROPIC_MODEL \
  ADVISOR_REVIEW_ACTIVE=1 CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 \
  "$claude_bin" -p --model claude-fable-5-2 --effort "$effort" \
  --permission-mode dontAsk \
  --tools "Read,Grep,Glob,Bash" \
  --allowedTools "Read" "Grep" "Glob" "Bash" \
  --strict-mcp-config --setting-sources "" --disable-slash-commands \
  --no-session-persistence --output-format text \
  <"$prompt" >"$out" 2>>"$out.log"
code=$?
rm -f "$prompt"
echo "exit $code $(date -u +%H:%MZ)" >"$out.done"
size=0; [ -f "$out" ] && size=$(wc -c <"$out" | tr -d ' ')
echo "Fable review ($effort) finished: exit $code, $size bytes in $out"
exit $code
