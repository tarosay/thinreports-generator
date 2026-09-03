# frozen_string_literal: true

module Thinreports
  module BasicReport
    module Core
      module Shape
        module Table
          class Internal < Basic::Internal
            # @return [Array<Thinreports::SectionReport::Builder::TableData::Row>]
            attr_accessor :rows

            def initialize(parent, format)
              super
              @rows = []
            end

            def type_of?(type_name)
              type_name == Table::TYPE_NAME
            end
          end
        end
      end
    end
  end
end
