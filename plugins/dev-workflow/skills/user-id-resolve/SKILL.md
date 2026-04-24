---
name: user-id-resolve
argument-hint: <service1,service2,...> [--name <表示名>]
description: Slack / Notion / GitHub など指定サービスで自分のユーザー ID を MCP または CLI 経由で取得し、skill へのハードコード用テーブルとして返す。skill 作成時のサブルーチンとして使用。
version: 1.0.0
---

# ユーザー ID 解決スキル

新しい skill を作る過程で自分や特定人物のユーザー ID（Slack member_id、Notion UUID、GitHub login など）が必要になったとき、各サービスを横断して一括取得してまとめる。

## 適用判断

以下のときに使用する:
- skill の `## ハードコード定数` セクションに書くべき ID を取得したいとき
- 「Slack で自分のユーザー ID を知りたい」「Notion のメンション用 UUID が必要」など

**このスキルは調査専用**。取得した ID をファイルに書き込む処理は呼び出し元が行う。

## 引数

- `<service1,service2,...>`（必須）: カンマ区切りで取得対象サービスを指定（`slack`, `notion`, `github` のうち 1 つ以上）
- `--name <表示名>`（任意）: 検索に使う人名。省略時は `git config user.name` の値を使う。それも空の場合は `CLAUDE.md` の `userEmail` から姓名を推定する

## ステップ

### Step 0: 対象人物の名前を確定する

`--name` が指定されていれば使用する。未指定の場合:

```bash
git config user.name
```

出力が空の場合は、セッションコンテキスト内の `userEmail` から名前を推定するか、ユーザーに確認する。

### Step 1: 各サービスで ID を取得（並列実行）

指定されたサービスをすべて並列で処理する。

#### Slack

`slack_search_users` を使用（ToolSearch で先にロードが必要):

```json
{
  "query": "<name>",
  "limit": 5
}
```

結果の `user.id`（例: `U05JW59MYFN`）を抽出する。

#### Notion

`notion-get-users` を使用（ToolSearch で先にロードが必要）:

```json
{
  "query": "<name>"
}
```

結果の `id`（UUID 形式、例: `3e89b4a5-fdab-4c43-9ed9-e2dadfbc3dda`）を抽出する。

#### GitHub

```bash
gh api user --jq '{login: .login, id: .id, name: .name}'
```

`login` をユーザー ID として扱う。未認証の場合は `git config user.email` を補助情報として表示する。

### Step 2: 結果の報告

以下の形式で出力する:

```markdown
## ユーザー ID 解決結果

| サービス | フィールド | 値 | 備考 |
|---|---|---|---|
| Slack | member_id | U05JW59MYFN | |
| Notion | UUID | 3e89b4a5-fdab-4c43-9ed9-e2dadfbc3dda | |
| GitHub | login | mpg-koyo-fushimi | |

### コピペ用（skill の「ハードコード定数」テーブル）

| キー | 値 |
|---|---|
| Slack user ID | `U05JW59MYFN` |
| Notion user UUID | `3e89b4a5-fdab-4c43-9ed9-e2dadfbc3dda` |
| GitHub username | `mpg-koyo-fushimi` |
```

## エラーハンドリング

| シナリオ | 対応 |
|---|---|
| 対象サービスの MCP ツールがロードできない | 該当サービス行を「未取得（MCP 利用不可）」として他サービスは継続 |
| 検索結果が 0 件 | 「見つかりませんでした」と記載し、別の表記で再検索するかユーザーに確認 |
| 検索結果が複数件でどれか不明 | 候補リストをユーザーに提示して選択を求める |
| `gh` CLI 未認証 | GitHub 行を「未取得（gh CLI 未認証）」として記載し、`gh auth login` を案内 |
