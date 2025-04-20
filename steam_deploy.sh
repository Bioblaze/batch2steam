#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Define paths and inputs
steamdir=${STEAM_HOME:-$HOME/Steam}
steamdir_logs=${STEAM_HOME:-$HOME/.local/share/Steam}
contentroot=$(pwd)/${rootPath:-.}
buildOutputDir=$(pwd)/BuildOutput
appId=${appId:-1000}
entries=${entries:-"[]"}
baseDesc=${baseDesc:-""}

# Ensure the build output directory exists
mkdir -p "$buildOutputDir"

echo "#################################"
echo "#  Generating Depot Manifests   #"
echo "#################################"

depot_section=""
entries_parsed=$(echo "$entries" | jq -c '.[]')
for entry in $entries_parsed; do
  depotId=$(echo "$entry" | jq -r '.depotID')
  buildDescription=$(echo "$entry" | jq -r '.buildDescription')
  depotPath=$(echo "$entry" | jq -r '.depotPath')

  depotVdfPath="depot_build_${depotId}.vdf"
  echo "Generating $depotVdfPath for depot $depotId..."
  echo "\t$buildDescription"

  cat > "$depotVdfPath" <<EOF
"DepotBuild"
{
    "DepotID" "$depotId"
    "FileMapping"
    {
        "LocalPath" "$depotPath/*"
        "DepotPath" "."
        "recursive" "1"
    }
}
EOF
  cat "$depotVdfPath"
  depot_section="${depot_section}        \"$depotId\" \"$depotVdfPath\"\n"
done

echo "#################################"
echo "#     Generating App VDF        #"
echo "#################################"

vdfFilePath="$(pwd)/app_build.vdf"

cat > "$vdfFilePath" <<EOF
"AppBuild"
{
    "AppID" "$appId"
    "Desc" "Batch Build - $baseDesc - $(date +'%Y-%m-%d %H:%M:%S')"
    "BuildOutput" "$buildOutputDir"
    "ContentRoot" "$contentroot"
    "SetLive" ""
    "Depots"
    {
$(echo -e "$depot_section")
    }
}
EOF

# Output app VDF for logging
echo "Generated app_build.vdf:"
cat "$vdfFilePath"
echo ""

# Ensure steam_username and steam_password are set
: ${steam_username:?}
: ${steam_password:?}

# Handle SteamGuard config
if [ -n "${steam_shared_secret:-}" ]; then
  echo "Using SteamGuard TOTP"
else  
  if [ ! -n "${configVdf:-}" ]; then
    echo "Config VDF input is missing or incomplete! Cannot proceed."
    exit 1
  fi
  steam_shared_secret="INVALID"
  echo "Copying SteamGuard Files..."
  mkdir -p "$steamdir/config"
  printf "%s" "$configVdf" | base64 -d > "$steamdir/config/config.vdf"
  chmod 777 "$steamdir/config/config.vdf"
fi

# Retry logic for steamcmd
execute_steamcmd() {
  local totp_code=""
  local totp_code_second=""
  local max_retries=5
  local attempt=1

  while [ $attempt -le $max_retries ]; do
    echo "Attempt $attempt of $max_retries..."

    if [ "$steam_shared_secret" != "INVALID" ]; then
      totp_code=$(node /root/get_totp.js "$steam_shared_secret")
      totp_code_second=$(node /root/get_totp.js "$steam_shared_secret" "5")

      if [ "$totp_code" != "$totp_code_second" ]; then
        totp_code=$totp_code_second
        sleep 6
      fi
    fi

    if steamcmd +login "$steam_username" "$steam_password" $totp_code "$@"; then
      echo "SteamCMD login successful on attempt $attempt."
      return 0
    else
      echo "SteamCMD login failed on attempt $attempt."
      attempt=$((attempt + 1))
      sleep 5
    fi
  done

  echo "SteamCMD login failed after $max_retries attempts."
  return 1
}

# Test login
echo "#################################"
echo "#        Test login             #"
echo "#################################"

if execute_steamcmd +quit; then
  echo "Successful login"
else
  echo "FAILED login"
  exit 1
fi

if [ ! -f "$vdfFilePath" ]; then
  echo "ERROR: App build VDF not found at $vdfFilePath"
  ls -alh "$(dirname "$vdfFilePath")"
  exit 1
fi

# Upload build
echo "#################################"
echo "#        Uploading build        #"
echo "#################################"

build_output=$(mktemp)
if ! execute_steamcmd +run_app_build "$vdfFilePath" +quit | tee "$build_output"; then
  echo "Errors during build upload"
  echo "#################################"
  echo "#             Logs              #"
  echo "#################################"

  ls -alh || true
  ls -alh "$rootPath" || true
  ls -Ralph "$steamdir_logs/logs/" || true

  for f in "$steamdir_logs"/logs/*; do
    echo "######## $f"
    cat "$f" || true
    echo
  done

  echo "Displaying error log"
  cat "$steamdir_logs/logs/stderr.txt" || true
  echo "Displaying bootstrapper log"
  cat "$steamdir_logs/logs/bootstrap_log.txt" || true
  echo "#################################"
  echo "#          Build Logs           #"
  echo "#################################"

  for f in BuildOutput/*.log; do
    echo "######## $f"
    cat "$f" || true
    echo
  done
  exit 1
fi

# Extract BuildID from output
build_id=$(grep -oE 'BuildID [0-9]+' "$build_output" | grep -oE '[0-9]+' | head -n1)

if [[ -n "$build_id" ]]; then
  echo "Detected BuildID: $build_id"
  echo "build_id=$build_id" >> "$GITHUB_OUTPUT"
else
  echo "Failed to detect BuildID from SteamCMD output."
  exit 1
fi
