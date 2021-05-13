#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw(say);
use Encode;
use FindBin qw($Bin $Script);
use File::Spec;
use FundScraping;
use FundScraping::Util qw(save_file trim);
use Getopt::Long::Subcommand;
use Pod::Usage 'pod2usage';

our $CACHE_DIR = File::Spec->catfile($ENV{HOME}, ".fund_cache");
our $FORMAT    = "json";
our $HANDLERS  = { 
				detail_search_result => \&detail_search_result,
				new_fund             => \&new_fund,
				snap_shot            => \&snap_shot,
			};

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
				'store-cache'    => {
					handler => \$opts{store_cache}
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
					options => {
						'check-updated|c' => {
							handler => \$opts{check_updated}
						}
					}
				},
				detail_search_result => {
					summary => "parse detail_search_result",
					options => {
						'count|c' => {
							handler => \$opts{count}
						},
						'page|P=i' => {
							handler => \$opts{page}
						},
						'word|w=s' => {
							handler => \$opts{word}
						}
					}
				},
				snap_shot => {
					summary => "parse snap_shot",
					options => {
						'fnc=i' => {
							handler => \$opts{fnc}
						},
					}
				},
			}
		);

$opts{cache_dir}   //= $CACHE_DIR;
$opts{format}      //= $FORMAT;

die "Missing subcommand\n" if scalar(@{$res->{subcommand}}) == 0;
die "GetOptions failed!\n" if $res->{success} == 0;

my $fund = FundScraping->new({
								cache_dir      => $opts{cache_dir},
								force          => $opts{force},
								store_cache    => $opts{store_cache},
								verbose        => $opts{verbose}
							});
my $subcommand = $res->{subcommand}->[0];
my $obj = $fund->load("morning_star", $subcommand);

my $output = $HANDLERS->{$subcommand}->();
_output($output);

exit;

sub new_fund {

	if ($opts{check_updated}) {
		my $message = "";
		my $exit = 0;
		if ($obj->updated) {
			$message = "new_updated:" . $obj->last_updated;
		} else {
			$message = "not updated. exit.";
			$exit = 1;
		}
		say $message;
		exit $exit;
	}

	if (!$obj->updated) {
		say "not updated. exit.";
		exit 1;
	}

	my @urllist = $obj->get_urllist;
	my @funds = $obj->get_funds(\@urllist);

	if (scalar(@funds) == 0) {
		say "new fund is not exists. exit.";
		exit;
	}

	my $output = trim($obj->convert(\@funds, { format => $opts{format}, pretty => $opts{pretty} }));
	return $output;
}

sub detail_search_result {

	my $word = $opts{word};
	if (!$word) {
		say "word is not defined. exit.";
		exit 1;
	}
	my $decoded_word = decode_utf8($word);
	if ($opts{count}) {
		my $count = $obj->get_funds_count($decoded_word);
		return $count;
	}
	my @funds = $obj->get_funds($decoded_word, $opts{page});
	if (scalar(@funds) == 0) {
		say "fund ($word) is not exists. exit.";
		exit 1;
	}
	my $output = trim($obj->convert(\@funds, { format => $opts{format}, pretty => $opts{pretty} }));
	return $output;
}

sub snap_shot {

	my $fnc = $opts{fnc};
	if (!$fnc) {
		say "fnc is not defined. exit.";
		exit 1;
	}
	my $fund = $obj->get_fund($opts{fnc});
	my $output = trim($obj->convert($fund, { format => $opts{format}, pretty => $opts{pretty} }));
	return $output;
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

ms_scraping.pl [subcommand] [option...]

  Subcommand:
    new_fund
    detail_search_result
    snap_shot

  Options:
    --cache-dir       script cache directory
    --force|f         clear cache and force execution
    --format          output format [csv|csv2|dumper|json]
    --store-cache     results cache mode
    --output|o        output specified file path
    --pretty|p        json format pretty mode
    --help|h          brief help message
    --verbose         verbose mode
    --version         output version

=head1 SUBCOMMAND

=item B<new_fund>

=item B<detail_search_result>

=head1 OPTIONS

=over 4

=item B<--cache-dir>

Script cache directory. default:$HOME/.fund_cache

=item B<--force|f>

Clear cache files in cache directory and force exection.

=item B<--format>

Output format [csv|csv2|dumper|ltsv|json]. default:json

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
