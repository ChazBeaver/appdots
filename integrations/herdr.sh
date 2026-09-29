#!/usr/bin/env bash
# appdots/integrations/herdr.sh
# Herdr agent integrations this repo expects, with the reviewed version of each.
# Source this; do not execute.
#
# Format: "<agent>=<version>"
#   <agent>   an id accepted by `herdr integration install`
#   <version> the HERDR_INTEGRATION_VERSION stamped in the hook file you last
#             read and approved. doctor/herdr-integrations.sh fails when the
#             installed version differs, so a herdr upgrade that rewrites the
#             hook is noticed instead of silently running at every agent start.
#
# Upgrade procedure: see README → "Herdr agent integrations".

HERDR_INTEGRATIONS=(
  "claude=8"
  "codex=8"
  "opencode=10"
)
