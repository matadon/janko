require "agrippa/mutable"

module Janko
    class InsertImporter
        include Agrippa::Mutable

        state_reader :connection, :table, :columns

        def start
            query = sprintf("INSERT INTO %s(%s) VALUES(%s)", table,
                columns.to_list, columns.to_binds)
            connection.prepare(statement_name, query)
            self
        end

        def push(values)
            connection.exec_prepared(statement_name, columns.pack(values))
            self
        end

        def stop
            connection.exec("DEALLOCATE \"#{statement_name}\"")
            self
        end

        private

        def statement_name
            @statement_name ||= "import-#{SecureRandom.hex(8)}"
        end
    end
end
