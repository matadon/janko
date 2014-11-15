require "janko/flag"

module Janko
    module Constants
        NULL = nil

        DEFAULT = Flag.new(2 ** 0)

        ALL = Flag.new(2 ** 1)

        KEEP = Flag.new(2 ** 2)
    end
end
