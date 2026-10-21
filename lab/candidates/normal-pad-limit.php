<?php
if (!isset($_GET['limit'])) {
    echo str_pad('ab', 6, 'xy') === 'abxyxy' ? "PAD_OK\n" : "PAD_BAD\n";
    return;
}

ini_set('memory_limit', '8M');
str_pad('x', 32 * 1024 * 1024);
echo "RETURNED\n";
