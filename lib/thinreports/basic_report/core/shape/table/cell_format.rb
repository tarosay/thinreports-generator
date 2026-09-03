# frozen_string_literal: true

module Thinreports
  module BasicReport
    module Core
      module Shape
        module Table
          class CellFormat < Core::Format::Base
            # [top, right, bottom, left]
            DEFAULT_PADDING = [0, 2, 0, 2].freeze

            config_reader column_id: %w[column-id]
            config_reader :content

            def display?
              attributes.fetch('display', true) != false
            end

            # @return [Integer] Number of columns which this cell spans over.
            def col_span
              positive_span(attributes['col-span'])
            end

            # @return [Integer] Number of rows which this cell spans over.
            def row_span
              positive_span(attributes['row-span'])
            end

            # @return [Hash]
            def style
              attributes['style'] || {}
            end

            # @return [Array<Numeric>] [top, right, bottom, left]
            def padding
              value = style['padding']
              return DEFAULT_PADDING unless value

              case value
              when ::Array
                case value.size
                when 4 then value.map(&:to_f)
                when 2 then [value[0].to_f, value[1].to_f, value[0].to_f, value[1].to_f]
                when 1 then ::Array.new(4, value[0].to_f)
                else DEFAULT_PADDING
                end
              when ::Numeric then ::Array.new(4, value.to_f)
              else DEFAULT_PADDING
              end
            end

            # @return [String, nil]
            def background_color
              style['background-color']
            end

            # @return [String, nil] 'none', 'horizontal', 'vertical', 'grid',
            #   'forward-diagonal', 'backward-diagonal' or 'cross-diagonal'
            def background_pattern
              style['background-pattern']
            end

            # @return [Hash]
            def background_pattern_options
              {
                pattern: background_pattern,
                color: style['background-pattern-color'],
                spacing: style['background-pattern-spacing'],
                width: style['background-pattern-width']
              }
            end

            # Returns the border settings of the given side.
            #
            # * nil    - inherits the default border of the table
            # * 'none' - draws no border
            # * Hash   - { 'width' => 0.5, 'color' => '#000000', 'style' => 'solid' }
            #
            # @param [:top, :right, :bottom, :left] side
            # @return [Hash, String, nil]
            def border(side)
              style["border-#{side}"]
            end

            private

            def positive_span(value)
              span = value.to_i
              span < 1 ? 1 : span
            end
          end
        end
      end
    end
  end
end
