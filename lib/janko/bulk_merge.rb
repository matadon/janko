require "janko/merge_result"
require "janko/import"
require "janko/upsert"

module Janko
    class BulkMerge
        def initialize(options = {})
            @options = options
            @target = "merge_#{SecureRandom.hex(8)}"
            @upsert = Upsert.new(options.merge(from_table: @target))
            @importer = Import.new(strategy: Janko::CopyImporter,
                table: @target, connection: connection,
                columns: options[:columns])
        end

        def start
            create_copy_target
            @importer.start
            self
        end

        def push(*values)
            @importer.push(*values)
            self
        end

        def stop
            @importer.stop
            @upsert.process.cleanup
            drop_copy_target
            self
        end

        def result
            @upsert.result
        end

        def connection
            @options[:connection]
        end

        private

        def create_copy_target
            connection.exec(<<-END)
                CREATE TEMP TABLE #{@target} WITHOUT OIDS ON COMMIT DROP
                AS (SELECT * FROM #{@options[:table]}) WITH NO DATA;
            END
            self
        end

        def drop_copy_target
            connection.exec("DROP TABLE #{@target}")
            self
        end
    end
end
