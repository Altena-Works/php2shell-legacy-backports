<?php
header('Content-Type: text/plain');

if (!isset($_POST['title']) || $_POST['title'] !== 'ordinary') {
    http_response_code(400);
    echo "POST_FIELD_FAIL\n";
    exit;
}

if (!isset($_FILES['attachment']) ||
    $_FILES['attachment']['error'] !== UPLOAD_ERR_OK ||
    $_FILES['attachment']['name'] !== 'note.txt' ||
    $_FILES['attachment']['size'] !== 5) {
    http_response_code(400);
    echo "FILE_FIELD_FAIL\n";
    exit;
}

echo "MULTIPART_OK\n";
