package FundScraping::MorningStar::StockInfo;

use strict;
use warnings;
use utf8;
use feature qw(say);
use parent qw(FundScraping::Base);
use Encode;
use Fcntl qw(:DEFAULT :flock :seek);
use File::Spec;
use Selenium::Waiter;
use Time::Piece;
use FundScraping::Util qw(:all);

our @KEYS  = qw(stock_name open high low end end_decition_date volume end_before high_of_year low_of_year outstanding_shares);
our $URL   = "https://portal.morningstarjp.com/StockInfo/info/snap/%s";


sub _init {

	my $self = shift;

	$self->keys(\@KEYS);
	$self->store_cache(undef);
}

sub get_stock {

	my($self, $stock_number) = @_;

	my $ref = {};
	my $url = sprintf $URL, $stock_number;
	$self->driver->get($url);

	## XPath
	my %xpaths = (
				# 社名
				stock_name         => '//*[@id="stname"]/div[1]',
				# 始値
				open               => '//*[@id="secBeginValue"]',
				# 高値
				high               => '//*[@id="secMaxValue"]',
				# 安値
				low                => '//*[@id="secMinValue"]',
				# 終値
				end                => '//*[@id="secCurrentValue"]',
				# 終値確定日
				end_decision_date  => '//*[@id="secCurrentDate"]',
				# 出来高（株）
				volume             => '//*[@id="secTradingVolume"]',
				# 前日終値
				end_before         => '//*[@id="secMainEndValue"]',
				# 年初来高値
				high_of_year       => '//*[@id="ms_ctr-col"]/div[4]/table[1]/tbody/tr[6]/td[1]',
				# 年初来安値
				low_of_year        => '//*[@id="ms_ctr-col"]/div[4]/table[1]/tbody/tr[7]/td[1]',
				# 発行済株式数（千株）
				outstanding_shares => '//*[@id="ms_ctr-col"]/div[4]/table[1]/tbody/tr[8]/td[1]',
			);

	foreach my $key (keys %xpaths) {
		my $xpath = $xpaths{$key};
		my $elem;
		$elem = wait_until { $self->driver->find_element($xpath) };
		if (!ref($elem)) {
			# 検索対象無
			return;
		}
		my $text = trim($elem->get_text);

		if ($key eq "end_decision_date") {
			my $t = localtime;
			my $current_year = $t->year;
			my($month, $day) = split /\//, $text;
			$month =~ s/^0//;
			if ($month > $t->mon) {
				$current_year--;
			}
			$text = sprintf "%04d/%02d/%02d", $current_year, $month, $day;
		}
		$ref->{$key} = $text;
	}

	$ref->{stock_number} = $stock_number;
	$ref->{url} = $url;
	return $ref;
}

1;
