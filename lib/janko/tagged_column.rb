require "janko/constants"
require "agrippa/state"
require "agrippa/mutable"
require "agrippa/delegation"

module Janko
    include Constants

    class TaggedColumn
        include Agrippa::Delegation

        include Agrippa::Mutable

        state_reader :tags, :name, :parent

        state_writer :wrap, :default, :on_update, prefix: false

        delegate :table, :connection, to: :parent

        def default_state
            { tags: {} }
        end

        def set(updates)
            chain(updates)
        end

        def tag(tag)
            tag = tag.to_s
            tags.merge!(tag => true) unless (tag == "")
            self
        end

        def untag(tag)
            tag = tag.to_s
            tags.reject! { |k| k == tag } unless (tag == "")
            self
        end

        def has_tag?(tag)
            tags.has_key?(tag.to_s)
        end

        def tagged?
            not tags.empty?
        end

        def to_s
            tags.keys.join(" ")
        end

        def type
            connection.column_type(table, name)
        end

        # FIXME: Quoting
        def quoted(prefix = nil)
            prefix.nil? ? "\"#{name}\"" : "\"#{prefix}\".\"#{name}\""
        end

        def to_condition(left, right)
            "#{quoted(left)} = #{quoted(right)}"
        end

        def to_setter(left, right)
            "#{quoted} = #{maybe_on_update(left, right)}"
        end

        def to_value(prefix = nil)
            maybe_wrap(nil, prefix)
        end

        def to_bind(position)
            "$#{position}"
        end

        def to_typecast_bind(position)
            "$#{position}::#{type}"
        end

        def inspect
            children = "(#{tags.keys.join(" ")})"
            "#<#{self.class}:0x#{self.__id__.to_s(16)} #{name}#{children}>"
        end

        private

        def maybe_wrap(left, right)
            inner = maybe_default(left, right)
            return(inner) unless @wrap
            @wrap.gsub(/\$NEW/i) { inner }
        end

        def maybe_on_update(left, right)
            inner = maybe_wrap(left, right)
            return(inner) unless @on_update
            output = Agrippa::State.new(@on_update, :gsub)
            output.gsub(/\$NEW/i) { inner }
            output.gsub(/\$OLD/i) { quoted(left) }
            output._value
        end

        def maybe_default(left, right)
            values = [ quoted(right) ]
            values.push(keep_existing_value(left))
            values.push(column_default_value)
            values.compact!
            return(values.first) if (values.length == 1)
            "COALESCE(#{values.join(", ")})"
        end

        def keep_existing_value(prefix)
            return if prefix.nil?
            return unless (value = @default)
            return unless (value == Janko::KEEP)
            quoted(prefix)
        end

        def column_default_value
            @column_default_value ||= begin
                return unless (value = @default)
                return(value) unless value.is_a?(Flag)
                return unless (value == Janko::DEFAULT)
                connection.column_default(table, name)
            end
        end

        def flagged(value, flag)
            return(false) unless value.is_a?(Fixnum)
            (value & flag) == value
        end
    end
end
