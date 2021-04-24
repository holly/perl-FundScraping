#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw(say);
use FindBin qw($Bin $Script);
use File::Spec;
use MorningStarScraping;
use MorningStarScraping::Util qw(save_file);
use Getopt::Long::Subcommand;
use Pod::Usage 'pod2usage';

our $CACHE_DIR = File::Spec->catfile($ENV{HOME}, ".mss_cache");
our $FORMAT    = "json";

our $VERSION = '1.0';
our $AUTHOR  = 'holly';


## Parse options
my %opts;
my $res = GetOptions(
			#configure => [qw(posix_default no_ignore_case gnu_compat bundling)],
			summary => "MorningStar(https://www.morningstar.co.jp/) scraping tool",
			options => {
				'cache-dir=s' => {
					handler => \$opts{cache_dir}
				},
				'force|f'     => {
					handler => \$opts{force}
				},
				'pretty|p'    => {
					handler => \$opts{pretty}
				},
				'output|o=s'  => {
					handler => \$opts{output}
				},
				'format=s'      => {
					handler => \$opts{format}
				},
				'verbose'     => {
					handler => \$opts{verbose}
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
				new_fund => {
					summary => "parse new_fund",
				},
				hogehoge => {
					summary => "parse new_fund",
				}
			}
		);

$opts{cache_dir}  //= $CACHE_DIR;
$opts{format}     //= $FORMAT;

die "Missing subcommand\n" if scalar(@{$res->{subcommand}}) == 0;
die "GetOptions failed!\n" if $res->{success} == 0;


my $ms = MorningStarScraping->new({ cache_dir => $opts{cache_dir}, force => $opts{force}, verbose => $opts{verbose} });
my $obj = $ms->load($res->{subcommand}->[0]);

if (!$obj->updated) {
	say "not updated. exit.";
	exit;
}

my @urllist = $obj->get_newfunds_urllist;
my @details = $obj->get_newfund_details(@urllist);

if (scalar(@details) < 1) {
	say "new fund is not exists. exit.";
	exit;
}

my $data = $obj->convert(\@details, { format => $opts{format}, pretty => $opts{pretty} });
#$ms->output($data, { file => "./a.csv", binmode => ":encoding(cp932)" });

if ($opts{output}) {
	my $binmode = $opts{format} eq "csv" ? ":encoding(cp932)" : ":utf8";
	save_file($data, $opts{output}, $binmode);
} else {
	binmode STDOUT, ":utf8";
	say $data;
}

exit;

__END__

=head1 SYNOPSIS

ms_scraping.pl [subcommand] [option...]

 Options:
   --cache-dir       script cache directory
   --force|f         clear cache and force execution
   --format          output format [csv|csv2|dumper|json]
   --pretty|p        json format pretty mode
   --help|h          brief help message
   --version         output version

=head1 OPTIONS

=over 4

=item B<--cache-dir>

Script cache directory. default:$HOME/.mss_cache

=item B<--force|f>

Clear cache files in cache directory and force exection.

=item B<--format>

Output format [csv|csv2|dumper|json]. default:json

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
