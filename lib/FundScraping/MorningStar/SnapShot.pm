package FundScraping::MorningStar::SnapShot;

use strict;
use warnings;
use utf8;
use feature qw(say);
use parent qw(FundScraping::Base);
use Encode;
use Fcntl qw(:DEFAULT :flock :seek);
use File::Spec;
use Selenium::Waiter;
use FundScraping::Util qw(:all);

our @KEYS  = qw(fund_name fund_company rating net_asset_value_per_share amount_of_net_assets category risk_measure trust_fee association_code fund_code url overview);
our $URL   = "https://portal.morningstarjp.com/FundData/SnapShot.do?fnc=%s";


sub _init {

	my $self = shift;

	$self->keys(\@KEYS);
	$self->store_cache(undef);
}

sub get_fund {

	my($self, $fnc) = @_;

	my $ref = {};
	my $url = sprintf $URL, $fnc;
	$self->driver->get($url);

	## XPath
	my %xpaths = ( 
				# ファンド名
				fund_name                  => '//*[@id="ftopmenu"]/div[3]/span[1]',
				# 運用会社
				fund_company               => '//*[@id="ftopmenu"]/div[4]',
				# レーティング
				rating                     => '//*[@id="ftopmenu"]/div[3]/span[3]',
				# 基準価額
				net_asset_value_per_share  => '//*[@id="ftopmenu"]/table/tbody/tr[2]/td[1]/span',
				# 純資産額
				amount_of_net_assets       => '//*[@id="ftopmenu"]/table/tbody/tr[2]/td[3]',
				# カテゴリー
				category                   => '//*[@id="ftopmenu"]/table/tbody/tr[2]/td[4]',
				# リスクメジャー
				risk_measure               => '//*[@id="ftopmenu"]/table/tbody/tr[2]/td[5]',
				# 協会コード
				association_code           => '//*[@id="snapshot"]/div[3]/div[1]/span[1]',
				# ファンドコード
				fund_code                  => '//*[@id="snapshot"]/div[3]/div[1]/span[2]',
				# 特色
				overview                   => '//*[@id="snapshot"]/div[3]/div[2]/p',
				# 信託報酬
				trust_fee                  => '//*[@id="graph21"]/div/div[3]'
			);

	foreach my $key (keys %xpaths) {
		my $xpath = $xpaths{$key};
		#my $elem = wait_until { $self->driver->find_element($xpath) };
		my $elem;
		$elem = wait_until { $self->driver->find_element($xpath) };
		if (!ref($elem)) {
			# 検索対象無
			return;
		}
		my $text = trim($elem->get_text);

		if ($key eq "fund_company") {
			$text =~ s/^投信会社名：//;
		}
		if ($key eq "amount_of_net_assets") {
			$text =~ s/百万円$//;
		}
		$ref->{$key} = $text;
	}

	$ref->{fnc} = $fnc;
	$ref->{url} = $url;
	return $ref;
}

1;
