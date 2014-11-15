require "spec_helper"
require "janko/connection"

RSpec.describe Janko::Connection do
    describe ".build" do
        it "PG::Connection" do
            backend = ActiveRecord::Base.connection.raw_connection
            connection = Janko::Connection.build(backend)
            expect(connection.backend).to be(backend)
        end

        it "ActiveRecord::Base.connection" do
            backend = ActiveRecord::Base.connection
            connection = Janko::Connection.build(backend)
            raw_connection = backend.raw_connection
            expect(connection.backend).to be(raw_connection)
        end

        it "ActiveRecord::Base" do
            backend = ActiveRecord::Base
            connection = Janko::Connection.build(backend)
            raw_connection = backend.connection.raw_connection
            expect(connection.backend).to be(raw_connection)
        end
    end
end

