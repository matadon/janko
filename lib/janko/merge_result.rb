module Janko
    class MergeResult
        include Enumerable

        attr_reader :count

        def initialize
            @tuples = Hash.new { |h, k| h[k] = [] }
            @count = 0
        end

        def push(tag, tuple)
            @tuples[tag.to_s].push(tuple)
            @count += 1
            self
        end

        def inserted
            @tuples["inserted"]
        end

        def updated
            @tuples["updated"]
        end

        def clear
            @tuples.clear
            self
        end

        def each(&block)
            inserted.each(&block)
            updated.each(&block)
            self
        end
    end
end
