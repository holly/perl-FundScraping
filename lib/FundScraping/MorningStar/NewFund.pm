package FundScraping::MorningStar::NewFund;

use strict;
use warnings;
use utf8;
use feature qw(say);
use parent qw(FundScraping::Base);
use Fcntl qw(:DEFAULT :flock :seek);
use File::Spec;
use Selenium::Waiter;
use FundScraping::Util qw(:all);

our @KEYS              = qw(start_date fund_code fund_name fund_nickname fund_company redemption_date first_settlement_date trust_fee partial_redemption_charge overview url);
our @KEYS_JP           = qw(設定日 ファンドコード ファンド名 ファンド名愛称 運用会社 償還日 初回決算日 信託報酬（%） 売却時信託財産留保額（%） ファンド概要 URL);
our $NEWFUND_URL       = "https://www.morningstar.co.jp/newfundWeb/";




sub _init {

	my $self = shift;

	$self->read_cache;

	my $last_updated = $self->get_newfunds_last_updated;
	if ($self->is_newfunds_updated($last_updated)) {
		$self->updated(1);
	} else {
		$self->updated(undef);
	}
	$self->last_updated($last_updated);
}


sub last_updated {

	my $self = shift;
	if (!exists $self->_cache->{last_updated}) {
		$self->_cache->{last_updated} = "";
	}
	if (scalar(@_) > 0) {
		$self->_cache->{last_updated} = $_[0];
	}
	return $self->_cache->{last_updated};
}

sub urllist {

	my $self = shift;
	if (!exists $self->_cache->{urllist}) {
		$self->_cache->{urllist} = [];
	}
	if (scalar(@_) > 0) {
		$self->_cache->{urllist} = $_[0];
	}
	return $self->_cache->{urllist};
}

sub clear_cache {

	my $self = shift;

	unlink $self->cache_file if -e $self->cache_file;
	$self->updated(undef);
	$self->last_updated(undef);
	$self->urllist([]);
}


sub get_newfunds_last_updated {

	my $self = shift;

	$self->driver->get($NEWFUND_URL);

	# 更新日
	my $elem = $self->driver->find_element('//*[@id="ms_ctr-col"]/div[2]/p[1]');
	my $last_updated = "";
	if ($elem->get_text =~ /^更新日：(\d{4}\/\d{2}\/\d{2})$/) {
		$last_updated = $1;
	}
	return $last_updated;
}

sub get_newfunds_urllist {

	my $self = shift;

	$self->driver->get($NEWFUND_URL);
	# 一覧
	my $elems   = $self->driver->find_elements('//*[@id="report_list_tbl"]/tbody/tr/td[3]/a');
	my @urllist = map { $_->get_attribute("href") } @{$elems};
	return @urllist;
}

sub get_newfund_detail {

	my($self, $url) = @_;

# record_number
#  1 信託設定日
#  2 ファンドコード
#  3 ファンド名
#  4 ファンド名愛称
#  5 運用会社
#  9 償還日
# 11 初回決算日
# 15 信託報酬合計
# 17 売却時信託財産留保金
#  6 ファンド概要
	my @record_numbers = qw(1 2 3 4 5 9 11 15 17 6);
	my $xpath_format   = '//*[@id="ms_ctr-col"]/table/tbody/tr[%i]/td';

	$url =~ s/^http/https/;
	$self->driver->get($url);
	wait_until { $self->driver->find_element('//*[@id="ms_ctr-col"]/h2') };

	my $ref = {};
	LOOP_OF_RECORD_NUMBERS:
	for(my $i = 0; $i < scalar(@record_numbers); $i++) {

		my $key    = $KEYS[$i];
		my $number = $record_numbers[$i];
		my $xpath  = sprintf $xpath_format, $number;
		my $elem   = $self->driver->find_element($xpath);
		my $text   = $elem->get_text;
		if ($number == 17 && $text eq "0") {
			$text .= "%";
		}
		$ref->{$key} = conv_normal_str($text);
	}
	$ref->{url} = $url;
	return $ref;
}

sub get_newfund_details {

	my($self, @newfunds_urllist) = @_;

	my @urllist = @{$self->urllist};
	my @alldata;

	LOOP_OF_NEW_URLLIST:
	foreach my $url (@newfunds_urllist) {

		if(!$self->force && in_array($url, \@urllist)) {
			next;
		}
		push @alldata, $self->get_newfund_detail($url);
		push @urllist, $url;
	}
	$self->urllist([array_dedup(@urllist)]);
	return @alldata;
}


sub is_newfunds_updated {

	my ($self, $last_updated) = @_;

	if ($self->force) {
		return 1;
	}
	my $cache_last_updated = $self->last_updated;
	return $last_updated ne $cache_last_updated ? 1 : 0;
}


sub DESTROY {

	my $self = shift;
	if (!$self->updated) {
		return;
	}
	if ($self->no_store_cache) {
		return;
	}
	$self->save_cache;
}


1;
