# table アイテムの設計

Section Format に追加した、列と行で構成される表のアイテム。

このドキュメントは**スキーマの仕様**と**実装の勘所**を書く。使い方の例は
[test/section_report/features/table/](../test/section_report/features/table/) を見ること。

## なぜ作ったか

これまで Thinreports で表を作るには、四角形と直線を並べて罫線にし、その上にテキストブロックを
置く必要があった。列を1つ増やすだけで全部を並べ直すことになり、行の高さを内容に応じて
変えることもできなかった。

`table` はそれを1つのアイテムにまとめ、列・行・セルという構造で扱えるようにする。

## スキーマ

```jsonc
{
  "type": "table",
  "id": "items",
  "x": 0, "y": 40,
  "description": "", "display": true,
  "follow-stretch": "none", "affect-bottom-margin": true,

  // 表の既定の罫線。セルが指定しない辺はこれを使う
  "style": { "border-width": 0.5, "border-color": "#333333", "border-style": "solid" },

  // 列。セルは column-id でこれを参照する。表の幅は width の合計
  "columns": [
    { "id": "name", "width": 180 },
    { "id": "qty",  "width": 60 }
  ],

  // 行のテンプレート。表の高さは height の合計（auto-stretch で伸びる）
  "rows": [
    {
      "id": "detail",
      "type": "body",            // header / body / footer
      "height": 24,
      "display": true,
      "auto-stretch": true,
      "cells": [
        {
          "column-id": "name",
          "col-span": 1,
          "row-span": 1,
          "display": true,
          "style": {
            "background-color": "#eeeeee",     // "none" で塗らない
            "background-pattern": "forward-diagonal",
            "background-pattern-color": "#999999",
            "background-pattern-spacing": 4,
            "background-pattern-width": 0.5,
            "padding": [1, 4, 1, 4],           // [上, 右, 下, 左]
            "border-top": null,                // null=表の既定 / "none"=引かない / {width,color,style}
            "border-right": null,
            "border-bottom": { "width": 1.5 },
            "border-left": null
          },
          // 通常のアイテムスキーマをそのまま埋め込む。
          // x/y/width/height はセルとパディングから計算されるので書いても無視される
          "content": { "type": "text-block", "id": "name", ... }
        }
      ]
    }
  ]
}
```

`background-pattern` は `none` / `horizontal` / `vertical` / `grid` /
`forward-diagonal` / `backward-diagonal` / `cross-diagonal`。

### 行の type

| type | 描画のされ方 |
|---|---|
| `header` | 常に先頭で1回 |
| `body` | パラメータの `rows` に指定された回数だけ |
| `footer` | 常に末尾で1回 |

header / footer にも値を入れたいときは、`rows` にその行の id を持つ要素を1つ入れる。
**追加の行にはならず、その行の値になる。**

## Ruby からの渡し方

```ruby
items: {
  items: {                     # ← table アイテムの id
    rows: [
      { id: 'detail', cells: { name: 'りんご', qty: 3 } },
      { id: 'total',  cells: { total_price: 1980 } }   # footer 行に値を入れる
    ]
  }
}
```

`cells` のキーは **列の id**、または **content の id** のどちらでも引ける。
値はスカラーのほか、`{ value:, display:, styles:, background_color:, background_pattern: }`
のハッシュ、または `Proc` も渡せる。

`rows` を省略すると、テンプレートの行をそのまま1回ずつ描画する（静的な表）。

## 実装

```
lib/thinreports/
├── basic_report/core/shape/table/          スキーマの読み取り
│   ├── format.rb        columns / rows / default_border / 列オフセット計算
│   ├── column_format.rb
│   ├── row_format.rb    type / height / auto-stretch / cells
│   ├── cell_format.rb   col-span / row-span / padding / 背景 / 罫線 / content
│   ├── interface.rb
│   └── internal.rb      描画用の行データを states に保持する
├── basic_report/generator/pdf/document/graphics/hatch.rb   網掛けの描画
├── section_report/builder/table_builder.rb  スキーマ × パラメータ → 行・セルのデータ
└── section_report/pdf/renderer/table_renderer.rb           描画本体
```

### 描画の流れ

`TableRenderer#render` は2パスで動く。

**1パス目 — 幅を確定してから高さを測る**

セルの幅は行の高さに依存しないので先に決まる。`prepare_contents` で各セルの content に
幅（セル幅 − 左右パディング）を注入し、そのうえで行の高さを求める。

```
行の高さ = max( 行の schema の height,
                各セルの (上パディング + content の実測高 + 下パディング) )
```

実測するのは **`overflow: expand` の text-block だけ**。それ以外は 0 を返すので、
schema の height がそのまま使われる。`row-span` が 2 以上のセルは計算から除外する
（自分がまたぐ行の高さを押し広げない）。

結果は `shape.states[:table_row_layouts]` にメモ化する。`section_height` と `render` の
両方から呼ばれるため、測り直すと無駄が大きい。

**2パス目 — 描画**

表全体で1つ `bounding_box` を張り、行ごとに入れ子の `bounding_box` を張る。
セルは行のボックス内の相対座標で描く。`row-span` するセルは行のボックスからはみ出すが、
Prawn の `bounding_box` はクリップしないので、そのまま下の行にまたがって描ける。

セル1つあたりの描画順は 背景 → 網掛け → 罫線 → content。

### 網掛け

**Prawn にタイリングパターンの機能は無い。** そこで `Graphics#hatch` が、セルの矩形に対して
線分を解析的にクリップして描く。斜線は `x + y = c`（`/` 方向）と `y - x = d`（`\` 方向）の
直線族で表し、矩形との交点から線分の端点を求めている。

### content の描画

content は**通常のアイテムスキーマ**なので、レンダラがセル矩形とパディングから
x/y/width/height を計算して `format.attributes` に注入し、既存の `draw_shape_tblock` /
`draw_shape_text` / `draw_shape_iblock` / `draw_shape_image` に渡すだけ。
フォント・書式・overflow など既存機能がそのまま効くのはこのため。

そのため **content のスキーマはセルごとに deep copy して持つ必要がある**
（`TableBuilder#build_content` が `Marshal` でコピーしている）。同じスキーマの Hash を
共有すると、繰り返した行のあいだで座標が上書きし合う。

`overflow: expand` の text-block を描くときは、`draw_item.rb` と同じ理由で
overflow を `truncate` に落として実測高を渡している（`expand` のままだと Prawn が
高さ指定を無視し、vertical-align が中央・下のときに位置がずれるため）。

## 制約

- **表はページを跨げない。** セクションに収まらなければはみ出す。
  大量の明細は detail セクションの繰り返しを使う
- 行の自動伸縮の対象は `overflow: expand` の text-block を持つセルだけ
- `row-span` したセルは、またぐ行の高さを押し広げない
- セル内に置けるのは content 1つだけ（複数アイテムの自由配置はできない）

## 変えたくなったら

| やりたいこと | 触る場所 |
|---|---|
| 高さの計算規則 | `table_renderer.rb` の `row_height` / `cell_content_height` |
| 網掛けの種類を増やす | `graphics/hatch.rb` の `hatch_segments` と、エディタの pattern 一覧 |
| セルに置ける content の種類を増やす | `table_renderer.rb` の `draw_content_shape` |
| 属性を1つ増やす | `cell_format.rb` / `row_format.rb` に読み取りを足す ＋ **エディタのスキーマも直す** |
| ページ跨ぎに対応する | `section_report/pdf/renderer/group_renderer.rb`（改ページ判定の本体）。table の分割は未実装 |
