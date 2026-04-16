---
name: fix-pr
argument-hint: [pr_number (optional)]
description: CIの失敗修正と未解決レビューコメントへの対応を自動実行
---

# Fix PR

現在のPRに対して、CI失敗の修正と未解決レビューコメントへの対応を自動的に実行してください。

## 前提条件の確認

1. `gh --version` を実行し、GitHub CLIがインストールされていることを確認する
   - 未インストールの場合: 「GitHub CLIが見つかりません。`brew install gh` を実行してください。」と表示して終了
2. `gh auth status` を実行し、認証済みであることを確認する
   - 未認証の場合: 「GitHub CLIの認証が必要です。`gh auth login` を実行してください。」と表示して終了

## ステップ 1: PR情報の取得

引数 `$ARGUMENTS` が指定されている場合はそのPR番号を使用する。指定がない場合は現在のブランチから自動検出する。

```bash
# 引数なしの場合
gh pr view --json number,url,headRefName,baseRefName,title

# 引数ありの場合
gh pr view $ARGUMENTS --json number,url,headRefName,baseRefName,title
```

PRが見つからない場合は以下のメッセージを表示して終了:
「現在のブランチにオープンなPRが見つかりません。先にPRを作成するか、PR番号を指定してください（例: /fix-pr 123）」

取得したPR番号を以降のステップで `PR_NUMBER` として使用する。

## ステップ 2: CIチェックの確認と修正

### 2-1. CIステータスの取得

```bash
gh pr checks $PR_NUMBER
```

すべてのチェックがpassしている場合は「CI: すべてのチェックが通過しています」と表示し、ステップ3に進む。

### 2-2. 失敗したCIランのログ取得

失敗しているCheckについて:

```bash
# PRブランチの失敗ランを取得
gh run list --branch $(gh pr view $PR_NUMBER --json headRefName --jq .headRefName) --status failure --json databaseId,name,conclusion --limit 5

# 各失敗ランの詳細ログを取得
gh run view <run_id> --log-failed
```

### 2-3. 失敗内容の分析と修正

ログを分析して失敗の根本原因を特定し、以下のカテゴリに分類して対応する:

- **テスト失敗**: 失敗テストのファイル・行番号を特定し、ソースコードを読んで修正
- **Lint/型エラー**: エラーメッセージに記載されたファイル・行番号を修正
- **ビルドエラー**: 依存関係や構文エラーを修正
- **その他**: ログから原因を推測して修正

### 2-4. 修正のコミットとプッシュ

修正がある場合:

```bash
git add <変更したファイル>
git commit -m "fix: resolve CI failures - <失敗内容の簡潔な説明>"
git push
```

CIの再実行完了を待たずにステップ3に進む。

## ステップ 3: 未解決レビューコメントの確認と対応

### 3-1. 未解決のレビュースレッドを取得

GitHub GraphQL API を使用する:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 50) {
          nodes {
            id
            isResolved
            isOutdated
            path
            line
            originalLine
            diffSide
            comments(first: 10) {
              nodes {
                id
                databaseId
                body
                author {
                  login
                }
                createdAt
              }
            }
          }
        }
      }
    }
  }
' -F owner="$(gh repo view --json owner --jq .owner.login)" \
  -F repo="$(gh repo view --json name --jq .name)" \
  -F pr=$PR_NUMBER
```

`isResolved: false` のスレッドのみを処理対象とする。
未解決スレッドがない場合は「レビューコメント: 未解決のスレッドはありません」と表示してステップ4に進む。

### 3-2. 各スレッドの対応

未解決スレッドごとに以下を実行する:

**a. コードコンテキストの読み込み**

スレッドの `path` と `line` を使って該当ファイルの該当箇所（前後10行程度）を読み込む。

**b. 対応の判断**

コメントの内容とコードを分析して、以下のいずれかを判断:

- **修正が必要**: バグ、設計上の問題、規約違反などを修正する
- **修正不要**: コメントが誤解に基づいている、または現在の実装が正しい場合

**c. 修正の実施（修正が必要な場合）**

該当ファイルを修正する。

**d. レビューコメントへの返信**

スレッドの最初のコメントの `databaseId` を使って返信する:

```bash
gh api \
  repos/{owner}/{repo}/pulls/$PR_NUMBER/comments/<最初のコメントのdatabaseId>/replies \
  -f body="<返信内容>"
```

返信内容:
- **修正した場合**: 「修正しました。[修正内容の概要]」
- **修正しない場合**: 「確認しました。[現在の実装が正しい理由]。変更は不要と判断しました。」

**e. スレッドの解決**

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: { threadId: $threadId }) {
      thread {
        isResolved
      }
    }
  }
' -F threadId="<スレッドのid>"
```

### 3-3. 修正のコミットとプッシュ

コード修正がある場合:

```bash
git add <変更したファイル>
git commit -m "fix: address PR review comments - <対応内容の簡潔な説明>"
git push
```

修正がなかった場合（すべて説明のみで対応）はコミット不要。

## ステップ 4: 完了サマリーの表示

以下の形式で結果を表示する:

```
## Fix PR 完了

### CI修正
- 修正したチェック: [チェック名のリスト、またはなし]
- 修正内容: [変更の概要]

### レビューコメント対応
- 処理したスレッド数: N件
- 修正を行ったスレッド: N件
- 説明で対応したスレッド: N件

### コミット
- [コミットハッシュ] <コミットメッセージ>

PR URL: <pr_url>
```

## エラーハンドリング

- PRが見つからない場合: メッセージを表示して終了
- CIログが非常に長い場合: 失敗箇所を中心に200行程度に限定して読み込む
- ファイルが見つからない場合: 「コメントが参照するファイル `<path>` が見つかりません」と表示してそのスレッドをスキップ
- GraphQLでスレッドの解決に失敗した場合: 警告を表示して次のスレッドに進む
- 修正の確信度が低い場合: ユーザーに確認を求めてから修正する
