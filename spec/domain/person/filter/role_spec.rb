# encoding: utf-8

#  Copyright (c) 2012-2017, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require 'spec_helper'

describe Person::Filter::Role do

  let(:user) { people(:top_leader) }
  let(:group) { groups(:top_group) }
  let(:range) { nil }
  let(:role_types) { [] }
  let(:role_type_ids_string) { role_types.collect(&:id).join(Person::Filter::Role::ID_URL_SEPARATOR) }
  let(:list_filter) do
    Person::Filter::List.new(group,
                             user,
                             range: range,
                             filters: {
                               role: {role_type_ids: role_type_ids_string }
                             })
  end

  let(:entries) { list_filter.entries }

  context 'initialize' do

    it 'ignores unknown role types' do
      filter = Person::Filter::Role.new(:role, role_types: %w(Group::TopGroup::Leader Group::BottomGroup::OldRole File Group::BottomGroup::Member))
      expect(filter.to_hash).to eq(role_types: %w(Group::TopGroup::Leader Group::BottomGroup::Member))
    end

    it 'ignores unknown role ids' do
      filter = Person::Filter::Role.new(:role, role_type_ids: %w(1 304 3 judihui))
      expect(filter.to_params).to eq(role_type_ids: '1-3')
    end

  end

  context 'filtering' do

    before do
      @tg_member = Fabricate(Group::TopGroup::Member.name.to_sym, group: groups(:top_group)).person
      Fabricate(:phone_number, contactable: @tg_member, number: '123', label: 'Privat', public: true)
      Fabricate(:phone_number, contactable: @tg_member, number: '456', label: 'Mobile', public: false)
      Fabricate(:social_account, contactable: @tg_member, name: 'facefoo', label: 'Facebook', public: true)
      Fabricate(:social_account, contactable: @tg_member, name: 'skypefoo', label: 'Skype', public: false)
      # duplicate role
      Fabricate(Group::TopGroup::Member.name.to_sym, group: groups(:top_group), person: @tg_member)
      @tg_extern = Fabricate(Role::External.name.to_sym, group: groups(:top_group)).person

      @bl_leader = Fabricate(Group::BottomLayer::Leader.name.to_sym, group: groups(:bottom_layer_one)).person
      @bl_extern = Fabricate(Role::External.name.to_sym, group: groups(:bottom_layer_one)).person

      @bg_leader = Fabricate(Group::BottomGroup::Leader.name.to_sym, group: groups(:bottom_group_one_one)).person
      @bg_member = Fabricate(Group::BottomGroup::Member.name.to_sym, group: groups(:bottom_group_one_one)).person
    end

    context 'group' do
      it 'loads all members of a group' do
        expect(entries.collect(&:id)).to match_array([user, @tg_member].collect(&:id))
      end

      it 'contains all existing members' do
        expect(entries.size).to eq(list_filter.all_count)
      end

      context 'with external types' do
        let(:role_types) { [Role::External] }
        it 'loads externs of a group' do
          expect(entries.collect(&:id)).to match_array([@tg_extern].collect(&:id))
        end

        it 'contains all existing externals' do
          expect(entries.size).to eq(list_filter.all_count)
        end
      end

      context 'with specific types' do
        let(:role_types) { [Role::External, Group::TopGroup::Member] }
        it 'loads selected roles of a group' do
          expect(entries.collect(&:id)).to match_array([@tg_member, @tg_extern].collect(&:id))
        end

        it 'contains all existing people' do
          expect(entries.size).to eq(list_filter.all_count)
        end
      end

      context 'with specific timeframe' do
        include ActiveSupport::Testing::TimeHelpers
        let(:role_types) { [Group::TopGroup::Member] }
        around(:each) { |example| travel_to(Date.new(2017, 02, 28)) { example.run } }

        context 'created' do
          let(:kind) { :created }
          before {  Role.where(person: @tg_member).update_all(created_at: '2017-02-01') }

          it 'finds role created within timeframe' do
            expect(filter(start_at: '2017-02-01').entries).to have(1).item
            expect(filter(start_at: '2017-02-01').entries).to have(1).item
            expect(filter(finish_at: '2017-02-01').entries).to have(1).item

            expect(filter(start_at: '2017-02-01', finish_at: '2017-02-01').entries).to have(1).item

            expect(filter(start_at: '2017-02-02').entries).to be_empty
            expect(filter(finish_at: '2017-01-31').entries).to be_empty
            expect(filter(start_at: '2017-02-02', finish_at: '2017-02-02').entries).to be_empty
          end
        end

        context 'deleted' do
          let(:kind) { :deleted }
          before { Role.where(person: @tg_member).update_all(deleted_at: '2017-02-01') }

          it 'finds role deleted within timeframe' do
            expect(filter(start_at: '2017-02-01').entries).to have(1).item
            expect(filter(finish_at: '2017-02-01').entries).to have(1).item

            expect(filter(start_at: '2017-02-01', finish_at: '2017-02-01').entries).to have(1).item

            expect(filter(start_at: '2017-02-02').entries).to be_empty
            expect(filter(finish_at: '2017-01-31').entries).to be_empty
            expect(filter(start_at: '2017-02-02', finish_at: '2017-02-02').entries).to be_empty

            expect(filter(start_at: '2017-02-01').all_count).to eq(1)
            expect(filter(finish_at: '2017-01-31').all_count).to eq(0)
          end
        end

        context 'active' do
          let(:kind) { :active }

          it 'finds role active within timeframe' do
            Role.where(person: @tg_member).update_all(created_at: '2017-02-01')
            expect(filter(start_at: '2017-02-01').entries).to have(1).item
            expect(filter(finish_at: '2017-02-01').entries).to have(1).item
            expect(filter(start_at: '2017-02-04').entries).to have(1).item
            expect(filter(finish_at: '2017-02-04').entries).to have(1).item

            expect(filter(start_at: '2017-01-31', finish_at: '2017-02-02').entries).to have(1).item
            expect(filter(start_at: '2017-01-02', finish_at: '2017-02-05').entries).to have(1).item
            expect(filter(start_at: '2017-01-31', finish_at: '2017-02-05').entries).to have(1).item

            expect(filter(start_at: '2017-01-30', finish_at: '2017-01-31').entries).to be_empty
            expect(filter(start_at: '2017-02-04', finish_at: '2017-02-05').entries).to have(1).item

            expect(filter(finish_at: '2017-01-31').entries).to be_empty
          end

          it 'finds deleted role active within timeframe' do
            Role.where(person: @tg_member).update_all(created_at: '2017-02-01', deleted_at: '2017-02-03')
            expect(filter(start_at: '2017-02-04').entries).to be_empty
            expect(filter(finish_at: '2017-01-31').entries).to be_empty

            expect(filter(start_at: '2017-01-31', finish_at: '2017-02-02').entries).to have(1).item
            expect(filter(start_at: '2017-01-02', finish_at: '2017-02-05').entries).to have(1).item
            expect(filter(start_at: '2017-01-31', finish_at: '2017-02-05').entries).to have(1).item

            expect(filter(start_at: '2017-01-30', finish_at: '2017-01-31').entries).to be_empty
            expect(filter(start_at: '2017-02-04', finish_at: '2017-02-05').entries).to be_empty
          end
        end

        def filter(attrs)
          filters = { role: attrs.merge(role_type_ids: role_type_ids_string, kind: kind.to_s) }
          Person::Filter::List.new(group, user, range: range, filters: filters)
        end

      end
    end

    context 'layer' do
      let(:group) { groups(:bottom_layer_one) }
      let(:range) { 'layer' }

      context 'with layer and below full' do
        let(:user) { @bl_leader }

        it 'loads group members when no types given' do
          expect(entries.collect(&:id)).to match_array([people(:bottom_member), @bl_leader].collect(&:id))
          expect(list_filter.all_count).to eq(2)
        end

        context 'with specific types' do
          let(:role_types) { [Group::BottomGroup::Member, Role::External] }

          it 'loads selected roles of a group when types given' do
            expect(entries.collect(&:id)).to match_array([@bg_member, @bl_extern].collect(&:id))
            expect(list_filter.all_count).to eq(2)
          end
        end
      end

    end

    context 'deep' do
      let(:group) { groups(:top_layer) }
      let(:range) { 'deep' }

      it 'loads group members when no types are given' do
        expect(entries.collect(&:id)).to match_array([])
      end

      context 'with specific types' do
        let(:role_types) { [Group::BottomGroup::Leader, Role::External] }

        it 'loads selected roles of a group when types given' do
          expect(entries.collect(&:id)).to match_array([@bg_leader, @tg_extern].collect(&:id))
        end

        it 'contains not all existing people' do
          expect(entries.size).to eq(list_filter.all_count - 1)
        end
      end
    end
  end
end
