#!/usr/bin/env bash
# Installs Liquid Glass into a Jellyfin server's Custom CSS, keeping the rest of its branding.
#
#   JELLYFIN_URL=http://localhost:8096 JELLYFIN_API_KEY=... ./install.sh            full CSS, works offline
#   JELLYFIN_URL=... JELLYFIN_API_KEY=... ./install.sh --import                     one @import line, auto-updates
#   JELLYFIN_URL=... JELLYFIN_API_KEY=... ./install.sh --remove                     back to stock Jellyfin
#
# API key: Dashboard → API Keys → +. The previous Custom CSS is saved to custom-css.backup.css.
set -euo pipefail
cd "$(dirname "$0")"

URL=${JELLYFIN_URL:-http://localhost:8096}
URL=${URL%/}
KEY=${JELLYFIN_API_KEY:-}
CDN="https://cdn.jsdelivr.net/gh/xditya/jellyfin-liquid-glass@main/liquid-glass.css"

if [[ -z "$KEY" ]]; then
    echo "Set JELLYFIN_API_KEY (Dashboard → API Keys → +) and try again." >&2
    exit 1
fi
command -v curl >/dev/null && command -v python3 >/dev/null || {
    echo "Needs curl and python3." >&2
    exit 1
}

case "${1:-}" in
    "")       CSS=$(cat liquid-glass.css); WHAT="Liquid Glass (full CSS)" ;;
    --import) CSS="@import url(\"$CDN\");"; WHAT="Liquid Glass (@import, follows main)" ;;
    --remove) CSS=""; WHAT="stock Jellyfin (Custom CSS cleared)" ;;
    *)        sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

AUTH="Authorization: MediaBrowser Token=\"$KEY\""
if ! CFG=$(curl -sf -H "$AUTH" "$URL/System/Configuration/branding"); then
    echo "Couldn't read branding from $URL. Check JELLYFIN_URL and that the key belongs to an admin." >&2
    exit 1
fi

python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("CustomCss") or "", end="")' "$CFG" \
    > custom-css.backup.css
NEW=$(python3 -c 'import json,sys; c=json.loads(sys.argv[1]); c["CustomCss"]=sys.argv[2]; print(json.dumps(c))' "$CFG" "$CSS")
curl -sf -o /dev/null -H "$AUTH" -H 'Content-Type: application/json' -X POST \
    "$URL/System/Configuration/branding" -d "$NEW"

echo "Switched $URL to $WHAT."
echo "Previous Custom CSS saved to custom-css.backup.css. Reload Jellyfin to see the change."
