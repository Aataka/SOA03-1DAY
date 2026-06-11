# 想定U: 手打ちの stress-ng / head を、再現可能・自動停止付きの FIS 実験に昇格する
# AWSFIS-Run-CPU-Stress / AWSFIS-Run-Memory-Stress は内部で stress-ng を SSM 経由で実行する

# Web-Server への CPU 負荷（停止条件: CPU高アラーム）
resource "aws_fis_experiment_template" "cpu_stress_web" {
  description = "Reproducible CPU stress on Web-Server"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.web_cpu_high.arn
  }

  action {
    name      = "cpu-stress"
    action_id = "aws:ssm:send-command"

    parameter {
      key   = "documentArn"
      value = "arn:aws:ssm:${data.aws_region.current.name}::document/AWSFIS-Run-CPU-Stress"
    }
    parameter {
      key   = "documentParameters"
      value = jsonencode({ DurationSeconds = "120", InstallDependencies = "True" })
    }
    parameter {
      key   = "duration"
      value = "PT3M"
    }

    target {
      key   = "Instances"
      value = "web"
    }
  }

  target {
    name           = "web"
    resource_type  = "aws:ec2:instance"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "Web-Server"
    }
  }

  tags = { Name = "cpu-stress-web" }
}

# DB-Server へのメモリ負荷（停止条件: メモリ高アラーム）
resource "aws_fis_experiment_template" "mem_stress_db" {
  description = "Reproducible memory stress on DB-Server"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.db_mem_high.arn
  }

  action {
    name      = "memory-stress"
    action_id = "aws:ssm:send-command"

    parameter {
      key   = "documentArn"
      value = "arn:aws:ssm:${data.aws_region.current.name}::document/AWSFIS-Run-Memory-Stress"
    }
    parameter {
      key   = "documentParameters"
      value = jsonencode({ DurationSeconds = "120", Percent = "70", InstallDependencies = "True" })
    }
    parameter {
      key   = "duration"
      value = "PT3M"
    }

    target {
      key   = "Instances"
      value = "db"
    }
  }

  target {
    name           = "db"
    resource_type  = "aws:ec2:instance"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "DB-Server"
    }
  }

  tags = { Name = "mem-stress-db" }
}
