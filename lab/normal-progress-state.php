<?php
header('Content-Type: text/plain');

if (!session_start()) {
    http_response_code(500);
    exit("SESSION_FAIL\n");
}

echo isset($_SESSION['backport_health']) && $_SESSION['backport_health'] === 'ok'
    ? "SESSION_OK\n" : "SESSION_FAIL\n";
echo isset($_SESSION['upload_progress_check'])
    ? "PROGRESS_PRESENT\n" : "PROGRESS_ABSENT\n";
