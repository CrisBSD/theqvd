$sel->click_ok("css=div.js-user-menu.menu > ul > li.menu-option[data-target=\"profile\"]");
WAIT: {
    for (1..60) {
        if (eval { $sel->is_element_present("css=div.sec-profile") }) { pass; last WAIT }
        sleep(1);
    }
    fail("timeout");
}
