# ===== Web-Server CPU アラーム（高・低） =====
resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "Over-utilized CPU: Web-Server"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.web.id }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 75
  alarm_actions       = [aws_sns_topic.ops.arn]
  ok_actions          = [aws_sns_topic.ops.arn]
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_low" {
  alarm_name          = "Under-utilized CPU: Web-Server"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.web.id }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = 25
  alarm_actions       = [aws_sns_topic.ops.arn]
}

# ===== DB-Server メモリアラーム =====
# 想定Y: エージェント停止＝メトリクス欠落を「異常」として検知する
resource "aws_cloudwatch_metric_alarm" "db_mem_high" {
  alarm_name          = "Over-utilized Memory: DB-Server"
  namespace           = "MemoryUsage" # カスタム名前空間
  metric_name         = "mem_used_percent"
  dimensions          = { InstanceId = aws_instance.db.id }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 75
  treat_missing_data  = "breaching" # 欠落を異常として扱う（監視喪失の検知）
  alarm_actions       = [aws_sns_topic.ops.arn]
  ok_actions          = [aws_sns_topic.ops.arn]
}

# ===== 複合アラーム（想定V: OR の欠損伝播を検証） =====
resource "aws_cloudwatch_composite_alarm" "web_app" {
  alarm_name = "Web Application: Over Utilized"
  alarm_rule = "ALARM(\"${aws_cloudwatch_metric_alarm.db_mem_high.alarm_name}\") OR ALARM(\"${aws_cloudwatch_metric_alarm.web_cpu_high.alarm_name}\")"

  alarm_actions = [aws_sns_topic.ops.arn]
  ok_actions    = [aws_sns_topic.ops.arn]

  depends_on = [
    aws_cloudwatch_metric_alarm.db_mem_high,
    aws_cloudwatch_metric_alarm.web_cpu_high,
  ]
}

# ===== ダッシュボード（CPU と Memory の単一ビュー） =====
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "EC2_Metric_Comparison"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EC2 CPU Usage"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web.id, { label = "Web-Server" }],
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.db.id, { label = "DB-Server" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EC2 Memory Usage"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["MemoryUsage", "mem_used_percent", "InstanceId", aws_instance.web.id, { label = "Web-Server" }],
            ["MemoryUsage", "mem_used_percent", "InstanceId", aws_instance.db.id, { label = "DB-Server" }],
          ]
        }
      }
    ]
  })
}
