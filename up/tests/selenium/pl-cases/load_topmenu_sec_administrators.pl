$sel->mouse_over_ok("css=li.menu-option.js-menu-option-wat");
$sel->click_ok("css=a.js-submenu-option-administrators");
WAIT: {
    for (1..60) {
        if (eval { $sel->is_element_present("css=div.sec-list-administrator") }) { pass; last WAIT }
        sleep(1);
    }
    fail("timeout");
}
