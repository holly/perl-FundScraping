#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw(say);
use Encode;
use FindBin qw($Bin $Script);
use File::Spec;
use FundScraping::MakeData;
use FundScraping::Util qw(:all);
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Pod::Usage 'pod2usage';

our $FORMAT  = "json";
our $VERSION = '1.0';
our $AUTHOR  = 'holly';


## Parse options
my %opts;

GetOptions(\%opts, qw(
	from-csv1=s
	from-csv2=s
	format=s
	pretty|p
	output|o=s
	help|h
	version|v
 ));

if($opts{help}){
	pod2usage(-verbose => 1);
}
if($opts{version}){
	version();
}

$opts{format} //= $FORMAT;


my $obj = FundScraping::MakeData->new;
my $csv1 = $opts{'from-csv1'};
my $csv2 = $opts{'from-csv2'};
my $ref = $obj->merge_arrayref_from_csvs($csv1, $csv2);

my $convert_opts = {
		format => $opts{format},
		pretty => $opts{pretty},
		keys   => [$obj->get_csv_header($csv1)]
	};

if ($opts{output}) {
	#save_file($output, $opts{output}, $binmode);
	$obj->save_auto_rotate_file($ref, $opts{output}, $convert_opts);
} else {
	binmode STDOUT, ":utf8";
	say $obj->convert($ref, $convert_opts);
}

exit;

# version
sub version {
	printf("%s %s\n", $FindBin::Script, $VERSION);
	exit;
}

__END__

=head1 SYNOPSIS

make_csv.pl [option...]

  Options:
    --from-csv1       base csv
    --from-csv2       plus csv
    --format          output format [csv|csv2|dumper|json]
    --output|o        output specified symlink path
    --pretty|p        json format pretty mode
    --help|h          brief help message
    --version         output version

=head1 OPTIONS

=over 4

=item B<--from-csv1>

Base csv file(sjis, require header)

=item B<--from-csv2>

Plus csv file(sjis, require header)

=item B<--format>

Output format [csv|csv2|dumper|ltsv|json]. default:json

=item B<--output>

Output symlink path. 

Ex:

  --output=new_funds.csv

  result:
  auto making
       -> symlink: new_funds.csv
       -> entity:  new_funds_${CURRENT_YEAR}.csv

=item B<--pretty|p>

Enable json pretty format (only --format=json)

=item B<--help>

Print a brief help message and exits.

=item B<--version>

Prints script version and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut
