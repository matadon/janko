require "csv"
require "agrippa/mutable"

module Janko
    class CopyImporter
        include Agrippa::Mutable

        state_reader :connection, :table, :columns

        def start
            connection.async_exec(sprintf("COPY %s(%s) FROM STDOUT CSV",
                table, columns.to_list))
            self
        end

        def push(values)
            begin
                line = CSV.generate_line(columns.pack(values))
                connection.put_copy_data(line)
            rescue
                stop
                raise
            end
            self
        end

        def stop
            connection.put_copy_end
            result = connection.get_last_result
            return(self) if (result.result_status == PG::PGRES_COMMAND_OK)
            return(self) if (result.result_status == PG::PGRES_COPY_IN)
            raise(PG::Error, result.error_message)
            self
        end
    end
end
