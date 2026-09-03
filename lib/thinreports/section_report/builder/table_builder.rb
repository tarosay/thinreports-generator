# frozen_string_literal: true

require_relative 'table_data'

module Thinreports
  module SectionReport
    module Builder
      class TableBuilder
        Context = Struct.new(:row_schema, :cell_schema)

        def initialize(item)
          @item = item
        end

        # @param [Hash] params Parameters of the table item.
        # @option params [Array<Hash>] :rows
        def update(params)
          schema_rows = item.internal.format.rows.select(&:display?)
          rows_params = params[:rows]

          item.internal.rows =
            if rows_params.nil?
              schema_rows.map { |row_schema| build_row(row_schema, {}) }
            else
              build_rows(schema_rows, rows_params)
            end
        end

        private

        attr_reader :item

        # Header and footer rows are always rendered once, in the order they are
        # defined in the schema. Body rows are rendered as many times as they are
        # given in the :rows parameter.
        #
        # A parameter which refers to a header or a footer row is not rendered as
        # an additional row: it gives the values of that row instead.
        def build_rows(schema_rows, rows_params)
          body_params = []
          params_by_row_id = {}

          rows_params.each do |row_params|
            row_params = { id: row_params } unless row_params.is_a?(::Hash)
            row_schema = find_row_schema(schema_rows, row_params[:id])
            next unless row_schema

            if row_schema.body?
              body_params << [row_schema, row_params]
            else
              params_by_row_id[row_schema.id.to_s] = row_params
            end
          end

          rows = schema_rows.select(&:header?).map do |row_schema|
            build_row(row_schema, params_by_row_id[row_schema.id.to_s] || {})
          end

          body_params.each { |(row_schema, row_params)| rows << build_row(row_schema, row_params) }

          rows + schema_rows.select(&:footer?).map do |row_schema|
            build_row(row_schema, params_by_row_id[row_schema.id.to_s] || {})
          end
        end

        def find_row_schema(schema_rows, id)
          if id.nil?
            schema_rows.find(&:body?)
          else
            schema_rows.find { |row_schema| row_schema.id.to_s == id.to_s }
          end
        end

        def build_row(row_schema, row_params)
          cells_params = row_params[:cells] || {}

          cells = row_schema.cells.each_with_object([]) do |cell_schema, built|
            next unless cell_schema.display?

            cell = build_cell(row_schema, cell_schema, cell_params_for(cell_schema, cells_params))
            built << cell if cell
          end

          TableData::Row.new(row_schema, cells)
        end

        # A cell parameter can be specified by the id of its content,
        # or by the id of the column which the cell belongs to.
        def cell_params_for(cell_schema, cells_params)
          content_id = cell_schema.content && cell_schema.content['id']

          if !blank?(content_id) && cells_params.key?(content_id.to_sym)
            cells_params[content_id.to_sym]
          else
            cells_params[cell_schema.column_id.to_s.to_sym]
          end
        end

        def build_cell(row_schema, cell_schema, cell_params)
          params = build_params(cell_params, row_schema, cell_schema)
          return nil if params.key?(:display) && !params[:display]

          TableData::Cell.new(
            cell_schema,
            build_content(cell_schema, params),
            params.fetch(:background_color) { cell_schema.background_color },
            build_background_pattern(cell_schema, params)
          )
        end

        def build_params(params, row_schema, cell_schema)
          case params
          when nil then {}
          when ::Hash then params
          when ::Proc then params.call(Context.new(row_schema, cell_schema))
          else { value: params }
          end
        end

        def build_background_pattern(cell_schema, params)
          options = cell_schema.background_pattern_options
          options[:pattern] = params[:background_pattern] if params.key?(:background_pattern)
          options
        end

        def build_content(cell_schema, params)
          content_schema = cell_schema.content
          return nil if content_schema.nil?

          schema = deep_dup(content_schema)
          format = Core::Shape::Format(schema['type']).new(schema)
          content = Core::Shape::Interface(nil, format)

          content.value(params[:value]) if params.key?(:value) && content.respond_to?(:value)
          content.styles(params[:styles]) if params[:styles]
          content
        end

        def deep_dup(schema)
          ::Marshal.load(::Marshal.dump(schema))
        end

        def blank?(value)
          value.nil? || value.to_s.empty?
        end
      end
    end
  end
end
