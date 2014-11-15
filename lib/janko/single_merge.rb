require "janko/merge_result"
require "janko/upsert"

module Janko
    class SingleMerge
        attr_reader :upsert

        def initialize(options = {})
            @upsert = Upsert.new(options)
            @options = options
        end

        def start
            upsert.result.clear
            upsert.prepare if @options[:use_prepared_query]
            self
        end

        def push(*values)
            upsert.push(*values)
            self
        end

        def stop
            upsert.cleanup
            self
        end

        def result
            upsert.result
        end
    end
end
