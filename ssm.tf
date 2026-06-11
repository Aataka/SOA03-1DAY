# CloudWatch エージェント設定（カスタムメトリクス: mem_used_percent）
# ラボの AmazonCloudWatch-AgentConfig 相当を Parameter Store に保存
resource "aws_ssm_parameter" "cwagent_config" {
  name = "AmazonCloudWatch-AgentConfig"
  type = "String"

  value = jsonencode({
    agent = {
      metrics_collection_interval = 15
      run_as_user                 = "root"
    }
    metrics = {
      namespace = "MemoryUsage"
      append_dimensions = {
        InstanceId = "$${aws:InstanceId}"
      }
      metrics_collected = {
        mem = {
          measurement                 = ["mem_used_percent"]
          metrics_collection_interval = 15
        }
      }
    }
  })
}

# タグベースのリソースグループ（ラボの Web-Application-Instances 相当）
resource "aws_resourcegroups_group" "web_app" {
  name = "Web-Application-Instances"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::EC2::Instance"]
      TagFilters = [{
        Key    = "Application"
        Values = ["Web Application"]
      }]
    })
  }
}

# CloudWatch エージェントのインストール（AWS-ConfigureAWSPackage）
resource "aws_ssm_association" "install_cwagent" {
  association_name = "${var.project}-install-cwagent"
  name             = "AWS-ConfigureAWSPackage"

  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }

  targets {
    key    = "tag:Application"
    values = ["Web Application"]
  }

  # インストールが実機で成功するまで待つ（configure との競合を防ぐ）
  wait_for_success_timeout_seconds = 600

  depends_on = [aws_instance.web, aws_instance.db]
}

# CloudWatch エージェントの設定・起動（AmazonCloudWatch-ManageAgent）
resource "aws_ssm_association" "configure_cwagent" {
  association_name = "${var.project}-configure-cwagent"
  name             = "AmazonCloudWatch-ManageAgent"

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = aws_ssm_parameter.cwagent_config.name
    optionalRestart               = "yes"
  }

  targets {
    key    = "tag:Application"
    values = ["Web Application"]
  }

  # 設定適用が成功するまで待つ（メモリメトリクス送信開始を確実にする）
  wait_for_success_timeout_seconds = 600

  depends_on = [aws_ssm_association.install_cwagent]
}
