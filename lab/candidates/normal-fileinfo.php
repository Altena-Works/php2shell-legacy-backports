<?php
header('Content-Type: text/plain');
$finfo = new finfo(FILEINFO_MIME_TYPE);
$plain = $finfo->buffer("ordinary text\n");
$office = $finfo->file('/src/ext/fileinfo/tests/resources/test.ppt');
if ($plain !== 'text/plain' || $office !== 'application/vnd.ms-powerpoint') {
    http_response_code(500);
    exit('FILEINFO_FAIL');
}
echo 'FILEINFO_OK ', $office;
