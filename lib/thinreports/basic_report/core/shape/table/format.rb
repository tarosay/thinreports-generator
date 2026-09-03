# frozen_string_literal: true

module Thinreports
  module BasicReport
    module Core
      module Shape
        module Table
          class Format < Basic::Format
            DEFAULT_BORDER = {
              'width' => 0.5,
              'color' => '#000000',
              'style' => 'solid'
            }.freeze

            attr_reader :columns, :rows

            def initialize(*)
              super
              initialize_columns(attributes['columns'] || [])
              initialize_rows(attributes['rows'] || [])
            end

            # @param [String] id
            # @return [Integer, nil]
            def find_column_index(id)
              @column_indexes[id.to_s]
            end

            # @return [Array<Numeric>] x offset of each column
            def column_offsets
              @column_offsets ||= begin
                offset = 0.0
                columns.map do |column|
                  current = offset
                  offset += column.width
                  current
                end
              end
            end

            # @param [Integer] index
            # @param [Integer] span
            # @return [Numeric]
            def span_width(index, span)
              columns[index, span].to_a.sum(0.0, &:width)
            end

            # @return [Numeric]
            def total_width
              @total_width ||= columns.sum(0.0, &:width)
            end

            # Height of the table when no row is stretched.
            # @return [Numeric]
            def total_height
              @total_height ||= rows.sum(0.0, &:height)
            end

            # The border which is used by cells that do not have their own setting.
            # @return [Hash, nil]
            def default_border
              return @default_border if defined?(@default_border)

              border = style && style['border']
              @default_border =
                case border
                when 'none' then nil
                when ::Hash then DEFAULT_BORDER.merge(border)
                else
                  if style && (style['border-width'] || style['border-color'])
                    DEFAULT_BORDER.merge(
                      'width' => style.fetch('border-width', DEFAULT_BORDER['width']),
                      'color' => style.fetch('border-color', DEFAULT_BORDER['color']),
                      'style' => style.fetch('border-style', DEFAULT_BORDER['style'])
                    )
                  else
                    DEFAULT_BORDER
                  end
                end
            end

            private

            def initialize_columns(column_schemas)
              @columns = column_schemas.map { |schema| Table::ColumnFormat.new(schema) }
              @column_indexes = {}
              @columns.each_with_index do |column, index|
                next if column.id.nil? || column.id.to_s.empty?
                @column_indexes[column.id.to_s] = index
              end
            end

            def initialize_rows(row_schemas)
              @rows = row_schemas.map { |schema| Table::RowFormat.new(schema) }
            end
          end
        end
      end
    end
  end
end
