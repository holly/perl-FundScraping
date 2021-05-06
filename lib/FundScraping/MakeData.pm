package FundScraping::MakeData;

use strict;
use warnings;
use utf8;
use feature qw(say);
use parent qw(FundScraping::Base);
use Encode;
use File::Spec;
use File::Basename;
use File::pushd;
use POSIX qw(strftime);
use FundScraping::Util qw(:all);
use Text::ParseWords;

sub _init {

	my $self = shift;

	$self->store_cache(undef);
}

sub get_csv_header {

	my($self, $csv) = @_;
	open my $fh, "<:encoding(cp932)", $csv or die $!;
	my $line = <$fh>;
	close $fh;

	$line = trim($line);
	return parse_line(",", undef, $line);
}

sub save_auto_rotate_file {

	my($self, $ref, $file, $opts) = @_;
	my $rotate_file = $file;
	my $symlink     = $file;
	$rotate_file =~ s/^(.*)\.(csv|ltsv|json)$/${1}_%Y\.$2/;
	$self->save_rotate_file($ref, $rotate_file, $symlink, $opts);
}

sub save_rotate_file {

	my($self, $ref, $rotate_file, $symlink, $opts) = @_;

	$rotate_file = POSIX::strftime($rotate_file, localtime(time));
	my $data = $self->convert($ref, $opts);

	my $binmode = $opts->{format} eq "csv" ? ":encoding(cp932)" : ":utf8";
	save_file($data, $rotate_file, $binmode);

	if (-l $symlink) {
		unlink $symlink;
	}
	{
		my $dir = pushd(dirname($symlink));
		symlink basename($rotate_file), basename($symlink);
	}
}

sub merge {

	my($self, $a, $b) = @_;
	return FundScraping::Util::merge_arrayref($a, $b);
}

sub merge_arrayref_from_jsons {

	my($self, $base_json, $update_json) = @_;
	my $a = read_json_file($base_json);
	my $b = read_json_file($update_json);
	return $self->merge($a, $b);
}

sub merge_arrayref_from_csvs {

	my($self, $base_csv, $update_csv) = @_;
	my $a = read_csv_file($base_csv);
	my $b = read_csv_file($update_csv);
	return $self->merge($a, $b);
}

1;
