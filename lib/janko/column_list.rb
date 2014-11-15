require "janko/tagged_column"
require "janko/constants"
require "agrippa/mutable_hash"

module Janko
    class ColumnList
        include Enumerable

        include Agrippa::MutableHash

        def ColumnList.build(source)
            source.is_a?(ColumnList) ? source : ColumnList.new.add(*source)
        end

        def default_state
            { columns: {} }
        end

        def builder
            self
        end

        def add(*names)
            each_column(names) { |name| add_column(name) }
        end

        def remove(*names)
            each_column(names) { |name| remove_column(name) }
        end

        def tag(tag, *names)
            each { |_, column| column.untag(tag) }
            each_column(names) { |name| add_column(name).tag(tag) }
        end

        def untag(tag, *names)
            each_column(names) { |_, column| column and column.untag(tag) }
        end

        def tagged(tag = nil)
            filter_columns do |name, column|
                (tag.nil? and column.tagged?) or column.has_tag?(tag)
            end
        end

        def not_tagged(tag)
            filter_columns { |name, column| not column.has_tag?(tag) }
        end

        def none_tagged?(tag)
            @state[:columns].none? { |_, column| column.has_tag?(tag) }
        end

        def alter(*names)
            each_column(names) do |name, column|
                raise("Unknown column: #{name}") unless column
                yield(column)
            end
        end

        def set(state)
            chain(state)
        end

        def pack(values)
            pack_hash(stringify_keys(values))
        end

        def to_list
            map_and_join { |_, column| column.quoted }
        end

        def to_conditions(left = nil, right = nil)
            map_and_join(" AND ") { |_, c| c.to_condition(left, right) }
        end

        def to_setters(left = nil, right = nil)
            map_and_join { |_, c| c.to_setter(left, right) }
        end

        def to_list_with_defaults
            map_and_join { |_, c| c.to_value }
        end

        def to_binds
            map_and_join_with_index { |_, c, i| c.to_bind(i + 1) }
        end

        def to_typecast_binds
            map_and_join_with_index { |_, c, i| c.to_typecast_bind(i + 1) }
        end

        def each(&block)
            @state[:columns].each(&block)
        end

        def map(&block)
            @state[:columns].map(&block)
        end

        def map_and_join(separator = ",", &block)
            map(&block).join(separator)
        end

        def map_and_join_with_index(separator = ",")
            output = each_with_index.map { |pair, index| yield(*pair, index) }
            output.join(separator)
        end

        def empty?
            @state[:columns].empty?
        end

        def columns
            @state[:columns].keys
        end

        def connection
            @state[:parent].connection
        end

        def table
            @state[:parent].table
        end

        def inspect
            children = @state[:columns].map { |name, column|
                "#{name}(#{column.inspect})" }
            "#<#{self.class}:0x#{self.__id__.to_s(16)} #{children.join(" ")}>"
        end

        def length
            @length ||= @state[:columns].length
        end

        def pack_hash(values)
            result = columns.map { |column| values.delete(column) }
            return(result) if values.empty?
            raise(ArgumentError, "Unknown columns: #{values.keys.join(" ")}")
        end

        private

        def add_column(name)
            @state[:columns][name.to_s] ||= TaggedColumn.new(name: name,
                parent: self)
        end

        def remove_column(name)
            @state[:columns].delete(name.to_s)
            self
        end

        def filter_columns
            result = {}
            each { |n, c| result[n] = c if yield(n, c) }
            self.class.new(@state.merge(columns: result))
        end

        def stringify_keys(hash)
            output = {}
            hash.each { |k, v| output[k.to_s] = v }
            output
        end

        def matching_names(names)
            result = []
            names.flatten.each do |name|
                if(name == Janko::ALL)
                    result.concat(connection.column_list(table))
                elsif(name == Janko::DEFAULT)
                    result.concat(connection.column_list(table) - [ "id" ])
                elsif(name.is_a?(Hash) and name.has_key?(:except))
                    all_columns = connection.column_list(table)
                    exceptions = [ name[:except] ].flatten.map(&:to_s)
                    result.concat(all_columns - exceptions)
                elsif(name.nil? or name == "")
                    raise("Blank or nil column names are not allowed.")
                else
                    result.push(name.to_s)
                end
            end
            result
        end
 
        def each_column(names)
            matching_names(names).each do |name|
                yield(name, @state[:columns][name.to_s])
            end
            self
        end
    end
end
