#!/bin/bash
# CodeGuru Security実行スクリプト
# 前提条件:
# 1. jqがインストールされていること
# 2. AWS CLIがインストールされていること

set -e # 最初のエラーで終了

scanName="$1"
fileOrFolder="$2"
region="$3"

die() { echo "$*" 1>&2 ; exit 1; }

zipName="/tmp/$(date +%s).zip"

[ "$#" -ge 2 ] || die "2つの引数が必要です。使用方法: ./run_codeguru_security.sh <scanName> <folder> <region>"

if [ ! -d "$fileOrFolder" ] && [ ! -f "$fileOrFolder" ]; then
    die "ファイルまたはフォルダが存在しません"
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
  die "スクリプトでリージョンが提供されておらず、AWS設定にデフォルトリージョンが存在しません"
fi

echo "アップロードURLを作成中..."
uploadUrl=$(aws codeguru-security create-upload-url --region "$region" --scan-name="$scanName")

echo "$uploadUrl"

### 変数の抽出
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

echo -e "\nコンテンツをアップロード中..."
"${uploadContentCommand[@]}"

echo -e "\n\nスキャンを作成中..."
scan=$(aws codeguru-security create-scan \
    --region "$region" \
    --scan-name="$scanName" \
    --resource-id "{\"codeArtifactId\": \"$codeArtifactId\"}")

runId=$(echo "$scan" | jq -r '.runId')
echo "$scan"
scanState="InProgress"

while [ "$scanState" = "InProgress" ]
do
    echo "スキャン状況を確認中..."
    getscanOut=$(aws codeguru-security get-scan --region "$region" --scan-name="$scanName" --run-id="$runId")
    scanState=$(echo "$getscanOut" | jq -r '.scanState')

    echo "現在のスキャン状態: $scanState"
    if [ "$scanState" = "InProgress" ]; then
        sleep 10
    fi
done

outputFile="$scanName.json"

aws codeguru-security get-findings --region "$region" --scan-name="$scanName" --output json > "$outputFile"

echo "検出結果を $outputFile に出力しました"