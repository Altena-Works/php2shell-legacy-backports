<?php
header('Content-Type: text/plain');
$image = @exif_read_data('/src/ext/exif/tests/test4.jpg', null, true, false);
if (!is_array($image) || !isset($image['FILE']['FileName']) || $image['FILE']['FileName'] !== 'test4.jpg') {
    http_response_code(500);
    exit('EXIF_FAIL');
}
echo 'EXIF_OK';
