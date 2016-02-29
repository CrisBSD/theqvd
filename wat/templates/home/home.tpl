<div class="<%= cid %> sec-home">
    <div class="welcome-message">
        <span class="welcome" data-i18n="Welcome to QVD's Web Administration Tool"></span>
        <div class="welcome-help">
            <a class="button2 <%= CLASS_ICON_HELP %> js-need-help" href="#documentation/introduction" data-i18n="Do you need help?"></a>

            <a class="button2 fa fa-file-pdf-o js-exportPDF desktop" data-i18n="Export to PDF"></a>
            <a class="button2 fa fa-file-o js-exportCSV desktop" data-i18n="Export to CSV"></a>
        </div>
    </div>
        <div class="home-wrapper">
    <% if (Wat.C.checkGroupACL('statisticsSummaryObjects') || Wat.C.checkACL('vm.stats.running-vms')) { %>
            <% if (Wat.C.checkGroupACL('statisticsSummaryObjects')) { %>
                <div class="home-row">
                    <% if (Wat.C.checkACL('user.stats.summary')) { %>
                        <div class="home-cell js-home-cell">
                            <div class="summary-element home-widget">
                                <div class="summary-element-title js-summary-element-title">
                                    <%= Wat.C.ifACL('<a href="#/users" data-i18n="Users">', 'user.see-main.') %>
                                        <%= i18n.t('Users') %>
                                    <%= Wat.C.ifACL('</a>', 'user.see-main.') %>
                                </div>
                                <div class="summary-element-icon js-summary-element-icon">
                                    <%= Wat.C.ifACL('<a href="#/users">', 'user.see-main.') %>
                                        <i class="<%= CLASS_ICON_USERS %>"></i>                                
                                    <%= Wat.C.ifACL('</a>', 'user.see-main.') %>
                                </div>
                                <div class="summary-element-count js-summary-element-count">
                                    <span class="summary-data js-summary-users" data-wsupdate="users_count"><%= stats.users_count %></span>

                                    <table class="summary-element-subtable second_row">
                                        <tr>
                                            <% if (Wat.C.checkACL('user.stats.blocked')) { %>
                                            <td>
                                                <%= Wat.C.ifACL('<a href="#/users/' + Wat.U.transformFiltersToSearchHash({blocked: 1}) + '">', 'user.see-main.') %>
                                                    <span data-wsupdate="blocked_users_count"><%= stats.blocked_users_count %></span>/<span class="summary-data js-summary-users" data-wsupdate="users_count"><%= stats.users_count %></span>
                                                    <span class="fa fa-lock" data-i18n="[title]Blocked"></span>
                                                <%= Wat.C.ifACL('</a>', 'user.see-main.') %>
                                            </td>
                                            <% } %>
                                            <% if (Wat.C.checkACL('user.stats.connected-users')) { %>
                                            <td>
                                                <%= Wat.C.ifACL('<a href="#/users">', 'user.see-main.') %>
                                                    <span data-wsupdate="connected_users_count"><%= stats.connected_users_count %></span>/<span class="summary-data js-summary-users" data-wsupdate="users_count"><%= stats.users_count %></span> 
                                                    <span class="fa fa-plug" data-i18n="[title]Users connected to at least one virtual machine"></span>
                                                <%= Wat.C.ifACL('</a>', 'user.see-main.') %>
                                            </td>
                                            <% } %>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>
                    <% } if (Wat.C.checkACL('vm.stats.summary')) { %>
                        <div class="home-cell js-home-cell">
                            <div class="summary-element home-widget">
                                <div class="summary-element-title js-summary-element-title">
                                    <%= Wat.C.ifACL('<a href="#/vms" data-i18n="Virtual machines">', 'vm.see-main.') %>
                                        <%= i18n.t('Virtual machines') %>
                                    <%= Wat.C.ifACL('</a>', 'vm.see-main.') %>
                                </div>
                                <div class="summary-element-icon js-summary-element-icon">
                                    <%= Wat.C.ifACL('<a href="#/vms">', 'vm.see-main.') %>
                                        <i class="<%= CLASS_ICON_VMS %>"></i>
                                    <%= Wat.C.ifACL('</a>', 'vm.see-main.') %>
                                </div>
                                <div class="summary-element-count js-summary-element-count">
                                    <span class="summary-data js-summary-vms" data-wsupdate="vms_count"><%= stats.vms_count %></span>

                                    <table class="summary-element-subtable second_row">
                                        <tr>
                                            <% if (Wat.C.checkACL('vm.stats.blocked')) { %>
                                            <td>
                                                <%= Wat.C.ifACL('<a href="#/vms/' + Wat.U.transformFiltersToSearchHash({blocked: 1}) + '">', 'vm.see-main.') %>
                                                    <span data-wsupdate="blocked_vms_count"><%= stats.blocked_vms_count %></span>/<span class="summary-data js-summary-vms" data-wsupdate="vms_count"><%= stats.vms_count %></span> 
                                                    <span class="fa fa-lock" data-i18n="[title]Blocked"></span>
                                                <%= Wat.C.ifACL('</a>', 'vm.see-main.') %>
                                            </td>
                                            <% } %>
                                            <% if (Wat.C.checkACL('vm.stats.running-vms')) { %>
                                            <td>
                                                <%= Wat.C.ifACL('<a href="#/vms/' + Wat.U.transformFiltersToSearchHash({'state': 'running'}) + '">', 'vm.see-main.') %>
                                                    <span data-wsupdate="running_vms_count"><%= stats.running_vms_count %></span>/<span class="summary-data js-summary-vms" data-wsupdate="vms_count"><%= stats.vms_count %></span> 
                                                    <span class="fa fa-play" data-i18n="[title]Running virtual machines"></span>
                                                <%= Wat.C.ifACL('</a>', 'vm.see-main.') %>
                                            </td>
                                            <% } %>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>
                    <% } if (Wat.C.checkACL('host.stats.summary')) { %>
                        <div class="home-cell js-home-cell js-home-cell">
                            <div class="summary-element home-widget">
                                <div class="summary-element-title js-summary-element-title">
                                    <%= Wat.C.ifACL('<a href="#/hosts" data-i18n="Nodes">', 'host.see-main.') %>
                                        <%= i18n.t('Nodes') %>
                                    <%= Wat.C.ifACL('</a>', 'host.see-main.') %>
                                </div>
                                <div class="summary-element-icon js-summary-element-icon">
                                    <%= Wat.C.ifACL('<a href="#/hosts">', 'host.see-main.') %>
                                        <i class="<%= CLASS_ICON_HOSTS %>"></i>
                                    <%= Wat.C.ifACL('</a>', 'host.see-main.') %>
                                </div>
                                <div class="summary-element-count js-summary-element-count">
                                    <span class="summary-data js-summary-hosts" data-wsupdate="hosts_count"><%= stats.hosts_count %></span>

                                    <table class="summary-element-subtable second_row">
                                        <tr>
                                            <% if (Wat.C.checkACL('host.stats.blocked')) { %>
                                            <td>
                                                <%= Wat.C.ifACL('<a href="#/hosts/' + Wat.U.transformFiltersToSearchHash({blocked: 1}) + '">', 'host.see-main.') %>
                                                    <span data-wsupdate="blocked_hosts_count"><%= stats.blocked_hosts_count %></span>/<span class="summary-data js-summary-hosts" data-wsupdate="hosts_count"><%= stats.hosts_count %></span> 
                                                    <span class="fa fa-lock" data-i18n="[title]Blocked"></span>
                                                <%= Wat.C.ifACL('</a>', 'host.see-main.') %>
                                            </td>
                                            <% } %>
                                            <% if (Wat.C.checkACL('host.stats.running-hosts')) { %>
                                            <td>
                                                <%= Wat.C.ifACL('<a href="#/hosts/' + Wat.U.transformFiltersToSearchHash({state: 'running'}) + '">', 'host.see-main.') %>
                                                    <span data-wsupdate="running_hosts_count"><%= stats.running_hosts_count %></span>/<span class="summary-data js-summary-hosts" data-wsupdate="hosts_count"><%= stats.hosts_count %></span> 
                                                    <span class="fa fa-play" data-i18n="[title]Running nodes"></span>
                                                <%= Wat.C.ifACL('</a>', 'host.see-main.') %>
                                            </td>
                                            <% } %>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>
                    <% } if (Wat.C.checkACL('osf.stats.summary')) { %>
                        <div class="home-cell js-home-cell">
                            <div class="summary-element home-widget">
                                <div class="summary-element-title js-summary-element-title">
                                    <%= Wat.C.ifACL('<a href="#/osfs" data-i18n="OS Flavours">', 'osf.see-main.') %>
                                        <%= i18n.t('OS Flavours') %>
                                    <%= Wat.C.ifACL('</a>', 'osf.see-main.') %>
                                </div>
                                <div class="summary-element-icon js-summary-element-icon">
                                    <%= Wat.C.ifACL('<a href="#/osfs">', 'osf.see-main.') %>
                                        <i class="<%= CLASS_ICON_OSFS %>"></i>
                                    <%= Wat.C.ifACL('</a>', 'osf.see-main.') %>
                                </div>
                                <div class="summary-element-count js-summary-element-count">
                                    <span class="summary-data js-summary-osfs" data-wsupdate="osfs_count"><%= stats.osfs_count %></span>
                                </div>
                            </div>
                        </div>
                    <% } if (Wat.C.checkACL('di.stats.summary')) { %>
                        <div class="home-cell js-home-cell">
                            <div class="summary-element home-widget">
                                <div class="summary-element-title js-summary-element-title">
                                    <%= Wat.C.ifACL('<a href="#/dis" data-i18n="Disk images">', 'di.see-main.') %>
                                        <%= i18n.t('Disk images') %>
                                    <%= Wat.C.ifACL('</a>', 'di.see-main.') %>
                                </div>
                                <div class="summary-element-icon js-summary-element-icon">
                                    <%= Wat.C.ifACL('<a href="#/dis">', 'di.see-main.') %>
                                        <i class="<%= CLASS_ICON_DIS %>"></i>
                                    <%= Wat.C.ifACL('</a>', 'di.see-main.') %>
                                </div>
                                <div class="summary-element-count js-summary-element-count">
                                    <span class="summary-data js-summary-dis" data-wsupdate="dis_count"><%= stats.dis_count %></span>

                                    <table class="summary-element-subtable second_row">
                                        <tr>
                                            <% if (Wat.C.checkACL('di.stats.blocked')) { %>
                                            <td>
                                                <%= Wat.C.ifACL('<a href="#/dis/' + Wat.U.transformFiltersToSearchHash({blocked: 1}) + '">', 'di.see-main.') %>
                                                    <span class="summary-data js-summary-blocked-dis" data-wsupdate="blocked_dis_count"><%= stats.blocked_dis_count %></span>/<span class="summary-data js-summary-dis" data-wsupdate="dis_count"><%= stats.dis_count %></span> 
                                                    <span class="fa fa-lock" data-i18n="[title]Blocked"></span>
                                                <%= Wat.C.ifACL('</a>', 'di.see-main.') %>
                                            </td>
                                            <% } %>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>
                    <% } %>
                </div>
            <% } %>
            <div class="home-row">
                <% if (Wat.C.checkACL('vm.stats.running-vms')) { %>
                <div class="home-cell js-home-cell">
                    <div class="home-title" data-i18n="Running virtual machines"></div>
                    <div class="home-percent-wrapper">
                        <div class="js-running-vms-percent home-title home-percent js-home-percent"></div>
                        <div id="running-vms" class="pie-chart js-pie-chart" data-target="vms/<%= Wat.U.transformFiltersToSearchHash({state: "running"}) %>" width="200px" height="200px"></div>
                    </div>
                    <%= Wat.C.ifACL('<a href="#/vms/' + Wat.U.transformFiltersToSearchHash({state: "running"}) + '">', 'vm.see-main.') %>
                        <div class="js-running-vms-data home-title"></div>
                    <%= Wat.C.ifACL('</a>', 'vm.see-main.') %>
                </div>
                <% } %>

                <% if (Wat.C.checkACL('user.stats.connected-users')) { %>
                <div class="home-cell js-home-cell">
                    <div class="home-title" data-i18n="Connected users"></div>
                    <div class="home-percent-wrapper">
                        <div class="js-connected-users-percent home-title home-percent js-home-percent"></div>
                        <div id="connected-users" class="pie-chart js-pie-chart" data-target="users" width="200px" height="200px"></div>
                    </div>
                    <%= Wat.C.ifACL('<a href="#/users">', 'user.see-main.') %>
                    <div class="js-connected-users-data home-title"></div>
                    <%= Wat.C.ifACL('</a>', 'user.see-main.') %>
                </div>
                <% } %>

                <% if (Wat.C.checkACL('host.stats.running-hosts')) { %>
                <div class="home-cell js-home-cell">
                    <div class="home-title" data-i18n="Running nodes"></div>
                    <div class="home-percent-wrapper">
                        <div class="js-running-hosts-percent home-title home-percent js-home-percent"></div>
                        <div id="running-hosts" class="pie-chart js-pie-chart" data-target="hosts/<%= Wat.U.transformFiltersToSearchHash({state: "running"}) %>" width="200px" height="200px"></div>
                    </div>
                    <%= Wat.C.ifACL('<a href="#/hosts/' + Wat.U.transformFiltersToSearchHash({state: "running"}) + '">', 'host.see-main.') %>
                        <div class="js-running-hosts-data home-title"></div>
                    <%= Wat.C.ifACL('</a>', 'host.see-main.') %>
                </div>
                <% } %>
            </div>
    <% } %>    

    <% if (Wat.C.checkGroupACL('statisticsBlockedObjects') || Wat.C.checkACL('vm.stats.close-to-expire') || Wat.C.checkACL('host.stats.top-hosts-most-vms')) { %>
            <div class="home-row">
                <% if (Wat.C.checkACL('vm.stats.close-to-expire')) { %>
                    <div class="home-cell js-home-cell bb-vms-expire"></div>
                <% } %>

                <% if (Wat.C.checkACL('host.stats.top-hosts-most-vms')) { %>
                <div class="home-cell js-home-cell">
                    <div class="home-title" data-i18n="Nodes with most running VMs"></div>
                    <div id="hosts-more-vms" class="bar-chart js-bar-chart" style="width:95%;height:200px;"></div>
                </div>
                <% } %>

                <% if (Wat.C.checkGroupACL('statisticsBlockedObjects')) { %>
                    <div class="home-cell js-home-cell">
                        <div class="home-title" data-i18n="Blocked elements"></div>
                        <table class="summary-table">
                            <% if (Wat.C.checkACL('user.stats.blocked')) { %>
                            <tr>
                                <td class="max-1-icons">
                                    <i class="<%= CLASS_ICON_USERS %>"></i>
                                </td>                    
                                <td>
                                    <%= Wat.C.ifACL('<a href="#/users/' + Wat.U.transformFiltersToSearchHash({blocked: 1}) + '" data-i18n="Users">', 'user.see-main.') %>
                                        <%= i18n.t('Users') %>
                                    <%= Wat.C.ifACL('</a>', 'user.see-main.') %>
                                </td>
                                <td>
                                    <span class="summary-data js-summary-blocked-users" data-wsupdate="blocked_users_count"><%= stats.blocked_users_count %></span>
                                </td>
                            </tr>
                            <% } if (Wat.C.checkACL('vm.stats.blocked')) { %>
                            <tr>    
                                <td class="max-1-icons">
                                    <i class="<%= CLASS_ICON_VMS %>"></i>
                                </td>        
                                <td>
                                    <%= Wat.C.ifACL('<a href="#/vms/' + Wat.U.transformFiltersToSearchHash({blocked: 1}) + '" data-i18n="Virtual machines">', 'vm.see-main.') %>
                                        <%= i18n.t('Virtual machines') %>
                                    <%= Wat.C.ifACL('</a>', 'vm.see-main.') %>
                                </td>
                                <td>
                                    <span class="summary-data js-summary-blocked-vms" data-wsupdate="blocked_vms_count"><%= stats.blocked_vms_count %></span>
                                </td>
                            </tr>
                            <% } if (Wat.C.checkACL('host.stats.blocked')) { %>
                            <tr>
                                <td class="max-1-icons">
                                    <i class="<%= CLASS_ICON_HOSTS %>"></i>
                                </td>       
                                <td>
                                    <%= Wat.C.ifACL('<a href="#/hosts/' + Wat.U.transformFiltersToSearchHash({blocked: 1}) + '" data-i18n="Nodes">', 'host.see-main.') %>
                                        <%= i18n.t('Nodes') %>
                                    <%= Wat.C.ifACL('</a>', 'host.see-main.') %>
                                </td>
                                <td>
                                    <span class="summary-data js-summary-blocked-hosts" data-wsupdate="blocked_hosts_count"><%= stats.blocked_hosts_count %></span>
                                </td>
                            </tr>
                            <% } if (Wat.C.checkACL('di.stats.blocked')) { %>
                            <tr>
                                <td class="max-1-icons">
                                    <i class="<%= CLASS_ICON_DIS %>"></i>
                                </td>                
                                <td>
                                    <%= Wat.C.ifACL('<a href="#/dis/' + Wat.U.transformFiltersToSearchHash({blocked: 1}) + '" data-i18n="Disk images">', 'di.see-main.') %>
                                        <%= i18n.t('Disk images') %>
                                    <%= Wat.C.ifACL('</a>', 'di.see-main.') %>
                                </td>
                                <td>
                                    <span class="summary-data js-summary-blocked-dis" data-wsupdate="blocked_dis_count"><%= stats.blocked_dis_count %></span>
                                </td>
                            </tr>
                            <% } %>
                        </table>
                    </div>
                <% } %>
            </div>
    <% } %>
        </div>
</div>