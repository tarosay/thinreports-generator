# frozen_string_literal: true

module Thinreports
  module SectionReport
    module Renderer
      class TableRenderer
        RowLayout = Struct.new(:row, :height, :top)

        def initialize(pdf)
          @pdf = pdf
        end

        # Total height of the table after all rows are stretched.
        # @param [Thinreports::BasicReport::Core::Shape::Table::Internal] shape
        # @return [Numeric]
        def section_height(shape)
          row_layouts(shape).sum(0.0, &:height)
        end

        # @param [Thinreports::BasicReport::Core::Shape::Table::Internal] shape
        def render(shape)
          doc = pdf.pdf
          format = shape.format
          layouts = row_layouts(shape)
          return if layouts.empty?

          x, y = format.attributes.values_at('x', 'y')
          width = format.total_width

          doc.bounding_box([x, doc.bounds.height - y], width: width, height: section_height(shape)) do
            layouts.each_with_index do |layout, row_index|
              doc.bounding_box([0, doc.cursor], width: width, height: layout.height) do
                render_row(shape, layouts, row_index)
              end
            end
          end
        end

        private

        attr_reader :pdf

        def render_row(shape, layouts, row_index)
          format = shape.format

          layouts[row_index].row.cells.each do |cell|
            column_index = format.find_column_index(cell.schema.column_id)
            next unless column_index

            draw_cell(
              format,
              cell,
              format.column_offsets[column_index],
              0,
              format.span_width(column_index, cell.schema.col_span),
              spanned_height(layouts, row_index, cell.schema.row_span)
            )
          end
        end

        def spanned_height(layouts, row_index, row_span)
          layouts[row_index, row_span].to_a.sum(0.0, &:height)
        end

        def draw_cell(table_format, cell, x, y, w, h)
          draw_cell_background(cell, x, y, w, h)
          draw_cell_borders(table_format, cell, x, y, w, h)
          draw_cell_content(cell, x, y, w, h)
        end

        def draw_cell_background(cell, x, y, w, h)
          color = cell.background_color
          pdf.rect(x, y, w, h, fill: color, stroke: 'none') if color && color != 'none'

          pattern = cell.background_pattern
          return unless pattern && pattern[:pattern] && pattern[:pattern] != 'none'

          pdf.hatch(x, y, w, h, pattern)
        end

        def draw_cell_borders(table_format, cell, x, y, w, h)
          Core::Shape::Table::BORDER_SIDES.each do |side|
            border = resolve_border(table_format, cell, side)
            next unless border

            x1, y1, x2, y2 =
              case side
              when :top then [x, y, x + w, y]
              when :bottom then [x, y + h, x + w, y + h]
              when :left then [x, y, x, y + h]
              when :right then [x + w, y, x + w, y + h]
              end

            pdf.line(
              x1, y1, x2, y2,
              stroke: border['color'],
              stroke_width: border['width'],
              stroke_type: border['style'] || 'solid'
            )
          end
        end

        def resolve_border(table_format, cell, side)
          value = cell.schema.border(side)
          return nil if value == 'none'

          border =
            if value.is_a?(::Hash)
              base = table_format.default_border || Core::Shape::Table::Format::DEFAULT_BORDER
              base.merge(value)
            else
              table_format.default_border
            end

          return nil if border.nil?
          return nil unless border['width'].to_f > 0
          return nil if border['color'].nil? || border['color'] == 'none'

          border
        end

        def draw_cell_content(cell, x, y, w, h)
          content = cell.content
          return unless content

          padding = cell.schema.padding
          shape = content.internal
          attributes = shape.format.attributes

          attributes['x'] = x + padding[3]
          attributes['y'] = y + padding[0]
          attributes['width'] = [w - padding[1] - padding[3], 0].max
          attributes['height'] = [h - padding[0] - padding[2], 0].max

          draw_content_shape(shape, attributes['height'])
        end

        def draw_content_shape(shape, height)
          if shape.type_of?(Core::Shape::TextBlock::TYPE_NAME)
            if shape.style.finalized_styles['overflow'] == 'expand'
              # See SectionReport::Renderer::DrawItem#draw_item for the reason
              # why the overflow attribute is overwritten here.
              pdf.draw_shape_tblock(
                shape,
                height: [height, calc_text_block_height(shape)].max,
                overflow: :truncate
              )
            else
              pdf.draw_shape_tblock(shape, height: height)
            end
          elsif shape.type_of?(Core::Shape::ImageBlock::TYPE_NAME)
            pdf.draw_shape_iblock(shape)
          elsif shape.type_of?('text')
            pdf.draw_shape_text(shape)
          elsif shape.type_of?('image')
            pdf.draw_shape_image(shape)
          else
            raise Thinreports::BasicReport::Errors::UnknownShapeType
          end
        end

        def row_layouts(shape)
          shape.states[:table_row_layouts] ||= build_row_layouts(shape)
        end

        def build_row_layouts(shape)
          prepare_contents(shape)

          layouts = shape.rows.map { |row| RowLayout.new(row, row_height(row)) }
          layouts.inject(0.0) do |top, layout|
            layout.top = top
            top + layout.height
          end
          layouts
        end

        # The width of a cell does not depend on the height of any row,
        # so it can be fixed before the heights of rows are calculated.
        def prepare_contents(shape)
          format = shape.format

          shape.rows.each do |row|
            row.cells.each do |cell|
              next unless cell.content

              column_index = format.find_column_index(cell.schema.column_id)
              next unless column_index

              padding = cell.schema.padding
              width = format.span_width(column_index, cell.schema.col_span)

              attributes = cell.content.internal.format.attributes
              attributes['x'] = 0
              attributes['y'] = 0
              attributes['width'] = [width - padding[1] - padding[3], 0].max
              attributes['height'] ||= 0
            end
          end
        end

        def row_height(row)
          base = row.schema.height
          return base unless row.schema.auto_stretch?

          # A cell which spans over multiple rows does not stretch its own row.
          content_height = row.cells
                              .reject { |cell| cell.schema.row_span > 1 }
                              .map { |cell| cell_content_height(cell) }
                              .max.to_f

          [base, content_height].max
        end

        def cell_content_height(cell)
          content = cell.content
          return 0.0 unless content

          shape = content.internal
          return 0.0 unless shape.type_of?(Core::Shape::TextBlock::TYPE_NAME)
          return 0.0 unless shape.style.finalized_styles['overflow'] == 'expand'

          padding = cell.schema.padding
          calc_text_block_height(shape) + padding[0] + padding[2]
        end

        def calc_text_block_height(shape)
          height = 0

          pdf.draw_shape_tblock(shape) do |array, options|
            height = pdf.pdf.height_of_formatted(array, options.merge(at: [0, 10_000], height: 10_000))
          end
          height
        end
      end
    end
  end
end
