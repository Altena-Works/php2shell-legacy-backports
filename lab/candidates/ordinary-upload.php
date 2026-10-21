<?php
header('Content-Type: text/plain');
echo isset($_FILES['attachment']) ? 'UPLOAD_OK' : 'UPLOAD_MISSING';
