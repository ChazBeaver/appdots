#!/usr/bin/env bash
set -euo pipefail

echo "Applying macOS symbolic hotkeys..."

PLIST="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"

set_hotkey() {
  local id="$1"
  local char="$2"
  local keycode="$3"
  local modifiers="$4"

  /usr/libexec/PlistBuddy -c "Delete :AppleSymbolicHotKeys:$id" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$id dict" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$id:enabled bool true" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$id:value dict" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$id:value:type string standard" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$id:value:parameters array" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$id:value:parameters:0 integer $char" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$id:value:parameters:1 integer $keycode" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$id:value:parameters:2 integer $modifiers" "$PLIST"
}

# cmd + ,
set_hotkey 79 44 43 1048576
set_hotkey 80 44 43 1179648

# cmd + .
set_hotkey 81 46 47 1048576
set_hotkey 82 46 47 1179648

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true
