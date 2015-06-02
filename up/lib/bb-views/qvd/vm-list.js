Wat.Views.VMListView = Wat.Views.ListView.extend({  
    qvdObj: 'vm',
    viewMode: 'grid',
    liveFields: ['state', 'user_state', 'ip', 'host_id', 'host_name', 'ssh_port', 'vnc_port', 'serial_port'],
    
    relatedDoc: {
        image_update: "Images update guide",
        full_vm_creation: "Create a virtual machine from scratch",
    },
    
    initialize: function (params) {  
        this.collection = new Wat.Collections.VMs(params);

        Wat.Views.ListView.prototype.initialize.apply(this, [params]);
    },
    
    // This events will be added to view events
    listEvents: {
        'click .js-change-viewmode': 'changeViewMode',
        'mouseover .js-vm-screenshot': 'overScreenshot',
        'mouseover .js-vm-screenshot>*': 'overScreenshotContent',
        'mouseout .js-vm-screenshot': 'outScreenshot',
        'mouseout .js-vm-screenshot>*': 'outScreenshotContent',
        'click .js-vm-details': 'openDetailsDialog',
        'click .js-vm-settings': 'openSettingsDialog',
    },
    
    overScreenshot: function (e) {
        $(e.target).find('.js-connect-btn').css('opacity', '1');
    },    
    
    outScreenshot: function (e) {
        $(e.target).find('.js-connect-btn').css('opacity', '0.5');
    },
    
    overScreenshotContent: function (e) {
        $(e.target).parent().find('.js-connect-btn').css('opacity', '1');
    },    
    
    outScreenshotContent: function (e) {
        $(e.target).parent().find('.js-connect-btn').css('opacity', '0.5');
    },
    
    startVM: function (filters) {        
        var messages = {
            'success': 'Successfully required to be started',
            'error': 'Error starting Virtual machine'
        }
        
        Wat.A.performAction ('vm_start', {}, filters, messages, function(){}, this);
    },
    
    // Different functions applyed to the selected items in list view
    applyStart: function (that) {
        that.startVM (that.applyFilters);
        that.resetSelectedItems ();
    },
    
    applyStop: function (that) {
        that.stopVM (that.applyFilters);
        that.resetSelectedItems ();
    },
    
    applyDisconnect: function (that) {
        that.disconnectVMUser (that.applyFilters);
        that.resetSelectedItems ();
    },
    
    openDetailsDialog: function (e) {
        this.selectedModelId = $(e.target).attr('data-model-id');
        
        var dialogConf = {
            title: 'Details',
            buttons : {
                "Force disconnection": function () {
                    $(this).dialog('close');
                },
                "Reboot VM": function () {
                    $(this).dialog('close');
                }
            },
            button1Class : 'fa fa-sign-out',
            button2Class : 'fa fa-refresh',
            fillCallback : this.fillDetailsDialog
        }
                
        Wat.I.dialog(dialogConf, this); 
    },  
    
    openSettingsDialog: function (e) {
        this.selectedModelId = $(e.target).attr('data-model-id');
        
        var dialogConf = {
            title: 'Connection settings',
            buttons : {
                "Save": function () {
                    $(this).dialog('close');
                },
            },
            button1Class : 'fa fa-save',
            fillCallback : this.fillSettingsDialog
        }
                
        Wat.I.dialog(dialogConf, this); 
    },
    
    fillDetailsDialog: function (dialog, that) {
        var model = that.collection.get(that.selectedModelId);
        
        // Fill the html with the template and the collection
        var template = _.template(
            Wat.TPL.details_vm, {
                model: model,
                userStateIcon: that.getUserStateIcon(model.get('user_state'), that.selectedModelId), 
                warningIcon: that.getWarningIcon(model.get('expiration_hard'), that.selectedModelId), 
            });
        
        $(dialog).html(template);
    },   
    
    fillSettingsDialog: function (dialog, that) {
        var model = that.collection.get(that.selectedModelId);
        
        // Fill the html with the template and the collection
        var template = _.template(
            Wat.TPL.connectionSettings, {
                model: model
            });
        
        $(dialog).html(template);
        
        Wat.I.chosenElement('select[name="type"]', 'single100');
    },
    
    getUserStateIcon: function (userState, modelId) {
        if (userState == 'disconnected') {
            return '<i class="fa fa-user not-notify state-icon js-state-icon" data-i18n="[title]User not connected" data-wsupdate="user_state" data-id="' + modelId + '"></i>';
        }
        else {
            return '<i class="fa fa-user ok state-icon js-state-icon" data-i18n="[title]Running" data-wsupdate="state" data-id="' + modelId + '"></i>';
        }
    },    
    
    getWarningIcon: function (expiration, modelId) {
        if (expiration) {
            return '<i class="fa fa-warning error warning-icon js-warning-icon" data-i18n="[title]The VM will expire" data-wsupdate="warning_icon" data-id="' + modelId + '"></i>';
        }
        else {
            return '<i class="fa fa-warning not-notify warning-icon js-warning-icon" data-i18n="[title]There are not warnings" data-wsupdate="warning_icon" data-id="' + modelId + '"></i>';
        }
    },      
});