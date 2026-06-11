# 現在のリージョン / アカウント
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# 自己完結のためデフォルトVPC・サブネットを利用
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 最新の Amazon Linux 2023 AMI（x86_64）を SSM パラメータから取得
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
