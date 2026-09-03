# frozen_string_literal: true

module Thinreports
  module BasicReport
    module Core
      module Shape
        module Table
          class RowFormat < Core::Format::Base
            TYPES = %w[header body footer].freeze

            config_reader :id
            config_checker true, auto_stretch: 'auto-stretch'

            attr_reader :cells

            def initialize(*)
              super
              initialize_cells(attributes['cells'] || [])
            end

            def height
              attributes['height'].to_f
            end

            def display?
              attributes.fetch('display', true) != false
            end

            # @return [String] 'header', 'body' or 'footer'
            def type
              type = attributes['type']
              TYPES.include?(type) ? type : 'body'
            end

            def header?
              type == 'header'
            end

            def body?
              type == 'body'
            end

            def footer?
              type == 'footer'
            end

            def find_cell(column_id)
              @cell_with_column_ids[column_id.to_s]
            end

            private

            def initialize_cells(cell_schemas)
              @cells = cell_schemas.map { |cell_schema| Table::CellFormat.new(cell_schema) }
              @cell_with_column_ids = @cells.each_with_object({}) do |cell, cells|
                next if blank_column_id?(cell)
                cells[cell.column_id.to_s] = cell
              end
            end

            def blank_column_id?(cell)
              cell.column_id.nil? || cell.column_id.to_s.empty?
            end
          end
        end
      end
    end
  end
end
