# frozen_string_literal: true

module Thinreports
  module BasicReport
    module Generator
      class PDF
        module Graphics
          DEFAULT_HATCH_SPACING = 4.0
          DEFAULT_HATCH_WIDTH = 0.5
          DEFAULT_HATCH_COLOR = '#000000'

          HATCH_PATTERNS = %w[
            horizontal
            vertical
            grid
            forward-diagonal
            backward-diagonal
            cross-diagonal
          ].freeze

          # Fills the given rectangle with a line pattern.
          #
          # PDF tiling patterns are not supported by Prawn, so the pattern is
          # emulated by drawing each line clipped to the rectangle.
          #
          # @param [Numeric, String] x
          # @param [Numeric, String] y
          # @param [Numeric, String] w
          # @param [Numeric, String] h
          # @param [Hash] attrs
          # @option attrs [String] :pattern one of HATCH_PATTERNS
          # @option attrs [String] :color ('#000000')
          # @option attrs [Numeric] :spacing (4.0) Distance between lines.
          # @option attrs [Numeric] :width (0.5) Width of lines.
          def hatch(x, y, w, h, attrs = {})
            pattern = attrs[:pattern].to_s
            return unless HATCH_PATTERNS.include?(pattern)

            color = attrs[:color] || DEFAULT_HATCH_COLOR
            return if color == 'none'

            spacing = to_positive_float(attrs[:spacing], DEFAULT_HATCH_SPACING)
            width = to_positive_float(attrs[:width], DEFAULT_HATCH_WIDTH)

            x, y, w, h = s2f(x, y, w, h)
            return if w <= 0 || h <= 0

            segments = hatch_segments(pattern, x, y, w, h, spacing)
            return if segments.empty?

            save_graphics_state
            pdf.stroke_color(parse_color(color))
            line_width(width)
            segments.each { |x1, y1, x2, y2| pdf.stroke_line(pos(x1, y1), pos(x2, y2)) }
            restore_graphics_state
          end

          private

          def to_positive_float(value, default)
            value = value.to_f unless value.nil?
            value.nil? || value <= 0 ? default : value
          end

          # @return [Array<Array<Numeric>>] [[x1, y1, x2, y2], ...]
          def hatch_segments(pattern, x, y, w, h, spacing)
            case pattern
            when 'horizontal' then horizontal_hatch_segments(x, y, w, h, spacing)
            when 'vertical' then vertical_hatch_segments(x, y, w, h, spacing)
            when 'grid'
              horizontal_hatch_segments(x, y, w, h, spacing) +
                vertical_hatch_segments(x, y, w, h, spacing)
            when 'forward-diagonal' then forward_hatch_segments(x, y, w, h, spacing)
            when 'backward-diagonal' then backward_hatch_segments(x, y, w, h, spacing)
            when 'cross-diagonal'
              forward_hatch_segments(x, y, w, h, spacing) +
                backward_hatch_segments(x, y, w, h, spacing)
            else []
            end
          end

          def horizontal_hatch_segments(x, y, w, h, spacing)
            segments = []
            offset = spacing
            while offset < h
              segments << [x, y + offset, x + w, y + offset]
              offset += spacing
            end
            segments
          end

          def vertical_hatch_segments(x, y, w, h, spacing)
            segments = []
            offset = spacing
            while offset < w
              segments << [x + offset, y, x + offset, y + h]
              offset += spacing
            end
            segments
          end

          # Lines of "/" direction. Each line satisfies (px + py) == c.
          def forward_hatch_segments(x, y, w, h, spacing)
            step = spacing * Math.sqrt(2)
            segments = []

            c = x + y + step
            c_max = x + w + y + h
            while c < c_max
              x1 = [x, c - (y + h)].max
              x2 = [x + w, c - y].min
              segments << [x1, c - x1, x2, c - x2] if x2 > x1
              c += step
            end
            segments
          end

          # Lines of "\\" direction. Each line satisfies (py - px) == d.
          def backward_hatch_segments(x, y, w, h, spacing)
            step = spacing * Math.sqrt(2)
            segments = []

            d = y - (x + w) + step
            d_max = y + h - x
            while d < d_max
              x1 = [x, y - d].max
              x2 = [x + w, y + h - d].min
              segments << [x1, x1 + d, x2, x2 + d] if x2 > x1
              d += step
            end
            segments
          end
        end
      end
    end
  end
end
