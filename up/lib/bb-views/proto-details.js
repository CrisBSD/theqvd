Up.Views.DetailsView = Up.Views.MainView.extend({
    elementId: 0,
    detailsContainer: '.bb-details',
    sideContainer: '.bb-details-side',
    
    viewKind: 'details',
    
    /*
    ** params:
    **  id (numeric): Id of the element which details will be shown
    */
    
    initialize: function (params) {
        Up.Views.MainView.prototype.initialize.apply(this);

        this.elementId = params.id;
        
        this.setBreadCrumbs();
        this.setViewACL();
        this.setDetailsFields();
        
        // Extend the common events
        this.extendEvents(this.eventsDetails);
        
        this.addDetailsTemplates();

        Up.A.getTemplates(this.templates, this.fetchDetails, this); 
    },
    
    addDetailsTemplates: function () {
        var templates = Up.I.T.getTemplateList('details', {qvdObj: this.qvdObj});
        
        this.templates = $.extend({}, this.templates, templates);
    },
    
    setBreadCrumbs: function () {
        this.breadcrumbs = Up.I.getDetailsBreadCrumbs(this.qvdObj);
    }, 
    
    setViewACL: function () {
        this.viewACL = this.qvdObj + '.see-details.';
    },
    
    afterRender: function () {
        var that = this;
        
        // If this view have Side component, render it after render
        if (this.renderSide) {
            this.renderSide();
        }
    },
    
    fetchDetails: function (that) {
        var that = that || this;
        that.model.fetch({      
            success: function () {
                var enabledProperties = $.inArray(that.qvdObj, QVD_OBJS_WITH_PROPERTIES) != -1;
                
                if (enabledProperties) {
                    var filters = {};

                    var classifiedByTenant = $.inArray(that.qvdObj, QVD_OBJS_CLASSIFIED_BY_TENANT) != -1;
                    
                    if (Up.C.isMultitenant() && Up.C.isSuperadmin() && classifiedByTenant) {
                        filters['-or'] = ['tenant_id', that.model.get('tenant_id'), 'tenant_id', SUPERTENANT_ID];
                    }

                    Up.A.performAction(that.qvdObj + '_get_property_list', {}, filters, {}, that.completePropertiesAndRender, that, undefined, {"field":"key","order":"-asc"});
                }
                else {
                    that.render();
                }
            }
        });
    },
    
    completePropertiesAndRender: function (that) {
		// If is an element without properties just render
        if (!that.model.get('properties')) {
            that.render;
            return;
        }
        
        var properties = {};

        if (that.retrievedData.total > 0) {
            $.each(that.retrievedData.rows, function (iProp, prop) {
                properties[prop.property_id] = {
                    value: that.model.get('properties')[prop.property_id] ? that.model.get('properties')[prop.property_id].value : '',
                    key: prop.key,
                    description: prop.description,
                    tenant_id: prop.tenant_id,
                    property_id: prop.property_id,
                };
            });
        }
        
        // Override properties including not setted on element
        that.model.set({properties: properties});
        
        that.render();
    },
    
    eventsDetails: {
        'click .js-button-edit': 'openEditElementDialog',
        'click .js-button-unblock': 'applyUnblock' ,
        'click .js-button-block': 'applyBlock', 
        'click .js-button-delete': 'askDelete',
        'click .js-button-default': 'applyDefault',
        'click .js-button-start-vm': 'startVM',
        'click .js-button-stop-vm': 'stopVM',
        'click .js-button-restart-vm': 'restartVM',
        'click .js-button-disconnect-all-vms': 'applyDisconnectAll',
        'click .js-show-details-actions': 'toggleActions'
    },

    render: function () {
        // If user have not access to main section, redirect to home
        if (!Up.C.checkACL(this.viewACL)) {
            window.location = '#';
            return;
        }
        
        // If only id is stored in model means that it wasnt found
        if (this.notFound == undefined) {
            this.notFound = Object.keys(this.model.attributes).length <= 1;
        }
        
        // If screen attribute of last breadcrumb is not defined, element wasnt found
        var lastScreen = undefined;
        var nextBread = this.breadcrumbs.next;
        while (1) {
            if (!nextBread.next) {
                lastScreen = !nextBread.screen ? undefined : nextBread.screen;
                break;
            }
            
            nextBread = nextBread.next;
        }
        
        // Add name of the model to breadcrumbs. Some cases will have another fields
        switch (this.qvdObj) {
            case 'di':
                nextBread.screen = this.model.get('disk_image');
                break;
            case 'configwat':
                break;
            case 'log':
                nextBread.screen = this.model.get('id');
                break;
            default:
                nextBread.screen = this.model.get('name');
        }
        
        if (this.notFound) {
            this.template = _.template(
                Up.TPL.warn404, {
                }
            );

            $(this.el).html(this.template);
            
            nextBread.screen = '-';
            this.printBreadcrumbs(this.breadcrumbs, '');
            //delete nextBread.screen;
        }
        else { 
            var enabledProperties = $.inArray(this.qvdObj, QVD_OBJS_WITH_PROPERTIES) != -1 && Up.C.checkACL(this.qvdObj + '.see.properties');
            
            // Fill the html with the template and the model
            this.template = _.template(
                Up.TPL.detailsCommon, {
                    model: this.model,
                    enabledProperties: enabledProperties,
                    cid: this.cid,
                    qvdObj: this.qvdObj
                }
            );

            $(this.el).html(this.template);
        
            this.printBreadcrumbs(this.breadcrumbs, '');

            this.template = _.template(
                Up.TPL.details, {
                    model: this.model,
                    detailsFields: this.detailsFields,
                    enabledProperties: enabledProperties
                }
            );

            $(this.detailsContainer).html(this.template);
        
            this.template = _.template(
                Up.TPL.detailsSide, {
                    model: this.model,
                    qvdObj: this.qvdObj
                }
            );

            $(this.sideContainer).html(this.template);
            
            if (enabledProperties) {
                var filters = {};
                
                if (Up.C.isMultitenant() && Up.C.isSuperadmin()) {
                    filters['tenant_id'] = this.model.get('tenant_id');
                }
                
                this.renderProperties();
            }
        }
        
        // If there isnt action buttons, hide action show/hide button
        if ($('.details-header').find('a.button').length == 0) {
            $('.js-show-details-actions').hide();
        }
        
        Up.T.translateAndShow();
        
        // Open websockets for live fields
        if (this.liveFields) {
            Up.WS.openDetailsWebsockets(this.qvdObj, this.model, this.liveFields, this.cid);
        }
    },
    
    renderProperties: function () {
        // Fill the html with the template and the model
        this.template = _.template(
            Up.TPL.detailsCommonProperties, {
                properties: this.model.get('properties')
            }
        );

        $('.bb-properties').html(this.template);
    },
    
    applyBlock: function () {
        this.updateModel({blocked: 1}, {id: this.elementId}, this.fetchDetails);
    },   
    
    applyUnblock: function () {
        this.updateModel({blocked: 0}, {id: this.elementId}, this.fetchDetails);
    },  
    
    askDelete: function () {
        Up.I.confirm('dialog/confirm-undone', this.applyDelete, this);
    },
    
    toggleActions: function (e) {
        
        switch ($(e.target).attr('data-options-state')) {
            case 'hidden':
                $(e.target).attr('data-options-state', 'shown');
                $(e.target).removeClass('fa-eye');
                $(e.target).addClass('fa-eye-slash');
                $(e.target).parent().find('a.button').show();
                $(e.target).parent().find('a.button[data-enabled="false"]').hide();
                break;
            case 'shown':
                $(e.target).attr('data-options-state', 'hidden');
                $(e.target).removeClass('fa-eye-slash');
                $(e.target).addClass('fa-eye');
                $(e.target).parent().find('a.button').hide();
                break;
        }
    },
        
    applyDelete: function (that) {
        that.deleteModel({id: that.elementId}, that.afterDelete, that.model);
    },
    
    afterDelete: function (that) {
        //Find the last link to rederect to it after deletion
        var lastLink = '';
        var crumb = that.breadcrumbs;
        while (1) {
            if (crumb.next != undefined) {
                if (crumb.link != undefined) {
                    lastLink = crumb.link;
                }
                crumb = crumb.next;
            }
            else {
                break;
            }
        }
        
        window.location = lastLink;
    },
    
    setDetailsFields: function () {
        // Get Fields from configuration
        this.detailsFields = Up.I.getDetailsFields(this.qvdObj);
        
        // Check acls on fields to remove forbidden ones
        Up.C.purgeConfigData(this.detailsFields);

        // The superadmin have an extra field on lists: tenant
        
        // Every element but the hosts has tenant
        if (Up.C.isSuperadmin() && this.qvdObj != 'host') {
            this.detailsFields.tenant = {
                'text': 'Tenant',
                'display': true,
                'noTranslatable': true
            };
        }
    },
    
    // Check some acls to show or not the side of a details view
    // If no acl pass, return false, otherwise return an object with acls and true or false if pass or not
    checkSide: function (acls) {
        var nAcls = acls.length;
        var pass = 0;
        var result = {};
        
        $.each(acls, function (acl, layer) {
            if (Up.C.checkACL(acl)) {
                pass++;
                result[acl] = true;
            }
            else {
                result[acl] = false;
                $(layer).hide();
            }
        });
        
        if (!pass) {
            $('.js-details-side').hide();
            $('.js-details-block').addClass('col-width-100');
            return false;
        }
        //$('.js-details-side').show();
        //$('.js-details-block').removeClass('col-width-100');
        return result;
    },
    
    // Return the params to render a embeded side list with object log registers
    getSideLogParams: function (sideContainer) {
        var params = {};
        params.whatRender = 'list';
        params.listContainer = sideContainer;
        params.forceListColumns = {
            see_details: true, 
            action: true, 
            datetime: true
        };

        params.forceSelectedActions = {};
        params.block = 5;
        params.filters = {
            qvd_object: this.qvdObj, 
            object_id: this.elementId
        };
        
        return params;
    },
    
    renderLogGraph: function (params) {
        var fields = ["time"];
        var filters = params.filters;
        var orderBy = {
            "field": "id",
            "order": "-desc"
        };
        
        var that = this;
        
        Up.A.performAction ('log_get_list', {}, filters, {}, function(result){
            var dataGroups = 50;
            
            if (result.retrievedData.total > 0) {
                var rows = result.retrievedData.rows;
                
                var serverTimestamp = (Date.parse(Date()) / 1000);
                var olderTimestamp = Date.parse(rows[rows.length-1].time) / 1000;
                var newerTimestamp = Date.parse(rows[0].time) / 1000;
                
                // Give it 20% margin
                var timeFromOlder = parseInt((serverTimestamp - olderTimestamp) * 1);
                
                var step = parseInt(timeFromOlder / dataGroups);
                
                var graphData = [];
                for (iMin=olderTimestamp-1; iMin<=serverTimestamp-step; iMin+=step) {
                    var iMax = (iMin+step)<=serverTimestamp ? iMin+step : serverTimestamp + 1;
                    
                    var groupCount = 0;
                    var groupName = iMin;
                    
                    $.each(rows, function (i, v) {
                        if (!v) {
                            return;
                        }
                        
                        var stepTimestamp = Date.parse(v.time) / 1000;
                        if (stepTimestamp > iMin && stepTimestamp <= iMax) {
                            groupCount++;
                            delete rows[i];
                        }
                    });
                    
                    graphData.push({
                        "id": iMin,
                        "name": groupName,
                        "registers": groupCount
                        }
                    );
                }
                
                that.loadLogGraphData(graphData);                
            }
        }, this, fields, orderBy);
    },
    
    loadLogGraphData: function (data) {
        if (!data) {
            return;
        }

        if ($('#graph-log').html() != undefined) {
            // Trick to draw bar chart when the div where it will be located will be rendered
            // We know that it is rendered when CSS width attribute change from 'XXX%' to 'XXXpx'
            setTimeout(function () {
                if ($('#graph-log').css('width').indexOf("%") == -1) {
                    Up.I.G.drawBarChartLog('graph-log', data);
                }
            }, 50);
        }
    },
});
