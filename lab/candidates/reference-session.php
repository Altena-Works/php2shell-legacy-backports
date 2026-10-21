<?php
header('Content-Type: text/plain');
if (!session_start()) {
    exit("SESSION_FAIL\n");
}
if (isset($_GET['seed'])) {
    $_SESSION['alias'] = 'ordinary';
    $_SESSION['upload_progress_check'] =& $_SESSION['alias'];
    echo "SEEDED\n";
} else {
    if (isset($_SESSION['alias']) && is_array($_SESSION['alias'])) {
        $_SESSION['alias']['marker'] = 'linked';
    }
    echo isset($_SESSION['upload_progress_check']['marker'])
        && $_SESSION['upload_progress_check']['marker'] === 'linked'
        ? "ALIAS_LINKED\n" : "ALIAS_BAD\n";
    echo isset($_SESSION['upload_progress_check']['bytes_processed'])
        ? "PROGRESS_OK\n" : "PROGRESS_BAD\n";
}
