<?php
class ImplodePart {
    public function __toString() { return 'q'; }
}

if (!isset($_GET['limit'])) {
    $pieces = ['a', 'b'];
    echo implode('-', $pieces) === 'a-b'
        && implode($pieces, '-') === 'a-b'
        && implode('-', [new ImplodePart(), 'b']) === 'q-b'
        ? "IMPLODE_OK\n" : "IMPLODE_BAD\n";
    return;
}

ini_set('memory_limit', '8M');
$glue = str_repeat('x', 1024 * 1024);
$pieces = array_fill(0, 32, 'y');
$pieces[0] = new ImplodePart();
implode($glue, $pieces);
echo "RETURNED\n";
