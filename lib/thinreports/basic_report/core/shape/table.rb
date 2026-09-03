# frozen_string_literal: true

module Thinreports
  module BasicReport
    module Core
      module Shape
        module Table
          TYPE_NAME = 'table'.freeze

          # Sides of a cell border, in drawing order.
          BORDER_SIDES = %i[top right bottom left].freeze
        end
      end
    end
  end
end

require_relative 'table/column_format'
require_relative 'table/cell_format'
require_relative 'table/row_format'
require_relative 'table/format'
require_relative 'table/interface'
require_relative 'table/internal'
