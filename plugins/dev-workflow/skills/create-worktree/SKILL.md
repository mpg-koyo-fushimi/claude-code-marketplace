---
name: create-worktree
argument-hint: <branch-name>
description: git worktreeで開発環境を作成する（大元のDBコンテナを共有）
---

# Worktree開発環境作成コマンド（DB共有方式）

`{{branch-name}}` でgit worktreeを作成し、大元のDBコンテナを共有する.envを設定する。
worktreeごとにDockerコンテナは立てず、メモリ消費を抑える。

## 前提条件

- 大元のリポジトリでDBコンテナが稼働していること（`docker compose up -d db`）
- DBコンテナは 127.0.0.1:3306 でアクセス可能であること

## 実行手順

### 1. 引数の検証

- `{{branch-name}}` が空の場合はエラーメッセージを表示して終了
- ブランチ名に使えない文字が含まれていないか確認

### 2. 大元のDBコンテナの稼働確認

`docker compose ls` で大元のclinpeer Docker Composeプロジェクトが稼働中か確認する。

稼働していない場合:
- ユーザーに警告: 「大元のDBコンテナが稼働していません。`docker compose up -d db` を実行してください」
- 処理を中断する

### 3. 既存worktreeのDATABASE_SUFFIXを調査

`.claude/worktrees` ディレクトリ内の全worktreeの `.env` ファイルを走査し、使用中の `DATABASE_SUFFIX` を収集する。

### 4. DATABASE_SUFFIXの決定

以下のルールで、他のworktreeと被らないサフィックスを決定する:

1. インデックス `n` を 2 から順に増やす
2. `DATABASE_SUFFIX=n` が未使用のインデックスを見つける
   - 例: `DATABASE_SUFFIX=2` → DB名が `clinpeer_development2`, `clinpeer_test2`

### 5. Worktreeの作成

```bash
git worktree add .claude/worktrees/{{branch-name}} -b {{branch-name}}
```

ブランチが既に存在する場合は `-b` を省略:

```bash
git worktree add .claude/worktrees/{{branch-name}} {{branch-name}}
```

### 6. 環境変数ファイルの作成

#### .envrc の作成

worktreeのルートに `.envrc` を作成:

```
dotenv
```

#### .env の作成

worktreeのルートに `.env` を作成する。大元のDBコンテナを共有する設定:

```
DATABASE_URL=trilogy://root:@127.0.0.1
READER_DATABASE_URL=trilogy://root:@127.0.0.1
DATABASE_SUFFIX={算出したサフィックス}
```

`COMPOSE_FILE`, `WEB_PORT`, `VITE_RUBY_PORT`, `DB_PORT` は設定しない（Dockerコンテナを立てないため）

### 7. direnvの許可

```bash
cd .claude/worktrees/{{branch-name}} && direnv allow
```

### 8. DBのセットアップ

worktreeディレクトリで以下を実行し、サフィックス付きのDBを作成:

```bash
cd .claude/worktrees/{{branch-name}} && bin/rails db:create db:migrate
```

### 9. 完了メッセージ

以下の情報をユーザーに表示する:

- 作成されたworktreeのパス
- 設定されたDATABASE_SUFFIX
- 共有しているDBコンテナの情報
- 開発を始めるための手順:
  1. `cd .claude/worktrees/{{branch-name}}`
  2. `bin/dev` でサーバーを起動（Dockerなしで直接実行）

## 注意事項

- worktreeではDockerコンテナを一切起動しない
- 大元のDBコンテナが停止するとworktreeの開発も止まる
- worktree削除時は `bin/rails db:drop` でサフィックス付きDBを削除してからworktreeを削除する
