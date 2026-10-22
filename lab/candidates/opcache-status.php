<?php
$status = function_exists('opcache_get_status') ? opcache_get_status(false) : false;
if (!is_array($status) || empty($status['opcache_enabled'])) {
    http_response_code(503);
    echo "OPCACHE_DISABLED\n";
    exit;
}
echo "OPCACHE_OK\n";
