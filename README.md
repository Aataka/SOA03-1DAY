# SOA03-1DAY — EC2 Rightsizing を運用監視の目線で検証する

AWS Skill Builder ラボ「EC2 Instance Rightsizing」を題材に、ラボが省略している**運用要素**を 4 つの仮説として立て、IaC（Terraform）で構築・検証するプロジェクト。検証結果を Zenn 記事化する。

> 注: 当初の仮説 W（Compute Optimizer）は推奨に最低30時間以上のメトリクス蓄積が必要で、1時間の検証枠では完遂不可のため本プロジェクトの対象外とした（記事側では設計言及に留める）。

## 検証する4つの仮説と結果

| 仮説 | 内容 | 使うサービス | 検証結果 |
|---|---|---|---|
| U | 手打ち負荷は再現性・安全性に欠ける。再現可能・自動停止付きの仕組みが要る | AWS FIS | ✅ 実証（CPU 0.5%→100%、実験は所定時間で完了） |
| X | 通知を消したアラームは機能しない。検知→通知の経路が要る | SNS | ✅ 実証（※メール確認に罠あり→[ハマりどころ](#ハマりどころ実機で踏んだ点)） |
| Y | エージェント停止でメモリが静かに欠落し、既定設定では発火しない | CloudWatch `treat_missing_data` | ✅ 実証（欠落→ALARMまで約6〜7分） |
| V | 複合アラーム(OR)は片方欠損でも他方ALARMならALARM。両方欠損はOKに落ちる罠 | CloudWatch 複合アラーム | ✅ V(a)実証 / ⬜ V(b)は設計言及のみ |

## 前提

- Terraform >= 1.5 / AWS CLI 設定済み
- Session Manager Plugin（FIS実験の確認や手動接続に使用）

## 使い方

```bash
cp terraform.tfvars.example terraform.tfvars   # notification_email を自分のアドレスに
terraform init
terraform plan
terraform apply
# apply後、SNS購読の確認が必要（下記ハマりどころ参照。メールのリンク直接クリックは非推奨）
```

> ⚠️ コスト注意: t3.medium + r5.large の 2 台が常時起動する。検証が終わったら必ず `terraform destroy`。

## 検証手順（Runbook）

### 想定U: FISで再現可能な負荷をかける
```bash
aws fis start-experiment \
  --experiment-template-id $(terraform output -raw fis_cpu_experiment_template_id)
```
→ CloudWatch ダッシュボードで Web-Server の CPU 上昇を確認。CPU高アラーム発火で**実験が自動停止**することも確認（停止条件の動作）。

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
# 確認: 実行中インスタンス・アラーム・SNSトピックが全て0になればOK
```

## ハマりどころ（実機で踏んだ点）

実際に検証して詰まった2点。再現する人向けに残す。

### 1. SNSメール購読が「確認直後」に自動解除される
確認メールの「Confirm subscription」をクリックすると `Subscription confirmed!` が出るのに、直後に購読が `Deleted` になり通知が届かない。原因は**メール/ブラウザのセキュリティ機構が確認完了ページの unsubscribe リンク（GETで解除される設計）を自動先読み**するため（企業メールだけでなく Gmail でも発生し得る）。

**対策**: メールのリンクを直接クリックせず、**右クリックでURLをコピー → Token を取り出して CLI で承認**する。`--authenticate-on-unsubscribe true` を付けると、解除に AWS 認証が要求され、スキャナのGETでは解除されなくなる。
```bash
# 確認メールのURLから Token を抜き出して実行
aws sns confirm-subscription \
  --topic-arn arn:aws:sns:<region>:<acct>:SOA03-1DAY-ops-alerts \
  --token <Token> \
  --authenticate-on-unsubscribe true
# ConfirmationWasAuthenticated=true を確認
```

### 2. CWエージェントの configure が install より先に走って失敗
新規インスタンスでは `AmazonCloudWatch-ManageAgent`(configure) が `AWS-ConfigureAWSPackage`(install) の実機完了前に実行され、`CloudWatch Agent not installed` で失敗することがある。`depends_on` / `wait_for_success_timeout_seconds` でも実機の実行順は完全には保証されない。

**対策**: configure 関連付けを手動で再実行する。
```bash
aws ssm start-associations-once --association-ids <configure-association-id>
```
本番では user_data でのインストールや、apply後の収集疎通チェックを運用フローに組み込むのが確実。

## 注意
- このリポジトリの Terraform は**自分の検証用 AWS アカウント**で実行する。Skill Builder のラボ環境では指定外サービス（FIS等）でエラーになる可能性がある。
- `terraform.tfstate` / `*.tfvars` は `.gitignore` 済み。コミットしないこと。
