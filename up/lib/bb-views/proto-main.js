Up.Views.MainView = Backbone.View.extend({
    el: '.bb-content',
    editorContainer: '.bb-editor',
    editorPropertiesContainer: '.bb-custom-properties',
    breadcrumbs: {},
    message: 'Unknown problem',
    // error/success/info
    messagetype: 'error',
    dialogConf: {},
    deleteProps: [],
    deleteACLs: [],
    addACLs: [],
    deleteRoles: [],
    addRoles: [],
    currentMenu: '', // platform-setup
    sideViews: [],
    templates: {},
    
    initialize: function () {
        _.bindAll(this, 'render');
        
        // Add common functions
        Up.C.addCommonFunctions (this);
        
        // Add to the view events the parent class of this view to avoid collisions with other views events
        this.events = this.restrictEventsScope(this.events);
        
        // Add the commonly used templates
        this.addCommonTemplates();

        var that = this;
        this.render = _.wrap(this.render, function(render) { 
            that.beforeRender(); 
            render(); 
            that.afterRender(); 
            return that; 
        }); 

		// If any message os sent from last refresh, show it and delete cookie
        if ($.cookie('messageToShow')) {
            var tInt = setInterval(function() {
                if (Up.T.loaded) {
                    Up.I.M.showMessage(JSON.parse($.cookie('messageToShow')));
                    $.removeCookie('messageToShow', {path: '/'});
                    clearInterval(tInt);
                }
                else {
                    console.log('not loaded');
                }
            }, 100);
        }
        
        $('.js-super-wrapper').removeClass('super-wrapper--login');
        $('body').css('background','');
        $('.header-wrapper, .menu-lat').show();        
    },
    
    addCommonTemplates: function () {
        var templates = Up.I.T.getTemplateList('commonEditors', {qvdObj: this.qvdObj});
        
        this.templates = $.extend({}, this.templates, templates);
    },
    
    beforeRender: function () {
        // Close submenus for touch devices compatibility
        $('.js-menu-corner li ul').hide();
    },
    
    afterRender: function () {
        var htmlString ="<html><body ><label>INPUT TYPE</label></body></html>";
        var doc = new jsPDF('landscape','pt');
        var specialElementHandlers = {
          '#editor': function( element, renderer ) {
              return true;
            }
        };
        
        Up.I.updateLoginOnMenu();
    },
    
    events:  {
        'input .filter-control>input': 'filterBySubstring',
        'ajaxError': 'handleAjaxError'
    },
    
    handleAjaxError: function (event, request, settings, thrownError) {
        alert('error');
    },
    
    filterBySubstring: function(e) {
        // Store typed search to mantain the order in filter task avoiding 
        // filtering if current typed search doesnt match with stored one
        Up.CurrentView.typedSearch = $(e.target).val();
        
        this.filter(e);
    },
    
    extendEvents: function (ev) {
        if (ev == undefined) {
            return;
        }
        ev = this.restrictEventsScope(ev);
        this.events = _.extend(this.events, ev);
    },
  
    restrictEventsScope: function (events) {
        var that = this;
        var newEvents = {};
        $.each(events, function(key, value) {
            var newKey = key.replace(' ', ' .' + that.cid + ' ');
            newEvents[newKey] = value;
        });
        return newEvents;
    },
    
    printBreadcrumbs: function (bc, bcHTML) {
        // If no bradcrumbs are given, do nothing
        if ($.isEmptyObject(bc)) {
            return;
        }
        
        if (bc.link != undefined) {
            bcHTML += '<a href="' + bc.link + '" data-i18n="' + bc.screen + '"></a>';
        }
        else {
            bcHTML += '<span data-i18n="' + bc.screen + '">' + bc.screen + '</span>';
        }
        if (bc.next != undefined) {
            bcHTML += ' <i class="fa fa-angle-double-right"></i> ';
            this.printBreadcrumbs (bc.next, bcHTML);
        }
        else {
            bcHTML += '<a href="javascript:" class="fa fa-book js-screen-help screen-help" data-i18n="[title]Related documentation" data-docsection="' + this.qvdObj + '"></a>'
            $('#breadcrumbs').html(bcHTML);
        }
    },
    
    // Editor
    editorElement: function (e) {
        Up.I.dialog(this.dialogConf, this);    
    },
    
    updateElement: function () {
        this.parseProperties('update');
        
        var context = '.editor-container.' + this.cid;
        
        return Up.I.validateForm(context);
    },  
    
    createElement: function () {
        this.parseProperties('create');
        
        var context = '.editor-container.' + this.cid;
        
        return Up.I.validateForm(context);
    },
    
    // Parse properties from create/edit forms
    parseProperties: function (mode) {
        var propIds = $('.' + this.cid + '.editor-container input.custom-prop-id');
        var propValues = $('.' + this.cid + '.editor-container input.custom-prop-value');
        
        switch (mode) {
            case 'create':
                var createPropertiesACL = this.qvdObj + '.create.properties';
                
                if (!createPropertiesACL) {
                    return;
                }
                break;
            case 'update':
                switch(this.viewKind) {
                    case 'list':
                        var updatePropertiesACL = this.qvdObj + '.update-massive.properties';
                        break;
                    case 'details':
                        var updatePropertiesACL = this.qvdObj + '.update.properties';
                        break;    
                }
                
                if (!updatePropertiesACL) {
                    return;
                }
                break;
        }
        
        var setProps = {};

        for(i=0;i<propIds.length;i++) {
            var id = propIds.eq(i);
            var value = propValues.eq(i);
                 
            setProps[id.val()] = value.val();
        }
        
        this.properties = {
            'set' : setProps
        };
    },
    
    createModel: function (arguments, successCallback) {
        this.model.setOperation('create');
        
        var messages = {
            'success': 'Successfully created',
            'error': 'Error creating'
        };
        
        this.saveModel(arguments, {}, messages, successCallback);        
    },
    
    updateModel: function (arguments, filters, successCallback, model) {
        // If not model is passed, use this.model
        var model = model || this.model;
        
        // If we are updating an element from list view, reset selected items
        if (this.viewKind == 'list') {
            this.resetSelectedItems();
        }
        
        model.setOperation('update');
        
        var messages = {
            'success': 'Successfully updated',
            'error': 'Error updating'
        };
        
        this.saveModel(arguments, filters, messages, successCallback, model);
    },
    
    deleteModel: function (filters, successCallback, model) {
        // If not model is passed, use this.model
        var model = model || this.model;
        
        model.setOperation('delete');
        
        var messages = {
            'success': 'Successfully deleted',
            'error': 'Error deleting'
        };
        
        this.saveModel({}, filters, messages, successCallback, model);
    },
    
    saveModel: function (arguments, filters, messages, successCallback, model) {
        var model = model || this.model;
        
        var that = this;
        model.save(arguments, {filters: filters}).complete(function(e, a, b) {
            Up.I.loadingUnblock();

            var callResponse = e.status;
            var response = {status: e.status};
            
            if (e.responseText) {
                try {
                    response = JSON.parse(e.responseText);
                }
                catch (err) {
                    //console.log (e.responseText);
                }
            }

            if (callResponse == 200 && response.status == STATUS_SUCCESS) {
                that.message = messages.success;
                that.messageType = 'success';
            }
            else {
                that.message = messages.error;
                that.messageType = 'error';
            }

            if (that.dialog) {
                Up.I.closeDialog(that.dialog);
            }
                        
            var messageParams = {
                message: that.message,
                messageType: that.messageType
            };
            
            that.retrievedData = response;
            successCallback(that);
            
            Up.I.M.showMessage(messageParams, response);
        });
    },
    
    stopVM: function (filters, messages) {        
        var messages = messages || {
            'success': 'Stop request successfully performed',
            'error': 'Error stopping Virtual machine'
        };
        
        Up.A.performAction ('vm_stop', messages, function(){}, this);
    },
    
    disconnectVMUser: function (filters, messages) {        
        var messages = messages || {
            'success': 'User successfully disconnected from VM',
            'error': 'Error disconnecting user from Virtual machine'
        };
        
        Up.A.performAction ('vm_user_disconnect', messages, this.fetchList, this);
    },
    
    openRelatedDocsDialog: function () {
        var that = this;
        
        var dialogConf = {};

        dialogConf.title = $.i18n.t("Related documentation");

        dialogConf.buttons = {
            "Read full documentation": function (e) {
                Up.I.closeDialog($(this));
                window.location = '#documentation';
            },
            Close: function (e) {
                Up.I.closeDialog($(this));
            }
        };

        dialogConf.button1Class = 'fa fa-book js-button-read-full-doc';
        dialogConf.button2Class = 'fa fa-check js-button-close';

        dialogConf.fillCallback = function (target, that) {
            // Back scroll of the div to top position
            target.html('');
            $('.js-dialog-container').animate({scrollTop:0});

            var sectionDoc = [];
            sectionDoc[this.qvdObj] = "This section step by step";
            this.relatedDoc = $.extend({}, sectionDoc, that.relatedDoc);
            
            if (this.relatedDoc) {
                var that = this;

                that.template = _.template(
                        Up.TPL.relatedDoc, {
                            relatedDoc: that.relatedDoc,
                        }
                    );

                target.html(that.template);
            }
        };


        Up.I.dialog(dialogConf, this);          
    },
    
    // Fetch details or list depending on the current view kind
    fetchAny: function (that) {
        switch (that.viewKind) {
            case 'list':
                that.fetchList();
                break;
            case 'details':
                that.fetchDetails();
                break;
        }
    },
    
    loadFakeData: function () {        
        // Workspaces rows
        this.collectionWorkspaces = new Up.Collections.Collection();
        this.collectionWorkspaces.models.push(new Up.Models.Model({
            id: 0,
            name: "Default",
            clonable: true,
            systemWS: true,
            active: false,
            settings: {
                connection_type: 'modem',
                audio: true,
                printing: true,
                full_screen: false,
                share_folders: false,
                share_usb: false
            }
        }));
        this.collectionWorkspaces.models.push(new Up.Models.Model({
            id: 1,
            name: "Office",
            clonable: true,
            systemWS: true,
            active: true,
            settings: {
                connection_type: 'adsl',
                audio: true,
                audio: true,
                printing: true,
                full_screen: false,
                share_folders: true,
                share_usb: true
            }
        }));
        this.collectionWorkspaces.models.push(new Up.Models.Model({
            id: 2,
            name: "Home",
            clonable: true,
            systemWS: true,
            active: false,
            settings: null
        }));
        this.collectionWorkspaces.models.push(new Up.Models.Model({
            id: 10000,
            name: "New",
            clonable: true,
            systemWS: false,
            active: false,
            settings: {
                connection_type: 'local',
                audio: true,
                printing: true,
                full_screen: true,
                share_folders: true,
                share_usb: true
            }
        }));
        
        this.emptyWorkspace = new Up.Models.Model({
            name: "New Workspace",
            clonable: true,
            systemWS: false,
            active: false,
            settings: {
                connection_type: 'adsl',
                audio: false,
                printing: false,
                full_screen: false,
                share_folders: false,
                share_usb: false
            }
        });
    },
});
