## Janko

One day, your Ruby app may meed to feed a metric shit-ton of data into
PostgreSQL.

On that day, you need Janko.

Janko imports and merges large datasets with truly stupid levels of
performance (see the benchmarks below).

## Installation

Run `gem install janko`, or add `gem "janko"` to your `Gemfile`.

Janko has been tested against PostgreSQL 9.3, and requires at least
PostgreSQL 9.1, as it makes use of a [writable
CTE](http://www.postgresql.org/docs/9.1/static/queries-with.html). As soon
as PostgreSQL 9.5 goes platinum, Janko support will be added there as well.

## Putting It to Work

#### Importing

`Janko::Import` needs to be configured for each table you want to load with
data:

```ruby
require "janko/import"

# Let's import some data with Janko::Import
importer = Janko::Import.new

# Use the same database connection as ActiveRecord.
importer.connect(ActiveRecord::Base)

# Import lots of records at once.
importer.use(Janko::CopyImporter)

# Let's only import a few columns into the "users" table.
importer.table("users").columns(:id, :email, :password)

# And feed it some data from an array
importer.start
rows.each { |row| importer.push(row) }
importer.stop
```

Out of the box, `Janko::Import` offers a choice of two different
data-loading behaviors: `Janko::InsertImporter` and `Janko::CopyImporter`.

`Janko::CopyImporter` is notably faster, but only throws errors after
feeding the entire dataset into PostgreSQL. `Janko::InsertImporter` is half
as fast as copy, but will error immediately if the database is unhappy with
what its being fed.

Both will have the same final result regardless of errors, the only
differences are speed, and whether or not errors occur immediately on
`importer.push`, or when `importer.stop` is called.

## Merging / Upserting

`Janko::Merge` works similarly to `Janko::Import`:

```ruby
require "janko/merge"

# Create a Merger, and fetch a Builder.
merge = Janko::Merge.new

# Tell it about our connection.
merge.connect(ActiveRecord::Base)

# Set the target table.
merge.table("users")

# Use the email address as the key column, used to determine whether
# to UPDATE an existing row, or INSERT a new one.
merge.key(:email)

# Feed it some data from an array
merge.start
rows.each { |row| merge.push(row) }
merge.stop
```

By default, `Merge` will attempt to fill all columns on both INSERT and
UPDATE *except* the `id` column. You can choose to UPDATE or INSERT only on
specific columns with `merge.update("column")` and `merge.insert("column")`,
respectively.

Multiple `key` columns are allowed.

#### Returning

`Merge` can return both updated and inserted rows via `returning`:

```ruby
# Return inserted rows.
merge.returning(:inserted)

# Return updated rows.
merge.returning(:updated)

# Return all rows.
merge.returning(:all)

# Return nothing.
merge.returning(:none)
```

Results are stored in `merge.result`.

#### Column Defaults

PostgreSQL provides a lot of functionality that is difficult or impossible
to expose through an ORM, so Janko provides some shockingly unsafe ways to
interact with the database.

**`Merge#alter` is dangerous as all hell.** It provides *zero* safety
against stupidity, intentional or otherwise, and is injected directly into
the database without escaping.

Here's how it works:

```ruby
# Use the database default value for a column if nil.
merge.alter(:updated_at) { |c| c.default(Janko::DEFAULT) }

# Preserve the existing value of a column if nil.
merge.alter(:created_at) { |c| c.default(Janko::KEEP) }

# Do both of those things.
merge.alter(:updated_at) { |c| c.default(Janko::KEEP | Janko::DEFAULT) }

# Have the vote column increment whenever a row is updated.
merge.alter(:votes) { |c| c.on_update("$OLD + 1") }

# Make all post titles really, really shouty.
merge.alter(:title) { |c| c.wrap("upper($NEW)") }

# Completely nuke every record in the users table via SQL injection. Did I
# mention that Merge#alter should fill you with a sense of great danger?
merge.alter(:title) { |c| c.wrap("; rollback; delete * from users;" }
```

When alterting columns, `$NEW` is a placeholder for the value to be inserted
from the Ruby side, and `$OLD` is the existing value in the database.

Both of these use parameter binding, *not* string escaping or quoting, so
you don't need to worry about SQL injection on the values themselves, just
on any raw query you might supply with `wrap` or `on_update`.

## Benchmarks

Benchmarks were run under a single-processor virtual machine on my laptop (a
Macbook Air, 1.3GhZ Core i5), and yielded surprisingly nice results.

#### Import

![Insert Performance Graph](assets/insert-performance-graph.png)

#### Merge

![Merge Performance Graph](assets/merge-performance-graph.png)

## Other Considerations.

Both Insert and Merge *should* be threadsafe insofar as the underlaying
connection library is.

## The FUTURE!

Better documentation.

Returning rows into a custom handler or other table.

JRuby and Sequel support should be fairly straightforward.

Integration with `ActiveRecord` and `Sequel::Model`.

Profiling, optimization, and concurrency testing.

Binary-format COPY support and/or faster CSV encoding.

No plans to support other databases, just PostgreSQL, but I wouldn't turn
down a well-implemented pull request.
