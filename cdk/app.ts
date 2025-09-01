#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { NetworkStack } from './lib/network-stack';
import { IamStack } from './lib/iam-stack';
import { LambdaStack } from './lib/lambda-stack';
import { EcsStack } from './lib/ecs-stack';
import { Ec2Stack } from './lib/ec2-stack';
import { PipelineStack } from './lib/pipeline-stack';
import { GitHubOidcStack } from './lib/github-oidc-stack';
import { MonitoringStack } from './lib/monitoring-stack';

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
        lambdaExecutionRole: iamStack.lambdaExecutionRole,
        cicdTool: cicdTool,
        description: `Lambda and API Gateway infrastructure for CI/CD comparison project (${cicdTool})`,
    });
});

// CI/CDツール別ECSスタック
const ecsStacks: { [key: string]: EcsStack } = {};
const portMapping = { github: 8080, gitlab: 8081, codepipeline: 8082 };

cicdTools.forEach(cicdTool => {
    ecsStacks[cicdTool] = new EcsStack(app, `${cicdTool}-${createResourceName('stack', 'ecs')}`, {
        ...commonProps,
        vpc: networkStack.vpc,
        ecsTaskRole: iamStack.ecsTaskRole,
        ecsExecutionRole: iamStack.ecsExecutionRole,
        cicdTool: cicdTool,
        port: portMapping[cicdTool as keyof typeof portMapping],
        description: `ECS infrastructure for CI/CD comparison project (${cicdTool})`,
    });
});

// CI/CDツール別EC2スタック
const ec2Stacks: { [key: string]: Ec2Stack } = {};

cicdTools.forEach(cicdTool => {
    ec2Stacks[cicdTool] = new Ec2Stack(app, `${cicdTool}-${createResourceName('stack', 'ec2')}`, {
        ...commonProps,
        vpc: networkStack.vpc,
        ec2Role: iamStack.ec2Role,
        codeDeployRole: iamStack.codeDeployRole,
        cicdTool: cicdTool,
        port: portMapping[cicdTool as keyof typeof portMapping],
        description: `EC2 infrastructure for CI/CD comparison project (${cicdTool})`,
    });
});

// CodePipelineスタック（オプション）
if (app.node.tryGetContext('enableCodePipeline') === 'true') {
    const pipelineStack = new PipelineStack(app, createResourceName('stack', 'pipeline'), {
        ...commonProps,
        codeBuildRole: iamStack.codeBuildRole,
        codePipelineRole: iamStack.codePipelineRole,
        githubOwner: app.node.tryGetContext('githubOwner'),
        githubRepo: app.node.tryGetContext('githubRepo'),
        githubBranch: app.node.tryGetContext('githubBranch') || 'main',
        githubConnectionArn: app.node.tryGetContext('githubConnectionArn'),
        description: 'CodePipeline infrastructure for CI/CD comparison project',
    });
}

// GitHub OIDC接続（オプション）
if (app.node.tryGetContext('enableGitHubOidc') === 'true') {
    const githubOidcStack = new GitHubOidcStack(app, createResourceName('stack', 'github-oidc'), {
        ...commonProps,
        githubOrg: app.node.tryGetContext('githubOrg') || 'your-github-org',
        githubRepo: app.node.tryGetContext('githubRepo') || 'your-repo-name',
        description: 'GitHub OIDC Provider and IAM Role for GitHub Actions',
    });
}

// 監視スタック（オプション）
if (app.node.tryGetContext('enableMonitoring') !== 'false') {
    const monitoringStack = new MonitoringStack(app, createResourceName('stack', 'monitoring'), {
        ...commonProps,
        cicdTools: cicdTools,
        description: 'Monitoring and logging infrastructure for CI/CD comparison project',
    });

    // 依存関係を設定（ログ グループが作成された後に監視スタックを作成）
    cicdTools.forEach(cicdTool => {
        monitoringStack.addDependency(lambdaStacks[cicdTool]);
        monitoringStack.addDependency(ecsStacks[cicdTool]);
        monitoringStack.addDependency(ec2Stacks[cicdTool]);
    });
}

app.synth();