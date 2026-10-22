<?php
ini_set('memory_limit', '8M');
header('Content-Type: text/plain');
echo "READY\n";
flush();
$input = str_repeat('A', 2500000);
mb_convert_kana($input, 'R', 'UTF-8');
echo 'RETURNED';
