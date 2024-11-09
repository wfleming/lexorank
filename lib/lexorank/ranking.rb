# frozen_string_literal: true

class Lexorank::Ranking
  include Lexorank

  attr_reader :record_class, :field, :group_by, :advisory_lock_config

  def initialize(record_class:, field:, group_by:, advisory_lock:)
    @record_class = record_class
    @field = field
    @group_by = process_group_by_column_names(group_by)
    @advisory_lock_config = { enabled: record_class.respond_to?(:with_advisory_lock) }.merge(advisory_lock)
  end

  def validate!
    if advisory_lock_config[:enabled] && !record_class.respond_to?(:with_advisory_lock)
      raise(
        Lexorank::InvalidConfigError,
        "Cannot enable advisory lock if #{record_class.name} does not respond to #with_advisory_lock. " \
        'Consider installing the with_advisory_lock gem (https://rubygems.org/gems/with_advisory_lock).'
      )
    end

    unless field
      raise(
        Lexorank::InvalidConfigError,
        'The supplied ":field" option cannot be "nil"!'
      )
    end
  end

  def scoped_collection(instance)
    collection = record_class.ranked
    if group_by.present?
      collection = collection.where(Hash[*group_by.flat_map { |col| [col, instance.send(col)] }])
    end
    collection
  end

  def move_to(instance, position = nil, **options)
    if block_given? && advisory_locks_enabled?
      return with_lock_if_enabled(instance, **options.fetch(:advisory_lock, {})) do
        move_to(instance, position, **options)
        yield
      end
    end

    collection = scoped_collection(instance)

    # exceptions:
    #   move to the beginning (aka move to position 0)
    #   move to end (aka position = collection.size - 1)
    # when moving to the end of the collection the offset and limit statement automatically handles
    # that 'after' is nil which is the same like [collection.last, nil]
    before, after =
      if position.nil?
        if options.include?(:before)
          resolve_relative_record_position(instance, :before, options[:before])
        elsif options.include?(:after)
          resolve_relative_record_position(instance, :after, options[:after])
        else
          raise ArgumentError.new("Static or relative position must be specified")
        end
      elsif position == :last
        [collection.last, nil]
      elsif position.zero?
        [nil, collection.first]
      elsif Integer === position
        collection.where.not(id: instance.id).offset(position - 1).limit(2)
      else
        raise ArgumentError.new("Invalid position #{position}")
      end

    # If position >= collection.size both `before` and `after` will be nil. In this case
    # we set before to the last element of the collection
    if before.nil? && after.nil?
      before = collection.last
    end

    rank =
      if (self == after && send(field).present?) || (before == self && after.nil?)
        send(field)
      else
        value_between(before&.send(field), after&.send(field))
      end

    instance.send(:"#{field}=", rank)

    if block_given?
      yield
    else
      rank
    end
  end

  def with_lock_if_enabled(instance, **options, &)
    if advisory_locks_enabled?
      advisory_lock_options = advisory_lock_config.except(:enabled, :lock_name).merge(options)

      record_class.with_advisory_lock(advisory_lock_name(instance), **advisory_lock_options, &)
    else
      yield
    end
  end

  def advisory_lock_name(instance)
    if advisory_lock_config[:lock_name].present?
      advisory_lock_config[:lock_name].(instance)
    else
      "#{record_class.table_name}_update_#{field}".tap do |name|
        if group_by.present?
          name << "_group_" << group_by.map { |col| instance.send(col).to_s }.join("_")
        end
      end
    end
  end

  def advisory_locks_enabled?
    record_class.respond_to?(:with_advisory_lock) && advisory_lock_config[:enabled]
  end

  private

  def record_before(instance)
    scoped_collection(instance).unscope(:order).ranked(direction: :desc).where("#{field} < ?", instance.rank).first
  end

  def record_after(instance)
    scoped_collection(instance).where("#{field} > ?", instance.rank).first
  end

  def process_group_by_column_names(names)
    # This requires rank! to be after the association if names is an association name
    if names.present?
      Array.wrap(names).flat_map do |name|
        if (association = record_class.reflect_on_association(name))
          [association.foreign_type&.to_sym, association.foreign_key.to_sym].compact
        else
          name
        end
      end
    end
  end

  def resolve_relative_record_position(instance, direction, relative_record)
    if relative_record.nil?
      if direction == :before
        return [scoped_collection(instance).last, nil]
      else
        return [nil, scoped_collection(instance).first]
      end
    end

    relative_record =
      if relative_record.is_a?(self.record_class)
        relative_record
      else
        scoped_collection(instance).find(relative_record)
      end

    if direction == :before
      [record_before(relative_record), relative_record]
    else
      [relative_record, record_after(relative_record)]
    end
  end
end
