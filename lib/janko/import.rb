require "agrippa/mutable_hash"
require "janko/connection"
require "janko/column_list"
require "janko/copy_importer"
require "janko/insert_importer"
require "janko/constants"

# http://starfighter.ngrok.io/

# delegate :start, :stop, :push, to: :delegate
# set(table:, columns:)
#
# connect(connection)
# builder => self

module Janko
    class Import
        include Agrippa::MutableHash

        state_reader :connection

        state_writer :table, prefix: false

        def default_state
            { columns: Janko::ALL, importer: Janko::CopyImporter }
        end

        def connect(connection)
            @state[:connection] = Connection.build(connection)
            self
        end

        def use(importer)
            @state[:importer] = importer
            self
        end

        def columns(*columns)
            @state[:columns] = columns.flatten
            self
        end

        def start
            @state[:started] = true
            delegate.start
            self
        end

        def push(values)
            raise("Call #start before #push") unless @state[:started]
            delegate.push(values)
            self
        end

        def stop
            raise("Call #start before #stop") unless @state[:started]
            delegate.stop
            @state[:started] = false
            self
        end

        private

        def preserve_state_if_started
            return(self) unless @state[:started]
            raise("Call #stop before changing import options.")
        end

        def delegate
            @delegate ||= @state[:importer].new(delegate_options)
        end

        def delegate_options
            raise("No table specified.") unless @state[:table]
            column_list = ColumnList.build(@state[:columns])
            raise("No columns specified.") if column_list.empty?
            @state.merge(columns: column_list)
        end
    end
end
