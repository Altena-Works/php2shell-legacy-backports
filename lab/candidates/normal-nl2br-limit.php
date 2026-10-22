<?php
if (!isset($_GET['limit'])) {
    echo nl2br("a\nb", false) === "a<br>\nb"
        && nl2br("x\r\ny") === "x<br />\r\ny"
        ? "NL2BR_OK\n" : "NL2BR_BAD\n";
    return;
}

ini_set('memory_limit', '8M');
$input = str_repeat("\n", 2 * 1024 * 1024);
echo "READY\n";
nl2br($input);
echo "RETURNED\n";
