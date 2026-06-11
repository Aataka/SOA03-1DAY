# Session Manager は ingress 不要。egress のみ許可（SSM/CWエージェントの通信用）
resource "aws_security_group" "instance" {
  name_prefix = "${var.project}-instance-"
  description = "Egress only for SSM and CloudWatch agent"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  subnet_id = tolist(data.aws_subnets.default.ids)[0]
}

resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.web_instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true
  monitoring                  = true # 詳細モニタリング（1分間隔）

  tags = {
    Name        = "Web-Server"
    Application = "Web Application"
  }
}

resource "aws_instance" "db" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.db_instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true
  monitoring                  = true

  tags = {
    Name        = "DB-Server"
    Application = "Web Application"
  }
}
