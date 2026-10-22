<?php
header('Content-Type: text/plain; charset=UTF-8');
$parsed = [];
mb_parse_str('alpha=ordinary', $parsed);
if ($parsed !== ['alpha' => 'ordinary']) {
    http_response_code(500);
    exit('MBSTRING_FAIL');
}
if (mb_convert_encoding(mb_convert_encoding('ordinary', 'UTF-16LE', 'UTF-8'), 'UTF-8', 'UTF-16LE') !== 'ordinary'
    || mb_ereg_replace('a', 'o', 'banana') !== 'bonono'
    || mb_eregi_replace('a', 'o', 'BANANA') !== 'BoNoNo'
    || mb_ereg_replace_callback('a', function ($match) { return 'o'; }, 'banana') !== 'bonono') {
    http_response_code(500);
    exit('MBSTRING_FAIL');
}
echo 'MBSTRING_OK';
