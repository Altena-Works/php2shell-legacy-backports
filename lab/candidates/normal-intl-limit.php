<?php
ini_set('memory_limit', '8M');
header('Content-Type: text/plain');
echo "READY\n";
flush();
$input = str_repeat('A', 2500000);
(new UConverter('UTF-16LE', 'UTF-8'))->convert($input);
echo 'RETURNED';
