<?php
ini_set('memory_limit', '8M');
header('Content-Type: text/plain');
echo "READY\n";
flush();
$input = str_repeat('=', 2000000);
mb_convert_encoding($input, 'Quoted-Printable', 'UTF-8');
echo 'RETURNED';
