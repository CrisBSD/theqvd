<table class="roles-inherit-table">
    <tr>
        <td>
            <%
                var classFixed = '';
                if (model.get('fixed') && RESTRICT_TEMPLATES) {
                    classFixed = 'hidden';
                }

                var elementsCount = 0;
                $.each(model.get('roles'), function (iRole, role) {
                    switch (inheritFilter) {
                        case "templates":
                            if (!role.internal) {
                                return;
                            }
                            break;
                        case "roles":
                            if (role.internal) {
                                return;
                            }
                            break;
                    }
                    elementsCount++;
            %>
                <div>
                    <%
                        if (Up.C.checkACL('role.update.assign-role')) {
                    %>
                            <i class="delete-role-button js-delete-role-button fa fa-times <%= classFixed %>" data-id="<%= iRole %>" data-name="<%= role.name %>" data-inherit-type="<%= inheritFilter %>" data-i18n="[title]Delete"></i>
                    <%
                        }

                    // If restrict templates flag is disabled, show templates with link like roles
                    if (role.internal && RESTRICT_TEMPLATES) {
                    %>
                        <span class="text"><%= role.name %></span>
                    <%
                    }
                    else {
                    %>
                        <%= Up.C.ifACL('<a href="#/role/' + iRole + '">', 'role.see-details.') %>
                        <span class="text"><%= role.name %></span>
                        <%= Up.C.ifACL('</a>', 'role.see-details.') %>
                    <%
                    }
                    %>
                </div>
            <%
                }); 
            %>  
            <%
                if (elementsCount == 0) {
            %>
                    <span data-i18n="No elements found" class="second_row"></span>
            <%
                }
            %>
        </td>
    </tr>
</table>