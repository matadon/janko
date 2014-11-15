require "spec_helper"
require "janko/tagged_column"

RSpec.describe Janko::TaggedColumn do
    describe "parent" do
        let(:target) { double }

        let(:subject) { Janko::TaggedColumn.new(parent: target) }

        it "#connection" do
            expect(target).to receive(:connection)
            subject.connection
        end

        it "#table" do
            expect(target).to receive(:table)
            subject.table
        end
    end

    it "#set" do
        subject = Janko::TaggedColumn.new
        expect(subject.name).to be_nil
        subject.set(name: "field")
        expect(subject.name).to eq("field")
    end

    describe "#default" do
        let(:parent) { double }

        let(:subject) { Janko::TaggedColumn.new(parent: parent, 
            name: "field") }

        it "none by default" do
            expect(subject.to_setter("left", "right")).to \
                eq('"field" = "right"."field"')
        end

        it "user-specified" do
            subject.default("current_time")
            expect(subject.to_setter("left", "right")).to \
                eq('"field" = COALESCE("right"."field", current_time)')
        end

        it "from the database" do
            connection = double
            expect(parent).to receive(:connection).and_return(connection)
            expect(parent).to receive(:table)
            expect(connection).to receive(:column_default).and_return("NEXT")
            subject.default(Janko::Constants::DEFAULT)
            expect(subject.to_setter("left", "right")).to \
                eq('"field" = COALESCE("right"."field", NEXT)')
        end
    end
end

