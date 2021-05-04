package FundScraping::MorningStar::DetailSearchResult;

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

our @KEYS              = qw(fund_name fund_company category rating return_3year standard_deviation_3year trust_fee amount_of_net_assets url);
our $SEARCH_URL        = "https://www.morningstar.co.jp/FundData/DetailSearchResult.do?mode=1";
our $SEARCH_VIEW_COUNT = 50;


sub _init {

	my $self = shift;

	$self->no_store_cache(1);
}

sub clear_cache {

	my $self = shift;

}

sub get_search_funds_count {

	my($self, $word) = @_;

	my $elem;
	$self->driver->get($SEARCH_URL);

	# 投資信託を選択
	$elem = $self->driver->find_element('//*[@id="search"]/div/ul/li[1]/label');
	$elem->set_selected;

	# 検索フォームにword設定
	my $script = <<SCRIPT;
var id   = arguments[0];
document.getElementById(id).value = "$word";
SCRIPT
	$self->driver->execute_script($script, 'searchFundName');

	# フォーム送信
	$elem = $self->driver->find_element('//*[@id="search"]/div/ul/li[3]/input');
	$elem->click;

	# 検索結果が反映されるため、検索結果数を取得
	$elem = wait_until { $self->driver->find_element('//*[@id="sresult1"]/div[2]/h3/span[1]/span') };
	my $count = int(trim($elem->get_text));
	return $count;

}


sub get_search_funds {

	my($self, $word, $page) = @_;

	my @funds;
	my $count = $self->get_search_funds_count($word);

	if ($count == 0) {
		return @funds;
	}

	# 2以上が指定されている場合は適切かチェックする
	if (defined($page) && $page >= 2) {
		# 次のページがまだある場合は次頁に遷移するJavaScriptを実行
		# $elem->submit では何故か正常に動かなかったため、対象フォームのactionを変更して、フォーム送信するボタンをMSFDSearchBeanの子要素として、動的に作成してクリックするようにする
		if (($page * $SEARCH_VIEW_COUNT - $count) < $SEARCH_VIEW_COUNT) {
			my $script = <<SCRIPT;
var pageNo    = arguments[0];
var buttonVal = "selenium dynamic submit page" + pageNo;
var buttonID  = buttonVal.replace(/ /g, "_");
var url       = "/FundData/DetailSearchResult.do?pageNo=" + pageNo;
var tag       = "<input type='submit' value='" + buttonVal + "' id='" + buttonID + "' />";

document.forms['MSFDSearchBean'].insertAdjacentHTML("beforeend", tag);
document.forms['MSFDSearchBean'].action = url;
SCRIPT
			$self->driver->execute_script($script, $page);
			# submitでは動かなかった。以前のelement情報を保持したままの挙動になるようだ
			#my $elem = $self->driver->find_element('//*[@id="sresult1"]/form[@name="MSFDSearchBean"]');
			#$elem->submit;
			my $id = "selenium_dynamic_submit_page" . $page;
			my $elem = $self->driver->find_element(sprintf('//*[@id="%s"]', $id));
			$elem->click;
		}
	}

	# 検索結果テーブルの行要素を取得
	# //*[@id="sresult1"]/form/table/tbody/tr[2]/td[1]/a
	my $elems = wait_until { $self->driver->find_elements('//*[@id="sresult1"]/form/table/tbody/tr') };


	foreach my $elem (@{$elems}) {
		my $children = $self->driver->find_child_elements($elem, './td');
		if (ref($children) ne "ARRAY") {
			next;
		}
		if (scalar(@{$children}) == 0) {
			next;
		}
		my $ref = {};
		for(my $i = 0; $i < scalar(@KEYS); $i++) {

			my $key = $KEYS[$i];
			my $val;
			if ($key eq "url") {
				# 0番目のchildからhrefの値を取得する
				my $elem = $self->driver->find_child_element($children->[0], "./a");
				$val = $elem->get_attribute("href");

				# URLからfncを取得する
				if ($val =~ /.*SnapShot\.do\?fnc=(\d{1,})$/) {
					$ref->{fnc} = $1;
				}
			} else {
				$val = $children->[$i]->get_text;
			}
			$ref->{$key} = conv_normal_str($val);
		}
		push @funds, $ref;
	}
	return @funds;
}



1;
