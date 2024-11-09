class SimpleNote < Base
  self.table_name = "notes"

  rank!(group_by: [:noted_type, :noted_id])
end

class PolymorphicNote < SimpleNote
  belongs_to :noted, polymorphic: true

  rank!(group_by: :noted)
end
