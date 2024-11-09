ActiveRecord::Schema.define(version: 2020_10_02_124236) do
  def collation_by_db
    case ENV['DB']
    when 'mysql'
      'ascii_bin'
    when 'postgresql'
      'C'
    else
      nil
    end
  end

  create_table "pages", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "rank", collation: collation_by_db
    t.string "other_ranking_field", collation: collation_by_db
    t.index ["rank"], name: "index_pages_on_rank", unique: true
    t.index ["other_ranking_field"], name: "index_pages_on_other_ranking_field", unique: true
  end

  create_table "paragraphs", force: :cascade do |t|
    t.bigint "page_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "rank", collation: collation_by_db
    t.index ["rank", "page_id"], name: "index_pages_on_rank_and_page_id", unique: true
    t.index ["page_id"], name: "index_pages_on_resource_id"
  end

  create_table "notes", force: :cascade do |t|
    t.string "noted_type", null: false
    t.bigint "noted_id", null: false
    t.string "rank", collation: collation_by_db
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["noted_type", "noted_id", "rank"], name: "index_notes_on_noted_and_rank", unique: true
  end
end
