#!/bin/bash

# LocalStack helper functions
# Source this file to use these functions: source scripts/localstack-helpers.sh

# Set LocalStack environment variables
setup_localstack_env() {
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    export AWS_DEFAULT_REGION=ap-northeast-1
    export AWS_ENDPOINT_URL=http://localhost:4566
    export LOCALSTACK_ENDPOINT=http://localhost:4566
    
    echo "✅ LocalStack environment variables set"
}

# Check if LocalStack is running
is_localstack_running() {
    if curl -s http://localhost:4566/_localstack/health >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Wait for LocalStack to be ready
wait_for_localstack() {
    echo "⏳ Waiting for LocalStack to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if is_localstack_running; then
            echo "✅ LocalStack is ready!"
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts: LocalStack not ready yet..."
        sleep 2
        ((attempt++))
    done
    
    echo "❌ LocalStack failed to start within timeout"
    return 1
}

# Deploy Lambda function to LocalStack
deploy_lambda_to_localstack() {
    local function_name=$1
    local zip_file=$2
    local handler=$3
    local runtime=${4:-python3.11}
    
    if [ -z "$function_name" ] || [ -z "$zip_file" ] || [ -z "$handler" ]; then
        echo "Usage: deploy_lambda_to_localstack <function_name> <zip_file> <handler> [runtime]"
        return 1
    fi
    
    echo "🚀 Deploying Lambda function: $function_name"
    
    aws --endpoint-url=$LOCALSTACK_ENDPOINT lambda create-function \
        --function-name "$function_name" \
        --runtime "$runtime" \
        --role arn:aws:iam::000000000000:role/LocalStackLambdaExecutionRole \
        --handler "$handler" \
        --zip-file "fileb://$zip_file" \
        --region $AWS_DEFAULT_REGION || \
    aws --endpoint-url=$LOCALSTACK_ENDPOINT lambda update-function-code \
        --function-name "$function_name" \
        --zip-file "fileb://$zip_file" \
        --region $AWS_DEFAULT_REGION
    
    echo "✅ Lambda function deployed: $function_name"
}

# Create API Gateway for Lambda
create_api_gateway_for_lambda() {
    local api_name=$1
    local function_name=$2
    
    if [ -z "$api_name" ] || [ -z "$function_name" ]; then
        echo "Usage: create_api_gateway_for_lambda <api_name> <function_name>"
        return 1
    fi
    
    echo "🌐 Creating API Gateway: $api_name"
    
    # Create REST API
    local api_id=$(aws --endpoint-url=$LOCALSTACK_ENDPOINT apigateway create-rest-api \
        --name "$api_name" \
        --region $AWS_DEFAULT_REGION \
        --query 'id' --output text)
    
    echo "API ID: $api_id"
    
    # Get root resource ID
    local root_resource_id=$(aws --endpoint-url=$LOCALSTACK_ENDPOINT apigateway get-resources \
        --rest-api-id "$api_id" \
        --region $AWS_DEFAULT_REGION \
        --query 'items[0].id' --output text)
    
    # Create proxy resource
    local resource_id=$(aws --endpoint-url=$LOCALSTACK_ENDPOINT apigateway create-resource \
        --rest-api-id "$api_id" \
        --parent-id "$root_resource_id" \
        --path-part '{proxy+}' \
        --region $AWS_DEFAULT_REGION \
        --query 'id' --output text)
    
    # Create ANY method
    aws --endpoint-url=$LOCALSTACK_ENDPOINT apigateway put-method \
        --rest-api-id "$api_id" \
        --resource-id "$resource_id" \
        --http-method ANY \
        --authorization-type NONE \
        --region $AWS_DEFAULT_REGION
    
    # Set up Lambda integration
    aws --endpoint-url=$LOCALSTACK_ENDPOINT apigateway put-integration \
        --rest-api-id "$api_id" \
        --resource-id "$resource_id" \
        --http-method ANY \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri "arn:aws:apigateway:$AWS_DEFAULT_REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$AWS_DEFAULT_REGION:000000000000:function:$function_name/invocations" \
        --region $AWS_DEFAULT_REGION
    
    # Deploy API
    aws --endpoint-url=$LOCALSTACK_ENDPOINT apigateway create-deployment \
        --rest-api-id "$api_id" \
        --stage-name local \
        --region $AWS_DEFAULT_REGION
    
    local api_url="http://localhost:4566/restapis/$api_id/local/_user_request_"
    echo "✅ API Gateway created: $api_url"
    echo "$api_url"
}

# Test API endpoint
test_api_endpoint() {
    local endpoint_url=$1
    local path=${2:-/health}
    
    if [ -z "$endpoint_url" ]; then
        echo "Usage: test_api_endpoint <endpoint_url> [path]"
        return 1
    fi
    
    echo "🧪 Testing API endpoint: $endpoint_url$path"
    
    local response=$(curl -s -w "\n%{http_code}" "$endpoint_url$path")
    local body=$(echo "$response" | head -n -1)
    local status_code=$(echo "$response" | tail -n 1)
    
    echo "Status Code: $status_code"
    echo "Response Body: $body"
    
    if [ "$status_code" = "200" ]; then
        echo "✅ API test passed"
        return 0
    else
        echo "❌ API test failed"
        return 1
    fi
}

# Show LocalStack services status
show_localstack_status() {
    echo "📊 LocalStack Services Status:"
    curl -s http://localhost:4566/_localstack/health | jq '.' 2>/dev/null || \
    curl -s http://localhost:4566/_localstack/health
}

# List LocalStack resources
list_localstack_resources() {
    echo "📋 LocalStack Resources:"
    
    echo "S3 Buckets:"
    aws --endpoint-url=$LOCALSTACK_ENDPOINT s3 ls 2>/dev/null || echo "  No S3 buckets found"
    
    echo "Lambda Functions:"
    aws --endpoint-url=$LOCALSTACK_ENDPOINT lambda list-functions \
        --region $AWS_DEFAULT_REGION \
        --query 'Functions[].FunctionName' \
        --output table 2>/dev/null || echo "  No Lambda functions found"
    
    echo "API Gateways:"
    aws --endpoint-url=$LOCALSTACK_ENDPOINT apigateway get-rest-apis \
        --region $AWS_DEFAULT_REGION \
        --query 'items[].[name,id]' \
        --output table 2>/dev/null || echo "  No API Gateways found"
    
    echo "CloudWatch Log Groups:"
    aws --endpoint-url=$LOCALSTACK_ENDPOINT logs describe-log-groups \
        --region $AWS_DEFAULT_REGION \
        --query 'logGroups[].logGroupName' \
        --output table 2>/dev/null || echo "  No log groups found"
}