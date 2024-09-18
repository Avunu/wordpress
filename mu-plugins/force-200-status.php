<?php
// force-200-status.php
add_filter('status_header', 'force_200_status_code', 10, 4);
function force_200_status_code($status_header, $header, $text, $protocol) {
    return "$protocol 200 OK";
}
