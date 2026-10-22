<?php
ini_set('memory_limit', '8M');
header('Content-Type: text/plain');
echo "READY\n";
flush();
$input = str_repeat('A', 2000000);
Normalizer::normalize($input, Normalizer::FORM_D);
echo 'RETURNED';
