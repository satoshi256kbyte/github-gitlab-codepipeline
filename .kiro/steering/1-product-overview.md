# プロダクト概要

## プロダクト名

GitHub、GitLab、CodePipelineの3種のツールでCI/CDパイプラインを作り、その書き方と挙動の違いを比較するためのサンプルコードです。

## 概要

以下3つのツールそれぞれでCI/CDパイプラインを作ります

- GitHub
- GitLab
- CodePipeline

デプロイするアプリケーションは、PythonによるREST APIです。
Pythonは3.13を使用、FastAPIを使用します。
APIの内容はごくシンプルなものです。
APIはAPI Gateway + AWS Lambda、Amazon ECS Cluster、Amazon EC2の3箇所にデプロイします。
Amazon ECS Cluster、Amazon EC2に関してはBlue/Greenデプロイを行います。

全ツール、CI/CDパイプラインの工程は以下の通りです。

- ソース
- チェック
  - キャッシュ作成
  - ここから下は並列実行
    - 静的解析
    - ユニットテスト
    - SCAチェック
    - SASTチェック
- ビルド＆デプロイ
  - AWS Lambdaのデプロイ
  - Amazon ECSのBlue/Greenデプロイ
  - Amazon EC2のBlue/Greenデプロイ

## ディレクトリ構造

```bash
.
├── .github/
│   └── workflows/          # GitHub Actionsワークフロー
├── .gitlab-ci.yml          # GitLab CI/CDパイプライン設定
├── gitlab/
│   ├── scripts/            # GitLab CI/CD用スクリプト
│   └── templates/          # GitLab CI/CDテンプレート
├── cdk/                    # AWS CDKインフラコード
├── modules/
│   └── api/                # FastAPI アプリケーション
├── codepipeline/           # CodePipelineで使用するbuildspecなど
│   ├── buildspecs/         # CodeBuild用buildspecファイル
│   └── scripts/            # CodePipeline用スクリプト
└── docs/                   # ドキュメント
```

## 各工程の詳細

### キャッシュ作成

CodePipelineにおけるサンプルはこちらです。
CodeBuildでキャッシュを作ります。
`common_install.sh`は`apt`の更新やインストール、`common_pre_build.sh`は環境変数のセットなどを行います。

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash codepipeline/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash codepipeline/buildspecs/common_pre_build.sh

  build:
    commands:
      - . codepipeline/buildspecs/common_env.sh
      - echo "Export all workspace dependencies to requirements.txt for Amazon Inspector compatibility"
      - uv export --all-packages --no-dev --frozen --no-editable -o requirements.txt --no-emit-workspace --no-hashes --no-header

  post_build:
    commands:
      - echo "SCA preparation completed"

artifacts:
  files:
    - '**/*'

cache:
  key: cache-key-include-dev-$(codebuild-hash-files .tool-versions)-$(codebuild-hash-files package-lock.json)-$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
```

### SCAチェック

AWS CodePipelineの場合は、CodeGuru Securityを実行してください。
GitHub、GitLabの場合は、それぞれの独自のツールとCodeGuru Securityの両方を実行してください。
CodeGuru SecurityのCodeBuildにおける実行サンプルは下記の通りです。

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash codepipeline/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash codepipeline/buildspecs/common_pre_build.sh

  build:
    commands:
      - . codepipeline/buildspecs/common_env.sh
      - echo "Running static analysis..."
      - npm run lint

  post_build:
    commands:
      - echo "Static analysis completed successfully"

cache:
  key: cache-key-include-dev-$(codebuild-hash-files .tool-versions)-$(codebuild-hash-files package-lock.json)-$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
```

run_codeguru_security.shの内容は以下の通り。

```bash
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

[ "$#" -ge 2 ] || die "2 arguments required, $# provided, pass  <scanName>, <folder> and <region> example: ./run_codeguru_security.sh MyScan upload_folder/zipFile us-east-1"

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
```

### SASTチェック

AWS CodePipelineの場合は、Inspectorを実行してください。
GitHub、GitLabの場合は、それぞれの独自のツールとInspectorの両方を実行してください。
InspectorのCodeBuildにおける実行サンプルは下記の通りです。

```yaml
version: 0.2

phases:
  install:
    commands:
      - bash codepipeline/buildspecs/common_install.sh

  pre_build:
    commands:
      - bash codepipeline/buildspecs/common_pre_build.sh --dev

  build:
    commands:
      - . codepipeline/buildspecs/common_env.sh
      - echo "Running SAST scan with Amazon CodeGuru Security..."
      - SCAN_NAME="${SERVICE_NAME}-${STAGE_NAME}-$(date +%s)"
      - echo "Scan name:$SCAN_NAME"
      - zip -r /tmp/source-code.zip . -x "*.git*" "node_modules/*" "*.pyc" "__pycache__/*" ".venv/*"
      - bash ./codepipeline/buildspecs/run_codeguru_security.sh $SCAN_NAME /tmp/source-code.zip $AWS_DEFAULT_REGION
      - echo "SAST scan completed"

  post_build:
    commands:
      - CRITICAL_COUNT=$(jq '[.findings[] | select(.severity == "Critical")] | length' $SCAN_NAME.json)
      - HIGH_COUNT=$(jq '[.findings[] | select(.severity == "High")] | length' $SCAN_NAME.json)
      - MEDIUM_COUNT=$(jq '[.findings[] | select(.severity == "Medium")] | length' $SCAN_NAME.json)
      - LOW_COUNT=$(jq '[.findings[] | select(.severity == "Low")] | length' $SCAN_NAME.json)
      - |
        echo "--------- Vulnerability analysis --------"
        echo "Critical severity vulnerabilities found:" $CRITICAL_COUNT
        echo "High severity vulnerabilities found:" $HIGH_COUNT
        echo "Medium severity vulnerabilities found:" $MEDIUM_COUNT
        echo "Low severity vulnerabilities found:" $LOW_COUNT
        echo "------------------------------------------"
      - |
        if [ "$CRITICAL_COUNT" -gt 0 ]; then
          echo "ERROR: Found $CRITICAL_COUNT critical vulnerabilities"
          exit 1
        fi 

artifacts:
    files:
      - $SCAN_NAME.json

cache:
  key: cache-key-include-dev-$(codebuild-hash-files .tool-versions)-$(codebuild-hash-files package-lock.json)-$(codebuild-hash-files uv.lock)
  paths:
    - '/root/.cache/pip/**/*'
    - '/root/.cache/uv/**/*'
    - '/root/.cargo/**/*'
    - '/root/.npm/**/*'
    - '/root/.asdf/**/*'
    - '/root/.local/bin/**/*'
    - 'node_modules/**/*'
```

### ビルド＆デプロイ

#### AWS Lambda

AWS LambdaはAWS SAMでデプロイします。

#### Amazon ECS

Amazon ECSのBlue/Greenデプロイは、ECSの機能で行います。
CodeDeployによるBlue/Greenデプロイは行いません。
CodeBuildによるECSのBlue/Greenデプロイのサンプルは以下の通りです。

```yaml
version: 0.2

phases:
  pre_build:
    commands:

      - echo Constructing ECR repository URL...
      - RepositoryUri=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
      - echo RepositoryUri=$RepositoryUri
      - echo Getting image URI from imageDetail.json...
      - ImageURI=$(cat $CODEBUILD_SRC_DIR_BuildOutput/imageDetail.json | jq -r '.ImageURI')
      - echo ImageURI=$ImageURI

  build:
    commands:

      - echo Replacing image URI in taskdef.json...
      - sed -i "s|<IMAGE1_NAME>|$ImageURI|g" $CODEBUILD_SRC_DIR_BuildOutput/taskdef.json

      - echo Registering task definition...
      - TASK_DEF_ARN=$(aws ecs register-task-definition --cli-input-json file://$CODEBUILD_SRC_DIR_BuildOutput/taskdef.json --region $AWS_DEFAULT_REGION --query "taskDefinition.taskDefinitionArn" --output text)
      - echo "TASK_DEF_ARN=$TASK_DEF_ARN"

      - echo Replacing task definition ARN in appspec.yml...
      - sed -i "s|\"<TASK_DEFINITION>\"|\"$TASK_DEF_ARN\"|g" $CODEBUILD_SRC_DIR/appspec.yml

      - echo Preparing appspec content for direct deployment...

  post_build:
    commands:

        - echo Creating CodeDeploy deployment with direct appspec content...
        - CONTENT=$(cat $CODEBUILD_SRC_DIR/appspec.yml | jq -Rs .)
        - SHA256=$(cat $CODEBUILD_SRC_DIR/appspec.yml | sha256sum | awk '{print $1}')
        - |
        cat > deployment.json << EOF
        {
            "applicationName": "$APPLICATION_NAME",
            "deploymentGroupName": "$DEPLOYMENT_GROUP",
            "deploymentConfigName": "CodeDeployDefault.ECSAllAtOnce",
            "revision": {
                "revisionType": "AppSpecContent",
                "appSpecContent": {
                    "content": $CONTENT,
                    "sha256": "$SHA256"
                }
            }
        }
        EOF
        - DEPLOYMENT_ID=$(aws deploy create-deployment --cli-input-json file://deployment.json --region $AWS_DEFAULT_REGION --query "deploymentId" --output text)
        - echo "DEPLOYMENT_ID=$DEPLOYMENT_ID"

        - echo Waiting for deployment to complete...
        - |
        TIMEOUT=${DEPLOYMENT_TIMEOUT}
        INTERVAL=30
        ELAPSED=0

        while true; do
          STATUS=$(aws deploy get-deployment --deployment-id "$DEPLOYMENT_ID" --region $AWS_DEFAULT_REGION --query "deploymentInfo.status" --output text)

          echo "[$ELAPSED sec] Deployment status: $STATUS"

          if [[ "$STATUS" == "Succeeded" ]]; then
            echo "Deployment succeeded."
            break
          fi

          if [[ "$STATUS" == "Failed" || "$STATUS" == "Stopped" ]]; then
            echo "Deployment failed or was stopped."
            exit 1
          fi

          if [[ $ELAPSED -ge $TIMEOUT ]]; then
            echo "Deployment did not finish within the timeout period of $TIMEOUT seconds. "
            echo "Please check the CodeDeploy console to stop the deployment."
            exit 1
          fi

          sleep $INTERVAL
          ELAPSED=$((ELAPSED + INTERVAL))
        done

```

#### Amazon EC2

Amazon EC2に関しては、全ツールCodeDeployでBlue/Greenデプロイを行います。

## インフラ

デプロイに必要なインフラはAWS CDKで実装します。
CodePipeline、ECSクラスター、ALB、EC2、S3などがこれにあたります。
AWS CDKはCI/CDパイプラインで実行せず、手動で実行するとします。

GitHub - AWS間のOIDC接続の設定が必要でうが、それに必要なロールなどはオプションとしてください。
オプションを指定すれば作成、デフォルトはスキップです。
