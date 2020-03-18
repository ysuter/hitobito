require 'spec_helper'
require 'digest/md5'

describe Synchronize::Mailchimp::Synchronizator do
  let(:user)         { people(:top_leader) }
  let(:mailing_list) { mailing_lists(:leaders) }

  subject { Synchronize::Mailchimp::Synchronizator.new(mailing_list) }

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
    def result(total, finished, errored)
      {
        'total_operations' => total,
        'finished_operations' => finished,
        'errored_operations' => errored
      }
    end

    it 'calls operations with empty lists' do
      allow(subject).to receive(:mailchimp_emails).and_return([])

      expect(subject.client).to receive(:subscribe).with([])
      expect(subject.client).to receive(:delete).with([])

      subject.call
      expect(subject.result.state).to eq :unchanged
      expect(mailing_list.reload.mailchimp_result).to be_present
      expect(mailing_list.mailchimp_last_synced_at).to be_present
    end

    it 'subscribes missing person' do
      allow(subject).to receive(:mailchimp_emails).and_return([])
      mailing_list.subscriptions.create!(subscriber: user)

      expect(subject.client).to receive(:subscribe).with([user])
      expect(subject.client).to receive(:delete).with([])

      subject.call
    end

    it 'removes obsolete person' do
      allow(subject).to receive(:mailchimp_emails).and_return([user.email])

      expect(subject.client).to receive(:subscribe).with([])
      expect(subject.client).to receive(:delete).with([user.email])

      subject.call
    end

    it 'knows about partial result' do
      allow(subject).to receive(:mailchimp_emails).and_return([user.email])

      expect(subject.client).to receive(:subscribe).with([])
      expect(subject.client).to receive(:delete).with([user.email]).and_return(result(2,1,1))

      subject.call
      expect(subject.result.state).to eq :partial
    end

  end
end
