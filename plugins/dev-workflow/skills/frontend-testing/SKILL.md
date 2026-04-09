---
name: frontend-testing
description: >
  frontendファイル（.vue, .ts, .js, .css）を変更・作成した場合に
  自動的に適用されるテスト実行ルール。タスク完了前に必ず従うこと。
version: 1.0.0
---

# Frontend Testing Rule

frontendファイル（`.vue`, `.ts`, `.js`, `.css`）に変更を加えた場合、
タスク完了前に以下を必ず実行する:

## 必須チェック

1. **Frontend unit tests**: `pnpm run test`
2. **Frontend linting**: `npx eslint`, `npx oxfmt --check`, `npx stylelint`

## 実行条件

- `.vue`, `.ts`, `.js`, `.css` ファイルを新規作成・変更した場合に適用
- テストが失敗した場合はタスク完了としない
- 該当ファイルの変更がない場合は実行不要
