<?php
header('Content-Type: text/plain');
$image = @exif_read_data('/src/ext/exif/tests/test4.jpg', null, true, false);
if (!is_array($image) || !isset($image['FILE']['FileName']) || $image['FILE']['FileName'] !== 'test4.jpg') {
    http_response_code(500);
    exit('EXIF_FAIL');
}
$thumbnail = @exif_thumbnail('/src/ext/exif/tests/test2.jpg');
if (!is_string($thumbnail) || strlen($thumbnail) !== 523
    || md5($thumbnail) !== '27bbfd9fc10e1e663d749f5225447905') {
    http_response_code(500);
    exit('EXIF_THUMBNAIL_FAIL');
}
echo 'EXIF_OK';
