# encoding: utf-8

#  Copyright (c) 2012-2013, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

# This class is only used for fetching lists based on a group association.
class PersonReadables < PersonFetchables

  self.same_group_permissions  = [:group_full, :group_read,
                                  :group_and_below_full, :group_and_below_read]
  self.above_group_permissions = [:group_and_below_full, :group_and_below_read]
  self.same_layer_permissions  = [:layer_full, :layer_read,
                                  :layer_and_below_full, :layer_and_below_read]
  self.above_layer_permissions = [:layer_and_below_full, :layer_and_below_read]

  attr_reader :group

  delegate :permission_group_ids, :permission_layer_ids, to: :user_context

  def initialize(user, group = nil, with_deleted_roles = false)
    super(user)
    @group = group
    @with_deleted_roles = with_deleted_roles

    if @group.nil?
      can :index, Person, accessible_people { |_| true }
    else # optimized queries for a given group
      group_accessible_people
    end
  end

  private

  def group_accessible_people
    if read_permission_for_this_group?
      can :index, Person, person_public_data_with_roles(group) { |_| true }

    elsif layer_and_below_read_in_above_layer?
      can :index, Person, person_public_data_with_roles(group).visible_from_above(group) { |_| true }
    elsif contact_data_visible?
      can :index, Person, person_public_data_with_roles(group).contact_data_visible { |_| true }
    end
  end

  def accessible_people
    if user.root?
      person_public_data
    else
      person_public_data_with_roles
        .where(accessible_conditions.to_a)
        .uniq
    end
  end

  def person_public_data
    Person.only_public_data
  end

  def person_public_data_with_roles(group = nil)
    scope = person_public_data.join_roles(@with_deleted_roles).where(groups: { deleted_at: nil })
    group ? scope.where(groups: { id: group.id }) : scope
  end

  def accessible_conditions
    OrCondition.new.tap do |condition|
      condition.or(*herself_condition)
      condition.or(*contact_data_condition) if contact_data_visible?
      append_group_conditions(condition)
    end
  end

  def contact_data_condition
    ['people.contact_data_visible = ?', true]
  end

  def herself_condition
    ['people.id = ?', user.id]
  end

  def read_permission_for_this_group?
    user.root? ||
    group_read_in_this_group? ||
    group_read_in_above_group? ||
    layer_read_in_same_layer? ||
    layer_and_below_read_in_same_layer?
  end

  def contact_data_visible?
    user.contact_data_visible?
  end

  def group_read_in_this_group?
    permission_group_ids(:group_read).include?(group.id)
  end

  def group_read_in_above_group?
    ids = permission_group_ids(:group_and_below_read)
    ids.present? && (ids & group.local_hierarchy.collect(&:id)).present?
  end

  def layer_read_in_same_layer?
    permission_layer_ids(:layer_read).include?(group.layer_group_id)
  end

  def layer_and_below_read_in_same_layer?
    permission_layer_ids(:layer_and_below_read).include?(group.layer_group_id)
  end

  def layer_and_below_read_in_above_layer?
    ids = permission_layer_ids(:layer_and_below_read)
    ids.present? && (ids & group.layer_hierarchy.collect(&:id)).present?
  end

  def with_deleted_roles?
    @with_deleted_roles
  end

end
