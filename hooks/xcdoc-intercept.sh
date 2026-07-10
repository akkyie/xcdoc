#!/usr/bin/env bash
# PreToolUse hook: redirect WebFetch of developer.apple.com documentation to the
# offline `xcdoc` CLI, which renders the same pages without a network round-trip.
#
# Denies the fetch only when the URL is an Apple documentation page AND `xcdoc`
# is installed, so a fetch is never blocked when there is no offline fallback.
# Any other URL — or a missing/unparsable payload — is allowed (fail-open).
set -uo pipefail

input=$(cat)
url=$(printf '%s' "$input" | jq -r '.tool_input.url // empty' 2>/dev/null || true)

case "$url" in
  https://developer.apple.com/documentation/* | http://developer.apple.com/documentation/*)
    if command -v xcdoc >/dev/null 2>&1; then
      jq -n --arg url "$url" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: ("Use the offline xcdoc CLI instead of fetching this page from the web. Run: xcdoc show \"" + $url + "\"")
        }
      }'
    fi
    ;;
esac

exit 0
