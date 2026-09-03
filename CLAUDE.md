# thinreports-generator

Thinreports のテンプレート（`.tlf`）を読み込んで PDF を生成する Ruby ライブラリ。

## このリポジトリだけでは完結しない

Thinreports は3つのリポジトリでできている。

```
Editor (GUI)  ──書き出し──▶  .tlf (JSON)  ──読み込み──▶  Generator (このリポジトリ)  ──▶  PDF
```

- [thinreports-basic-editor](https://github.com/thinreports/thinreports-basic-editor) … Basic Format 用エディタ（Electron + Google Closure）
- [thinreports-section-editor](https://github.com/thinreports/thinreports-section-editor) … Section Format 用エディタ（Electron + Vue 3 + TypeScript）

**エディタとの間にコードの依存は一切ない。`.tlf` の JSON スキーマだけが契約。**

したがって **`.tlf` に新しい属性やアイテムを足すときは、必ずエディタ側も同時に直す必要がある。**
片方だけ直すと、エディタで作れないテンプレート、または Generator が読めないテンプレートができる。

## 開発環境

```
ruby -v     # gemspec が required_ruby_version >= 3.3.0 を要求する
bundle install
```

Windows で複数バージョンを切り替えるなら [rbenv for Windows](https://github.com/RubyMetric/rbenv-for-windows)。

> **ハマりどころ:** セキュリティソフト（Avast など）が HTTPS を復号・再署名していると、
> `bundle install` が `Could not verify the SSL certificate` で落ちる。Windows の証明書ストアには
> その root CA が入っていても、Ruby は独自の CA バンドルを見るため知らないのが原因。
> `ruby -ropenssl -e "puts OpenSSL::X509::DEFAULT_CERT_FILE"` が指すファイルに、
> その root 証明書を PEM で追記すれば通る。

## テスト

```
bundle exec rake test              # 全部
bundle exec rake test:main
bundle exec rake test:basic_report
bundle exec rake test:section_report
```

`test/section_report/features/` 以下は **1機能1ディレクトリ**で、README・テンプレート・
`expect.pdf`・`test_feature.rb` の4点セット。**ここが実質の仕様書**であり、機能を足したら
ここに1ディレクトリ追加するのが作法。

フィーチャテストは PDF を比較するため外部コマンド [diff-pdf](https://github.com/vslavik/diff-pdf)
が要る。無い場合は skip されるので、**「0 failures」だけを見て通ったと判断してはいけない。**
skip 数を必ず確認すること。diff-pdf を入れられない環境では、生成された `actual.pdf` と
`expect.pdf` をレンダリングして画素比較すれば代用できる。

## アーキテクチャ

```
lib/thinreports/
├── basic_report/     Basic Format ＋ 両フォーマット共通の基盤
│   ├── core/         Shape / Format / Style … 【Section Format も使う】
│   ├── layout/       .tlf 読み込み（Basic 用）
│   ├── report/       Report / Page（利用者が触る API）
│   └── generator/pdf Prawn のラッパ 【Section Format も使う】
└── section_report/   Section Format
    ├── schema/       .tlf のパース
    ├── builder/      スキーマ × パラメータ → 描画用データ
    └── pdf/renderer/ 描画
```

**`section_report.rb` の先頭に注意。**

```ruby
Core = BasicReport::Core
Generator = BasicReport::Generator
```

Section Format は独立していない。**図形定義と PDF 描画層は Basic のものを borrow している。**
だから `generator/pdf/document/` を直すと両フォーマットに効く。

### 覚えておくべき決まりごと

- **座標系**: `.tlf` は左上原点、Prawn は左下原点。`Document#pos` / `#rpos` で毎回変換する
- **スキーマの読み方**: `Core::Format::Base` の `config_reader :page_width, %w[report width]` という
  DSL でネストしたキーをメソッドにする。属性を1つ増やすだけならここに1行足すだけ
- **Basic Format の stamp**: 値が変わらない要素はレイアウトごとに一度だけ Prawn の stamp として
  登録し、各ページは貼るだけ。数千ページでもファイルが膨らまない
- **Section Format の改ページ**: `GroupRenderer#render` が高さを足していって溢れたら改ページ、
  それだけ。**フッタをページ下端に固定する機能は無い**
- **auto-stretch**: `section_height.rb` が本体。text-block の `overflow: expand` は
  Prawn の `height_of_formatted` で実測してから本描画する2パス方式
- **フォント**: IPA 4書体を gem に同梱。追加は `Thinreports.config.fallback_fonts`
- **B4/B5**: JIS 実寸をハードコードしている（Prawn の B4 は ISO なので別物）

### アイテムの種類を増やすとき

1. `lib/thinreports/basic_report/core/shape/<type>/` に `format` / `interface` / `internal` を作る
2. `core/shape.rb` の `find_by_type` に登録し、`require_relative` を足す
3. Section Format で使うなら
   - `section_report/pdf/renderer/` に描画を足し、`draw_item.rb` に分岐を追加
   - `section_report/pdf/renderer/section_height.rb` の `item_layout` に分岐を追加
     （足さないと auto-stretch の高さ計算で落ちる）
   - パラメータを受けるなら `section_report/builder/item_builder.rb` に分岐を追加
4. `test/section_report/features/<name>/` に一式追加
5. **エディタ側にも同じスキーマを実装する**

実例として `table` の実装がある。[docs/table-item.md](docs/table-item.md) を読むこと。

## 初めてこのリポジトリに触る人へ

git や GitHub に不慣れな利用者向けの導入手順が
[docs/getting-started-ja.md](docs/getting-started-ja.md) にある。環境構築から表の使い方、
改造の始め方までを、**Claude Code に貼り付ける文章**の形で書いてある。
利用者が詰まっていたら、まずこれを案内すること。

## コーディング上の慣習

- 全ファイル `# frozen_string_literal: true`
- 例外は `Thinreports::BasicReport::Errors::` 以下。**`Thinreports::Errors` という名前空間は存在しない**
  （存在しない定数を参照している箇所が過去にあった）
- 公開 API には YARD コメント（`@param` / `@return`）
