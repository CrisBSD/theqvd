var qvdObj = 'tenant';

// Columns configuration on list view
Up.I.listFields[qvdObj] = {
    'checks': {
        'display': true,
        'fields': [],
        'acls': 'tenant.delete-massive.',
        'fixed': true,
        'text': '',
        'sortable': false,
    },
    'info': {
        'display': true,
        'fields': [
            'blocked'
        ],
        'groupAcls': [
            'tenantInfo'
        ],
        'aclsLogic': 'OR',
        'text': 'Info',
        'sortable': false,
    },
    'id': {
        'display': true,
        'fields': [
            'id'
        ],
        'acls': 'tenant.see.id',
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
        'acls': 'tenant.see.description',
        'text': 'Description',
        'sortable': true,
    },
    'creation_date': {
        'text': 'Creation date',
        'fields': [
            'creation_date'
        ],
        'acls': 'tenant.see.log',
        'display': false,
        'sortable': true,
    },
    'creation_admin_name': {
        'text': 'Created by',
        'fields': [
            'creation_admin_name',
            'creation_admin_id'
        ],
        'acls': 'tenant.see.log',
        'display': false,
        'sortable': true,
    }
};

Up.I.listDefaultFields[qvdObj] = $.extend({}, Up.I.listFields[qvdObj]);

        
// Filters configuration on list view
Up.I.formFilters[qvdObj] = {
    'name': {
        'filterField': 'name',
        'type': 'text',
        'text': 'Name',
        'displayMobile': true,
        'displayDesktop': true
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
        'acls': 'tenant.filter.block'
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
        'acls': 'tenant.filter.created-by',
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
        'acls': 'tenant.filter.creation-date'
    },
    'min_date': {
        'filterField': 'creation_date',
        'type': 'text',
        'text': 'Min creation date',
        'transform': 'dateMin',
        'class': 'datepicker-past date-filter',
        'displayMobile': false,
        'displayDesktop': false,
        'acls': 'tenant.filter.creation-date'
    },
    'max_date': {
        'filterField': 'creation_date',
        'type': 'text',
        'text': 'Max creation date',
        'transform': 'dateMax',
        'class': 'datepicker-past date-filter',
        'displayMobile': false,
        'displayDesktop': false,
        'acls': 'tenant.filter.creation-date'
    }
};

Up.I.formDefaultFilters[qvdObj] = $.extend({}, Up.I.formFilters[qvdObj]);

// Actions of the bottom of the list (those that will be done with selected items) configuration on list view
Up.I.selectedActions[qvdObj] = {
    'massive_changes': {
        'text': 'Edit',
        'groupAcls': 'tenantMassiveEdit',
        'aclsLogic': 'OR',
        'iconClass': 'fa fa-pencil'
    },
    'block': {
        'text': 'Block',
        'acls': 'tenant.update-massive.block',
        'iconClass': 'fa fa-lock',
        'visibilityCondition': {
            'type': 'eq',
            'field': 'blocked',
            'value': '0'
        }
    },
    'unblock': {
        'text': 'Unblock',
        'acls': 'tenant.update-massive.block',
        'iconClass': 'fa fa-unlock-alt',
        'visibilityCondition': {
            'type': 'eq',
            'field': 'blocked',
            'value': '1'
        }
    },
    'delete': {
        'text': 'Delete',
        'acls': 'tenant.delete-massive.',
        'iconClass': 'fa fa-trash',
        'darkButton': true
    }
};

// Action button (tipically New button) configuration on list view
Up.I.listActionButton[qvdObj] = {
            'name': 'new_tenant_button',
            'value': 'New Tenant',
            'link': 'javascript:',
            'acl': 'tenant.create.'
        };

// Breadcrumbs configuration on list view
$.extend(Up.I.listBreadCrumbs[qvdObj], Up.I.homeBreadCrumbs);
Up.I.listBreadCrumbs[qvdObj]['next'] = {
            'screen': 'WAT Management',
            'next': {
                'screen': 'Tenants'
            }
        };

// Breadcrumbs configuration on details view
$.extend(true, Up.I.detailsBreadCrumbs[qvdObj], Up.I.listBreadCrumbs[qvdObj]);
Up.I.detailsBreadCrumbs[qvdObj].next = {
            'screen': 'WAT Management',
            'next': {
                'screen': 'Tenants',
                'link': '#/tenants',
                'linkACL': 'tenant.see-main.',
                'next': {
                    'screen': '' // Will be filled dinamically
                }
            }
        };