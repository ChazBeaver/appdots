#!/usr/bin/env bash
# appdots/lib/detect.sh
# OS detection. Source this; do not execute.

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}
