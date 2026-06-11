# SOA03-1DAY — EC2 Rightsizing を運用監視の目線で検証する

AWS Skill Builder ラボ「EC2 Instance Rightsizing」を題材に、ラボが省略している**運用要素**を 5 つの仮説として立て、IaC（Terraform）で構築・検証するプロジェクト。検証結果を Zenn 記事化する。

## 検証する5つの仮説

| 仮説 | 内容 | 使うサービス |
|---|---|---|
| U | 手打ち負荷は簡単だが再現性・安全性に欠ける。再現可能・自動停止付きの仕組みが要る | AWS FIS |
| W | 手動分析なしでも Compute Optimizer が同じリサイズ結論（ここでは finding=Optimized で追認）に至る | Compute Optimizer |
| X | 通知を消したアラームは機能しない。検知→通知→対応の経路が要る | SNS / EventBridge |
| Y | エージェント停止でメモリメトリクスが静かに欠落し、既定設定では発火しない | CloudWatch `treat_missing_data` |
| V | 複合アラーム(OR)は片方欠損でも他方ALARMならALARM。だが両方欠損は OK に落ちる罠 | CloudWatch 複合アラーム |

## 前提

- Terraform >= 1.5 / AWS CLI 設定済み
- Session Manager Plugin（FIS実験の確認や手動接続に使用）

## 使い方

```bash
cp terraform.tfvars.example terraform.tfvars   # notification_email を自分のアドレスに
terraform init
terraform plan
terraform apply
# apply後、SNSの確認メールのリンクを必ず承認すること（未承認だと通知が届かない）
```

> ⚠️ コスト注意: t3.medium + r5.large の 2 台が常時起動する。検証が終わったら必ず `terraform destroy`。

## 検証手順（Runbook）

### 想定U: FISで再現可能な負荷をかける
```bash
aws fis start-experiment \
  --experiment-template-id $(terraform output -raw fis_cpu_experiment_template_id)
```
→ CloudWatch ダッシュボードで Web-Server の CPU 上昇を確認。CPU高アラーム発火で**実験が自動停止**することも確認（停止条件の動作）。

### 想定W: Compute Optimizer
```bash
aws compute-optimizer update-enrollment-status --status Active
# 30時間以上のメトリクス蓄積後に取得（1日では出ない可能性が高い）
aws compute-optimizer get-ec2-instance-recommendations \
  --query "instanceRecommendations[].{arn:instanceArn,finding:finding}"
```
→ 後日 `finding=Optimized`（手動リサイズの追認）をスクショ。

### 想定X: 通知の到達
FIS実験 or メモリ負荷でアラームを発火させ、登録メールに通知が届くことを確認。

### 想定Y: メトリクス欠落の検知
DB-Server に Session Manager で接続し、CloudWatch エージェントを停止:
```bash
sudo systemctl stop amazon-cloudwatch-agent
```
→ `Over-utilized Memory: DB-Server` が `treat_missing_data=breaching` により ALARM に遷移し、通知が届くことを確認（＝監視喪失を検知できる）。

### 想定V: 複合アラームの欠損伝播
1. 片方のみ欠損 + 他方 ALARM → 複合が `ALARM` になることを確認
2. 両方の子を `INSUFFICIENT_DATA` にする → 複合が `INSUFFICIENT_DATA` ではなく **`OK`** に落ちることを確認（スクショの目玉）

## クリーンアップ
```bash
terraform destroy
aws compute-optimizer update-enrollment-status --status Inactive   # destroy対象外なので明示的に
```

## 注意
- このリポジトリの Terraform は**自分の検証用 AWS アカウント**で実行する。Skill Builder のラボ環境では指定外サービス（FIS等）でエラーになる可能性がある。
- `terraform.tfstate` / `*.tfvars` は `.gitignore` 済み。コミットしないこと。
