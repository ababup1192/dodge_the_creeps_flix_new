## 言語

開発者とのやり取りは、日本語を使うこと

## 環境

- devbox shell で開発環境に入る（JDK 21 必須）
- bin/flix.jar は Flix 0.71.0（devbox には最新がないため手動ダウンロード）
- コマンド実行は `devbox run -- java -jar bin/flix.jar <command>` の形式で行う

```bash
devbox run -- java -jar bin/flix.jar test
devbox run -- java -jar bin/flix.jar run
devbox run -- java -jar bin/flix.jar build
```

**注意**: `devbox run flix test` は対話REPLに入ってしまうので使わないこと

## 変更後の確認

コード変更後は `/verify` スキルを実行すること。
セッション終了時、所感があれば `/dev-log` で記録できる。

## スキル参照ガイド

| タイミング | スキル |
|---|---|
| Flix コードを新規作成・修正する前 | `/flix-docs` |
| GameNode / Scene / GameEngine を触る前 | `/engine-guide` |
| GameNode を拡張・新しいゲームを作るとき | `/scene-pattern` |
| コンパイルエラーが解決しないとき | `/compile-fix` |
| 外部 JAR を追加するとき | `/add-jar` |
| コードレビューするとき | `/review-checklist` |
| テストを設計するとき | `/test-strategy` |

## Flix バージョン更新

```bash
curl -L -o bin/flix.jar https://github.com/flix/flix/releases/download/vX.XX.X/flix.jar
```
