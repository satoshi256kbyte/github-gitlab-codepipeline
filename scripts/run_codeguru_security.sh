#!/bin/bash
# prereq:
# 1. Install jq
# 2. Install aws cli

set -e # exit on first error

scanName="$1"
fileOrFolder="$2"
region="$3"

die() { echo "$*" 1>&2 ; exit 1; }

zipName="/tmp/$(date +%s).zip"

[ "$#" -ge 2 ] || die "2 arguments required, $# provided, pass  <scanName>, <folder> and <region> example: ./run_codeguru_security.sh MyScan upload_folder/zipFile ap-northeast-1"

if [ ! -d "$fileOrFolder" ] && [ ! -f "$fileOrFolder" ]; then
    die "file or folder doesn't exist"
fi
if [ -d "$fileOrFolder" ]; then
  zipName="/tmp/$(date +%s).zip"
  zip -r "$zipName" "$fileOrFolder"
else
  zipName="$fileOrFolder"
fi

if [[ -z "$region" ]]; then
  region=$(aws configure get region)
fi

if [[ -z "$region" ]]; then
  die "no region provided in script and no default region is present in aws configuration"
fi

echo "Creating upload URL..."
uploadUrl=$(aws codeguru-security create-upload-url --region "$region" --scan-name="$scanName")

echo "$uploadUrl"

### Extracting variables
s3Url=$(echo "$uploadUrl" | jq -r '.s3Url')
header_args_str=$(echo "$uploadUrl" | jq -r '.requestHeaders | to_entries[] | "-H", "\( .key ):\( .value )"')
mapfile -t header_args_array < <(echo "$header_args_str")
codeArtifactId=$(echo "$uploadUrl" | jq -r '.codeArtifactId')

uploadContentCommand=(
    curl
    -X PUT
    -T "$zipName"
    -H "Content-Type: application/zip"
    "${header_args_array[@]}"
    "$s3Url"
)

echo -e "\nUploading content..."
"${uploadContentCommand[@]}"

echo -e "\n\nCreating a scan..."
scan=$(aws codeguru-security create-scan \
    --region "$region" \
    --scan-name="$scanName" \
    --resource-id "{\"codeArtifactId\": \"$codeArtifactId\"}")

runId=$(echo "$scan" | jq -r '.runId')
echo "$scan"
scanState="InProgress"

while [ "$scanState" = "InProgress" ]
do
    echo "Running Get to check if status is completed"
    getscanOut=$(aws codeguru-security get-scan --region "$region" --scan-name="$scanName" --run-id="$runId")
    scanState=$(echo "$getscanOut" | jq -r '.scanState')

    echo "Current scanState: $scanState"
    if [ "$scanState" = "InProgress" ]; then
        sleep 10
    fi
done

outputFile="$scanName.json"

aws codeguru-security get-findings --region "$region" --scan-name="$scanName" --output json > "$outputFile"

echo "Findings written to $outputFile"