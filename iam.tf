# ===== EC2 用ロール（Session Manager + CloudWatch エージェント） =====
resource "aws_iam_role" "ec2" {
  name = "${var.project}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Session Manager 経由の接続に必要
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch エージェントがメトリクスを送信するために必要
resource "aws_iam_role_policy_attachment" "cwagent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ===== FIS 用ロール（再現可能な負荷実験を SSM 経由で実行） =====
resource "aws_iam_role" "fis" {
  name = "${var.project}-fis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "fis.amazonaws.com" }
    }]
  })
}

# FIS が aws:ssm:send-command アクションを実行し、停止条件(アラーム)を参照するための権限
resource "aws_iam_role_policy" "fis" {
  name = "${var.project}-fis-policy"
  role = aws_iam_role.fis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:CancelCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:DescribeAlarms"]
        Resource = "*"
      }
    ]
  })
}
