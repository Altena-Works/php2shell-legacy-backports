<?php
header('Content-Type: text/plain');

if (!isset($_GET['limit'])) {
    $plain = setrawcookie('plain', 'safe-check');
    $encoded = setcookie('encoded', 'safe check');
    echo $plain && $encoded ? "COOKIE_OK\n" : "COOKIE_FAIL\n";
    return;
}

ini_set('memory_limit', '8M');
$value = str_repeat('a', 5 * 1024 * 1024);
echo "READY\n";
setrawcookie('large', $value);
echo "RETURNED\n";
