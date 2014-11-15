require "spec_helper"
require "janko/merge"

RSpec.shared_examples_for "a merger" do
    around :each do |example|
        begin
            connection.exec(<<-END)
                BEGIN;
                CREATE TEMP TABLE merge_test(id SERIAL NOT NULL,
                    user_id INTEGER, title TEXT, content TEXT,
                    vector TSVECTOR, votes INTEGER DEFAULT 0)
                ON COMMIT DROP;
                CREATE UNIQUE INDEX index_merge_test_id ON merge_test(id);
                CREATE UNIQUE INDEX index_merge_test_unique_content
                    ON merge_test(user_id, content);
            END
            merge.connect(connection)
            example.run
        rescue
            raise
        ensure
            connection.exec("ROLLBACK")
        end
    end

    let(:connection) { Janko::Connection.default }

    let(:merge) { subject.set_table("merge_test") }

    def select_all
        result = connection.exec(<<-END)
            SELECT * FROM merge_test ORDER BY id asc
        END
        output = []
        result.each { |tuple| output.push(tuple) }
        output
    end

    let(:results) { select_all }

    it "#start preserves state" do
        merge.start
        expect(lambda { merge.insert(:id) }).to raise_error(RuntimeError)
    end

    it "#stop allows state changes" do
        merge.start.stop
        expect(lambda { merge.insert(:id) }).to_not raise_error
    end

    it "#push" do
        record = { title: "Hello, world!" }
        merge.start.push(record).stop
        expect(results.count).to eq(1)
        expect(results.first["title"]).to eq(record[:title])
    end

    describe "#insert" do
        let(:row) { { id: 42, user_id: 1, title: "foo", content: "bar" } }

        it "defaults to everything but id" do
            merge.start.push(row).stop
            expect(results.count).to eq(1)
            expect(results.first["id"]).to eq("1")
            expect(results.first["title"]).to eq(row[:title])
            expect(results.first["content"]).to eq(row[:content])
            expect(results.first["user_id"]).to eq(row[:user_id].to_s)
        end

        it "specific fields only" do
            merge.insert(:title).start.push(row).stop
            expect(results.count).to eq(1)
            expect(results.first["id"]).to eq("1")
            expect(results.first["title"]).to eq(row[:title])
            expect(results.first["content"]).to be_nil
            expect(results.first["user_id"]).to be_nil
        end

        it "multiple rows" do
            merge.start.push(title: "foo").push(title: "bar").stop
            expect(results.count).to eq(2)
        end

        describe "#alter" do
            it "#default from user" do
                merge.insert(:title)
                merge.alter(:title) { |f| f.default("upper('foo')") }
                merge.start.push(title: nil).stop
                expect(results.first["title"]).to eq("FOO")
            end

            it "#default from database" do
                merge.insert(:id)
                merge.alter(:id) { |f| f.default(Janko::DEFAULT) }
                merge.start.push(id: nil).stop
                expect(results.first["id"]).to eq("1")
            end

            it "#default keep existing ignored" do
                merge.insert(:title)
                merge.alter(:title) { |f| f.default(Janko::KEEP) }
                merge.start.push(id: 1, title: nil).stop
                expect(results.count).to eq(1)
                expect(results.first["title"]).to be_nil
            end

            it "#default keep if nil, otherwise use database default" do
                merge.insert(:title).alter(:title) { |f|
                    f.default(Janko::DEFAULT | Janko::KEEP) }
                merge.start.push(id: 1, title: nil).stop
                expect(results.count).to eq(1)
                expect(results.first["title"]).to be_nil
            end

            it "#wrap function" do
                merge.insert(:title)
                merge.alter(:title) { |f| f.wrap("upper($NEW)") }
                merge.start.push(title: "foo").stop
                expect(results.first["title"]).to eq("FOO")
            end

            it "#wrap cast" do
                merge.insert(:vector)
                merge.alter(:vector) { |f| f.wrap("$NEW::tsvector") }
                merge.start.push(vector: "hello:1A world:2A").stop
                expect(results.first["vector"]).to eq("'hello':1A 'world':2A")
            end

            it "#wrap value" do
                merge.insert(:votes)
                merge.alter(:votes) { |f| f.wrap("3") }
                merge.start.push(votes: "42").stop
                expect(results.first["votes"]).to eq("3")
            end
        end
    end

    describe "#key" do
        it "defaults to id" do
            original = { title: "Hello, world!" }
            update = { id: 1, title: "こんにちは" }
            merge.start.push(original).stop
            merge.start.push(update).stop
            expect(results.count).to eq(1)
            expect(results.first["id"]).to eq("1")
            expect(results.first["title"]).to eq(update[:title])
        end

        it "one field" do
            original = { title: "foo", content: "bar" }
            update = { title: "quux", content: "bar" }
            merge.key(:content)
            merge.start.push(original).stop
            merge.start.push(update).stop
            expect(results.count).to eq(1)
            expect(results.first["title"]).to eq(update[:title])
            expect(results.first["content"]).to eq(update[:content])
        end

        it "multiple fields" do
            original = { title: "foo", content: "bar", user_id: 1 }
            keep = { title: "foo", content: "bar", user_id: 2 }
            update = { title: "foo", content: "baz", user_id: 1 }
            merge.key(%w(title user_id))
            merge.start.push(original).push(keep).stop
            merge.start.push(update).stop
            expect(results.count).to eq(2)
            expect(results.first["content"]).to eq(update[:content])
            expect(results.last["content"]).to eq(keep[:content])
            expect(results.last["user_id"]).to eq(keep[:user_id].to_s)
        end
    end

    describe "#update" do
        let(:original) { { title: "foo", content: "bar", votes: 1 } }

        let(:update) { { id: 1, title: "baz", content: "bang" } }

        before(:each) { merge.start.push(original).stop }

        it "defaults to everything but id" do
            merge.start.push(update).stop
            expect(results.count).to eq(1)
            expect(results.first["id"]).to eq("1")
            expect(results.first["title"]).to eq(update[:title])
            expect(results.first["content"]).to eq(update[:content])
            expect(results.first["user_id"]).to be_nil
        end

        it "specific fields only" do
            merge.update(:title).start.push(update).stop
            expect(results.count).to eq(1)
            expect(results.first["title"]).to eq(update[:title])
            expect(results.first["content"]).to eq(original[:content])
        end

        describe "#alter" do
            it "#default NULL" do
                merge.update(:votes)
                merge.alter(:votes) { |f| f.default(nil) }
                merge.start.push(update).stop
                expect(results.count).to eq(1)
                expect(results.first["votes"]).to be_nil
            end

            it "#default from user" do
                merge.update(:votes)
                merge.alter(:votes) { |f| f.default("round(3.14)") }
                merge.start.push(update).stop
                expect(results.count).to eq(1)
                expect(results.first["votes"]).to eq("3")
            end

            it "#default from database" do
                merge.update(:votes)
                merge.alter(:votes) { |f| f.default(Janko::DEFAULT) }
                merge.start.push(update).stop
                expect(results.count).to eq(1)
                expect(results.first["votes"]).to eq("0")
            end

            it "#default keep existing" do
                merge.update(:title)
                merge.alter(:title) { |f| f.default(Janko::KEEP) }
                merge.start.push(id: 1, title: nil).stop
                expect(results.count).to eq(1)
                expect(results.first["title"]).to eq(original[:title])
            end

            it "#default keep if nil, otherwise use database default" do
                merge.update(:title).alter(:title) { |f|
                    f.default(Janko::DEFAULT | Janko::KEEP) }
                merge.start.push(id: 1, title: nil).stop
                expect(results.count).to eq(1)
                expect(results.first["title"]).to eq(original[:title])
            end

            it "#wrap function" do
                merge.update(:title)
                merge.alter(:title) { |f| f.wrap("upper($NEW)") }
                merge.start.push(update).stop
                expect(results.first["title"]).to eq("BAZ")
            end

            it "#wrap cast" do
                merge.update(:title)
                merge.alter(:title) { |f| f.wrap("$NEW::text") }
                merge.start.push(update).stop
                expect(results.first["title"]).to eq("baz")
            end

            it "#on_update alter existing value" do
                merge.update(:title, :votes)
                merge.alter(:votes) { |f| f.on_update("$OLD + 1") }
                merge.start.push(update).stop
                expect(results.first["votes"]).to eq("2")
            end
        end

    end

    describe "#returning" do
        def insert_and_update
            merge.start.push(title: "foo").stop
            merge.start
            merge.push(id: 1, title: "bar")
            merge.push(title: "baz")
            merge.stop
        end

        it "inserted" do
            merge.returning(:inserted)
            insert_and_update
            expect(merge.result.inserted.count).to eq(1)
            expect(merge.result.updated.count).to eq(0)
        end
        
        it "updated" do
            merge.returning(:updated)
            insert_and_update
            expect(merge.result.inserted.count).to eq(0)
            expect(merge.result.updated.count).to eq(1)
        end

        it "all" do
            merge.returning(:all)
            insert_and_update
            expect(merge.result.inserted.count).to eq(1)
            expect(merge.result.updated.count).to eq(1)
        end

        it "none" do
            merge.returning(:none)
            insert_and_update
            expect(merge.result.inserted.count).to eq(0)
            expect(merge.result.updated.count).to eq(0)
        end

        it "invalid" do
            expect(lambda { merge.returning(:ducks) })
                .to raise_error(RuntimeError)
        end

        it "into object" do
            collector = double
            merge.returning(:all).set_collector(collector)
            expect(collector).to receive(:push).at_least(3).times
            expect(collector).to receive(:clear).at_least(:once)
            insert_and_update
        end

        pending "into table"
    end

    describe "#select" do
        let(:record) { { title: "foo", content: "bar", user_id: 1 } }

        let(:inserted) do
            merge.returning(:inserted).start.push(record).stop
            merge.result.inserted.first
        end

        it "all columns by default" do
            expect(inserted["id"]).to eq("1")
            expect(inserted["title"]).to eq(record[:title])
            expect(inserted["content"]).to eq(record[:content])
            expect(inserted["user_id"]).to eq(record[:user_id].to_s)
        end

        it "select columns" do
            merge.select(:id, :title)
            expect(inserted.count).to eq(2)
            expect(inserted["id"]).to eq("1")
            expect(inserted["title"]).to eq(record[:title])
        end
    end

    describe "#set_locking" do
        let(:record) { { title: "foo", content: "bar", user_id: 1 } }

        it "true" do
            merge.set_locking(true).start.push(record).stop
            expect(results.count).to eq(1)
            expect(results.first["title"]).to eq(record[:title])
        end

        it "false" do
            merge.set_locking(false).start.push(record).stop
            expect(results.count).to eq(1)
            expect(results.first["title"]).to eq(record[:title])
        end
    end

    describe "#set_transaction" do
        let(:record) { { title: "foo", content: "bar", user_id: 1 } }

        it "true" do
            merge.set_transaction(true).start.push(record).stop
            expect(results.count).to eq(1)
            expect(results.first["title"]).to eq(record[:title])
        end

        it "false" do
            merge.set_transaction(false).start.push(record).stop
            expect(results.count).to eq(1)
            expect(results.first["title"]).to eq(record[:title])
        end
    end

    it "inserts on null key" do
        merge.start.push(title: "foo", content: "bar").stop
        merge.start.push(title: nil, content: "baz").stop
        expect(select_all.count).to eq(2)
        merge.key(:title).start
        merge.push(title: nil, content: "bang")
        merge.push(title: "foo", content: "quux")
        merge.stop
        expect(results.count).to eq(3)
        expect(results).to be_any { |r| 
            r["title"].nil? and r["content"] == "baz" }
        expect(results).to be_any { |r| 
            r["title"].nil? and r["content"] == "bang" }
        expect(results).to be_any { |r| 
            r["title"] == "foo" and r["content"] == "quux" }
    end
end

RSpec.describe Janko::Merge do
    describe "#strategy single" do
        let(:subject) { Janko::Merge.new.use(Janko::SingleMerge) }

        it_behaves_like "a merger"
    end

    describe "#strategy bulk" do
        let(:subject) { Janko::Merge.new.use(Janko::BulkMerge) }

        it_behaves_like "a merger"
    end
end
