<div class="details-header">
    <span class="fa fa-suitcase h1"><%= model.get('name') %></span>
    <div class="clear mobile"></div>
    <a class="button2 fright fa fa-eye js-show-details-actions" data-options-state="hidden" data-i18n="Actions"></a>
    
    <% if(Up.C.checkACL('administrator.delete.') && Up.C.adminID != model.get('id')) { %>
    <a class="button fleft button-icon--desktop js-button-delete fa fa-trash" href="javascript:" data-i18n="[title]Delete"><span data-i18n="Delete" class="mobile"></span></a>
    <% } %>
    
    <% if(Up.C.checkGroupACL('administratorEdit')) { %>
    <a class="button fright button-icon--desktop js-button-edit fa fa-pencil" href="javascript:" data-i18n="[title]Edit"><span data-i18n="Edit" class="mobile"></span></a>
    <% } %>
    
    <% if(Up.C.checkACL('administrator.update.assign-role')) { %>
    <a class="button fright button-icon--desktop js-tools-roles-btn <%= CLASS_ICON_ROLES %>" href="javascript:" data-i18n="[title]Assign roles"><span data-i18n="Assign roles" class="mobile"></span></a>
    <% } %>
    
    <div class="clear mobile"></div>
</div>

<table class="details details-list col-width-100">
    <%   
    if (Up.C.isSuperadmin()) { 
    %>
        <tr>
            <td><i class="<%= CLASS_ICON_TENANTS %>"></i><span data-i18n="Tenant"></span></td>
            <td>
                <%= Up.C.ifACL('<a href="#/tenant/' + model.get('tenant_id') + '">', 'tenant.see-details.') %>
                <%= model.get('tenant_name') %>
                <%= Up.C.ifACL('</a>', 'tenant.see-details.') %>
            </td>
        </tr>
    <%   
    }
    if (Up.C.checkACL('administrator.see.id')) { 
    %>
        <tr>
            <td><i class="fa fa-asterisk"></i><span data-i18n="Id"></span></td>
            <td>
                <%= model.get('id') %>
            </td>
        </tr>
    <% 
    }
    if (Up.C.checkACL('administrator.see.description')) { 
    %>
        <tr>
            <td><i class="fa fa-align-justify"></i><span data-i18n="Description"></span></td>
            <td>
                <% 
                if (model.get('description')) { 
                %>
                    <%= model.get('description').replace(/\n/g, '<br>') %>
                <%
                }
                else {
                %>
                    <span class="second_row">-</span>
                <%
                }
                %>
            </td>
        </tr>
    <% 
    }
    if (Up.C.checkACL('administrator.see.language')) { 
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
    if (Up.C.checkACL('administrator.see.roles')) {
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
                                <div data-role-id="<%= iRole %>">
                                    <%
                                        if (Up.C.checkACL('administrator.update.assign-role')) {
                                    %>
                                            <i class="delete-role-button js-delete-role-button fa fa-times" data-id="<%= iRole %>" data-name="<%= role %>" data-inherit-type="roles" data-i18n="[title]Delete"></i>
                                    <%
                                        }
                                    %>

                                    <%= Up.C.ifACL('<a href="#/role/' + iRole + '">', 'role.see-details.') %>
                                    <span class="text"><%= role %></span>
                                    <%= Up.C.ifACL('</a>', 'role.see-details.') %>
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
                </table>
            </td>
        </tr>
    <% 
    }
    if (Up.C.checkACL('administrator.see.created-by')) {
    %>
        <tr>
            <td><i class="<%= CLASS_ICON_ADMINS %>"></i><span data-i18n="Created by"></span></td>
            <td>
                <span><%= model.get('creation_admin_name') %></span>
            </td>
        </tr>
    <% 
    }
    if (Up.C.checkACL('administrator.see.creation-date')) {
    %>
        <tr>
            <td><i class="fa fa-clock-o"></i><span data-i18n="Creation date"></span></td>
            <td>
                <span><%= model.get('creation_date') %></span>
            </td>
        </tr>
    <% 
    }
    if (Up.C.isMultitenant()) { 
    %>
        <tr>
            <td><i class="fa fa-sitemap"></i><span data-i18n="Global username">Global username</span></td>
            <td>
                 <%= Up.C.getLoginData(model.get('name'), model.get('tenant_name')) %>
            </td>
        </tr>
    <%   
    }
    %>
</table>

<div class="bb-admin-roles admin-roles"></div>

