#!/bin/bash
yum update -y
yum install -y ruby wget

# Install CodeDeploy agent
cd /home/ec2-user
wget https://aws-codedeploy-ap-northeast-1.s3.ap-northeast-1.amazonaws.com/latest/install
chmod +x ./install
./install auto

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Install Python 3.13 and uv
yum install -y python3 python3-pip
pip3 install uv

# Create application directory
mkdir -p /opt/app
chown ec2-user:ec2-user /opt/app

# Start CodeDeploy agent
service codedeploy-agent start
chkconfig codedeploy-agent on

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/ec2/cicd-comparison-local-ec2-application",
                        "log_group_name": "/ec2/cicd-comparison-local-ec2-application",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/ec2/cicd-comparison-local-ec2-system",
                        "log_group_name": "/ec2/cicd-comparison-local-ec2-system",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/ec2/cicd-comparison-local-ec2-codedeploy",
                        "log_group_name": "/ec2/cicd-comparison-local-ec2-codedeploy",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s
