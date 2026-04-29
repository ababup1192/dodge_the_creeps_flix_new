## Flix 0.71.0 制約

- ラムダ引数でのタプル直接分解 `(acc, (idx, config)) ->` は **未サポート**。`let (idx, config) = pair` で分解する必要あり。
- `List.foldLeftWithIndex` は標準ライブラリに存在しない。`zipWithIndex |> foldLeft` を使う。