<?php
header('X-Test-Worker: ' . getmypid());
ini_set('memory_limit', '8M');
$data = str_repeat('a', 9 * 1024 * 1024);
echo 'LIMIT_NOT_REACHED';
