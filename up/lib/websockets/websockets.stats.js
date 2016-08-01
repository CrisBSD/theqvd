Up.WS.changeWebsocketStats = function (field, data) {
    if (!Up.CurrentView.stats || Up.CurrentView.stats[field] == undefined) {
        return;
    }
    
    Up.CurrentView.stats[field] = data;
    
    switch (field) {
        case 'users_count':
        case 'vms_count':
        case 'hosts_count':
        case 'osfs_count':
        case 'dis_count':
        case 'blocked_users_count':
        case 'blocked_vms_count':
        case 'blocked_hosts_count':
        case 'blocked_dis_count':
        case 'running_hosts_count':
        case 'running_vms_count':
        case 'connected_users_count':
            $('[data-wsupdate="' + field + '"]').html(data); 
            break;
        case 'vms_with_expiration_date':
/*            data = [
                {
                    expiration: "2014-11-30T12:22:00",
                    id: 5,
                    name: "mVM-2-UFake",
                    remaining_time: {
                        days: 2,
                        hours: 0,
                        minutes: 53,
                        seconds: 46,
                    }
                }
            ];
            Up.CurrentView.stats[field] = data;*/
            
            
            Up.CurrentView.renderVmsExpire();
            
            Up.T.translateXDays();
            break;
        case 'top_populated_hosts':
/*            data = [
                {id: 1, name: "node1", number_of_vms: 21},
                {id: 3, name: "node3", number_of_vms: 13},
                {id: 4, name: "node4", number_of_vms: 5},
                {id: 5, name: "node5", number_of_vms: 2}
            ]
            Up.CurrentView.stats[field] = data;*/
            
            var hostsMoreVMSData = [];
            
            $.each(Up.CurrentView.stats.top_populated_hosts, function (iPop, population) {
                hostsMoreVMSData.push(population);
            });
            
            Up.I.G.drawBarChartRunningVMsSimple('hosts-more-vms', hostsMoreVMSData);
            break;
    }
    
    switch (field) {
        case 'hosts_count':
        case 'running_hosts_count':
            var runningHostsData = [Up.CurrentView.stats.running_hosts_count, Up.CurrentView.stats.hosts_count - Up.CurrentView.stats.running_hosts_count];
            Up.I.G.drawPieChartSimple('running-hosts', runningHostsData);
            break;
        case 'users_count':
        case 'connected_users_count':
            var connectedUsersData = [Up.CurrentView.stats.connected_users_count, Up.CurrentView.stats.users_count - Up.CurrentView.stats.connected_users_count];
            Up.I.G.drawPieChartSimple('connected-users', connectedUsersData);
            break;
        case 'vms_count':
        case 'running_vms_count':
            var runningVMSData = [Up.CurrentView.stats.running_vms_count, Up.CurrentView.stats.vms_count - Up.CurrentView.stats.running_vms_count];
            Up.I.G.drawPieChartSimple('running-vms', runningVMSData);
            break;
    }
}