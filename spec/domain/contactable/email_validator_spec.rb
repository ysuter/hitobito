# frozen_string_literal: true

require 'spec_helper'

describe Contactable::EmailValidator do
  let(:validator) { described_class.new }
  let(:top_leader) { people(:top_leader) }
  let(:bottom_member) { people(:bottom_member) }

  before { allow(Truemail).to receive(:valid?).and_call_original }

  it 'tags people with invalid primary e-mail' do
    top_leader.email = 'not-an-email'
    top_leader.save!(validate: false)

    validator.validate_people

    leader_tagging = taggings_for(top_leader).first
    expect(leader_tagging.tag.name).to eq('t_email:primary-invalid')
    expect(leader_tagging.context).to eq('tags')
    expect(leader_tagging.hitobito_tooltip).to eq('not-an-email')
  end

  it 'tags people with invalid additional e-mail' do
    top_leader.email = 'not-an-email'
    top_leader.save!(validate: false)

    validator.validate_people

    leader_tagging = taggings_for(top_leader).first
    expect(leader_tagging.tag.name).to eq('t_email:additional-invalid')
    expect(leader_tagging.context).to eq('tags')
    expect(leader_tagging.hitobito_tooltip).to eq('not-an-email')
  end

  private

  def taggings_for(person)
    ActsAsTaggableOn::Tagging
      .where(taggable: person)
  end

end
