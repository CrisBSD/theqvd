<table>
    <% if (Wat.C.checkACL('vm.update.name')) { %>
    <tr>
        <td data-i18n="Name"></td>
        <td>
            <input type="text" class="" name="name" value="<%= model.get('name') %>" data-required>
        </td>
    </tr>
    <% } %>
    <% if (Wat.C.checkACL('vm.update.description')) { %>
    <tr>
        <td data-i18n="Description"></td>
        <td>
            <textarea id="name" type="text" name="description"><%= model.get('description') %></textarea>
        </td>
    </tr>
    <% } %>
    <tr>
        <td data-i18n="Image tag"></td>
        <td>
            <select class="" name="di_tag"></select>
        </td>
    </tr>
    <%
        var expirationRowClass = 'hidden expiration_row';
        var expirationChecked = '';
        if (model.get('expiration_soft') || model.get('expiration_hard')) {
        var expirationRowClass = 'expiration_row';
            var expirationChecked = 'checked';
        }
    %>
    <tr>
        <td data-i18n="Expire"></td>
        <td>
            <input type="checkbox" class="js-expire" name="expire" value="1" <%= expirationChecked %>>
        </td>
    </tr>
    <tr class="<%= expirationRowClass %>">
        <td data-i18n="Soft expiration"></td>
        <td>
            <input type="text" class="datetimepicker" name="expiration_soft" value="<%= model.get('expiration_soft') ? model.get('expiration_soft').replace('T',' ') : '' %>">
        </td>
    </tr>
    <tr class="<%= expirationRowClass %>">
        <td data-i18n="Hard expiration"></td>
        <td>
            <input type="text" class="datetimepicker" name="expiration_hard" value="<%= model.get('expiration_hard') ? model.get('expiration_hard').replace('T',' ') : '' %>">
        </td>
    </tr>
 </table>