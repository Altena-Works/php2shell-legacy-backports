<?php
header('Content-Type: text/plain; charset=UTF-8');
$utf16 = (new UConverter('UTF-16LE', 'UTF-8'))->convert('café');
$back = (new UConverter('UTF-8', 'UTF-16LE'))->convert($utf16);
$normalized = Normalizer::normalize("e\u{301}", Normalizer::FORM_C);
if ($back !== 'café' || $normalized !== 'é') {
    http_response_code(500);
    exit('INTL_FAIL');
}
echo 'INTL_OK';
