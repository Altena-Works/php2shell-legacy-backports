<?php
header('Content-Type: text/plain');
ini_set('display_errors', '1');
$length = isset($_GET['n']) ? (int) $_GET['n'] : 2000000;
if ($length < 100000 || $length > 4000000) {
    http_response_code(400);
    exit('INVALID_LENGTH');
}
$source = '<?php /*' . str_repeat('a', $length) . '*/';
ini_set('memory_limit', '8M');
echo "READY\n";
flush();
token_get_all($source, isset($_GET['parse']) ? TOKEN_PARSE : 0);
echo "RETURNED\n";
