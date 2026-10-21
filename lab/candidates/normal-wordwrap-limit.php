<?php
if (!isset($_GET['limit'])) {
    $normal = wordwrap('alpha beta gamma', 6, '|') === 'alpha|beta|gamma';
    $forced = wordwrap('abcdef', 2, '<br>', true) === 'ab<br>cd<br>ef';
    $legacy = @wordwrap('x', 0, '|', true) === false;
    echo $normal && $forced && $legacy ? "WORDWRAP_OK\n" : "WORDWRAP_BAD\n";
    return;
}

ini_set('memory_limit', '8M');
$input = str_repeat('a', 1024 * 1024);
wordwrap($input, 1, '1234567890abcdef', true);
echo "RETURNED\n";
