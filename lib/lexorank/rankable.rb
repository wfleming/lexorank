# frozen_string_literal: true

require 'lexorank'
require 'lexorank/ranking'
require 'lexorank/rebalance'
require 'active_support/concern'

module Lexorank::Rankable
  extend ActiveSupport::Concern

  module ClassMethods
    attr_reader :lexorank_ranking

    def rank!(field: :rank, group_by: nil, advisory_lock: {})
      @lexorank_ranking = Lexorank::Ranking.new(record_class: self, field: field, group_by: group_by, advisory_lock: advisory_lock)
      lexorank_ranking.validate!

      if lexorank_ranking.field
        scope :ranked, ->(direction: :asc) { where.not("#{lexorank_ranking.field}": nil).order("#{lexorank_ranking.field}": direction) }
        include InstanceMethods
      end
    end

    def rebalance_rank!(group_vals = nil)
      Lexorank::Rebalance.new(ranking: lexorank_ranking, group_vals: group_vals).execute
    end
  end

  module InstanceMethods
    def move_to_top(...)
      move_to(0, ...)
    end

    def move_to_end(...)
      self.class.lexorank_ranking.move_to(self, :last, ...)
    end

    def move_to(...)
      self.class.lexorank_ranking.move_to(self, ...)
    end

    def move_to!(position = nil, **options)
      move_to(position, **options) do
        save
      end
    end

    def move_to_top!(**options)
      move_to_top(**options) do
        save
      end
    end

    def move_to_end!(**options)
      move_to_end(**options) do
        save
      end
    end

    def no_rank?
      !send(self.class.lexorank_ranking.field)
    end

    def rebalance_rank_group!
      self.class.rebalance_rank!(self.class.lexorank_ranking.group_by_vals(self))
    end
  end
end

ActiveRecord::Base.include Lexorank::Rankable
