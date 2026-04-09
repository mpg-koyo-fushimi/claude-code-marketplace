---
name: cleanup-worktree
argument-hint: <branch-name>
description: git worktreeで作成した開発環境を削除する（DB削除・worktree削除・ブランチ削除）
version: 1.0.0
---

# Worktree開発環境クリーンアップコマンド

`{{branch-name}}` で作成されたgit worktreeと関連リソースを削除する。
`create-worktree` で作成した環境の逆操作。

## 前提条件

- 大元のリポジトリのルートディレクトリで実行すること（worktree内からは実行しない）
- 対象のworktreeが `.claude/worktrees/{{branch-name}}` に存在すること

## 実行手順

### 1. 引数の検証

- `{{branch-name}}` が空の場合はエラーメッセージを表示して終了
- `.claude/worktrees/{{branch-name}}` が存在しない場合は「worktree '{{branch-name}}' が見つかりません」と表示して終了

### 2. 対象worktreeの確認

`git worktree list` で対象のworktreeが存在することを確認する。

ユーザーに以下の情報を表示し、削除の確認を求める:
- 削除対象のworktreeパス: `.claude/worktrees/{{branch-name}}`
- 対象ブランチ: `{{branch-name}}`
- DATABASE_SUFFIX（`.claude/worktrees/{{branch-name}}/.env` から取得）

### 3. 未コミットの変更の確認

worktreeディレクトリ内に未コミットの変更がないか確認する:

```bash
git -C .claude/worktrees/{{branch-name}} status --porcelain
```

未コミットの変更がある場合:
- ユーザーに警告: 「worktree '{{branch-name}}' に未コミットの変更があります。削除すると変更が失われます。」
- 続行するか確認を求める

### 4. サフィックス付きDBの削除

worktreeの `.env` から `DATABASE_SUFFIX` を読み取り、対応するDBを削除する:

```bash
cd .claude/worktrees/{{branch-name}} && bin/rails db:drop
```

DB削除に失敗した場合は警告を表示するが、処理は続行する（DBが既に存在しない場合もあるため）。

### 5. Worktreeの削除

```bash
git worktree remove .claude/worktrees/{{branch-name}} --force
```

`--force` は未コミットの変更がある場合にステップ3でユーザーの承認を得た上で使用する。
未コミットの変更がなかった場合は `--force` なしで実行する:

```bash
git worktree remove .claude/worktrees/{{branch-name}}
```

### 6. ブランチの削除

ブランチを削除するかユーザーに確認する。

削除する場合:

```bash
git branch -d {{branch-name}}
```

マージされていないブランチの場合は警告を表示し、強制削除 (`-D`) するか確認を求める。

### 7. 完了メッセージ

以下の情報をユーザーに表示する:

- 削除されたworktreeのパス
- 削除されたDB（DATABASE_SUFFIX）
- ブランチの削除有無
- 残っているworktree一覧（`git worktree list`）

## 注意事項

- 大元のリポジトリのworktreeは絶対に削除しない
- 削除前に必ずユーザーの確認を取る（未コミットの変更がある場合は特に）
- DB削除はworktree削除の前に行う（worktree削除後は `bin/rails` が実行できないため）
