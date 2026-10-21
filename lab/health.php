<?php
header('Content-Type: text/plain');
if (!session_start()) {
    http_response_code(500);
    exit("SESSION_FAIL\n");
}
$_SESSION['backport_health'] = 'ok';
echo PHP_VERSION, "\n", PHP_SAPI, "\n";
echo $_SESSION['backport_health'] === 'ok' ? "SESSION_OK\n" : "SESSION_FAIL\n";
