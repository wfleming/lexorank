# frozen_string_literal: true

require 'test_helper'

class GroupByTest < ActiveSupport::TestCase
  should 'group paragraphs by page id and update accordingly' do
    page_1 = Page.create
    paragraphs_1 = create_sample_paragraphs(page_1)

    page_2 = Page.create
    paragraphs_2 = create_sample_paragraphs(page_2)

    assert_equal paragraphs_1, page_1.paragraphs.ranked
    assert_equal paragraphs_2, page_2.paragraphs.ranked

    paragraphs_2.last.move_to!(0)
    assert_equal [paragraphs_2.last, *paragraphs_2[0..1]], page_2.paragraphs.ranked

    paragraphs_1.first.move_to!(2)
    assert_equal paragraphs_1[1..2].push(paragraphs_1.first), page_1.paragraphs.ranked
  end

  should 'resolve attribute names' do
    assert_equal [:page_id], GroupedParagraph.lexorank_ranking.group_by

    class Paragraph2 < Base
      self.table_name = 'paragraphs'
      belongs_to :page
      rank!(group_by: :page)
    end
    assert_equal [:page_id], Paragraph2.lexorank_ranking.group_by
  end

  describe 'moving to a different group' do
    should 'insert into middle' do
      page_1, page_2 = create_sample_pages(count: 2)
      paragraph_1, paragraph_2, paragraph_3 = create_sample_paragraphs(page_1, clazz: GroupedParagraph)

      new_paragraph = create_sample_paragraphs(page_2, count: 1, clazz: GroupedParagraph).first

      new_paragraph.page = page_1
      new_paragraph.move_to(2)
      new_paragraph.save!

      expected = [paragraph_1, paragraph_2, new_paragraph, paragraph_3]
      assert_equal expected, GroupedParagraph.where(page_id: page_1.id).ranked
    end

    should 'insert at top' do
      page_1, page_2 = create_sample_pages(count: 2)
      paragraph_1, paragraph_2, paragraph_3 = create_sample_paragraphs(page_1, clazz: GroupedParagraph)

      new_paragraph = create_sample_paragraphs(page_2, count: 1, clazz: GroupedParagraph).first

      new_paragraph.page = page_1
      new_paragraph.move_to(0)
      new_paragraph.save!

      expected = [new_paragraph, paragraph_1, paragraph_2, paragraph_3]
      assert_equal expected, GroupedParagraph.where(page_id: page_1.id).ranked
    end

    should 'insert at the end' do
      page_1, page_2 = create_sample_pages(count: 2)
      paragraph_1, paragraph_2, paragraph_3 = create_sample_paragraphs(page_1, clazz: GroupedParagraph)

      new_paragraph = create_sample_paragraphs(page_2, count: 1, clazz: GroupedParagraph).first

      new_paragraph.page = page_1
      new_paragraph.move_to(3)
      new_paragraph.save!

      expected = [paragraph_1, paragraph_2, paragraph_3, new_paragraph]
      assert_equal expected, GroupedParagraph.where(page_id: page_1.id).ranked
    end
  end

  describe 'multi-column group by' do
    describe 'via explicit list of columns' do
      it "resolves column names" do
        assert_equal [:noted_type, :noted_id], SimpleNote.lexorank_ranking.group_by
      end

      should 'correctly distinguish scopes' do
        page = Page.create!(id: 42)
        paragraph = Paragraph.create!(id: 42, page: page)
        page_note_1 = SimpleNote.create!(noted_type: "Page", noted_id: page.id).tap(&:move_to_end!)
        page_note_2 = SimpleNote.create!(noted_type: "Page",noted_id: page.id).tap(&:move_to_end!)
        paragraph_note_1 = SimpleNote.create!(noted_type: "Paragraph", noted_id: paragraph.id).tap(&:move_to_end!)
        paragraph_note_2 = SimpleNote.create!(noted_type: "Paragraph", noted_id: paragraph.id).tap(&:move_to_end!)

        assert_equal [page_note_1, page_note_2], SimpleNote.where(noted_type: "Page", noted_id: page.id).ranked
        assert_equal [paragraph_note_1, paragraph_note_2], SimpleNote.where(noted_type: "Paragraph", noted_id: paragraph.id).ranked
        assert_equal page_note_1.rank, paragraph_note_1.rank
        assert_equal page_note_2.rank, paragraph_note_2.rank
      end
    end

    describe 'via polymorphic belongs_to' do
      it "resolves column names" do
        assert_equal [:noted_type, :noted_id], PolymorphicNote.lexorank_ranking.group_by
      end

      should 'correctly distinguish scopes' do
        page = Page.create!(id: 42)
        paragraph = Paragraph.create!(id: 42, page: page)
        page_note_1 = PolymorphicNote.create!(noted: page).tap(&:move_to_end!)
        page_note_2 = PolymorphicNote.create!(noted: page).tap(&:move_to_end!)
        paragraph_note_1 = PolymorphicNote.create!(noted: paragraph).tap(&:move_to_end!)
        paragraph_note_2 = PolymorphicNote.create!(noted: paragraph).tap(&:move_to_end!)

        assert_equal [page_note_1, page_note_2], PolymorphicNote.where(noted: page).ranked
        assert_equal [paragraph_note_1, paragraph_note_2], PolymorphicNote.where(noted: paragraph).ranked
        assert_equal page_note_1.rank, paragraph_note_1.rank
        assert_equal page_note_2.rank, paragraph_note_2.rank
      end
    end
  end
end
