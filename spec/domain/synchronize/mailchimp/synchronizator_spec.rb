require 'spec_helper'
require 'digest/md5'

describe Synchronize::Mailchimp::Synchronizator do
  let(:user)         { people(:top_leader) }
  let(:mailing_list) { mailing_lists(:leaders) }

  subject { Synchronize::Mailchimp::Synchronizator.new(mailing_list, rescued: false) }

  before :each do
    mailing_list.update!(mailchimp_list_id: 123456789,
                         mailchimp_api_key: '1234567890d66d25cc5c9285ab5a5552-us12')
  end

  context '#missing_people' do
    it 'is empty without people' do
      expect(subject.missing_people).to be_empty
    end

    it 'includes user if email not yet in mailchimp' do
      mailing_list.subscriptions.create!(subscriber: user)

      expect(subject).to receive(:mailchimp_emails).and_return([])
      expect(subject.missing_people).to eq([user])
    end

    it 'is empty if email is on mailchimp' do
      mailing_list.subscriptions.create!(subscriber: user)

      expect(subject).to receive(:mailchimp_emails).and_return([user.email])
      expect(subject.missing_people).to be_empty
    end
  end

  context '#obsolete_emails' do
    it 'is empty when mailchimp is empty' do
      allow(subject).to receive(:mailchimp_emails).and_return([])
      expect(subject.obsolete_emails).to be_empty
    end

    it 'includes email when in mailchimp to but not on list' do
      allow(subject).to receive(:mailchimp_emails).and_return([user.email])
      expect(subject.obsolete_emails).to eq([user.email])
    end

    it 'is empty if user is on list and in mailchimp' do
      mailing_list.subscriptions.create!(subscriber: user)

      allow(subject).to receive(:mailchimp_emails).and_return([user.email])
      expect(subject.obsolete_emails).to be_empty
    end
  end


  context '#call' do
    let(:client)       { subject.client }

    before do
      subject.member_fields = []
      subject.merge_fields  = []

      allow(client).to receive(:fetch_merge_fields).and_return([])
      allow(client).to receive(:fetch_segments).and_return([])
      allow(client).to receive(:fetch_members).and_return([])
    end

    def member(person, tags = [])
      client.subscriber_body(person).merge(tags: tags)
    end

    context 'result' do
      let(:result)       { subject.result }
      subject            { Synchronize::Mailchimp::Synchronizator.new(mailing_list, rescued: true) }

      def batch_result(total, finished, errored)
        {
          'total_operations' => total,
          'finished_operations' => finished,
          'errored_operations' => errored
        }
      end

      it 'handles exception and persists on result' do
        allow(client).to receive(:fetch_merge_fields).and_raise ArgumentError.new('ouch')
        subject.call
        expect(result.data[:exception]).to eq 'ArgumentError - ouch'
        expect(result.state).to eq :failed

        expect(mailing_list.mailchimp_result.data[:exception]).to eq 'ArgumentError - ouch'
        expect(mailing_list.mailchimp_result.state).to eq :failed
      end

      it 'resets sync flag in case of exception' do
        allow(client).to receive(:fetch_merge_fields).and_raise ArgumentError.new('ouch')
        subject.call
        expect(mailing_list.mailchimp_syncing).to eq false
        expect(mailing_list.mailchimp_last_synced_at).to be_nil
      end

      it 'has result for empty sync' do
        subject.call
        expect(mailing_list.mailchimp_syncing).to eq false
        expect(mailing_list.mailchimp_result.state).to eq :unchanged
        expect(mailing_list.mailchimp_last_synced_at).to be_present
      end

      it 'has result for successful sync' do
        allow(client).to receive(:fetch_members).and_return([{ email_address: user.email }])
        expect(client).to receive(:delete).with([user.email]).and_return(batch_result(1,1,0))
        subject.call
        expect(mailing_list.mailchimp_syncing).to eq false
        expect(mailing_list.mailchimp_result.state).to eq :success
        expect(mailing_list.mailchimp_last_synced_at).to be_present
      end

      it 'has result for partial sync' do
        allow(client).to receive(:fetch_members).and_return([{ email_address: user.email }])
        expect(client).to receive(:delete).with([user.email]).and_return(batch_result(2,1,1))
        subject.call
        expect(mailing_list.mailchimp_syncing).to eq false
        expect(mailing_list.mailchimp_result.state).to eq :partial
        expect(mailing_list.mailchimp_last_synced_at).to be_present
      end

      it 'has result for two operations sync' do
        mailing_list.subscriptions.create!(subscriber: user)
        allow(client).to receive(:fetch_members).and_return([{ email_address: "other@example.com" }])
        expect(client).to receive(:subscribe).with([user]).and_return(batch_result(1,1,0))
        expect(client).to receive(:delete).with(["other@example.com"]).and_return(batch_result(2,1,1))
        subject.call
        expect(mailing_list.mailchimp_syncing).to eq false
        expect(mailing_list.mailchimp_result.state).to eq :partial
        expect(mailing_list.mailchimp_last_synced_at).to be_present
      end
    end

    context 'merge fields' do
      let(:merge_field) {
        [ 'Gender', 'dropdown', { choices: %w(m w) }, ->(p) { person.gender } ]
      }

      it 'creates with empty list if no merge fields are set' do
        allow(client).to receive(:fetch_merge_fields).and_return([])
        expect(client).to receive(:create_merge_fields).with([])
        subject.call
      end

      it 'creates missing merge field' do
        subject.merge_fields = [merge_field]

        allow(client).to receive(:fetch_merge_fields).and_return([])
        expect(client).to receive(:create_merge_fields).with([merge_field])
        subject.call
      end

      it 'creates with empty list if merge field already exists' do
        subject.merge_fields = [merge_field]
        allow(client).to receive(:fetch_merge_fields).and_return([{ tag: 'GENDER', }])
        expect(client).to receive(:create_merge_fields).with([])
        subject.call
      end
    end

    context 'create segments' do
      let(:tags) { %w(foo bar) }

      it 'creates with empty list if no tags are present' do
        allow(client).to receive(:fetch_members).and_return([member(user)])
        mailing_list.subscriptions.create!(subscriber: user)
        expect(client).to receive(:create_segments).with([])
        subject.call
      end

      it 'creates missing tags' do
        tags.each { |tag| user.tags.create!(name: tag) }
        mailing_list.subscriptions.create!(subscriber: user)

        allow(client).to receive(:fetch_members).and_return([member(user)])
        expect(client).to receive(:fetch_segments).and_return([])
        expect(client).to receive(:create_segments).with(%w(foo bar))
        expect(client).to receive(:update_segments).with(anything)
        subject.call
      end

      it 'creates with empty list if tags are already present' do
        tags.each { |tag| user.tags.create!(name: tag) }
        mailing_list.subscriptions.create!(subscriber: user)
        remote_tags = tags.collect.each_with_index do |tag, index|
          { id: index, name: tag, member_count: 0 }
        end
        allow(client).to receive(:fetch_members).and_return([member(user)])
        expect(client).to receive(:fetch_segments).and_return(remote_tags)
        expect(client).to receive(:update_segments).with(anything)
        subject.call
      end
    end

    context 'update segments' do
      let(:tags) { %w(foo bar) }
      let(:remote_tags) do
        tags.collect.each_with_index do |tag, index|
        { id: index, name: tag, member_count: 0 }
        end
      end

      it 'creates with empty list if no tags are present' do
        allow(client).to receive(:fetch_members).and_return([member(user)])
        mailing_list.subscriptions.create!(subscriber: user)
        expect(client).to receive(:update_segments).with([])
        subject.call
      end

      it 'updates missing tags' do
        tags.each { |tag| user.tags.create!(name: tag) }
        mailing_list.subscriptions.create!(subscriber: user)

        allow(client).to receive(:fetch_members).and_return([member(user)])
        expect(client).to receive(:fetch_segments).thrice.and_return(remote_tags)
        expect(client).to receive(:update_segments).with([[0, %w(top_leader@example.com)],
                                                          [1, %w(top_leader@example.com)]])
        subject.call
      end

      it 'updates single tag' do
        tags.each { |tag| user.tags.create!(name: tag) }
        mailing_list.subscriptions.create!(subscriber: user)
        allow(client).to receive(:fetch_members).and_return([member(user, remote_tags.take(1))])
        expect(client).to receive(:fetch_segments).thrice.and_return(remote_tags)
        expect(client).to receive(:update_segments).with([[1, %w(top_leader@example.com)]])
        subject.call
      end

      it 'creates with empty list if al tags are present' do
        tags.each { |tag| user.tags.create!(name: tag) }
        mailing_list.subscriptions.create!(subscriber: user)
        allow(client).to receive(:fetch_members).and_return([member(user, remote_tags)])
        expect(client).to receive(:fetch_segments).thrice.and_return(remote_tags)
        expect(client).to receive(:update_segments).with([])
        subject.call
      end

      it 'deletes obsolete segments' do
        mailing_list.subscriptions.create!(subscriber: user)
        user.tags.create!(name: tags.first)
        allow(client).to receive(:fetch_members).and_return([member(user, remote_tags.take(1))])
        expect(client).to receive(:fetch_segments).thrice.and_return(remote_tags)
        expect(client).to receive(:update_segments).with([])
        expect(client).to receive(:delete_segments).with([1])
        subject.call
      end
    end

    context 'subscriptions' do
      it 'calls operations with empty lists' do
        expect(client).to receive(:subscribe).with([])
        expect(client).to receive(:delete).with([])

        subject.call
      end

      it 'subscribes missing person' do
        allow(client).to receive(:fetch_members).and_return([])
        mailing_list.subscriptions.create!(subscriber: user)

        expect(client).to receive(:subscribe).with([user])
        expect(client).to receive(:delete).with([])

        subject.call
      end

      it 'ignores person without email' do
        allow(client).to receive(:fetch_members).and_return([])
        user.update(email: nil)
        mailing_list.subscriptions.create!(subscriber: user)

        expect(client).to receive(:subscribe).with([])
        expect(client).to receive(:delete).with([])

        subject.call
      end

      it 'removes obsolete person' do
        allow(client).to receive(:fetch_members).and_return([{ email_address: user.email }])

        expect(client).to receive(:subscribe).with([])
        expect(client).to receive(:delete).with([user.email])

        subject.call
      end
    end

    context 'update members' do

      it 'updates changed first name' do
        mailing_list.subscriptions.create!(subscriber: user)
        allow(client).to receive(:fetch_members).and_return([member(user)])

        user.update(first_name: 'topster')
        expect(client).to receive(:update_members).with([user])
        subject.call
      end

    end

  end
end
