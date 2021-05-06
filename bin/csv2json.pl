#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw(say);
use Encode;
use Encode::Guess qw(euc-jp shiftjis 7bit-jis);
use FindBin qw($Bin $Script);
use FundScraping::Util qw(:all);
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

our $VERSION = '1.0';
our $AUTHOR  = 'holly';


## Parse options
my %opts;

GetOptions(\%opts, qw(
	pretty|p
 ));

my $data = "";
while (my $line = <STDIN>) {
	$data .= $line;
}

my $enc = guess_encoding($data);
if (ref($enc)) {
	$data = $enc->decode($data);
} else {
	$data = Encode::decode("guess", $data);
}

binmode STDOUT, ":utf8";
my $ref = csv2ref($data);
say ref2json($ref, $opts{pretty});
