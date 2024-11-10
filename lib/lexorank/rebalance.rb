# frozen_string_literal: true

class Lexorank::Rebalance
  include Lexorank

  attr_reader :ranking, :group_vals, :batch_size

  def initialize(ranking:, group_vals:, batch_size: 1_000)
    @ranking = ranking
    @group_vals = group_vals
    @batch_size = batch_size

    if ranking.group_by && (!group_vals || ranking.group_by.any? { |k| !group_vals.include?(k) })
      raise ArgumentError.new("This table's ranks are grouped by #{ranking.group_by}, not all keys were present")
    end
  end

  def execute
    ranking.record_class.transaction do
      # need a record instance for advisory lock name
      first_instance = ranking.record_class.where(group_vals).first

      last_rank = nil
      scope = ranking.record_class.where(group_vals).ranked.select(ranking.record_class.primary_key, ranking.field)
      ranking.with_lock_if_enabled(first_instance) do
        scope.in_batches(of: batch_size) do |batch|
          last_rank = process_batch(batch, last_rank)
        end
      end
    end
  end

  def process_batch(batch, last_rank)
    updates = []
    batch.each do |record|
      last_rank = value_between(last_rank, nil)
      updates << Hash[record.class.primary_key, record.send(record.class.primary_key), ranking.field, last_rank]
    end
    ranking.record_class.upsert_all(updates)
    last_rank
  end
end
