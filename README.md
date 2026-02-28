# Claude (Bedrock) Launcher

AWS Bedrock 経由で Claude Code を起動するためのランチャースクリプトです。
`~/.aws/config` に設定された複数の AWS プロファイルをメニューから選択し、SSO ログインを自動化したうえで Claude を起動します。

## 機能

- `~/.aws/config` の全プロファイルを自動検出してメニュー表示
- SSO プロファイルは `aws sso login` を自動実行
- 静的認証情報プロファイルはログインをスキップして即起動
- Claude Code の Bedrock 向け環境変数を自動設定

## 前提条件

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) がインストール済み
- [Claude Code](https://docs.anthropic.com/claude-code) がインストール済み (`claude` コマンドが使えること)
- `~/.aws/config` に AWS プロファイルが設定済み
- AWS Bedrock で Claude モデルへのアクセスが有効化済み

## セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/akira-sato22/claude-shell.git
cd claude-shell

# スクリプトに実行権限を付与
chmod +x claude-launcher.sh
```

## 使い方

```bash
./claude-launcher.sh
```

実行すると、設定済みプロファイルの一覧が表示されます。

```
=== Claude (Bedrock) Launcher ===

   1) my-dev-profile                          (123456789012 / DevRole) [SSO]
   2) my-prod-profile                         (987654321098 / ProdRole) [SSO]
   3) local-static                            (region: ap-northeast-1)

プロファイルを選択してください [1-3]:
```

番号を入力すると、続いてリージョン選択メニューが表示されます。

```
=== AWS リージョンを選択 ===

   1) us-east-1      (米国東部 - バージニア北部)
   2) us-east-2      (米国東部 - オハイオ)
   3) us-west-2      (米国西部 - オレゴン)
   4) ap-northeast-1 (アジアパシフィック - 東京)

リージョンを選択してください [1-4]:
```

リージョンを選択すると、SSO プロファイルの場合はブラウザが開いて認証が完了した後、Claude が起動します。

## 設定されている環境変数

スクリプトは以下の環境変数を設定して Claude を起動します。

| 変数名                           | 値                                            | 説明                           |
| -------------------------------- | --------------------------------------------- | ------------------------------ |
| `AWS_PROFILE`                    | 選択したプロファイル名                        | AWS SDK が使用するプロファイル |
| `AWS_REGION`                     | 実行時に選択した値                            | Bedrock のリージョン           |
| `CLAUDE_CODE_USE_BEDROCK`        | `1`                                           | Bedrock モードの有効化         |
| `ANTHROPIC_DEFAULT_OPUS_MODEL`   | `us.anthropic.claude-opus-4-6-v1`             | Opus モデル ID                 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `us.anthropic.claude-sonnet-4-6`              | Sonnet モデル ID               |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL`  | `us.anthropic.claude-haiku-4-5-20251001-v1:0` | Haiku モデル ID                |


## `~/.aws/config` の設定例

**SSO プロファイル**
```ini
[profile my-dev-profile]
sso_session = my-sso
sso_account_id = 123456789012
sso_role_name = DevRole
region = ap-northeast-1

[sso-session my-sso]
sso_start_url = https://my-org.awsapps.com/start
sso_region = ap-northeast-1
sso_registration_scopes = sso:account:access
```

**静的認証情報プロファイル**
```ini
[profile local-static]
region = ap-northeast-1
```

## ライセンス

MIT
