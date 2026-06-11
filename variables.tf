variable "region" {
  description = "デプロイ先リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "プロジェクト識別子（タグ・命名に使用）"
  type        = string
  default     = "SOA03-1DAY"
}

variable "notification_email" {
  description = "アラーム通知の送信先メールアドレス（SNSサブスクリプション）。apply後に届く確認メールで承認が必要"
  type        = string
}

variable "web_instance_type" {
  description = "Web-Server のインスタンスタイプ（リサイズ後の最適化サイズ）"
  type        = string
  default     = "t3.medium"
}

variable "db_instance_type" {
  description = "DB-Server のインスタンスタイプ（メモリ最適化）"
  type        = string
  default     = "r5.large"
}
