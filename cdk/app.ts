#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { NetworkStack } from './lib/network-stack';
import { IamStack } from './lib/iam-stack';
import { LambdaStack } from './lib/lambda-stack';

const app = new cdk.App();

// 環境設定
const environment = app.node.tryGetContext('environment') || 'local';
const serviceName = 'cicd-comparison';

// 共通のプロパティ
const commonProps = {
    env: {
        account: process.env.CDK_DEFAULT_ACCOUNT,
        region: process.env.CDK_DEFAULT_REGION || 'ap-northeast-1',
    },
    environment,
    serviceName,
};

// リソース命名規約に従った関数
export function createResourceName(resourceType: string, purpose: string, sequence?: number): string {
    const parts = [serviceName, environment, resourceType, purpose];
    if (sequence !== undefined) {
        parts.push(sequence.toString());
    }
    return parts.join('-');
}

// IAMスタック（他のスタックで使用するロールを作成）
const iamStack = new IamStack(app, createResourceName('stack', 'iam'), {
    ...commonProps,
    description: 'IAM roles and policies for CI/CD comparison project',
});

// ネットワークスタック
const networkStack = new NetworkStack(app, createResourceName('stack', 'network'), {
    ...commonProps,
    description: 'Network infrastructure for CI/CD comparison project',
});

// CI/CDツール別Lambdaスタック
const cicdTools = ['github', 'gitlab', 'codepipeline'];
const lambdaStacks: { [key: string]: LambdaStack } = {};

cicdTools.forEach(cicdTool => {
    lambdaStacks[cicdTool] = new LambdaStack(app, `${cicdTool}-${createResourceName('stack', 'lambda')}`, {
        ...commonProps,
        vpc: networkStack.vpc,
        cicdTool: cicdTool,
        description: `Lambda and API Gateway infrastructure for CI/CD comparison project (${cicdTool})`,
    });
});

app.synth();