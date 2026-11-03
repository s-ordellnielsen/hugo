#!/bin/sh
# Checks the folder layout described in AGENTS.md section 7.
set -eu
cd "$(dirname "$0")/.."

status=0
fail() {
    echo "layout: $1" >&2
    status=1
}

# Top level of Hugo/
for d in Hugo/*/; do
    case "$(basename "$d")" in
    App | Assets.xcassets | DesignSystem | Domain | Features | Persistence | PreviewSupport | Resources) ;;
    *) fail "unexpected top-level folder $d" ;;
    esac
done

# DesignSystem role folders
for d in Hugo/DesignSystem/*/; do
    [ -d "$d" ] || continue
    case "$(basename "$d")" in
    Components | Styles | Modifiers | Motion | Theme) ;;
    *) fail "unexpected DesignSystem folder $d" ;;
    esac
done
for f in Hugo/DesignSystem/*.swift; do
    [ -e "$f" ] && fail "$f must be inside a DesignSystem role folder"
done

# Feature role folders
for f in Hugo/Features/*/*.swift; do
    [ -e "$f" ] && fail "$f must be inside a role folder (Screens, Views, State, Domain or Services)"
done
for d in Hugo/Features/*/*/; do
    [ -d "$d" ] || continue
    case "$(basename "$d")" in
    Screens | Views | State | Domain | Services) ;;
    *) fail "unexpected feature folder $d" ;;
    esac
done
for d in Hugo/Features/*/*/*/; do
    [ -d "$d" ] && fail "nested folder $d (role folders must not contain folders)"
done

# DesignSystem and Domain must not name feature types
if grep -rwnE 'Entry|Tracker|SubmittedReport|TheocraticYear|PublisherStatus' Hugo/DesignSystem Hugo/Domain; then
    fail "DesignSystem and Domain must not reference feature types"
fi

exit "$status"
