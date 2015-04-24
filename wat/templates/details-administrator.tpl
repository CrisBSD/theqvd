<div class="details-header">
    <span class="fa fa-suitcase h1"><%= model.get('name') %></span>
    <% if(Wat.C.checkACL('administrator.delete.')) { %>
    <a class="button fleft button-icon js-button-delete fa fa-trash" href="javascript:" data-i18n="[title]Delete"></a>
    <% } %>
    
    <% if(Wat.C.checkGroupACL('administratorEdit')) { %>
    <a class="button fright button-icon js-button-edit fa fa-pencil" href="javascript:" data-i18n="[title]Edit"></a>
    <% } %>
</div>

<table class="details details-list col-width-100">
    <% 
    if (Wat.C.checkACL('administrator.see.id')) { 
    %>
    <tr>
        <td><i class="fa fa-male"></i><span data-i18n="Id"></span></td>
        <td>
            <%= model.get('id') %>
        </td>
    </tr>
    <% 
    }
    if(Wat.C.isSuperadmin()) { 
    %>
    <tr>
        <td><i class="fa fa-building"></i><span data-i18n="Tenant"></span></td>
        <td>
            <%= model.get('tenant_name') %>
        </td>
    </tr>
    <% } %>
    <% 
    if (Wat.C.checkACL('administrator.see.language')) { 
    %>
    <tr>
        <td><i class="fa fa-globe"></i><span data-i18n="Language"></span></td>
        <td>
            <span data-i18n="<%= WAT_LANGUAGE_ADMIN_OPTIONS[model.get('language')] %>"></span>
            <%
            switch (model.get('language')) {
                case  'auto':
            %>
                    <div class="second_row" data-i18n="Language will be detected from the browser"></div>
            <%
                    break;
                case 'default':
            %>
                    <div class="second_row" data-i18n="The default language of the system"></div>
            <%
                    break;
            }
            %>
        </td>
    </tr>
    <% 
    }
    if (Wat.C.checkACL('administrator.see.created-by')) {
    %>
        <tr>
            <td><i class="<%= CLASS_ICON_ADMINS %>"></i><span data-i18n="Created by"></span></td>
            <td>
                <span><%= model.get('creation_admin_name') %></span>
            </td>
        </tr>
    <% 
    }
    if (Wat.C.checkACL('administrator.see.creation-date')) {
    %>
        <tr>
            <td><i class="fa fa-clock-o"></i><span data-i18n="Creation date"></span></td>
            <td>
                <span><%= model.get('creation_date') %></span>
            </td>
        </tr>
    <% 
    }
    if (Wat.C.checkACL('administrator.see.roles')) {
    %>
        <tr>
            <td><i class="<%= CLASS_ICON_ROLES %>"></i><span data-i18n="Assigned roles"></span></td>
            <td>
                <table class="roles-inherit-table">
                    <tr>
                        <td>
                            <%
                                $.each(model.get('roles'), function (iRole, role) {
                            %>
                                <div>
                                    <%
                                        if (Wat.C.checkACL('administrator.update.assign-role')) {
                                    %>
                                            <i class="delete-role-button js-delete-role-button fa fa-trash-o" data-id="<%= iRole %>" data-name="<%= role %>"></i>
                                    <%
                                        }
                                    %>

                                    <%= Wat.C.ifACL('<a href="#/role/' + iRole + '">', 'role.see-details.') %>
                                    <span class="text"><%= role %></span>
                                    <%= Wat.C.ifACL('</a>', 'role.see-details.') %>
                                </div>
                            <%
                                }); 
                            %>  
                            <%
                                if (Object.keys(model.get('roles')).length == 0) {
                            %>
                                    <span data-i18n="No elements found"></span>
                            <%
                                }
                            %>
                        </td>
                    </tr>
                    <% 
                    }
                    %>
                </table>
            </td>
        </tr>
</table>

<div class="bb-admin-roles admin-roles"></div>

