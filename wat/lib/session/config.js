// Config
Wat.C = {
    // Version of WAT
    version: '4.0',
    
    // Login parameters
    login: '',
    password: '',
    loggedIn: false,
    
    // API parameters
    apiAddress: '', //Will be loaded from external file config.json
    apiPort: '', // Will be loaded from external file config.json

    // Source to be stored by API log
    source: 'WAT',
    
    // Configuration file name
    configFileName: 'config.json',
    
    // Days to login expiration
    loginExpirationDays: 1,
    
    // ACL variables
    acls: [],
    aclGroups: {},
    
    // Session ID
    sid: '',
    
    // Current admin IDs
    tenantID: -1,
    adminID: -1,
    
    // Abort old requests when navigate or not
    abortOldRequests: true,
    
    // ajax requests
    requests: [],
    
    // Flag to know if router history is started
    routerHistoryStarted: false,
    
    // Show a clock with server's time
    showServerClock: false,
    
    // Init Api address configuration
    initApiAddress: function () {
        this.apiUrl = 'https://' + Wat.C.apiAddress + ':' + Wat.C.apiPort + '/api/';
        this.apiWSUrl = 'wss://' + Wat.C.apiAddress + ':' + Wat.C.apiPort + '/api/';
    },

    // Get the base URL for API calls using credentials or session ID
    getBaseUrl: function () {
        if (this.login && this.password) {
            var baseUrl = this.getApiUrl() + "?login=" + this.login + "&password=" + this.password;
            
            if (this.multitenant && this.tenant != undefined) {
                baseUrl += "&tenant=" + this.tenant;
            }
            
            return baseUrl;
        }
        else {
            return this.getApiUrl() + "?sid=" + this.sid;
        }
    },
    
    // Get the API URL
    getApiUrl: function () {
        return this.apiUrl;
    },   
    
    // Get the API URL for update DIs
    getUpdateDiUrl: function () {
        return this.getApiUrl() + "di/upload?sid=" + this.sid;
    }, 
    
    // Get the API URL for download DIs from URL
    getDownloadDiUrl: function (url) {
        return this.getApiUrl() + "di/download?sid=" + this.sid + "&url=" + url;
    },
    
    // Return if current admin is superadmin
    isSuperadmin: function () {
        return this.tenantID == SUPERTENANT_ID;
    },    
    
    // Return if current admin is recover admin
    isRecoveradmin: function (idToCheck) {
        if (idToCheck == undefined) {
            idToCheck = this.adminID;
        }
        return idToCheck == RECOVER_USER_ID;
    },
    
    // Return if system is configured as multitenant WAT
    isMultitenant: function () {
        return this.multitenant;
    },
    
    // Set calls source
    setSource: function (newSource) {
        this.source = newSource;
    },
    
    // Set aborting old requests flag
    setAbortOldRequests: function (newValue) {
        this.abortOldRequests = newValue;
    },
    
    // Return if WAT administrator should know about multitenant enviroment
    knowMultitenant: function () {
        return this.isMultitenant() && (this.isRecoveradmin() || this.isSuperadmin());
    },
    
    getDocGuides: function () {
        guides = {
            'introduction': 'Introduction',
            'stepbystep': 'WAT Step by step', 
            'user': 'User guide'
        };
        
        if (this.knowMultitenant()) {
            guides.multitenant = 'Multitenant guide'
        }
        
        return guides;
    },
    
    // Return a boolean value depending on if the retrieved guide name is valid or not for current administrator
    // Params:
    //      guide: guide name that will be checked as valid or not
    isValidDocGuide: function (guide) {
        var guides = this.getDocGuides ();
        
        return $.inArray(guide, Object.keys(guides)) != -1;
    },
    
    // Stored views configuration retrieved from database to the inner data structure
    // Params:
    //      viewsConfiguration: Hash with each view configured on DB for current admin.
    storeViewsConfiguration: function (viewsConfiguration) {
        $.each (viewsConfiguration, function (iView, view) {
            switch (view.view_type) {
                case 'list_column':
                    if (!Wat.I.listFields[view.qvd_object][view.field]) {
                        Wat.I.listFields[view.qvd_object][view.field] = {
                            'display': view.visible,
                            'noTranslatable': true,
                            'fields': [
                                view.field
                            ],
                            'acls': view.qvd_object + '.see.properties',
                            'property': true,
                            'text': view.field
                        };
                    }
                    
                    Wat.I.listFields[view.qvd_object][view.field].display = view.visible;
                    Wat.I.listFields[view.qvd_object][view.field].customized = true;
                    break;
                case 'filter':
                    if (!Wat.I.formFilters[view.qvd_object][view.field]) {
                        Wat.I.formFilters[view.qvd_object][view.field] = {
                            'filterField': view.field,
                            'type': 'text',
                            'text': view.field,
                            'noTranslatable': true,
                            'property': true,
                            'acls': view.qvd_object + '.filter.properties',
                        };
                    }
                    
                    switch (view.device_type) {
                        case 'mobile':
                            Wat.I.formFilters[view.qvd_object][view.field].displayMobile = view.visible;
                            break;
                        case 'desktop':
                            Wat.I.formFilters[view.qvd_object][view.field].displayDesktop = view.visible;
                            break;
                    }
                    
                    Wat.I.formFilters[view.qvd_object][view.field].customized = true;
                    break;
            }
        });
    },
    
    // Given an ACL or an array of ACLs, check if the current admin is granted to it
    // Params:
    //      acl: string or array of acls
    //      logic: OR/AND to calculate the pass condition if is array
    checkACL: function (acl, logic) {
        if ($.isArray(acl)) {
            var pass = 0;
            var that = this;
            $.each(acl, function (i, anAcl) {
                if ($.inArray(anAcl, that.acls) != -1) {
                    pass++;
                }
            });
            
            switch(logic) {
                case 'OR':
                    if (pass > 0) {
                        return true;
                    }
                    break;
                case 'AND':
                default:
                    if (pass == acl.length) {
                        return true;
                    }
                    break;
            }
        }
        else {
            return $.inArray(acl, this.acls) != -1;
        }
        
        if (DEBUG_ACL_FAILS) {
            console.warn('ACL Fail for user ' + this.login + ':');
            console.warn(acl);
        }

        return false;
    },
    
    // Check all the ACLs of predifened groups. If any of them is available, return true
    // Params:
    //      group: ACls group or groups name associted to groups of ACLs defined on configuration file
    checkGroupACL: function (group) {
        var aclGranted = false;
        
        // Convert to array if is not an array yet
        if (typeof group == 'string') {
            var groups = [group];
        }
        else {
            var groups = group;
        }
        
        var that = this;
        $.each(groups, function (iGroup, group) {
            if (aclGranted) {
                return false;
            }
            $.each(that.aclGroups[group], function (iAcl, acl) {
                if (that.checkACL(acl)) {
                    aclGranted = true;
                    return false;
                }
            });
        });
        
        return aclGranted;
    },
    
    // Return a given string if an acl is granted. Empty string will be returned otherwise
    // Params:
    //      string: string that will be returned if pass
    //      acl: acl that will be checked
    ifACL: function (string, acl) {
        if (this.checkACL(acl)) {
            return string;
        }
        else {
            return '';
        }
    },
    
    // Given configuration data (fields, filters, columns...) Delete those which specified ACLs doesnt pass
    // Params:
    //      data: Structure of data for any purpose where is specified ACL or ACL group to be checked for each element.
    purgeConfigData: function (data) {
        var that = this;
        
        // Check acls on data items to remove forbidden ones
        $.each(data, function (item, itemConfig) {
            if (itemConfig.groupAcls != undefined) {
                if (typeof itemConfig.groupAcls == 'string') {
                    itemConfig.groupAcls = [itemConfig.groupAcls];
                }
                
                itemConfig.acls = [];
                
                $.each (itemConfig.groupAcls, function (iGACLs, gACLs) {
                    var acls = that.aclGroups[gACLs];
                    itemConfig.acls = itemConfig.acls.concat(acls);
                });
            }
                        
            if (itemConfig.acls != undefined) {
                if (!that.checkACL(itemConfig.acls, itemConfig.aclsLogic)) {
                    delete data[item];
                }
            }
        });
        
        return data;
    },
    
    // Set different parameters to correct menu and sections visibility. 
    // These settings will be performed depending on ACL checks, mono/multi tenant configurations, or administrators tenants type
    configureVisibility: function () {        
        Wat.I.menu = $.extend(true, {}, Wat.I.menuOriginal);
        Wat.I.userMenu = $.extend(true, {}, Wat.I.menuUserOriginal);
        Wat.I.helpMenu = $.extend(true, {}, Wat.I.menuHelpOriginal);
        Wat.I.configMenu = $.extend(true, {}, Wat.I.menuConfigOriginal);
        Wat.I.setupMenu = $.extend(true, {}, Wat.I.menuSetupOriginal);
        Wat.I.mobileMenu = $.extend(true, {}, Wat.I.mobileMenuOriginal);
        Wat.I.cornerMenu = $.extend(true, {}, Wat.I.cornerMenuOriginal);

        var that = this;

        // Menu visibility
        var aclMenu = {
            'di.see-main.' : 'dis',
            'host.see-main.' : 'hosts',
            'osf.see-main.' : 'osfs',
            'user.see-main.' : 'users',
            'vm.see-main.' : 'vms',
        };
        
        $.each(aclMenu, function (acl, menu) {
            if (!that.checkACL(acl)) {
                delete Wat.I.menu[menu];
                delete Wat.I.mobileMenu[menu];
                delete Wat.I.cornerMenu.platform.subMenu[menu];
            }
        });
        
        // Menu visibility
        var aclSetupMenu = {
            'config.wat.' : 'watconfig',
            'role.see-main.' : 'roles',
            'administrator.see-main.' : 'administrators',
            'tenant.see-main.' : 'tenants',
            'views.see-main.' : 'views',
            'property.see-main.' : 'properties',
            'log.see-main.' : 'logs',
        };
        
        $.each(aclSetupMenu, function (acl, menu) {
            if (!that.checkACL(acl)) {
                delete Wat.I.setupMenu[menu];
                delete Wat.I.cornerMenu.wat.subMenu[menu];
            }
        });
        
        // Recover user will has not profile section
        if (Wat.C.isRecoveradmin()) {
            delete Wat.I.userMenu['profile'];
            delete Wat.I.cornerMenu.user.subMenu['profile'];
        }
        
        // Set to the menu option the link of its first sub-option link
        if (Wat.I.cornerMenu.wat && !$.isEmptyObject(Wat.I.cornerMenu.wat.subMenu)) {
            Wat.I.cornerMenu.wat.link = Wat.I.cornerMenu.wat.subMenu[Object.keys(Wat.I.cornerMenu.wat.subMenu)[0]].link;
        }         
        if (Wat.I.cornerMenu.user && !$.isEmptyObject(Wat.I.cornerMenu.user.subMenu)) {
            Wat.I.cornerMenu.user.link = Wat.I.cornerMenu.user.subMenu[Object.keys(Wat.I.cornerMenu.user.subMenu)[0]].link;
        }        
        if (Wat.I.cornerMenu.platform && !$.isEmptyObject(Wat.I.cornerMenu.platform.subMenu)) {
            Wat.I.cornerMenu.platform.link = Wat.I.cornerMenu.platform.subMenu[Object.keys(Wat.I.cornerMenu.platform.subMenu)[0]].link;
        }
        
        // Hide help option if there are not acls given (not logged)
        if (Wat.C.acls.length == 0) {
            delete Wat.I.cornerMenu.help;
        }
        
        if ($.isEmptyObject(Wat.I.cornerMenu.platform.subMenu)) {
            delete Wat.I.cornerMenu.platform;
        }        
        
        if ($.isEmptyObject(Wat.I.cornerMenu.wat.subMenu)) {
            delete Wat.I.cornerMenu.wat;
        }
        
        if (!that.checkACL('config.qvd.')) {
            delete Wat.I.cornerMenu.config;
        }
        
        // For tenant admins (not superadmins) and recover admin in monotenant mode the acl section tenant will not exist
        var tenantsExist = false;
        
        if (Wat.C.isSuperadmin() && Wat.C.isMultitenant()) {
            tenantsExist = true;
        }
        
        // For monotenant  enviroments, multitenant documentation will not be shown
        if (!Wat.C.isMultitenant()) {
            $.each(Wat.I.docSections, function (iSec, sec) {
                if (sec.guide == 'multitenant') {
                    delete Wat.I.docSections[iSec];
                }
            });
        }
        
        if (!tenantsExist) {
            delete ACL_SECTIONS['tenant'];
            delete ACL_SECTIONS_PATTERNS['tenant'];
        }
    },
    
    // Check if administrator session is expired
    // Params:
    //      response: API call response
    sessionExpired: function (response) {
        if (!Wat.Router.watRouter) {
            return false;
        }
        else {
            switch  (response.status) { 
                case STATUS_SESSION_EXPIRED:
                case STATUS_CREDENTIALS_FAIL:
                    // Close dialog (if opened)
                    $('.js-dialog-container').remove();
                    $('html, body').attr('style', '');
                    
                    // Store message on cookies to print it after reloading
            $.cookie('messageToShow', JSON.stringify({'message': ALL_STATUS[response.status], 'messageType': 'error'}), {expires: 1, path: '/'});
            window.location = '#/logout';
            return true;
        }
        }
        
        return false;
    },
    
    // Retrieve the block size for this administrator
    getBlock: function () {
        if (this.block == 0) {
            return this.tenantBlock;
        }
        else {
            return this.block;
        }
    },
    
    // Abort stored ajax requests
    abortRequests: function () {
        var that = this;
        
        $.each(that.requests, function(idx, jqXHR) {
            if (jqXHR == undefined) {
                return;
            }
            
            jqXHR.abort();
        });

        $.each(that.requests, function(idx, jqXHR) {
            var index = $.inArray(jqXHR, that.requests);
            if (index > -1) {
                that.requests.splice(index, 1);
            }
        });
    },
    
    // Add common functions to the view
    addCommonFunctions: function (that) {
        if (Wat.Common.BySection[that.qvdObj] != undefined) {
            if (!$.isEmptyObject(Wat.Common.BySection[that.qvdObj])) {
                $.extend(that, Wat.Common.BySection[that.qvdObj]);
                that.initializeCommon(that);
                delete that.initializeCommon;
            }
        }
    },
    
    setConfigToken: function (token, value) {
        if ($.inArray(token, ['apiAddress', 'apiPort']) == -1) {
            console.error('A not allowed token was intented to load from config file (' + token + ')');
            return;
        }
        
        this[token] = value;
    },
    
    // Add extensions or another setup parameters to jQuery
    setupJQuery: function () {
        // Extend jQuery with pseudo selector :blank
        (function($) {
            $.extend($.expr[":"], {
                // http://docs.jquery.com/Plugins/Validation/blank
                blank: function(a) {
                    return !$.trim(a.value);
                },
            });
        })(jQuery);
        

        // Setup jQuery ajax to store all requests in a requests queue
        $.ajaxSetup({
            beforeSend: function(jqXHR) {
                // Dictionary calls will not be stored
                if (jqXHR.requestURL.indexOf('dictionaries') != -1) {
                    return;
                }
                
                Wat.C.requests.push(jqXHR);
            },
            complete: function(jqXHR) {
                var index = $.inArray(jqXHR, Wat.C.requests);
                if (index > -1) {
                    Wat.C.requests.splice(index, 1);
                }
            }
        });
        
		// Attach request url to ajax data
        $.ajaxPrefilter(function( options, originalOptions, jqXHR ) {
            jqXHR.requestURL = options.url;   
        });
    },
    
    // Read config file "/config.json"
    readConfigFile: function (callback) {
        $.ajax({
            url: Wat.C.configFileName,
            method: 'GET',
            async: true,
            contentType: 'json',
            cache: false,
            complete: function (response) {
                var isJSON = true;
                var configTokens = '';
                
                try {
                    configTokens = JSON.parse(response.responseText);
                }
                catch(err) {
                    isJSON = false;
                } 
                
                if (isJSON) {
                $.each(configTokens, function (token, value) {
                    Wat.C.setConfigToken(token, value);
                });
                                
                // After read configuration file, we will set API address
                Wat.C.initApiAddress();
                }
                
                // Remember login from cookies to recover session if was setted previously
                Wat.L.rememberLogin();
            }
        });
    },
    
    setupLibraries: function () {
        // Attach fast click events to separate tap from click
        Wat.I.attachFastClick(); 
    }
}