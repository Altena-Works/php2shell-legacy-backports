<?php
header('Content-Type: text/plain');

$path = tempnam(sys_get_temp_dir(), 'php73-file-');
if ($path === false) {
    echo "FILE_IMAGE_FAIL\n";
    return;
}
try {
    file_put_contents($path, "alpha\nbeta\n");
    $lines = file($path, FILE_IGNORE_NEW_LINES);
    $handle = fopen($path, 'rb');
    $line = fgets($handle);
    fclose($handle);

    file_put_contents($path, "a,b\n1,2\n");
    $handle = fopen($path, 'rb');
    $csv = fgetcsv($handle);
    fclose($handle);

    file_put_contents($path, "#define example_width 2\n#define example_height 3\n");
    $image = getimagesize($path);

    echo $lines === ['alpha', 'beta'] && $line === "alpha\n"
        && $csv === ['a', 'b'] && $image[0] === 2 && $image[1] === 3
        ? "FILE_IMAGE_OK\n" : "FILE_IMAGE_FAIL\n";
} finally {
    unlink($path);
}
