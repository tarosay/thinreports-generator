# Table

table によって、列と行で構成された表を作ることができる。

- [Example code](test_feature.rb)
- [Example template file](template.tlf)
- [Example PDF](expect.pdf)

table の主な機能は以下の通り。

- `columns` で列を定義する。セルは `column-id` によって自分が属する列を指定する
- `rows` で行のテンプレートを定義する。行の `type` は `header` / `body` / `footer` のいずれか
  - `header` と `footer` は常に1回だけ描画される
  - `body` はパラメータの `rows` に指定された回数だけ描画される
- 行に `auto-stretch` を指定すると、セルの内容に応じて行の高さが自動的に伸びる
  - 伸縮の対象になるのは `overflow: expand` の text-block を持つセルのみ
  - `row-span` が 2 以上のセルは、自分がまたぐ行の高さを押し広げない
- セルは `col-span` / `row-span` によって結合できる
- セルの罫線は4辺それぞれ指定できる。省略した辺は table の `style` の値を使い、`"none"` を指定すると描画しない
- セルの背景は塗りつぶし (`background-color`) と網掛け (`background-pattern`) を指定できる
- セルの中身 (`content`) には text / text-block / image-block / image を置ける。
  その座標はセルの矩形と `padding` から計算されるため、スキーマ上の x/y/width/height は無視される

table がページを跨ぐことはできない。大量の明細を出力する場合は detail セクションの繰り返しを使う。

## テンプレートについて

このテンプレートは [build_template.py](build_template.py) で生成している。

```
$ python build_template.py
```
