# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
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
$unbalanced_table_name = SecureRandom.hex

class Unbalanced < ActiveRecord::Base
  self.table_name = $unbalanced_table_name
  rank!
end

RECORD_COUNT = ARGV[0] ? ARGV[0].to_i : 10_000

ActiveRecord::Schema.define do
  create_table $unbalanced_table_name, force: :cascade do |t|
    t.string 'rank'
    t.index ['rank'], name: 'index_unbalanceds_on_rank', unique: true
  end
end

def setup_table
  ActiveRecord::Base.connection.truncate($unbalanced_table_name)
  ActiveRecord::Base.transaction do
    needed = 1
    RECORD_COUNT.times do |n|
      needed -= 1
      if needed.zero?
        # we need count + 1
        needed = n + 2
      end

      unbalanced = Unbalanced.new
      unbalanced.move_to(n % 2)
      unbalanced.save

      if ((n + 1) % 1_000).zero?
        puts "created #{n + 1} records"
      end
    end
  end
end

def clear_active_record_cache
  ActiveRecord::Base.connection.query_cache.clear
  Unbalanced.reset_column_information
end

Benchmark.bmbm do |x|
  x.report('setup') do
    setup_table
    clear_active_record_cache
  end
  x.report('rebalance') do
    Unbalanced.rebalance_rank!
  end
end
