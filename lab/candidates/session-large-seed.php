<?php
ini_set('memory_limit', '32M');
session_start();
$_SESSION['ordinary_data'] = str_repeat('x', 5 * 1024 * 1024);
session_write_close();
header('Content-Type: text/plain');
echo "SEEDED\n";
