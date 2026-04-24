---
name: skill-scaffold
argument-hint: <skill-name> [--spec <仕様要約>] [--skills-dir <path>] [--no-eval]
description: 新規 skill の作成 → テスト実行 → 改善ループを最小形式で定型化する。SKILL.md のドラフト生成と run-N ディレクトリでの実行結果保存までを一貫して行う。
version: 1.0.0
---

# Skill スキャフォルドスキル

新しい skill を作るときの「SKILL.md ドラフト → テスト実行 → 改善」のループをボイラープレートなしに素早く立ち上げる。

## 適用判断

以下のときに使用する:
- 新しい skill を一から作り始めるとき
- 既存 skill を大幅に改善するとき

アイデア整理・方針検討は済んでおり、「とりあえず動くドラフトを作って試したい」段階から使う。

## 引数

- `<skill-name>`（必須）: 作る skill の名前（ケバブケース）
- `--spec <仕様要約>`（任意）: skill が何をするかを 1〜3 文で指定。省略時はインタラクティブに確認
- `--skills-dir <path>`（任意）: SKILL.md の配置先ディレクトリ。省略時は `~/.claude/skills/`
- `--no-eval`（任意）: Step 2〜4（テスト実行と改善ループ）をスキップし、ドラフト作成のみ行う

## ステップ

### Step 1: SKILL.md ドラフトの作成

`--spec` または確認した仕様をもとに `<skills-dir>/<skill-name>/SKILL.md` を `Write` で作成する。

frontmatter の必須フィールド:
- `name`: `<skill-name>` と一致
- `description`: skill の目的と発動条件を 1 文で
- `argument-hint`: 引数があれば `<required>` / `[optional]` 記法で
- `version`: `1.0.0`

本文の必須セクション:
- `# <タイトル>`: 目的を 1 文
- `## 適用判断`: いつ使うかの条件
- `## ステップ`: 番号付きの実行手順
- `## エラーハンドリング`: 想定される失敗と対応（最低限 2〜3 ケース）

`--no-eval` が指定された場合はここで完了し、SKILL.md のパスを報告する。

### Step 2: テスト用ワークスペースの準備

カレントディレクトリ配下に `<skill-name>-test/` を作成する。

既存ディレクトリが存在する場合は `run-N` の連番を自動インクリメントして衝突を回避する:
- 初回: `<skill-name>-test/run-1/`
- 2 回目: `<skill-name>-test/run-2/`
- 以降同様

### Step 3: テスト実行

汎用サブエージェント（`Agent`）を起動し、以下を依頼する:

> 「`<skills-dir>/<skill-name>/SKILL.md` を読み込み、仕様を理解して実行してください。実行結果（生成物・報告内容・エラー）を `<skill-name>-test/run-N/output.md` に Markdown 形式で保存してください。」

### Step 4: 結果の評価と改善

`<skill-name>-test/run-N/output.md` を `Read` し、以下の観点で評価する:

**評価観点**:
- 仕様に記述した意図通りの出力が得られているか
- 出力形式・網羅性に欠けている観点はないか
- エラーが発生した場合、エラーハンドリング手順が機能しているか

問題がある場合は `Edit` で `SKILL.md` を修正し、run 番号をインクリメントして Step 3 に戻る（最大 3 周）。

3 周経過後もまだ問題がある場合は、問題点をユーザーに報告して手動対応を依頼する。

### Step 5: 完了報告

以下を報告する:

```
## skill-scaffold 完了

- SKILL.md: <skills-dir>/<skill-name>/SKILL.md
- テスト結果: <skill-name>-test/run-N/output.md
- ステータス: ✅ 正常 / ⚠️ 要確認
```

**配置先の確認**: 完成した skill をマーケットプレイスプラグインに追加するか、個人 global (`~/.claude/skills/`) のままにするか、プロジェクトローカル (`./.claude/skills/`) に移すかはユーザーに確認する。

## エラーハンドリング

| シナリオ | 対応 |
|---|---|
| `--spec` 未指定かつインタラクティブ確認なし | `AskUserQuestion` で仕様の概要を 1〜3 文で入力を求める |
| `<skills-dir>` が存在しない | `mkdir -p` で作成してから続行する |
| サブエージェントが `output.md` を保存しなかった | 「テスト実行は完了したが output.md が見つかりません」と報告し、サブエージェントの応答を要約する |
| 3 周試行後も critical issue 解消せず | 残存する問題点の一覧とその対応案をユーザーに提示し、手動修正を依頼する |
