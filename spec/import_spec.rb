require "spec_helper"
require "janko/import"
require "pg"

RSpec.shared_examples_for "an importer" do
    describe "insert" do
        let(:subject) { importer.connect(connection) }

        around :each do |example|
            begin
                subject.table("import_test").columns(:id, :value)
                connection.exec(<<-END)
                    BEGIN; CREATE TEMP TABLE import_test(
                        id integer not null, value text)
                        WITHOUT OIDS ON COMMIT DROP;
                    CREATE UNIQUE INDEX index_import_test_id
                        ON import_test(id);
                END
                example.run
            rescue
                raise
            ensure
                connection.exec("ROLLBACK")
            end
        end

        def result
            output = connection.exec(<<-END)
                SELECT id, value FROM import_test ORDER BY id asc
            END
            output.values.map { |v| v.join(",") }.join(";")
        end
 
        it "single row" do
            subject.start.push(id: 1, value: "fish").stop
            expect(result).to eq("1,fish")
        end

        it "multiple rows" do
            subject.start
            subject.push(id: 1, value: "fish")
            subject.push(id: 2, value: "fish")
            subject.stop
            expect(result).to eq("1,fish;2,fish")
        end

        it "nullable column" do
            subject.start.push(id: "1").stop
            expect(result).to eq("1,")
        end

        it "violates not-null constraint" do
            subject.start
            row = { value: "fish" }
            expect(lambda { subject.push(row).stop })
                .to raise_error(PG::NotNullViolation)
            connection.exec("ROLLBACK")
        end

        it "integer overflow" do
            subject.start
            row = { id: 2**32, value: "fish" }
            expect(lambda { subject.push(row).stop })
                .to raise_error(PG::NumericValueOutOfRange)
            connection.exec("ROLLBACK")
        end

        it "violate uniqueness constraint" do
            subject.start
            row = { id: 1, value: "fish" }
            subject.push(row)
            expect(lambda { subject.push(row).stop })
                .to raise_error(PG::UniqueViolation)
            connection.exec("ROLLBACK")
        end

        it "violate uniqueness constraint (async errors)" do
            subject.start
            a = { id: 1, value: "fish" }
            b = { id: 2, value: "fish" }
            c = { id: 3, value: "fish" }
            subject.push(b)
            copy = lambda { subject.push(a).push(b).push(c).stop }
            expect(copy).to raise_error(PG::UniqueViolation)
            connection.exec("ROLLBACK")
        end

        it "too many columns" do
            subject.start
            row = [ 1, "fish", "woah" ]
            expect(lambda { subject.push(*row).stop })
                .to raise_error(ArgumentError)
            connection.exec("ROLLBACK")
        end
    end
end

RSpec.describe Janko::Import do
    let(:connection) { ActiveRecord::Base.connection.raw_connection }

    describe "#strategy insert" do
        let(:importer) { Janko::Import.new.use(Janko::InsertImporter) }

        it_behaves_like "an importer"
    end

    describe "#strategy copy" do
        let(:importer) { Janko::Import.new.use(Janko::CopyImporter) }

        it_behaves_like "an importer"
    end
end
