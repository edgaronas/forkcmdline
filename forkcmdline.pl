#!/usr/bin/perl

=pod

=head1 NAME

B<forkcmdline> - run Perl C<system> function with C<Parallel::ForkManager>
from input or file.

=head1 SYNOPSIS

    forkcmdline [OPTIONS] CMDLINE [CMDLINE ...]
    forkcmdline [OPTIONS] --read CMDFILE [CMDFILE ...]

=head1 DESCRIPTION

=head2 Dependencies

C<strict>, C<warnings> (with C<FATAL> warnings) - Perl standard modules.

C<Parallel::ForkManager> - Perl fork managing.

C<Time::HiRes> - precise elapsed time.

C<Getopt::Long> - command line options handling.

C<Pod::PlainText> - POD text extraction for help.

=cut

use strict;
use warnings 'FATAL' => 'all';
use Parallel::ForkManager ();
use Time::HiRes ();
use Getopt::Long ();
use Pod::PlainText ();

$|=1;

=pod

=head2 Options

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

=cut

my $checkexit='';
my $forks = 1;
my $writeall='';
my $writeexit='';
my $writestderr='';
my $writestdout='';
my $quiet = 0;
my $read = 0;
my $sleep = 0.01;

Getopt::Long::GetOptions(
    'writeall|a=s'      =>  \$writeall,
    'checkexit|c=s'     =>  \$checkexit,
    'writestderr|e=s'   =>  \$writestderr,
    'forks|f=i'         =>  \$forks,
    'help|h'            =>  sub { 
        my $parser = Pod::PlainText->new();
        open(my $helpfh, '<', $0) or die("ERROR: failed to open '$0' for reading help POD parts: $?, $!\n"); 
        $parser->parse_from_filehandle($helpfh);
        close($helpfh);
        exit;
    },
    'writestdout|o=s'   =>  \$writestdout,
    'quiet|q'           =>  \$quiet,
    'read|r'            =>  \$read,
    'sleep|s=f'         =>  \$sleep,
    'writeexit|x=s'     =>  \$writeexit,
) or die("ERROR: failed processing command line arguments\n");

die("ERROR: missing arguments... use --help option for usage!\n") unless(@ARGV);

if($writeall ne ''){
    $writeexit = $writeall;
    $writestdout = $writeall;
    $writestderr = $writeall;
}

my @CMDS;
if($read){
    foreach my $argv (@ARGV){
        my $rownum = 0;
        open(my $fh, '<', $argv) or die("ERROR: failed to open file '$argv' for reading: $?, $!\n");
        while(my $row = <$fh>){
            $rownum++;
            $row=~s/^\s+|\s+$//s;
            if(length($row)>0){
                push @CMDS, $row;
            }
            else {
                warn("WARNING: row #$rownum is empty or space only in: $argv\n") unless($quiet);
            }
        }
        close($fh);
        print('INFO: found '.($#CMDS+1)." cmdline in file: $argv\n") unless($quiet);
    }
}
else {
    @CMDS=@ARGV;
    print('INFO: found '.($#CMDS+1)." cmdline from input arguments\n") unless($quiet);
}

=head2 Getting fork number

If the number of forks is not set by option, it is retrieved from:

1) environmental variable C<NUMBER_OF_PROCESSORS>, targeting Windows-like OSes;

2) C<nproc> utility, targeting Unix-like OSes.

If above steps fail, it is simply set to 4.

Finally, it is multiplied by 2 targeting 2 forks per core 
(this assumption made by script author after some modest tests).

The number of forks is reduced to the number of cmdlines if later is smaller.

It is set to zero, if there is only one cmdline to run.

=cut

if($forks == 1){
    $forks = 4;
    if($ENV{'NUMBER_OF_PROCESSORS'}){
        $forks = $ENV{'NUMBER_OF_PROCESSORS'};
        print("INFO: got initial $forks forks from OS '$^O' environmental variable: NUMBER_OF_PROCESSORS\n") unless($quiet);
    }
    else {
        my $nproc;
        eval { $nproc = `nproc`; };
        if(defined $nproc){
            $nproc=~s/\s+$//gs;
            $forks = $nproc;
            print("INFO: got initial $forks forks from OS '$^O' utility: nproc\n") unless($quiet);
        }
        else {
            warn("WARNING: failed to run nproc utility in current OS: $^O\n".
                "number of forks set to: $forks\n") unless($quiet);
        }
    }
    $forks*=2;
    print("INFO: final (multiplied by 2) forks number: $forks\n") unless($quiet);
}
else {
    print("INFO: fixed forks number: $forks\n") unless($quiet);
}

if($#CMDS<$forks){
    $forks = $#CMDS+1;
    warn("WARNING: reducing forks number to match number of cmdlines: $forks\n") unless($quiet);
}
if($#CMDS==0){
    warn("WARNING: no forking, only one element found...\n") unless($quiet);
    $forks = 0;
}

my $pm = Parallel::ForkManager->new($forks);
$pm->set_waitpid_blocking_sleep($sleep);

unless($forks == 0){
    $pm->run_on_finish(
        sub {
            my ($pid, $exitcode, $procid, $exitsignal, $coredump, $datastructref) = @_;
            my $c = $procid-1;
            if(defined $$datastructref){
                write_exit($procid, $$datastructref) if($writeexit ne '');
                check_exit($procid, $$datastructref) if($checkexit ne '');
            }
            else {
                die("ERROR: failed to get exit code ref for writing after cmdline #$procid: $CMDS[$c]\n") if($writeexit ne '');
                check_exit($procid, $exitcode) if($checkexit ne '');
            }
            die("ERROR: core dump for proc (pid=$pid) after cmdline #$procid: $CMDS[$c]\n") if($coredump);
        }
    );
}

my $start_time;
unless($quiet){
    $start_time=[Time::HiRes::gettimeofday()];
    print("PARALLEL FORKS $forks FOR CMDLINES ".($#CMDS+1).'..') unless($quiet);
}

DATA_LOOP:
for(my $c=0; $c<=$#CMDS; $c++){
    my $procid=$c+1;
    my $pid = $pm->start($procid) and next DATA_LOOP;
    print('.'.$procid) unless($quiet);
    my $cmdout='';
    $cmdout=" 1> $writestdout.stdout.$procid" if($writestdout ne '');
    my $cmderr='';
    $cmderr=" 2> $writestderr.stderr.$procid" if($writestderr ne '');
    my $exit = system($CMDS[$c].$cmdout.$cmderr);
    if($forks==0){
        write_exit($procid, $exit) if($writeexit ne '');
        check_exit($procid, $exit) if($checkexit ne '');
    }
    if($checkexit.$writeexit ne ''){
        $pm->finish(undef, \$exit);
    }
    else {
        $pm->finish;
    }
}

=pod

All forks are waited to end. If fork is lost, warning is generated, 
though usually it does not mean that process has failed. 
So additional analysis should be made by script caller, 
e.g..: check result file of C<cmdline>, check existence of C<writeexit> files and so on.

If C<--quiet> is not used, end time is printed to STDOUT.

=cut

print('...waiting') unless($quiet);
$pm->wait_all_children;
print('...DONE in ', Time::HiRes::tv_interval($start_time, 
    [Time::HiRes::gettimeofday()]), "s\n") unless($quiet);

### SUBS ### 

sub check_exit {
    my $procid = shift(@_);
    my $exit = shift(@_);
    my @CHK = split(/,\s*/s, $checkexit);
    my $eok = 0;
    foreach my $chk (@CHK){
        if($chk == $exit){
            $eok = 1;
            last;
        }
    }
    die("ERROR: cmdline #$procid '".$CMDS[$procid-1]."' exited with '$exit', ".
        "though expected: ".join(' or ', @CHK)."\n") unless($eok);
}
sub write_exit {
    my $procid = shift(@_);
    my $exit = shift(@_);
    open(my $fh, '>', "$writeexit.exit.$procid") or 
        die("ERROR: failed to open file '$writeexit.exit.$procid' for writing: $?, $!\n");
    print $fh $exit;
    close($fh);
}

=pod

=head1 TODO

- Tests on Windows.

- Are there any reasons to hard-code checking existence of C<writeexit> and so on files?

- Reproduce situations when C<$exitcode> in C<run_on_finish>
is less reliable than from C<$datastructref>.

- Are there any reasons not to check core dump from C<run_on_finish>?

- Reproduce and test situations when fork is lost with warning (e.g. in Windows).
Is C<writeexit> and so on files still created?

=head1 LICENSE

The MIT License. More info: L<https://opensource.org/licenses/MIT>.

=head1 AUTHOR

Edgaras Sakuras - L<edgaronas@yahoo.com|mailto:edgaronas@yahoo.com>

2018-11-30

=cut

