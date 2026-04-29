---
name: verify
description: "コード変更後にflix testとflix runの2段階検証を順番に行う"
disable-model-invocation: true
allowed-tools:
  - "Bash(devbox run -- java -jar bin/flix.jar *)"
---

# 変更後の検証実行

コード変更後に `flix test` と `flix run` の2段階検証を順番に行います。

## 手順

### ステップ 1: テスト実行

`flix test` を実行する。

- **成功した場合**: ステップ2に進む
- **失敗した場合**: 失敗したテストの詳細を報告して**停止**する。`flix run` は実行しない

### ステップ 2: 動作確認

テストが全て通過した後、`flix run` を実行する。

- コンパイルエラーや実行時エラーがないことを確認する

### ステップ 3: 結果サマリー

以下の形式で結果を報告する：

```
## 検証結果
- flix test: OK (XX tests passed)
- flix run:  OK (正常起動)
```

または失敗時：

```
## 検証結果
- flix test: NG
  - 失敗テスト: testXxx — expected X but got Y
```

### ステップ 4: 所感の記録提案（検証成功時のみ）

テストと動作確認が両方成功した場合、以下を提案する：

> 所感があれば `/dev-log` で記録できます（指摘・良パターン・ハマりポイント）

失敗時は修正が優先なので提案しない。

## 注意事項

- `flix test` が失敗した場合は絶対に `flix run` を実行しないこと
- エラーメッセージは省略せず、ユーザーが修正に必要な情報を全て含めること
