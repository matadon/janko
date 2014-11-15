module Janko
    class Flag
        attr_reader :value

        def initialize(value)
            @value = value
        end

        def |(other)
            self.class.new(value | other.value)
        end

        def eql?(other)
            return unless other.is_a?(self.class)
            (value & other.value) != 0
        end

        def ==(other)
            eql?(other)
        end

        def ===(other)
            eql?(other)
        end
    end
end
