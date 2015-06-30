<table class="role-template-tools">
    <thead>
        <tr>
            <th><span data-i18n="Inherited"></span></th>
            <th><span data-i18n="Role"></span></th>
        </tr>
    </thead>
    <tbody>
<%
    $.each(roles, function (iRole, role) {
        %>
            <tr>
                <td class="center">
                    <input type="checkbox" class="js-add-role-button" <%= role.inherited ? 'checked="checked"' : '' %> data-role-template-id="<%= role.id %>"/>
                </td>
                <td class="left">
                    <%= role.name %>
                </td>
            </tr>
        <%
    });
%>
    </tbody>
</table>
