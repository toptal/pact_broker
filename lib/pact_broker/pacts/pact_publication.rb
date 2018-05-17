require 'pact_broker/domain/pact'
require 'pact_broker/pacts/pact_version'
require 'pact_broker/repositories/helpers'

module PactBroker
  module Pacts
    class PactPublication < Sequel::Model(:pact_publications)

      extend Forwardable

      delegate [:consumer, :consumer_version_number, :name, :provider_name, :consumer_name] => :cached_domain_for_delegation

      set_primary_key :id
      associate(:many_to_one, :provider, :class => "PactBroker::Domain::Pacticipant", :key => :provider_id, :primary_key => :id)
      associate(:many_to_one, :consumer_version, :class => "PactBroker::Domain::Version", :key => :consumer_version_id, :primary_key => :id)
      associate(:many_to_one, :pact_version, class: "PactBroker::Pacts::PactVersion", :key => :pact_version_id, :primary_key => :id)

      dataset_module do
        include PactBroker::Repositories::Helpers
      end

      def before_create
        super
        self.revision_number ||= 1
      end

      def latest_tag_names
        LatestTaggedPactPublications.where(id: id).select(:tag_name).collect{|t| t[:tag_name]}
      end

      def latest_verification
        pact_version.latest_verification
      end

      def to_domain
        PactBroker::Domain::Pact.new(
          id: id,
          provider: provider,
          consumer: consumer_version.pacticipant,
          consumer_version_number: consumer_version.number,
          consumer_version: to_version_domain,
          revision_number: revision_number,
          json_content: pact_version.content,
          pact_version_sha: pact_version.sha,
          latest_verification: latest_verification,
          created_at: created_at
          )
      end

      def to_version_domain
        OpenStruct.new(number: consumer_version.number, pacticipant: consumer_version.pacticipant, tags: consumer_version.tags, order: consumer_version.order)
      end

      private

      def cached_domain_for_delegation
        @domain_object ||= to_domain
      end
    end

    PactPublication.plugin :timestamps, update_on_create: true
  end
end

# Table: pact_publications
# Columns:
#  id                  | integer                     | PRIMARY KEY DEFAULT nextval('pact_publications_id_seq'::regclass)
#  consumer_version_id | integer                     | NOT NULL
#  provider_id         | integer                     | NOT NULL
#  revision_number     | integer                     | NOT NULL
#  pact_version_id     | integer                     | NOT NULL
#  created_at          | timestamp without time zone | NOT NULL
# Indexes:
#  pact_publications_pkey | PRIMARY KEY btree (id)
#  cv_prov_revision_unq   | UNIQUE btree (consumer_version_id, provider_id, revision_number)
#  cv_prov_id_ndx         | btree (consumer_version_id, provider_id, id)
# Foreign key constraints:
#  pact_publications_consumer_version_id_fkey | (consumer_version_id) REFERENCES versions(id)
#  pact_publications_pact_version_id_fkey     | (pact_version_id) REFERENCES pact_versions(id)
#  pact_publications_provider_id_fkey         | (provider_id) REFERENCES pacticipants(id)
# Referenced By:
#  triggered_webhooks | triggered_webhooks_pact_publication_id_fkey | (pact_publication_id) REFERENCES pact_publications(id)
#  webhook_executions | webhook_executions_pact_publication_id_fkey | (pact_publication_id) REFERENCES pact_publications(id)