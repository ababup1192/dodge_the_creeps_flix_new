---
name: dev-log
description: "開発セッションの所感（指摘・良パターン・ハマりポイント）をMEMORY.mdに記録する"
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Edit
  - "Bash(git log *)"
  - "Bash(git diff *)"
---

# 開発ログの記録

開発セッションで得た所感をMEMORY.mdに記録し、次回セッションに活かします。

## 手順

### ステップ 1: 直近の作業内容を把握

以下を実行して直近の作業内容を確認する：

```bash
git log --oneline -5
git diff --stat HEAD~1
```

### ステップ 2: MEMORY.md を読み込み

`/Users/abab/.claude/projects/-Users-abab-Desktop-frogger/memory/MEMORY.md` を読み込む。
ファイルが存在しない場合は新規作成する。

### ステップ 3: ユーザーに所感を聞く

AskUserQuestion で以下の3カテゴリを提示し、記録したい内容を聞く：

- **開発者からの指摘**: セッション中に開発者から受けた指摘やフィードバック
- **良かったコードパターン**: うまくいった書き方やアプローチ
- **ハマったポイント**: 時間を取られた問題や落とし穴

ユーザーが自由記述できるようにし、該当なしのカテゴリは省略可能とする。

### ステップ 4: MEMORY.md に追記

以下のフォーマットでMEMORY.mdに追記する：

```markdown
## 開発ログ

### YYYY-MM-DD 作業概要
- **指摘**: 内容
- **良パターン**: 内容
- **ハマり**: 内容
```

- `## 開発ログ` セクションが既にある場合は、そのセクション内に新しいエントリを追加する
- 日付と作業概要（git logから推測）をヘッダにする
- 該当なしのカテゴリは記載しない

### ステップ 5: 行数チェックと整理

MEMORY.mdが200行を超えそうな場合：

1. `/Users/abab/.claude/projects/-Users-abab-Desktop-frogger/memory/dev-log.md` に古いエントリを移動する
2. MEMORY.mdには直近のエントリと、dev-log.mdへの参照リンクのみ残す

```markdown
## 開発ログ

過去のログ: [dev-log.md](dev-log.md)

### 2026-04-27 最新の作業
- ...
```

## 注意事項

- MEMORY.mdは200行以内に収めること（システムプロンプトに含まれるため）
- 記録内容はプロジェクト固有の学びに限定し、一般的な知識は含めない
