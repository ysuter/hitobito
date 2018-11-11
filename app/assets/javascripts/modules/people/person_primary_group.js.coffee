#  Copyright (c) 2012-2016, Dachverband Schweizer Jugendparlamente. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

app = window.App ||= {}

app.PersonPrimaryGroup = {
  setPrimaryGroup: (e) ->
    selected = $('#primary-group-select option:selected')
    url = selected.attr('data-url')
    $.ajax({ url: url, method: "PUT", dataType: "script"})
  showEditForm: (e) ->
    $('.edit-primary-group-form').show();
    $('#edit-primary-group').hide();
  hideEditForm: (e) ->
    $('.edit-primary-group-form').hide();
    $('#edit-primary-group').show();
  updateRolesAside: (rolesAside) ->
    $('section.roles').replaceWith(rolesAside)
    $('section.roles').effect( "highlight" );
}

$(document).on('change', '#primary-group-select', app.PersonPrimaryGroup.setPrimaryGroup)
$(document).on('click', '#show-primary-group-form', app.PersonPrimaryGroup.showEditForm)
$(document).on('click', '#hide-primary-group-form', app.PersonPrimaryGroup.hideEditForm)
