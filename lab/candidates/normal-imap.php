<?php
if (!extension_loaded('imap')) {
    echo "IMAP_MISSING\n";
    exit;
}

if (($_GET['mode'] ?? 'normal') === 'normal') {
    $parts = imap_mime_header_decode('=?UTF-8?Q?ordinary_data?=');
    if (count($parts) !== 1 || $parts[0]->charset !== 'UTF-8'
        || $parts[0]->text !== 'ordinary data') {
        echo "IMAP_FAILED\n";
        exit;
    }
    echo "IMAP_OK\n";
    exit;
}

$header = str_repeat('=?UTF-8?Q?ordinary_data?= ', 20000);
if (ini_set('memory_limit', '8M') === false) {
    echo "SETUP_FAILED\n";
    exit;
}
echo "READY\n";
imap_mime_header_decode($header);
echo "RETURNED\n";
