<?php
header('Content-Type: text/plain');
if (isset($_GET['seed'])) {
    ini_set('memory_limit', '64M');
    $encoded = serialize(range(0, 149999));
    file_put_contents('/tmp/ordinary-session-data', $encoded);
    echo "SEEDED\n";
    return;
}
ini_set('memory_limit', '8M');
$encoded = file_get_contents('/tmp/ordinary-session-data');
$value = unserialize($encoded);
echo is_array($value) ? "UNSERIALIZE_OK\n" : "UNSERIALIZE_FAILED\n";
