require "agrippa/maybe"
require "agrippa/delegation"

module Janko
    class Connection
        include Agrippa::Delegation

        def Connection.build(backend)
            return(default) if backend.nil?
            return(backend) if backend.is_a?(Connection)
            new(backend)
        end

        def Connection.default
            if Kernel.const_defined?("ActiveRecord::Base")
                new(Kernel.const_get("ActiveRecord::Base"))
            else
                raise("No default connection available.")
            end
        end

        def Connection.cache_catalog
            @catalog ||= yield
        end

        def Connection.reset_cached_catalog
            @catalog = nil
            self
        end

        attr_reader :backend

        delegate *%w(exec prepare exec_prepared async_exec put_copy_data
            put_copy_end get_last_result), to: "backend"

        def initialize(backend)
            @backend = extract_raw_connection(backend)
        end

        def in_transaction?
            backend.transaction_status > 0
        end

        def failed?
            backend.transaction_status >= 3
        end

        # http://dba.stackexchange.com/questions/22362/
        # http://www.postgresql.org/docs/9.3/static/catalog-pg-attribute.html
        # http://www.postgresql.org/docs/9.3/static/catalog-pg-attrdef.html
        def catalog
            Connection.cache_catalog do
                result = backend.exec(<<-END)
                    SELECT relname, attname, typname, pg_get_expr(adbin, 0)
                    FROM pg_class
                    LEFT JOIN pg_namespace ON (
                        pg_class.relnamespace = pg_namespace.oid)
                    LEFT JOIN pg_attribute ON (
                        pg_class.oid = pg_attribute.attrelid)
                    LEFT JOIN pg_attrdef ON (
                        pg_attribute.attrelid = pg_attrdef.adrelid
                        AND pg_attribute.attnum = pg_attrdef.adnum)
                    LEFT JOIN pg_type ON (
                        pg_attribute.atttypid = pg_type.oid)
                    WHERE pg_class.relkind IN ('r','')
                        AND pg_namespace.nspname
                            NOT IN ('pg_catalog', 'pg_toast')
                        AND pg_table_is_visible(pg_class.oid)
                        AND attnum > 0
                        AND NOT attisdropped;
                END

                output = {}
                result.each_row do |row|
                    output[row[0]] ||= {}
                    output[row[0]][row[1]] = { type: row[2], default: row[3] }
                end
                output
            end
        end

        def column_list(table)
            catalog[table].keys
        end

        def column_type(table, column)
            catalog[table][column][:type]
        end

        def column_default(table, column)
            catalog[table][column][:default]
        end

        private

        def maybe(*args)
            Agrippa::Maybe.new(*args)
        end

        def extract_raw_connection(backend)
            return(backend) if backend.is_a?(PG::Connection)
            maybe(backend).raw_connection._ \
                or maybe(backend).connection.raw_connection._ \
                or raise("Unable to extract a connection from: #{backend}")
        end
    end
end
