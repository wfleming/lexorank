# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'optparse'
require 'benchmark'
require 'pry'
require 'active_record'
require 'securerandom'

require 'lexorank'
require 'lexorank/rankable'

db_config = {
  adapter: 'sqlite3',
  database: 'file:benchmarkmemdb?mode=memory&cache=private'
}
ActiveRecord::Base.establish_connection(db_config)
ActiveRecord::Schema.verbose = false

# trying to avoid sqlite caching here
$table_name = "foo_#{SecureRandom.hex}"

class Foo < ActiveRecord::Base
  self.table_name = $table_name
  rank!
end

$mode = :unbalanced  # also supported :random, :sequential
$record_count = 10_000

OptionParser.new do |opts|
  opts.on("-cCOUNT") do |c|
    $record_count = Integer(c)
  end
  opts.on("-mMODE") do |m|
    $mode = m.to_sym
  end
end.parse!

ActiveRecord::Schema.define do
  create_table $table_name, force: :cascade do |t|
    t.string 'rank'
    t.string 'original_rank'
    t.index ['rank'], name: 'index_foo_on_rank', unique: true
    t.index ['original_rank'], name: 'index_foo_on_original_rank', unique: true
  end
end

def setup_table
  ActiveRecord::Base.connection.truncate($table_name)
  ActiveRecord::Base.transaction do
    $record_count.times do |n|
      foo = Foo.new
      case $mode
      when :unbalanced
        foo.move_to(n % 2)
      when :random
        foo.move_to(Random.rand(0..n))
      when :sequential
        foo.move_to(:last)
      end
      foo.original_rank = foo.rank
      foo.save!

      if ((n + 1) % 1_000).zero?
        puts "created #{n + 1} records"
      end
    end
  end
end

def clear_active_record_cache
  ActiveRecord::Base.connection.query_cache.clear
  Foo.reset_column_information
end

def compare_orders
  result = ActiveRecord::Base.connection.select_all(
    <<~EOF
    with orig_order as (
      select id, rank() over (order by original_rank) row_idx
      from \"#{$table_name}\"
    ),

    new_order as (
      select id, rank() over (order by rank) row_idx
      from \"#{$table_name}\"
    )

    select o.id, o.row_idx as orig_row_idx, n.row_idx as new_row_idx
    from orig_order o
    join new_order n on o.id = n.id and o.row_idx <> n.row_idx
    EOF
  )
  if result.count > 0
    $stderr.puts "ERROR: rows after rebalance appear to be in a different order!"
  end
end

Benchmark.bm do |x|
  setup_table

  x.report('rebalance') do
    Foo.rebalance_rank!
  end
end

compare_orders
