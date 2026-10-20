#!/usr/bin/env bash
# Lists the files a pull request or push changed, without a checkout.
#
# Environment (set by changed/action.yml):
#   GION        path to the gion binary
#   REPOSITORY  owner/repo or a git URL
#   BASE, HEAD  commits to compare (empty: picked from the event)
#   PATHS       newline-separated paths to limit the diff to
#   EVENT       github.event_name
#   BEFORE      github.event.before (push)
#   MQ_BASE, MQ_HEAD  github.event.merge_group.base_sha / head_sha
set -euo pipefail

fail() { echo "::error::gion changed: $*" >&2; exit 1; }

base=${BASE:-}
head=${HEAD:-}
if [[ -z $base ]]; then
  case "$EVENT" in
    pull_request | pull_request_review | pull_request_review_comment)
      # GITHUB_SHA is GitHub's test merge of the PR into its base; its first
      # parent is the base tip, so this diff is exactly what the PR changes,
      # even when the base branch has moved on since the PR branched.
      [[ -z $head ]] || fail "set base too when you set head on $EVENT"
      head=$GITHUB_SHA
      base="$GITHUB_SHA^1"
      ;;
    push)
      head=${head:-$GITHUB_SHA}
      if [[ -z ${BEFORE:-} || $BEFORE =~ ^0+$ ]]; then
        # A new branch has no "before"; fall back to its last commit.
        base="$head^1"
      else
        base=$BEFORE
      fi
      ;;
    merge_group)
      head=${head:-$MQ_HEAD}
      base=$MQ_BASE
      ;;
    *)
      fail "can't pick commits to compare on '$EVENT'; set the base and head inputs"
      ;;
  esac
fi
head=${head:-$GITHUB_SHA}

args=(diff "$REPOSITORY" "$base" "$head" --name-only)
while IFS= read -r p; do
  p=${p#"${p%%[![:space:]]*}"}
  p=${p%"${p##*[![:space:]]}"}
  if [[ -n $p ]]; then args+=(--path "$p"); fi
done <<<"${PATHS:-}"

echo "gion ${args[*]}"
files=$("$GION" "${args[@]}")
[[ -z $files ]] || echo "$files"
count=$(grep -c . <<<"$files" || true)
json=$(jq -Rnc '[inputs | select(length > 0)]' <<<"$files")

delim="gion_$RANDOM$RANDOM$RANDOM"
{
  echo "base=$base"
  echo "head=$head"
  echo "count=$count"
  [[ $count -gt 0 ]] && echo "any=true" || echo "any=false"
  echo "json=$json"
  echo "files<<$delim"
  echo "$files"
  echo "$delim"
} >>"$GITHUB_OUTPUT"
