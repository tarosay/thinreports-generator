# frozen_string_literal: true

require 'test_helper'

class Thinreports::SectionReport::TestTableFeature < Thinreports::FeatureTest[__dir__]
  ITEMS = [
    { name: 'りんご', qty: '3', price: '120', note: '青森県産。傷みやすいため配送時は要冷蔵。' },
    { name: 'バナナ', qty: '12', price: '20', note: '' },
    { name: 'みかん', qty: '5', price: '80',
      note: '和歌山県産の温州みかん。箱詰めで発送します。' \
            'この備考は長いので、セルの高さが内容に応じて自動的に伸びることを確認できます。' },
    { name: 'ぶどう', qty: '1', price: '980', note: 'シャインマスカット' }
  ].freeze

  feature do
    params = {
      type: :section,
      layout_file: template_path,
      params: {
        groups: [
          {
            details: [
              {
                id: 'main',
                items: {
                  items: { rows: build_rows }
                }
              }
            ]
          }
        ]
      }
    }
    assert_pdf Thinreports.generate(params)
  end

  private

  def build_rows
    rows = ITEMS.map do |item|
      {
        id: 'detail',
        cells: {
          name: item[:name],
          qty: item[:qty],
          price: item[:price],
          note: item[:note]
        }
      }
    end

    total = ITEMS.sum { |item| item[:qty].to_i * item[:price].to_i }
    rows << { id: 'total', cells: { total_price: total.to_s } }
  end
end
