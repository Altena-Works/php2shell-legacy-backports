<?php
function first_frame($value) {
    $trace = debug_backtrace();
    return $trace[0]['args'][0] === $value;
}
header('Content-Type: text/plain');
echo first_frame('ordinary') ? 'BACKTRACE_OK' : 'BACKTRACE_BAD';
