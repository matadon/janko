require "agrippa/mutable_hash"
require "agrippa/delegation"
require "janko/connection"
require "janko/column_list"
require "janko/single_merge"
require "janko/bulk_merge"

module Janko
    class Merge
        include Agrippa::MutableHash

        include Agrippa::Delegation

        state_writer :table, :locking, :transaction, :collector

        state_reader :table, :connection

        delegate :exec, to: "connection"

        delegate :result, to: "delegate"

        def default_state
            { strategy: Janko::BulkMerge, connection: Connection.default }
        end

        def connect(connection)
            @state[:connection] = Connection.build(connection)
            self
        end

        def use(strategy)
            @state[:strategy] = strategy
            self
        end

        def returning(returning)
            returning = returning.to_s
            raise("Merge can return inserted, updated, all, or none.") \
                unless %w(inserted updated all none).include?(returning)
            chain(returning: returning)
        end

        def key(*list)
            preserve_state_if_started
            columns.tag("key", *list)
            self
        end

        def update(*list)
            preserve_state_if_started
            columns.tag("update", *list)
            self
        end

        def insert(*list)
            preserve_state_if_started
            columns.tag("insert", *list)
            self
        end

        def select(*list)
            preserve_state_if_started
            columns.tag("select", *list)
            self
        end

        def alter(*list, &block)
            preserve_state_if_started
            columns.alter(*list, &block)
            self
        end

        def start
            @state[:started] = true
            reset_delegate
            begin_transaction and lock_table
            rollback_on_error { delegate.start }
            self
        end

        def push(*args)
            raise("Call #start before #push") unless @state[:started]
            rollback_on_error { delegate.push(*args) }
            self
        end

        def stop
            raise("Call #start before #stop") unless @state[:started]
            rollback_on_error { delegate.stop }
            @state[:started] = false
            self
        end

        def columns
            @state[:columns] ||= begin
                raise("Connect before setting merge parameters.") \
                    unless connected?
                default_column_list
            end
        end

        private

        def connected?
            @state.has_key?(:connection)
        end

        def default_column_list
            ColumnList.new(parent: self)
                .tag(:key, :id)
                .tag(:select, Janko::ALL)
                .tag(:insert, Janko::ALL).untag(:insert, :id)
                .tag(:update, Janko::ALL).untag(:update, :id)
        end

        def rollback_on_error
            begin
                yield
            rescue
                raise
            ensure
                commit_or_rollback_transaction
            end
        end

        def begin_transaction
            return(self) if connection.in_transaction?
            return(self) if (@state[:transaction] == false)
            @state[:our_transaction] == true
            exec("BEGIN")
            self
        end

        def commit_or_rollback_transaction
            return(self) unless connection.in_transaction?
            return(self) unless @state.delete(:our_transaction)
            exec(connection.failed? ? "ROLLBACK" : "COMMIT")
            self
        end

        def lock_table
            return(self) unless connection.in_transaction?
            return(self) if (@state[:locking] == false)
            exec("LOCK TABLE #{table} IN SHARE ROW EXCLUSIVE MODE;")
            self
        end

        def preserve_state_if_started
            return(self) unless @state[:started]
            raise("Call #stop before changing import options.")
        end

        def delegate
            @delegate ||= begin
                strategy_class = @state[:strategy]
                strategy_class || raise("Set strategy before merging.")
                strategy_class.new(@state.slice(:connection, :table, 
                    :returning, :collector).merge(columns: columns))
            end
        end

        def reset_delegate
            @delegate = nil
            self
        end
    end
end
