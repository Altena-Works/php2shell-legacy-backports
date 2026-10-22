<?php
ini_set('memory_limit', '8M');
header('Content-Type: text/plain');
echo "READY\n";
flush();
$query = str_repeat('x=1&', 400000);
$parsed = [];
mb_parse_str($query, $parsed);
echo 'RETURNED';
