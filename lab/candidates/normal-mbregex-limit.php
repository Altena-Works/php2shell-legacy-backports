<?php
ini_set('memory_limit', '8M');
header('Content-Type: text/plain');
echo "READY\n";
flush();
mb_ereg_replace('a', str_repeat('x', 512), str_repeat('a', 20000));
echo 'RETURNED';
