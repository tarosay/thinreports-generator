# frozen_string_literal: true

module Thinreports
  module BasicReport
    module Core
      module Shape
        module Table
          class Interface < Basic::Interface
            private

            def init_internal(parent, format)
              Table::Internal.new(parent, format)
            end
          end
        end
      end
    end
  end
end
