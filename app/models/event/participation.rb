# encoding: utf-8

#  Copyright (c) 2012-2013, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.
# == Schema Information
#
# Table name: event_participations
#
#  id                     :integer          not null, primary key
#  event_id               :integer          not null
#  person_id              :integer          not null
#  additional_information :text(65535)
#  created_at             :datetime
#  updated_at             :datetime
#  active                 :boolean          default(FALSE), not null
#  application_id         :integer
#  qualified              :boolean
#

class Event::Participation < ActiveRecord::Base

  self.demodulized_route_keys = true

  attr_accessor :enforce_required_answers

  ### ASSOCIATIONS

  belongs_to :event
  belongs_to :person

  belongs_to :application, inverse_of: :participation, dependent: :destroy, validate: true

  has_many :roles, inverse_of: :participation, dependent: :destroy

  has_many :answers, dependent: :destroy, validate: true


  accepts_nested_attributes_for :answers, :application


  ### VALIDATIONS

  validates_by_schema
  validates :person_id,
            uniqueness: { scope: :event_id }
  validates :additional_information,
            length: { allow_nil: true, maximum: 2**16 - 1 }


  ### CALLBACKS

  before_validation :init, on: :create
  before_validation :set_self_in_nested

  # There may be old participations without roles, so they must
  # update the count directly.
  after_destroy :update_participant_count


  ### CLASS METHODS

  class << self
    # Order people by the order participation types are listed in their event types.
    def order_by_role(event_type)
      joins(:roles).order(Arel.sql(order_by_role_statement(event_type)))
    end

    def order_by_role_statement(event_type)
      return '' if event_type.role_types.blank?
      statement = 'CASE event_roles.type '
      event_type.role_types.each_with_index do |t, i|
        statement << "WHEN '#{t.sti_name}' THEN #{i} "
      end
      statement << 'END'
    end

    def active
      where(active: true)
    end

    def pending
      where(active: false)
    end

    def upcoming
      joins(:event).merge(Event::upcoming(::Time.zone.today)).distinct
    end

  end


  ### INSTANCE METHODS

  def init_answers
    answers.tap do |list|
      event.questions.each do |q|
        next if list.find { |a| a.question_id == q.id }
        a = q.answers.new
        a.question = q # without this, only the id is set
        list << a
      end
    end
  end

  def init_application
    return unless applying_participant?

    (application || build_application).tap do |appl|
      appl.priority_1 = event
    end
  end

  def applying_participant?
    role = roles.first
    event.supports_applications && (application_id || role && role.class.participant?)
  end

  # Overwrite to handle improper characters
  def save(*args)
    super
  rescue ActiveRecord::StatementInvalid => e
    raise e unless e.cause.message =~ /Incorrect string value/
    errors.add(:base, :emoji_suspected)
    false
  end

  private

  def set_self_in_nested
    # don't try to set self in frozen nested attributes (-> marked for destroy)
    answers.each { |e| e.participation = self unless e.frozen? }
  end

  def init
    init_answers
    init_application
    true
  end

  def update_participant_count
    event.refresh_participant_counts!
  end
end
