<div class="login-box sec-login">
    <iframe id="remember" name="remember" class="hidden" src="remember.html"></iframe>

    <div class="login-side">
        <div class="logo-login"></div>
    </div>
    <div class="login-main">
        <form class="login-form js-login-form" target="remember" method="post" action="index.html">
            <div class="login-form">
                <%
                if (parseInt(multitenant)) {
                %>
                    <div class="login-control">
                        <div data-i18n="Tenant"></div>
                        <div>
                            <input type="text" name="admin_tenant"/>
                        </div>
                    </div>
                <%
                }
                %>
                <div class="login-control">
                    <div data-i18n="User"></div>
                    <div>
                        <input type="text" name="admin_user"/>
                    </div>
                </div>
                <div class="login-control">
                    <div data-i18n="Password"></div>
                    <div>
                        <input type="password" name="admin_password"/>
                    </div>
                </div>
                <% if (loginLinkSrc && loginLinkLabel) { %>
                    <div class="login-control login-link">
                        <a target="_blank" href="<%= loginLinkSrc %>" data-i18n="<%= loginLinkLabel %>"><%= loginLinkLabel %></a>
                    </div>
                <% } %>
                <div class="login-button">
                    <div>
                        <a class="fa fa-sign-in button js-login-button" data-i18n="Log-in"></a>
                        <!--<input type="submit" class="fa fa-sign-in button js-login-button" data-i18n="[value]Log-in">-->
                    </div>
                </div>
            </div>
        </form>
    </div>
</div>