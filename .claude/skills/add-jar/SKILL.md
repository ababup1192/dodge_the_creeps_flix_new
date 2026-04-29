---
name: add-jar
description: "外部JAR（Maven依存）をFlixプロジェクトに追加する手順ガイド。flix.toml設定、Javaラッパー作成、予約語回避を含む"
when_to_use: "外部ライブラリやJARを追加するとき、Maven依存を設定するとき、Javaラッパーを作るとき"
disable-model-invocation: true
allowed-tools:
  - Read
  - Edit
  - Write
  - "Bash(devbox run -- java -jar bin/flix.jar build)"
  - "Bash(javac *)"
  - "Bash(jar *)"
---

# 外部 JAR の追加手順

Flix プロジェクトに外部 JAR（Maven依存）を追加するためのガイドです。

## 前提知識

- Flix の予約語（`handler` 等）を含むパッケージは、直接 import できない
- その場合は Java ラッパー経由で利用する

## 手順

### ステップ 1: Maven 依存の追加

`flix.toml` の `[mvn-dependencies]` に依存を追加する。

```toml
[mvn-dependencies]
"group:artifact" = "version"
```

### ステップ 2: ビルドしてダウンロード

```bash
devbox run -- java -jar bin/flix.jar build
```

`lib/cache/` に JAR がダウンロードされることを確認する。

### ステップ 3: 予約語を含む場合 — Java ラッパー作成

予約語がパッケージ名やクラス名に含まれる場合のみ必要。

1. `lib/external/` に Java ラッパークラスを作成
2. コンパイルして JAR に固める

```bash
javac -cp "lib/cache/*" -d lib/external/classes lib/external/src/*.java
jar cf lib/external/xxx.jar -C lib/external/classes .
```

3. `flix.toml` の `[jar-dependencies]` に追加

```toml
[jar-dependencies]
"xxx.jar" = "url:file://local"
```

### ステップ 4: Flix から利用

```flix
import mypkg.MyClass
```

## 注意事項

- `handler` は Flix の予約語 — import文や変数名に使うとパースエラーになる
- 予約語を含まないパッケージなら、ステップ3は不要で直接 import できる
