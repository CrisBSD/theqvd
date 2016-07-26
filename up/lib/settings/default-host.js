var qvdObj = 'host';

// Columns configuration on list view
Up.I.listFields[qvdObj] = {
    'checks': {
        'display': true,
        'fields': [],
        'acls': [
            'host.delete-massive.',
            'host.update-massive.block',
            'host.update-massive.stop-vms',
            'host.update-massive.properties'
        ],
        'aclsLogic': 'OR',
        'fixed': true,
        'sortable': false,
    },
    'info': {
        'display': true,
        'fields': [
            'state',
            'blocked'
        ],
        'acls': [
            'host.see.block',
            'host.see.state'
        ],
        'aclsLogic': 'OR',
        'text': 'Info',
        'sortable': false,
    },
    'id': {
        'display': false,
        'fields': [
            'id'
        ],
        'acls': 'host.see.id',
        'text': 'Id',
        'sortable': true,
    },
    'name': {
        'display': true,
        'fields': [
            'id',
            'name'
        ],
        'text': 'Name',
        'fixed': true,
        'sortable': true,
    },
    'description': {
        'display': false,
        'fields': [
            'description'
        ],
        'acls': 'host.see.description',
        'text': 'Description',
        'sortable': true,
    },
    'state': {
        'display': false,
        'fields': [
            'state'
        ],
        'acls': 'host.see.state',
        'text': 'State',
        'sortable': true,
    },
    'address': {
        'display': true,
        'fields': [
            'address'
        ],
        'acls': 'host.see.address',
        'text': 'IP address',
        'sortable': true,
    },
    'vms_connected': {
        'display': true,
        'fields': [
            'id',
            'vms_connected'
        ],
        'acls': 'host.see.vms-info',
        'text': 'Running VMs',
        'sortable': false,
    },
    'creation_date': {
        'text': 'Creation date',
        'fields': [
            'creation_date'
        ],
        'acls': 'host.see.creation-date',
        'display': false,
        'sortable': true,
    },
    'creation_admin_name': {
        'text': 'Created by',
        'fields': [
            'creation_admin_name',
            'creation_admin_id'
        ],
        'acls': 'host.see.created-by',
        'display': false,
        'sortable': true,
    }
};

Up.I.listDefaultFields[qvdObj] = $.extend({}, Up.I.listFields[qvdObj]);

// Fields configuration on details view
Up.I.detailsFields[qvdObj] = {
    'id': {
        'display': false,
        'fields': [
            'id'
        ],
        'acls': 'host.see.id',
        'text': 'Id'
    },
    'name': {
        'display': true,
        'fields': [
            'id',
            'name'
        ],
        'text': 'Name'
    },
    'block': {
        'display': true,
        'fields': [
            'id'
        ],
        'acls': 'host.see.block',
        'text': 'Blocking'
    },
    'state': {
        'display': false,
        'fields': [
            'state'
        ],
        'acls': 'host.see.state',
        'text': 'State'
    },
    'address': {
        'display': true,
        'fields': [
            'address'
        ],
        'acls': 'host.see.address',
        'text': 'IP address'
    },
    'connected_vms': {
        'display': true,
        'fields': [
            'id',
            'number_of_vms_connected'
        ],
        'acls': 'host.see.vms-info',
        'text': 'Running VMs'
    },
    'creation_date': {
        'text': 'Creation date',
        'fields': [
            'creation_date'
        ],
        'acls': 'host.see.creation-date',
        'display': false
    },
    'creation_admin': {
        'text': 'Created by',
        'fields': [
            'creation_admin'
        ],
        'acls': 'host.see.created-by',
        'display': false
    }
};

Up.I.detailsDefaultFields[qvdObj] = $.extend({}, Up.I.detailsFields[qvdObj]);

// Filters configuration on list view
Up.I.formFilters[qvdObj] = {
    'name': {
        'filterField': 'name',
        'type': 'text',
        'text': 'Search by name',
        'displayMobile': true,
        'displayDesktop': true,
        'acls': 'host.filter.name'
    },
    'state': {
        'filterField': 'state',
        'type': 'select',
        'text': 'State',
        'class': 'chosen-single',
        'options': [
            {
                'value': FILTER_ALL,
                'text': 'All',
                'selected': true
            },
            {
                'value': 'running',
                'text': 'Running',
                'selected': false
            },
            {
                'value': 'stopped',
                'text': 'Stopped',
                'selected': false
            },
            {
                'value': 'starting',
                'text': 'Starting',
                'selected': false
            },
            {
                'value': 'stopping',
                'text': 'Stopping',
                'selected': false
            },
            {
                'value': 'lost',
                'text': 'Lost',
                'selected': false
            }
                    ],
        'displayMobile': false,
        'displayDesktop': true,
        'acls': 'host.filter.state'
    },
    'vm': {
        'filterField': 'vm_id',
        'type': 'select',
        'text': 'Virtual machine',
        'class': 'chosen-advanced',
        'fillable': true,
        'options': [
            {
                'value': FILTER_ALL,
                'text': 'All',
                'selected': true
            }
                    ],
        'displayMobile': false,
        'displayDesktop': true,
        'acls': 'host.filter.vm'
    },
    'blocked': {
        'filterField': 'blocked',
        'type': 'select',
        'text': 'Blocking',
        'class': 'chosen-advanced',
        'fillable': false,
        'options': [
            {
                'value': FILTER_ALL,
                'text': 'All',
                'selected': true
            },
            {
                'value': 1,
                'text': 'Blocked'
            },
            {
                'value': 0,
                'text': 'Unblocked'
            }
                    ],
        'displayMobile': false,
        'displayDesktop': true,
        'acls': 'host.filter.block'
    },
    'administrator': {
        'filterField': 'creation_admin_id',
        'type': 'select',
        'text': 'Created by',
        'class': 'chosen-advanced',
        'fillable': true,
        'options': [
            {
                'value': FILTER_ALL,
                'text': 'All',
                'selected': true
            }
                    ],
        'displayMobile': false,
        'displayDesktop': false,
        'acls': 'host.filter.created-by',
    },
    'antiquity': {
        'filterField': 'creation_date',
        'type': 'select',
        'text': 'Antiquity',
        'class': 'chosen-single',
        'fillable': false,
        'transform': 'dateGreatThanPast',
        'options': ANTIQUITY_OPTIONS,
        'displayMobile': false,
        'displayDesktop': false,
        'acls': 'host.filter.creation-date'
    },
    'min_date': {
        'filterField': 'creation_date',
        'type': 'text',
        'text': 'Min creation date',
        'transform': 'dateMin',
        'class': 'datepicker-past date-filter',
        'displayMobile': false,
        'displayDesktop': false,
        'acls': 'host.filter.creation-date'
    },
    'max_date': {
        'filterField': 'creation_date',
        'type': 'text',
        'text': 'Max creation date',
        'transform': 'dateMax',
        'class': 'datepicker-past date-filter',
        'displayMobile': false,
        'displayDesktop': false,
        'acls': 'host.filter.creation-date'
    }
};

Up.I.formDefaultFilters[qvdObj] = $.extend({}, Up.I.formFilters[qvdObj]);

// Actions of the bottom of the list (those that will be done with selected items) configuration on list view
Up.I.selectedActions[qvdObj] = {
    'massive_changes': {
        'text': 'Edit',
        'groupAcls': 'hostMassiveEdit',
        'aclsLogic': 'OR',
        'iconClass': 'fa fa-pencil',
        'otherClass': 'js-only-massive'
    },
    'changes': {
        'text': 'Edit',
        'groupAcls': 'hostEdit',
        'aclsLogic': 'OR',
        'iconClass': 'fa fa-pencil',
        'otherClass': 'js-only-one'
    },
    'block': {
        'text': 'Block',
        'acls': 'host.update-massive.block',
        'iconClass': 'fa fa-lock',
        'visibilityCondition': {
            'type': 'eq',
            'field': 'blocked',
            'value': '0'
        }
    },
    'unblock': {
        'text': 'Unblock',
        'acls': 'host.update-massive.block',
        'iconClass': 'fa fa-unlock-alt',
        'visibilityCondition': {
            'type': 'eq',
            'field': 'blocked',
            'value': '1'
        }
    },
    'stop_all': {
        'text': 'Stop all VMs',
        'acls': 'vm.update-massive.state',
        'iconClass': 'fa fa-stop',
        'visibilityCondition': {
            'type': 'ne',
            'field': 'number_of_vms_connected',
            'value': '0'
        }
    },
    'delete': {
        'text': 'Delete',
        'acls': 'host.delete-massive.',
        'iconClass': 'fa fa-trash',
        'darkButton': true
    }
};

// Action button (tipically New button) configuration on list view
Up.I.listActionButton[qvdObj] = {
            'name': 'new_host_button',
            'value': 'New Node',
            'link': 'javascript:',
            'acl': 'host.create.'
        };

// Breadcrumbs configuration on list view
$.extend(Up.I.listBreadCrumbs[qvdObj], Up.I.homeBreadCrumbs);
Up.I.listBreadCrumbs[qvdObj]['next'] = {
            'screen': 'Node list'
        };

// Breadcrumbs configuration on details view
$.extend(true, Up.I.detailsBreadCrumbs[qvdObj], Up.I.listBreadCrumbs[qvdObj]);
Up.I.detailsBreadCrumbs[qvdObj].next.link = '#/hosts';
Up.I.detailsBreadCrumbs[qvdObj].next.linkACL = 'host.see-main.';
Up.I.detailsBreadCrumbs[qvdObj].next.next = {
            'screen': '' // Will be filled dinamically
        };