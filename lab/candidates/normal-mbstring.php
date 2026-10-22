<?php
header('Content-Type: text/plain; charset=UTF-8');
$parsed = [];
mb_parse_str('alpha=ordinary', $parsed);
if ($parsed !== ['alpha' => 'ordinary']) {
    http_response_code(500);
    exit('MBSTRING_FAIL');
}
$quoted = mb_convert_encoding('A=B', 'Quoted-Printable', 'UTF-8');
$mime = mb_encode_mimeheader('café', 'UTF-8');
if (mb_convert_encoding(mb_convert_encoding('ordinary', 'UTF-16LE', 'UTF-8'), 'UTF-8', 'UTF-16LE') !== 'ordinary'
    || mb_convert_encoding($quoted, 'UTF-8', 'Quoted-Printable') !== 'A=B'
    || mb_substr_count('banana', 'ana', 'UTF-8') !== 1
    || mb_ord('A', 'UTF-8') !== 65
    || mb_convert_kana('Ａ', 'r', 'UTF-8') !== 'A'
    || mb_decode_mimeheader($mime) !== 'café'
    || mb_ereg_replace('a', 'o', 'banana') !== 'bonono'
    || mb_eregi_replace('a', 'o', 'BANANA') !== 'BoNoNo'
    || mb_ereg_replace_callback('a', function ($match) { return 'o'; }, 'banana') !== 'bonono') {
    http_response_code(500);
    exit('MBSTRING_FAIL');
}
echo 'MBSTRING_OK';
