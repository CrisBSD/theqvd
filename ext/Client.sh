cd $(dirname $0)

DEBUG="${DEBUG:+gdb --args}"

$DEBUG perl -Mlib::glob=*/lib QVD-Client/bin/qvd-gui-client.pl
