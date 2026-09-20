#!/usr/bin/env bash
set -euo pipefail

echo "Applying login items..."

add_login_item() {
  local app_name="$1"
  osascript <<APPLESCRIPT
tell application "System Events"
  if not (exists login item "${app_name}") then
    make new login item at end with properties {name:"${app_name}", hidden:false}
  end if
end tell
APPLESCRIPT
}

add_login_item "Rectangle"
add_login_item "LinearMouse"
add_login_item "Microsoft Outlook"
add_login_item "Acrobat Collaboration Synchronizer"
add_login_item "DisplayLink Manager"
add_login_item "Microsoft Teams"

echo "Login items applied."
