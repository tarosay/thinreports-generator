# frozen_string_literal: true

module Thinreports
  module BasicReport
    module Core
      module Shape
        module Table
          class ColumnFormat < Core::Format::Base
            config_reader :id

            def width
              attributes['width'].to_f
            end
          end
        end
      end
    end
  end
end
