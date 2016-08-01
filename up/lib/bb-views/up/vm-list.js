Up.Views.VMListView = Up.Views.ListView.extend({  
    qvdObj: 'vm',
    liveFields: ['state', 'user_state', 'ip', 'host_id', 'host_name', 'ssh_port', 'vnc_port', 'serial_port'],
    
    relatedDoc: {
        image_update: "Images update guide",
        full_vm_creation: "Create a virtual machine from scratch",
    },
    
    initialize: function (params) {   
        this.collection = new Up.Collections.VMs(params);
        
        Up.Views.ListView.prototype.initialize.apply(this, [params]);
    },
    
    // This events will be added to view events
    listEvents: {},
    
    openNewElementDialog: function (e) {
        this.model = new Up.Models.VM();
        
        this.dialogConf.title = $.i18n.t('New Virtual machine');
        Up.Views.ListView.prototype.openNewElementDialog.apply(this, [e]);
        
        var fillFields = function () {            
            // If main view is user view, we are creating a virtual machine from user details view. 
            // User and tenant (if exists) controls will be removed
            if (Up.CurrentView.qvdObj == 'user') {
                $('[name="user_id"]').parent().parent().remove();

                var userHidden = document.createElement('input');
                userHidden.type = "hidden";
                userHidden.name = "user_id";
                userHidden.value = Up.CurrentView.model.get('id');
                $('.editor-container').append(userHidden);

                if ($('[name="tenant_id"]').length > 0) {
                    $('[name="tenant_id"]').parent().parent().remove();

                    var tenantHidden = document.createElement('input');
                    tenantHidden.type = "hidden";
                    tenantHidden.name = "tenant_id";
                    tenantHidden.value = Up.CurrentView.model.get('tenant_id');
                    $('.editor-container').append(tenantHidden);
                    
                    // Store tenantId to be used on OSF filter
                    var tenantId = tenantHidden.value;
                }
            }
            else if ($('[name="tenant_id"]').length > 0) {
                // When tenant id is present attach change events. User, osf and di will be filled once the events were triggered
                Up.B.bindEvent('change', 'select[name="tenant_id"]', Up.B.editorBinds.filterTenantOSFs);
                Up.B.bindEvent('change', '[name="tenant_id"]', Up.B.editorBinds.filterTenantUsers);
                Up.I.chosenElement('[name="user_id"]', 'advanced100');
                Up.I.chosenElement('[name="osf_id"]', 'advanced100');
                Up.I.chosenElement('[name="di_tag"]', 'advanced100');
                return;
            }
            else {
                // Fill Users select on virtual machines creation form. 
                // This filling has sense when the view is the VM view and tenant filter is not present
                var params = {
                    'action': 'user_tiny_list',
                    'selectedId': '',
                    'controlName': 'user_id',
                    'chosenType': 'advanced100'
                };
                
                Up.A.fillSelect(params, function () {}); 
            }

            // Fill OSF select on virtual machines creation form
            var params = {
                'action': 'osf_tiny_list',
                'selectedId': '',
                'controlName': 'osf_id',
                'chosenType': 'advanced100'
            };
            
            // If tenant is defined, use it on OSF filter
            if (tenantId) {
                params.filters = {
                    tenant_id: tenantId
                };
            }

            Up.I.chosenElement('[name="di_tag"]', 'advanced100');
            
            $('[name="osf_id"] option').remove();
            
            Up.A.fillSelect(params, function () {
                // Fill DI Tags select on virtual machines creation form after fill OSF combo
                var params = {
                    'action': 'tag_tiny_list',
                    'selectedId': 'default',
                    'controlName': 'di_tag',
                    'filters': {
                        'osf_id': $('[name="osf_id"]').val()
                    },
                    'nameAsId': true,
                    'chosenType': 'advanced100'
                };

                Up.A.fillSelect(params); 
            });  
        }
                    
        fillFields();
    },
    
    createElement: function () {
        var valid = Up.Views.ListView.prototype.createElement.apply(this);
        
        if (!valid) {
            return;
        }
        
        // Properties to create, update and delete obtained from parent view
        var properties = this.properties;
                
        var context = $('.' + this.cid + '.editor-container');

        var user_id = context.find('[name="user_id"]').val();
        var osf_id = context.find('select[name="osf_id"]').val();
        
        var arguments = {
            "user_id": user_id,
            "osf_id": osf_id
        };
        
        if (!$.isEmptyObject(properties.set) && Up.C.checkACL('vm.create.properties')) {
            arguments["__properties__"] = properties.set;
        }
        
        var di_tag = context.find('select[name="di_tag"]').val();
        
        if (di_tag && Up.C.checkACL('vm.create.di-tag')) {
            arguments.di_tag = di_tag;
        }
        
        var name = context.find('input[name="name"]').val();
        if (name) {
            arguments["name"] = name;
        }
        
        var description = context.find('textarea[name="description"]').val();
        if (description) {
            arguments["description"] = description;
        }
        
        this.createModel(arguments, this.fetchList);
    },
    
    startVM: function (filters) {        
        var messages = {
            'success': 'Successfully required to be started',
            'error': 'Error starting Virtual machine'
        }
        
        Up.A.performAction ('vm_start', {}, filters, messages, function(){}, this);
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
    
    
    setupMassiveChangesDialog: function (that) {
        // If the edition is performed over one single element, call single editor
        if (that.selectedItems.length == 1) {
            that.editingFromList = true;
            this.openEditElementDialog(that);
            return;
        }
        
        Up.A.performAction('osf_all_ids', {}, {"vm_id": that.selectedItems}, {}, that.openMassiveChangesDialog, that);
    },
    
    configureMassiveEditor: function (that) {
        // Virtual machine form include a date time picker control, so we need enable it
        Up.I.enableDataPickers();
        
        var osfId = FILTER_ALL;
        // If there are returned more than 1 OSFs, it will restrict tag selection to head and default
        if($.unique(that.retrievedData.rows).length == 1) {
            osfId = that.retrievedData.rows[0];
            $('.js-advice-various-osfs').hide();
        }
        else {
            $('.js-advice-various-osfs').show();
        }
        
        var params = {
            'action': 'tag_tiny_list',
            'startingOptions': {
                '' : 'No changes',
                'default' : 'default',
                'head' : 'head'
            },
            'selectedId': '',
            'controlName': 'di_tag',
            'filters': {
                'osf_id': osfId
            },
            'nameAsId': true,
            'chosenType': 'advanced100'
        };
        
        Up.A.fillSelect(params);
    },
    
    updateMassiveElement: function (dialog, id) {
        var valid = Up.Views.ListView.prototype.updateElement.apply(this, [dialog]);
        
        if (!valid) {
            return;
        }
        
        // Properties to create, update and delete obtained from parent view
        var properties = this.properties;
        
        var arguments = {};
        
        if (!$.isEmptyObject(properties.set) && Up.C.checkACL('vm.update-massive.properties')) {
            arguments["__properties_changes__"] = properties;
        }
        
        var context = $('.' + this.cid + '.editor-container');
        
        var description = context.find('textarea[name="description"]').val();
        var di_tag = context.find('select[name="di_tag"]').val(); 
        
        var filters = {"id": id};
        
        if (description != '' && Up.C.checkACL('vm.update-massive.description')) {
            arguments["description"] = description;
        }
        
        if (di_tag != '' && Up.C.checkACL('vm.update-massive.di-tag')) {
            arguments["di_tag"] = di_tag;
        }
        
        if (Up.C.checkACL('vm.update-massive.expiration')) {
            // If expire is checked
            if (context.find('input.js-expire').is(':checked')) {
                var expiration_soft = context.find('input[name="expiration_soft"]').val();
                var expiration_hard = context.find('input[name="expiration_hard"]').val();

                if (expiration_soft != undefined) {
                    arguments['expiration_soft'] = expiration_soft;
                }

                if (expiration_hard != undefined) {
                    arguments['expiration_hard'] = expiration_hard;
                }
            }
        }
        
        this.resetSelectedItems();
        
        var auxModel = new Up.Models.VM();
        this.updateModel(arguments, filters, this.fetchList, auxModel);
    }
});