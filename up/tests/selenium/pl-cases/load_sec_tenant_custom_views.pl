$sel->click_ok("css=div.js-wat-menu.menu > ul > li.menu-option[data-target=\"views\"]");
WAIT: {
    for (1..60) {
        if (eval { $sel->is_element_present("css=div.sec-custom-views-tenant") }) { pass; last WAIT }
        sleep(1);
    }
    fail("timeout");
}
