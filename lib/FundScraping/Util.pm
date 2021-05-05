package FundScraping::Util;

use strict;
use warnings;
use autodie qw(open close flock seek);
use feature qw(say);
use utf8;
use parent qw(Exporter);
use Data::Dumper;
use Encode;
use Fcntl qw(:DEFAULT :flock :seek);
use JSON;
use POSIX qw(ceil);
use Text::ParseWords;

our @EXPORT_OK   = qw(array_dedup camelize conv_csv_str conv_normal_str csv2ref decamelize equal_file equal_in_file equal_arrays equal_hashes fold json2ref in_array merge_arrayref read_file read_csv_file read_json_file save_file touch_file ref2csv ref2dumper ref2json ref2ltsv trim);
our %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );
our $VERSION     = '1.0';
our $FOLD_LENGTH = 40;


sub array_dedup {

	my @array = @_;
	my %hash = map { $_ => 1 } @array;
	return keys %hash;
}

sub array_dedup2 {

	my @array = @_;
	my @tmp;
	foreach my $val (@array) {
		if (in_array($val, \@tmp)) {
			next;
		}
		push @tmp, $val;
	}
	return @tmp;
}

sub camelize {

	(my $str = shift) =~ s/(?:^|_)(.)/\U$1/g;
	return $str;
}

sub decamelize {

	my $str = shift;
	$str =~ s/(_)?((?:[A-Z](?![^A-Z]))+|[A-Z])/(pos($str)==0&&!$1?'':'_').lc($2)/ge;
	return $str;
}

sub conv_csv_str {

	my $str = shift;

	$str =~ s/(\r\n|\r|\n)/ /g;
	$str =~ s/,//g;
	$str =~ s/\t/ /g;
	$str =~ s/"/”/g;
	$str = conv_normal_str($str);
	$str = "\"" . $str . "\"";

	return $str;
}

sub conv_ltsv_str {

	my $str = shift;

	$str =~ s/(\r\n|\r|\n)/ /g;
	$str =~ s/:/：/g;
	$str =~ s/\t/ /g;
	$str = conv_normal_str($str);

	return $str;
}

sub conv_normal_str {

	my $str = shift;
	$str =~ s/％/%/g;
	if ($str eq "--") {
		$str = "";
	}
	return $str;
}

sub csv2ref {

	my($data) = @_;
	if (!utf8::is_utf8($data)) {
		$data = decode("UTF-8", $data);
	}
	$data = trim($data);
	my @lines  = split /\n/, $data;
	my $header = shift @lines;
	my @keys   = parse_line(",", undef, $header);

	my @alldata;
	foreach my $line (@lines) {

		my $ref = {};
		my @fields = parse_line(",", undef, $line);
		for (my $i = 0; $i < scalar(@keys); $i++) {
			$ref->{$keys[$i]} = $fields[$i];
		}
		push @alldata, $ref;
	}

	return \@alldata;
}

sub equal_arrays {

	my ( $a, $b ) = @_;
	if ( scalar @$a != scalar @$b ) {
		return 0;
	}
	for my $i ( 0 .. $#{$a} ) {
		my $va = $a->[$i];
		my $vb = $b->[$i];
		if ( ref $va ne ref $vb ) {
			return 0;
		}
		elsif ( ref $va eq 'SCALAR' && $va ne $vb ) {
			return 0;
		}
		elsif ( ref $va eq 'ARRAY' && !arrays_equal( $va, $vb ) ) {
			return 0;
		}
		elsif ( ref $va eq 'HASH' && !hashes_equal( $va, $vb ) ) {
			return 0;
		}
	}
	return 1;
}

sub equal_hashes {
	my ( $a, $b ) = @_;
	if ( scalar( keys %$a ) != scalar( keys %$b ) ) {
		return 0;
	}
	for my $k ( keys %$a ) {
		if ( exists $b->{$k} ) {
			my $va = $a->{$k};
			my $vb = $b->{$k};
			if ( ref $va ne ref $vb ) {
				return 0;
			}
			elsif ( ref $va eq 'SCALAR' && $va ne $vb ) {
				return 0;
			}
			elsif ( ref $va eq 'ARRAY' && !equal_arrays( $va, $vb ) ) {
				return 0;
			}
			elsif ( ref $va eq 'HASH' && !equal_hashes( $va, $vb ) ) {
				return 0;
			}
			elsif ( $va ne $vb ) {
				return 0;
			}
		}
		else {
			return 0;
		}
	}
	return 1;
}

sub equal_file {

	my($file1, $file2, $binmode) = @_;
	my $flag = 0;
	if (! -f $file1 || ! -f $file2) {
		return $flag;
	}
	my $val1 = trim(read_file($file1, $binmode));
	my $val2 = trim(read_file($file2, $binmode));

	if ($val1 eq $val2) {
		$flag = 1;
	}
	return $flag;
}

sub equal_in_file {

	my($check_val, $file, $binmode) = @_;
	my $flag = 0;
	if (! -f $file) {
		return $flag;
	}
	my $val = trim(read_file($file, $binmode));

	if ($val eq $check_val) {
		$flag = 1;
	}
	return $flag;
}


sub fold {

	my($val, $fold_length) = @_;

	if (!$fold_length) {
		$fold_length = $FOLD_LENGTH
	}

	if (!utf8::is_utf8($val)) {
		$val = decode("UTF-8", $val);
	}

	my $length = length($val);
	my $count  = ceil($length / $fold_length);
	my @data;
	for (my $i = 0; $i < $count; $i++) {
		push @data, substr($val, ($i * $fold_length), $fold_length);
	}
	return join("\n", @data);
}

sub in_array {

	my($check_val, $arrayref) = @_;
	my $flag = 0;
	foreach my $val (@{$arrayref}) {
		if ($val eq $check_val) {
			$flag = 1;
			last;
		}
	}
	return $flag;
}


sub json2ref {

	my($data) = @_;
	my $json = JSON->new->allow_nonref;
	if (!utf8::is_utf8($data)) {
		$data = decode("UTF-8", $data);
	}
	return $json->utf8(0)->decode($data);
}

sub merge_arrayref {

	my($a, $b) = @_;

	my @tmp;
	LOOP_OF_B:
	foreach my $hb (@{$b}) {

		my $merge = 1;
		LOOP_OF_A:
		foreach my $ha (@{$a}) {
			if (equal_hashes($ha, $hb)) {
				$merge = 0;
				last LOOP_OF_A;
			}
		}
		if ($merge == 1) {
			push @tmp, $hb;
		}
	}
	push @tmp, @{$a};
	return \@tmp;
}


sub read_file {

	my($file, $binmode) = @_;

	if (!defined($binmode)) {
		$binmode = ":utf8";
	}
	open my $fh, "<$binmode", $file or die $!;
	my $data = do { local $/ = undef; <$fh> };
	close $fh;
	return $data;
}

sub read_csv_file {

	my($file, $binmode) = @_;

	if (!defined($binmode)) {
		$binmode = ":encoding(cp932)";
	}
	my $data = read_file($file, $binmode);
	return csv2ref($data);
}

sub read_json_file {

	my($file, $binmode) = @_;

	my $data = read_file($file, $binmode);
	return json2ref($data);
}

sub save_file {

	my($val, $file, $binmode) = @_;
	if (!defined($binmode)) {
		$binmode = ":utf8";
	}
	if (!utf8::is_utf8($val)) {
		$binmode = "";
	}
	open my $fh, ">$binmode", $file or die $!;
	flock $fh, LOCK_EX;
	say $fh $val;
	close $fh;
	return 1;
}

sub touch_file {

	my($file) = @_;
	if (-e $file) {
		my $atime = time;
		my $mtime = $atime;
		utime $atime, $mtime, $file;
	} else {
		open my $fh, ">", $file or die $!;
		close $fh;
	}
	return 1;
}

sub ref2dumper {

	my $ref = shift;
	{
		no warnings "redefine";
		local *Data::Dumper::qquote = sub { return shift; };
		local $Data::Dumper::Useperl = 1;
		local $Data::Dumper::Terse = 1;
		return Dumper($ref);
	}

}

sub ref2json {

	my($ref, $pretty) = @_;
	my $json = JSON->new->allow_nonref;
	$json = $json->pretty(1) if $pretty;
	return $json->utf8(0)->encode($ref);
}


sub ref2csv {

	my($ref, $keys, $keys_jp) = @_;

	my @data;
	my @headers = ref($keys_jp) ? @{$keys_jp} : @{$keys};
	push @data, join(",", map { conv_csv_str($_) } @headers);

	my @array;
	if (ref($ref) eq "ARRAY") {
		@array = @{$ref};
	}
	if (ref($ref) eq "HASH") {
		push @array, $ref;
	}

	foreach my $ref (@array) {
		push @data, join(",", map { conv_csv_str($ref->{$_}) } @{$keys});
	}
	return join("\n", @data);
}


sub ref2ltsv {

	my($ref, $keys) = @_;

	my @data;

	my @array;
	if (ref($ref) eq "ARRAY") {
		@array = @{$ref};
	}
	if (ref($ref) eq "HASH") {
		push @array, $ref;
	}

	foreach my $ref (@array) {
		push @data, join("\t", map { sprintf("%s:%s", $_, conv_ltsv_str($ref->{$_})) } @{$keys});
	}
	return join("\n", @data);
}

sub trim {

	my $val = shift;
	$val =~ s/\A\s*(.*?)\s*\z/$1/;
	return $val;
}


1;
