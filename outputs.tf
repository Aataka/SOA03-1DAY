output "web_instance_id" {
  description = "Web-Server のインスタンスID"
  value       = aws_instance.web.id
}

output "db_instance_id" {
  description = "DB-Server のインスタンスID"
  value       = aws_instance.db.id
}

output "sns_topic_arn" {
  description = "通知用 SNS トピック ARN"
  value       = aws_sns_topic.ops.arn
}

output "dashboard_url" {
  description = "CloudWatch ダッシュボードへのリンク"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "fis_cpu_experiment_template_id" {
  description = "Web-Server CPU 負荷の FIS 実験テンプレートID（start-experiment で使用）"
  value       = aws_fis_experiment_template.cpu_stress_web.id
}

output "fis_mem_experiment_template_id" {
  description = "DB-Server メモリ負荷の FIS 実験テンプレートID"
  value       = aws_fis_experiment_template.mem_stress_db.id
}
