#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw(say);
use Encode;
use Encode::Guess qw(euc-jp shiftjis 7bit-jis);
use FindBin qw($Bin $Script);
use File::Spec;
use FundScraping::Util qw(:all);
use Getopt::Long::Subcommand;
use Pod::Usage 'pod2usage';

our $FORMAT    = "json";
our $HANDLERS  = { 
				csv2json => \&csv2json,
				json2csv => \&json2csv,
			};

our $VERSION = '1.0';
our $AUTHOR  = 'holly';


## Parse options
my %opts;
my $res = GetOptions(
			#configure => [qw(posix_default no_ignore_case gnu_compat bundling)],
			summary => "from stdin json|csv to csv|json stdout",
			options => {
				'output|o=s'  => {
					handler => \$opts{output}
				},

				'help|h' => {
					summary => "display help message",
					handler => sub {
						my ($cb, $val, $res) = @_;
						if ($res->{subcommand}) {
							say "Help message for " . $res->{subcommand} . "...";
						} else {
							pod2usage(-verbose => 1);
						}
						exit 0;
					},
				},
				'version|v' => {
					summary => "display program version",
					handler => sub {
						say "$Script $VERSION";
						exit 0;
					},
				},
			},

			subcommands => {
				json2csv => {
					summary => "from json to csv",
					options => {
						'headers=s' => {
							handler => \$opts{headers}
						}
					}
				},
				csv2json => {
					summary => "from csv to json",
					options => {
						'pretty|p'	=> {
							handler => \$opts{pretty}
						},
					}
				},
			}
		);


die "Missing subcommand\n" if scalar(@{$res->{subcommand}}) == 0;
die "GetOptions failed!\n" if $res->{success} == 0;

my $subcommand = $res->{subcommand}->[0];

$HANDLERS->{$subcommand}->();

exit;

sub json2csv {

    my $data = _input();

	my $ref    = json2ref($data);
	my $output = ref2csv($ref, [split /,/, $opts{headers}]);

	_output($output);
}

sub csv2json {

    my $data = _input();

	my $ref    = csv2ref($data);
	my $output = ref2json($ref, $opts{pretty});

	_output($output);
}


sub _input {

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
	return $data;
}

sub _output {

	my $output = shift;
	if ($opts{output}) {
		my $binmode = $opts{format} eq "csv" ? ":encoding(cp932)" : ":utf8";
		save_file($output, $opts{output}, $binmode);
	} else {
		binmode STDOUT, ":utf8";
		say $output;
	}
}

__END__

=head1 SYNOPSIS

in2conv.pl [subcommand] [option...]

  Subcommand:
    csv2json 
    json2csv

  Options:
    --output|o        output specified file path
    --pretty|p        json format pretty mode
    --help|h          brief help message
    --version         output version

=head1 SUBCOMMAND

=item B<csv2json>

=item B<json2csv>

=head1 OPTIONS

=over 4

=item B<--pretty|p>

Enable json pretty format (only csv2json)

=item B<--help>

Print a brief help message and exits.

=item B<--version>

Prints script version and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut
