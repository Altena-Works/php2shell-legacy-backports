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

if (isset($_GET['final'])) {
    $progress = isset($_SESSION['upload_progress_check'])
        ? $_SESSION['upload_progress_check'] : null;
    echo is_array($progress)
        && isset($progress['done'], $progress['bytes_processed'], $progress['content_length'])
        && $progress['done'] === true
        && $progress['bytes_processed'] === $progress['content_length']
        ? "PROGRESS_COMPLETE\n" : "PROGRESS_INCOMPLETE\n";
}
