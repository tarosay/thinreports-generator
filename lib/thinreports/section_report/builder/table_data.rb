# frozen_string_literal: true

module Thinreports
  module SectionReport
    module Builder
      module TableData
        Row = Struct.new :schema, :cells
        Cell = Struct.new :schema, :content, :background_color, :background_pattern
      end
    end
  end
end
