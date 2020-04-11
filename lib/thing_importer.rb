# frozen_string_literal: true

require 'net/http'
require 'uri'

LOCATION_REGEX = /POINT \((?<lng>-?\d+\.\d+) (?<lat>-?\d+\.\d+)\)/.freeze

# class for importing things from CSV datasource
# is currently very specific to drains from DataSF
#
# Dataset:
# https://data.sfgov.org/City-Infrastructure/Stormwater-inlets-drains-and-catch-basins/jtgq-b7c5
class ThingImporter
  class << self
    def load(file_path)
      Rails.logger.info('Downloading Things... ... ...')

      ActiveRecord::Base.transaction do
        import_temp_things(file_path)

        deleted_things_with_adoptee, deleted_things_no_adoptee = delete_non_existing_things
        created_things = upsert_things

        # ThingMailer.thing_update_report(deleted_things_with_adoptee, deleted_things_no_adoptee, created_things).deliver_now
      end
    end

    def integer?(string)
      return true if string =~ /\A\d+\Z/

      false
    end

    def normalize_thing(csv_thing)
      # matches = csv_thing['Location'].match(LOCATION_REGEX)
      # throw "could not match location #{csv_thing['Location']}" unless matches

      {
        city_name: csv_thing['city_name'],
        city_id: csv_thing['city_id'],
        lat: csv_thing['lat'],
        lng: csv_thing['lng'],
        type: csv_thing['Drain_Type'],
        system_use_code: csv_thing['System_Use_Code'],
        priority: csv_thing['PRIORITY_STATUS'] == '1',
      }
    end

    def invalid_thing(thing)
      false unless ['Storm Water Inlet Drain', 'Catch Basin Drain'].include?(thing[:type])
      false unless integer?(thing[:city_id])
      true
    end

    # load all of the items into a temporary table, temp_thing_import
    #
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def import_temp_things(file_path)
      insert_statement_id = SecureRandom.uuid

      conn = ActiveRecord::Base.connection
      conn.execute(<<-SQL.strip_heredoc)
        CREATE TEMPORARY TABLE IF NOT EXISTS "temp_thing_import" (
          id serial,
          name varchar,
          lat numeric(16,14),
          lng numeric(17,14),
          city_id integer,
          city_name text,
          system_use_code varchar,
          priority boolean
        )
      SQL
      conn.raw_connection.prepare(insert_statement_id, 'INSERT INTO temp_thing_import (name, lat, lng, city_id, city_name, system_use_code, priority) VALUES($1, $2, $3, $4, $5, $6, $7)')

      # response = Net::HTTP.get_response(URI.parse(source_url))
      # raise 'unable to fetch data source' unless response.is_a? Net::HTTPSuccess
      # content = response.body
      content = File.read(file_path)

      CSV.parse(content, headers: true).
        map { |t| normalize_thing(t) }.
        select { |t| invalid_thing(t) }.
        each do |thing|
        conn.raw_connection.exec_prepared(
          insert_statement_id,
          [thing[:type], thing[:lat], thing[:lng], thing[:city_id], thing[:city_name], thing[:system_use_code], thing[:priority]],
        )
      end

      conn.execute('CREATE INDEX IF NOT EXISTS "temp_thing_import_city_id_city_name" ON temp_thing_import(city_id, city_name)')
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    # mark drains as deleted that do not exist in the new set
    # return the deleted drains partitioned by whether they were adopted
    def delete_non_existing_things
      # mark deleted_at as this is what the paranoia gem uses to scope
      deleted_things = ActiveRecord::Base.connection.execute(<<-SQL.strip_heredoc)
        UPDATE things
        SET deleted_at = NOW()
        WHERE things.city_id NOT IN (SELECT city_id from temp_thing_import) AND deleted_at IS NULL
        RETURNING things.city_id, things.user_id
      SQL
      deleted_things.partition { |thing| thing['user_id'].present? }
    end

    # rubocop:disable Metrics/MethodLength
    def upsert_things
      # postgresql's RETURNING returns both updated and inserted records so we
      # query for the items to be inserted first
      created_things = ActiveRecord::Base.connection.execute(<<-SQL.strip_heredoc)
        SELECT temp_thing_import.city_id, temp_thing_import.city_name
        FROM things
        RIGHT JOIN temp_thing_import ON temp_thing_import.city_id = things.city_id AND temp_thing_import.city_name = things.city_name
        WHERE things.id IS NULL
      SQL

      ActiveRecord::Base.connection.execute(<<-SQL.strip_heredoc)
        INSERT INTO things(name, lat, lng, city_id, city_name, system_use_code, priority)
        SELECT name, lat, lng, city_id, city_name, system_use_code, priority FROM temp_thing_import
        ON CONFLICT(city_id, city_name) DO UPDATE SET
          lat = EXCLUDED.lat,
          lng = EXCLUDED.lng,
          name = EXCLUDED.name,
          priority = EXCLUDED.priority,
          deleted_at = NULL
      SQL

      created_things
    end
    # rubocop:enable Metrics/MethodLength
  end
end
