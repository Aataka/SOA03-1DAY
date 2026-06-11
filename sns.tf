# 想定X: 通知を「削除」せず、検知→通知の経路を作る
resource "aws_sns_topic" "ops" {
  name = "${var.project}-ops-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.ops.arn
  protocol  = "email"
  endpoint  = var.notification_email
  # 注: apply後に届く確認メールのリンクを承認するまで通知は届かない
}
