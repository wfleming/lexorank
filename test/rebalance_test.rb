# frozen_string_literal: true

require 'test_helper'

class RebalanceTest < ActiveSupport::TestCase
  should 'rebalance with list without group_by' do
    Page.create(rank: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    Page.create(rank: 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz')
    Page.create(rank: 'cccccccccccccccccccccccccccccccccccccccccccc')
    Page.create(rank: 'dddddddddddddddddddddddddddddddddddddddddddd')
    Page.create(rank: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb')
    pages = Page.ranked.load

    Page.rebalance_rank!

    updated_pages = Page.ranked
    assert_equal pages.to_a, updated_pages.to_a
    pages.zip(updated_pages).each do |orig, updated|
      refute_equal orig.rank, updated.rank, "rank should have changed"
    end
  end

  should 'rebalance one list' do
    page_1 = Page.create
    pg1_paragraphs = create_sample_paragraphs(page_1)

    page_2 = Page.create
    Paragraph.create(page: page_2, rank: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    Paragraph.create(page: page_2, rank: 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz')
    Paragraph.create(page: page_2, rank: 'cccccccccccccccccccccccccccccccccccccccccccc')
    Paragraph.create(page: page_2, rank: 'dddddddddddddddddddddddddddddddddddddddddddd')
    Paragraph.create(page: page_2, rank: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb')
    pg2_paragraphs = Paragraph.where(page: page_2).ranked.load

    pg2_paragraphs[0].rebalance_rank_group!

    assert_equal pg1_paragraphs.to_a, Paragraph.where(page: page_1).ranked.to_a

    updated_pg2_paragraphs = Paragraph.where(page: page_2).ranked
    assert_equal pg2_paragraphs.to_a, updated_pg2_paragraphs.to_a
    pg2_paragraphs.zip(updated_pg2_paragraphs).each do |orig, updated|
      refute_equal orig.rank, updated.rank, "rank should have changed"
    end
  end

  should 'raise if attempt to rebalance a grouped table without group args' do
    assert_raises ArgumentError do
      Paragraph.rebalance_rank!
    end
  end
end
