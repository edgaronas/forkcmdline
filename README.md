# NAME

**forkcmdline** - run Perl `system` function with `Parallel::ForkManager`
from input or file.

# SYNOPSIS

    forkcmdline [OPTIONS] CMDLINE [CMDLINE ...]
    forkcmdline [OPTIONS] --read CMDFILE [CMDFILE ...]

# DESCRIPTION

## Dependencies

`strict`, `warnings` (with `FATAL` warnings) - Perl standard modules.

`Parallel::ForkManager` - Perl fork managing.

`Time::HiRes` - precise elapsed time.

`Getopt::Long` - command line options handling.

`Pod::PlainText` - POD text extraction for help.

## Options

    -a, --writeall=FILEBASE 
                write exitcodes, stdout and stderr of cmdlines to files with fixed base name (or path) 
                and added fork number suffix: .exit.1 and .stdout.1 and .stderr.1 and so on
                default: do not write
                warning: redefines other write options
    -c, --checkexit=INTEGER[,INTEGER[,...]]
                check if every command ended with any exitcode from list, 
                generate error if not, default: do not check
    -e, --writestderr=FILEBASE   
                write stderr of cmdlines to files with fixed base name (or path) 
                and added fork number suffix: .stderr.1 and so on
                default: do not write
    -f, --forks=INTEGER     
            number of forks to run in parallel, 
            possible values:
                1 - count number automatically (default)
                0 - do not fork and run consistently (for debug)
                2 and so on - fixed number of forks
    -h, --help              
            show minimal help end exit
    -o, --writestdout=FILEBASE   
                write stdout of cmdlines to files with fixed base name (or path) 
                and added fork number suffix: .stdout.1 and so on
                default: do not write
    -q, --quiet             
            do not chat while working (no prints or warnings)
    -r, --read
                read and run command lines from files, 
                one line = one command,
                empty and space only lines are ignored
    -s, --sleep=FLOAT       
                sleep time in seconds of pseudo-blocking calls, default: 0.01
    -x, --writeexit=FILEBASE   
                write exitcodes of cmdlines to files with fixed base name (or path) 
                and added fork number suffix: .exit.1 and so on
                default: do not write

## Getting fork number

If the number of forks is not set by option, it is retrieved from:

1) environmental variable `NUMBER_OF_PROCESSORS`, targeting Windows-like OSes;

2) `nproc` utility, targeting Unix-like OSes.

If above steps fail, it is simply set to 4.

Finally, it is multiplied by 2 targeting 2 forks per core 
(this assumption made by script author after some modest tests).

The number of forks is reduced to the number of cmdlines if later is smaller.

It is set to zero, if there is only one cmdline to run.

All forks are waited to end. If fork is lost, warning is generated, 
though usually it does not mean that process has failed. 
So additional analysis should be made by script caller, 
e.g..: check result file of `cmdline`, check existence of `writeexit` files and so on.

If `--quiet` is not used, end time is printed to STDOUT.

# TODO

\- Tests on Windows.

\- Are there any reasons to hard-code checking existence of `writeexit` and so on files?

\- Reproduce situations when `$exitcode` in `run_on_finish`
is less reliable than from `$datastructref`.

\- Are there any reasons not to check core dump from `run_on_finish`?

\- Reproduce and test situations when fork is lost with warning (e.g. in Windows).
Is `writeexit` and so on files still created?

# LICENSE

The MIT License. More info: [https://opensource.org/licenses/MIT](https://opensource.org/licenses/MIT).

# AUTHOR

Edgaras Sakuras - [edgaronas@yahoo.com](mailto:edgaronas@yahoo.com)

2018-11-29
