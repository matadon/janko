require "spec_helper"
require "janko/column_list"

RSpec.describe Janko::ColumnList do
    let(:subject) { Janko::ColumnList.new.builder }

    it "#empty?" do
        expect(subject.empty?).to eq(true)
        expect(subject.add(:a).empty?).to eq(false)
    end

    it "#columns" do
        expect(subject.add(:a, "b", :c).columns).to eq(%w(a b c))
    end
    
    describe "#tagged" do
        it "filters" do
            subject.tag(:red, :a).tag(:blue, :b)
            expect(subject.tagged(:red).columns).to eq(%w(a))
        end

        it "symbols or strings" do
            subject.tag(:red, :a)
            expect(subject.tagged("red").columns).to eq(%w(a))
            subject.tag("red", :b)
            expect(subject.tagged("red").columns).to eq(%w(b))
        end

        it "preserves column order" do
            subject.add(:a, :b, :c)
            subject.tag(:red, :c, :b)
            expect(subject.tagged(:red).columns).to eq(%w(b c))
        end

        it "all tagged columns" do
            subject.add(:a, :b, :c)
            subject.tag(:red, :a).tag(:green, :c)
            expect(subject.tagged.columns).to eq(%w(a c))
        end
    end

    describe "#pack" do
        it "maintains order" do
            subject.add(:a, :b, :c)
            expect(subject.pack(b: "2", a: "1", c: "3")).to eq(%w(1 2 3))
        end

        it "null-fills fewer columns" do
            subject.add(:a, :b, :c)
            expect(subject.pack(a: 1, c: 3)).to eq([1, nil, 3])
        end

        it "unknown columns" do
            subject.add(:a, :b)
            expect(lambda { subject.pack(b: 2, a: 1, c: 3) }).to \
                raise_error(ArgumentError)
        end

        it "indifferent access" do
            subject.add(:a, "b")
            expect(subject.pack("a" => "1", b: "2")).to eq(%w(1 2))
        end
    end

    describe "#add" do
        it "multiple times" do
            subject.add(:a).add(:b, :c)
            expect(subject.pack(b: "2", a: "1", c: "3")).to eq(%w(1 2 3))
        end

        it "duplicate columns" do
            subject.add(:a).add(:a, :b, :c)
            expect(subject.pack(b: "2", a: "1", c: "3")).to eq(%w(1 2 3))
        end
    end

    describe "#alter" do
        before(:each) { subject.add(:a) }

        it "modifies a column" do
            subject.alter(:a) { |f| f.tag(:altered) }
            expect(subject.tagged(:altered).columns).to eq(%w(a))
        end

        it "modifies multiple columns" do
            subject.add(:b)
            subject.alter(:a, :b) { |f| f.tag(:altered) }
            expect(subject.tagged(:altered).columns).to eq(%w(a b))
        end

        it "preserves name and parent" do
            parent = double
            connection = double
            expect(parent).to receive(:connection).and_return(connection)
            subject.set(parent: parent)
            subject.alter(:a) { |f| Janko::TaggedColumn.new }
            expect(subject.columns).to eq(%w(a))
            expect(subject).to be_all { |_, c| c.connection == connection }
        end

        it "only works on existing columns" do
            expect(lambda { subject.alter(:b) { |f| f.tag(:b) } }) \
                .to raise_error(RuntimeError)
        end
    end

    it "Janko::ALL" do
        parent = double
        connection = double
        expect(parent).to receive(:table)
        expect(parent).to receive(:connection).and_return(connection)
        expect(connection).to receive(:column_list) \
            .and_return(%w(id a b c))
        subject.set(parent: parent)
        subject.add(Janko::ALL)
        expect(subject.columns).to eq(%w(id a b c))
    end

    it "Janko::DEFAULT" do
        parent = double
        connection = double
        expect(parent).to receive(:table)
        expect(parent).to receive(:connection).and_return(connection)
        expect(connection).to receive(:column_list) \
            .and_return(%w(id a b c))
        subject.set(parent: parent)
        subject.add(Janko::DEFAULT)
        expect(subject.columns).to eq(%w(a b c))
    end

    it "all columns except" do
        parent = double
        connection = double
        expect(parent).to receive(:table)
        expect(parent).to receive(:connection).and_return(connection)
        expect(connection).to receive(:column_list) \
            .and_return(%w(id a b c))
        subject.set(parent: parent)
        subject.add(except: "b")
        expect(subject.columns).to eq(%w(id a c))
    end

    it "#remove" do
        subject.add(:a, :b, :c).remove("b")
        expect(subject.columns).to eq(%w(a c))
    end

    it "#to_list" do
        subject.add(:a, :b, :c)
        expect(subject.to_list).to eq("\"a\",\"b\",\"c\"")
    end

    it "#to_binds" do
        subject.add(:a, :b, :c)
        expect(subject.to_binds).to eq("$1,$2,$3")
    end

    it "#inspect includes children" do
        subject.add(:foo, :bar).tag("blue", :bar)
        expect(subject.inspect).to match(/foo/)
        expect(subject.inspect).to match(/bar/)
        expect(subject.inspect).to match(/blue/)
    end
end
