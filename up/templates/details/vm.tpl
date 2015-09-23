<div class="h2" data-i18n="Details of the Virtual Machine"></div>
<table class="details details-list">
    <tbody>
        <tr>
            <td>
                <span data-i18n="Id"></span>
            </td>
            <td>
                <%= model.get('id') %>
            </td>
        </tr>
        <tr>
            <td>
                <span data-i18n="Name"></span>
            </td>
            <td>
                <%= model.get('name') %>
            </td>
        </tr>
        <tr>
            <td>
                <span data-i18n="IP address"></span>
            </td>
            <td>
                <%= model.get('ip_in_use') ? model.get('ip_in_use') : model.get('ip') %>
            </td>
        </tr>
        <tr>
            <td>
                <span data-i18n="Expiration"></span>
            </td>
            <td>
                <%= model.get('expiration_hard') ? model.get('expiration_hard').replace('T', ' ') : $.i18n.t('No') %>
                <span class="fright"><%= warningIcon %></span>
            </td>
        </tr>
        <tr>
            <td>
                <span data-i18n="Connected user"></span>
            </td>
            <td>
                <%= model.get('user_state') == 'connected' ? $.i18n.t('Yes') : $.i18n.t('No') %>
                <span class="fright"><%= userStateIcon %></span>
            </td>
        </tr>
        <%
            $.each(model.get('properties'), function (propId, prop) {
        %>
            <tr>
                <td>
                    <%= prop.key %>
                </td>
                <td>
                    <%= prop.value %>
                </td>
            </tr>
        <%
            });
        %>
    </tbody>
</table>