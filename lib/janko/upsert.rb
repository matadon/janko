require "securerandom"
require "agrippa/mutable"

module Janko
    # http://dba.stackexchange.com/questions/13468/most-idiomatic-way-to-implement-upsert-in-postgresql-nowadays
    # http://stackoverflow.com/questions/1109061/insert-on-duplicate-update-in-postgresql/8702291#8702291
    # http://stackoverflow.com/questions/17575489/postgresql-cte-upsert-returning-modified-rows
    class Upsert
        include Agrippa::Mutable

        state_reader :connection, :table, :columns, :collector, :returning

        def default_state
            { collector: MergeResult.new }
        end

        def result
            collector
        end

        def prepare
            return(self) if prepared?
            @prepared = "upsert_#{SecureRandom.hex(8)}"
            connection.prepare(@prepared, query)
            self
        end

        def push(*values)
            raise(RuntimeError, "Can't #push when reading from a table.") \
                if read_from_table?
            collect_result(exec_query(columns.pack(*values)))
            self
        end

        def process
            raise(RuntimeError, "Can't #process without from_table") \
                unless read_from_table?
            result.clear
            collect_result(exec_query)
            self
        end

        def cleanup
            return unless prepared?
            connection.exec("DEALLOCATE \"#{@prepared}\"")
            @prepared = nil
            self
        end

        private

        def result_type_column
            "__type"
        end

        def collect_result(tuples)
            return(self) if (tuples.count == 0)
            tuples.each { |t| result.push(t.delete(result_type_column), t) }
        end

        def read_from_table?
            not @from_table.nil?
        end

        def prepared?
            not @prepared.nil?
        end

        def exec_query(*binds)
            return(connection.exec(query, *binds)) unless prepared?
            connection.exec_prepared(@prepared, *binds)
        end

        def key_columns
            @key_columns ||= columns.tagged(:key)
        end

        def update_columns
            @update_columns ||= columns.tagged(:update).not_tagged(:key)
        end

        def insert_columns
            @insert_columns ||= columns.tagged(:insert)
        end

        def select_columns
            @select_columns ||= columns.tagged(:select)
        end

        def insert_columns_with_defaults
            insert_columns.to_list_with_defaults
        end

        def columns_to_binds_with_types
            columns.to_typecast_binds
        end

        def update_clause
            update_columns.to_setters("upsert_updates", source_table)
        end

        def update_key_clause
            key_columns.to_conditions("upsert_updates", source_table)
        end

        def insert_key_clause
            key_columns.to_conditions("upsert", source_table)
        end

        def query
            return(query_returning_nothing) if select_columns.empty?
            return(query_returning_all) if (returning == "all")
            return(query_returning_inserts) if (returning == "inserted")
            return(query_returning_updates) if (returning == "updated")
            query_returning_nothing
        end

        def source_table
            @from_table || "upsert_data"
        end

        def source_fragment
            return if read_from_table?
            return(<<-END)
                #{source_table} (#{columns.to_list}) AS (VALUES
                    (#{columns_to_binds_with_types})),
            END
        end

        def upsert_fragment
            return(<<-END)
                UPDATE #{table} upsert_updates
                SET #{update_clause} FROM #{source_table}
                WHERE (#{update_key_clause})
                RETURNING upsert_updates.*
            END
        end

        def insert_fragment
            return(<<-END)
                INSERT INTO #{table} (#{insert_columns.to_list})
                SELECT #{insert_columns_with_defaults} FROM #{source_table}
                WHERE NOT EXISTS (SELECT 1 FROM upsert
                    WHERE #{insert_key_clause})
            END
        end

        def query_returning_nothing
            return(<<-END)
                WITH #{source_fragment} upsert AS (#{upsert_fragment})
                #{insert_fragment}
            END
        end

        def query_with_returnable_tuples
            return(<<-END)
                WITH #{source_fragment} upsert AS (#{upsert_fragment}), 
                inserted AS (#{insert_fragment} RETURNING #{table}.*)
            END
        end

        def query_returning_inserts
            return(<<-END)
                #{query_with_returnable_tuples}
                SELECT 'inserted'
                    AS #{result_type_column}, #{select_columns.to_list}
                    FROM inserted
            END
        end

        def query_returning_updates
            return(<<-END)
                #{query_with_returnable_tuples}
                SELECT 'updated'
                    AS #{result_type_column}, #{select_columns.to_list}
                    FROM upsert
            END
        end

        def query_returning_all
            return(<<-END)
                #{query_with_returnable_tuples}
                SELECT 'inserted'
                    AS #{result_type_column}, #{select_columns.to_list}
                    FROM inserted
                UNION ALL
                SELECT 'updated'
                    AS #{result_type_column}, #{select_columns.to_list}
                    FROM upsert
            END
        end
    end
end
