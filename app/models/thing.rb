# frozen_string_literal: true

require 'open-uri'
require 'csv'

class Thing < ApplicationRecord
  acts_as_paranoid
  extend Forwardable
  include ActiveModel::ForbiddenAttributesProtection

  VALID_DRAIN_TYPES = ['Storm Water Inlet Drain', 'Catch Basin Drain'].freeze

  belongs_to :user
  def_delegators :reverse_geocode, :city, :country, :country_code,
                 :full_address, :state, :street_address, :street_name,
                 :street_number, :zip
  has_many :reminders, dependent: :destroy
  validates :city_id, uniqueness: true, allow_nil: true
  validates :lat, presence: true
  validates :lng, presence: true
  validates :name, obscenity: true
  validates :debris_removed_pounds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :adopted, -> { where.not(user_id: nil) }

  def self.find_closest(lat, lng, limit = 10)
    query = <<-SQL
      SELECT *, geom_point <-> ST_SetSRID(ST_MakePoint(?, ?), 4326) as distance
      FROM things
      WHERE deleted_at is NULL
      ORDER BY distance
      LIMIT ?
    SQL
    find_by_sql([query, lng.to_f, lat.to_f, limit.to_i])
  end

  def display_name
    (adopted? ? adopted_name : name) || ''
  end

  def reverse_geocode
    @reverse_geocode ||= Geokit::Geocoders::MultiGeocoder.reverse_geocode([lat, lng])
  end

  def adopted?
    !user.nil?
  end

  def as_json(options = {})
    super({methods: [:display_name]}.merge(options))
  end
end
