# frozen_string_literal: true

class Lexorank::Rebalance
  include Lexorank

  attr_reader :ranking, :group_vals, :batch_size, :collection, :record_count

  def initialize(ranking:, group_vals:, batch_size: 1_000)
    @ranking = ranking
    @group_vals = group_vals
    @batch_size = batch_size

    if ranking.group_by && (!group_vals || ranking.group_by.any? { |k| !group_vals.include?(k) })
      raise ArgumentError.new("This table's ranks are grouped by #{ranking.group_by}, not all keys were present")
    end

    @collection = ranking.record_class.where(group_vals).ranked.select(ranking.record_class.primary_key, ranking.field)
    @record_count = collection.unscope(:select).count
  end

  def execute
    ranking.record_class.transaction do
      # need a record instance for advisory lock name
      first_instance = ranking.record_class.where(group_vals).first

      last_rank = MIN_CHAR * rank_length
      all_updates = []

      ranking.with_lock_if_enabled(first_instance) do
        process_batches(collection) do |batch|
          batch_updates, last_rank = build_batch_updates(batch, last_rank)
          all_updates += batch_updates
        end

        perform_updates(all_updates)
      end
    end
  end

  def build_batch_updates(batch, last_rank)
    updates = batch.map do |record|
      last_rank = increment_rank(last_rank)
      Hash[record.class.primary_key, record.send(record.class.primary_key), ranking.field, last_rank]
    end
    [updates, last_rank]
  end

  def perform_updates(all_updates)
    all_updates.each_slice(batch_size) do |batch_updates|
      ranking.record_class.upsert_all(batch_updates)
    end
  end

  private

  def symbol_count
    @symbol_count ||= (MAX_CHAR.ord - MIN_CHAR.ord) + 1
  end

  def rank_length
    @rank_length ||=
      begin
        length_required_to_place_all = Math.log(record_count, symbol_count).ceil
        length_required_to_place_all * 2
      end
  end

  def rank_step
    @rank_step ||=
      begin
        # subtract highest order of magnitude because high end of symbols is exclusive (no rank >= z)
        possible_values = (symbol_count**rank_length) - (symbol_count**(rank_length-1))
        # want the spread to include space at beginning and end
        possible_values / (record_count + 2)
      end
  end

  def char_to_offset_ord(char)
    char.ord - MIN_CHAR.ord
  end

  def char_from_offset_ord(rel_ord)
    (MIN_CHAR.ord + rel_ord).chr
  end

  def increment_rank(rank)
    step = rank_step
    chars = rank.chars
    next_chars = chars.reverse_each.map do |c|
      if step.zero?
        c
      else
        tot = char_to_offset_ord(c) + step
        step = tot / symbol_count
        char_from_offset_ord(tot % symbol_count)
      end
    end.compact.reverse_each.to_a

    next_rank = next_chars.join('')

    if step > 0 # this is equivalent to carrying leftover, shouldn't happen since we've constructed the key space to all be the same length (number of "digits")
      raise InvalidRankError, 'looks like a bug: no carry over should happen during rebalance'
    elsif next_rank < rank
      raise InvalidRankError, 'looks like a bug: next rank ended up < last rank'
    elsif next_rank >= MAX_CHAR
      raise InvalidRankError, 'looks like a bug: no rank should be >= z'
    end

    next_rank
  end

  # ActiveRecord `in_batches` requires the cursor field (which would be `rank`) to be unique, but
  # while this gem encourages making rank unique it does not enforce it, and it's not unique indexed
  # in test models, so we do our own batching
  def process_batches(collection)
    pk_field = ranking.record_class.primary_key
    batch = collection.limit(batch_size).load

    while batch.any?
      yield batch
      last_rank = batch.last.send(ranking.field)
      ignore_ids = batch.reverse_each.take_while { |r| r.send(ranking.field) == last_rank }.map { |r| r.send(pk_field) }
      batch = collection.where("rank >= ?", last_rank).where.not(pk_field => ignore_ids).limit(batch_size).load
    end
  end
end
