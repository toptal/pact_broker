require "pact_broker/db"
require "pact_broker/repositories/helpers"

module PactBroker
  module Versions
    class BranchVersion < Sequel::Model(:branch_versions)
      plugin :timestamps, update_on_create: true
      plugin :insert_ignore, identifying_columns: [:branch_id, :version_id]
      plugin :upsert, identifying_columns: [:branch_id, :version_id]

      associate(:many_to_one, :branch, :class => "PactBroker::Versions::Branch", :key => :branch_id, :primary_key => :id)
      associate(:many_to_one, :version, :class => "PactBroker::Domain::Version", :key => :version_id, :primary_key => :id)
      associate(:many_to_one, :branch_head, :class => "PactBroker::Versions::BranchHead", :key => :branch_id, :primary_key => :branch_id)

      dataset_module do
        def find_latest_for_branch(branch)
          max_version_order = BranchVersion.select(Sequel.function(:max, :version_order)).where(branch_id: branch.id)
          BranchVersion.where(branch_id: branch.id, version_order: max_version_order).single_record
        end
      end

      def before_save
        super
        self.version_order = version.order
        self.pacticipant_id = version.pacticipant_id
        self.branch_name = branch.name
      end

      def latest?
        branch_head.branch_version_id == id
      end

      def version_number
        version.number
      end

      def pacticipant
        branch.pacticipant
      end
    end
  end
end

# Table: branch_versions
# Columns:
#  id             | integer                     | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  branch_id      | integer                     | NOT NULL
#  version_id     | integer                     | NOT NULL
#  version_order  | integer                     | NOT NULL
#  pacticipant_id | integer                     | NOT NULL
#  branch_name    | text                        | NOT NULL
#  created_at     | timestamp without time zone | NOT NULL
#  updated_at     | timestamp without time zone | NOT NULL
#  auto_created   | boolean                     | DEFAULT false
# Indexes:
#  branch_versions_pkey                                         | PRIMARY KEY btree (id)
#  branch_versions_branch_id_version_id_index                   | UNIQUE btree (branch_id, version_id)
#  branch_versions_branch_name_index                            | btree (branch_name)
#  branch_versions_pacticipant_id_branch_id_version_order_index | btree (pacticipant_id, branch_id, version_order)
#  branch_versions_version_id_index                             | btree (version_id)
# Foreign key constraints:
#  branch_versions_branches_fk | (branch_id) REFERENCES branches(id) ON DELETE CASCADE
#  branch_versions_versions_fk | (version_id) REFERENCES versions(id) ON DELETE CASCADE
# Referenced By:
#  branch_heads | branch_heads_branch_version_id_fkey | (branch_version_id) REFERENCES branch_versions(id) ON DELETE CASCADE
