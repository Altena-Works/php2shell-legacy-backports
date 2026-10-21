<?php
function ordinary_frames($remaining, $value) {
    if ($remaining === 0) {
        debug_backtrace();
        echo 'NO_LIMIT';
        return;
    }
    ordinary_frames($remaining - 1, $value);
}
ordinary_frames(20000, 'ordinary');
