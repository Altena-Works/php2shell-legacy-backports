<?php
header('Content-Type: text/plain');
$source = '<?php echo 123;';
$normal = token_get_all($source);
$parsed = token_get_all($source, TOKEN_PARSE);
if (!is_array($normal) || !is_array($parsed) || count($normal) !== count($parsed)) {
    http_response_code(500);
    exit('TOKEN_FAIL');
}
if ($normal[1][0] !== T_ECHO || $parsed[1][0] !== T_ECHO) {
    http_response_code(500);
    exit('TOKEN_FAIL');
}
echo 'TOKEN_OK';
