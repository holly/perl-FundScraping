package FundScraping::Base;

use strict;
use warnings;
use utf8;
use feature qw(say);
use parent qw(Class::Accessor);
use FundScraping::Util qw(:all);

__PACKAGE__->mk_accessors(qw(driver cache_dir force no_store_cache last_updated last_updated_file updated urllist urllist_file));

sub new {

	my $class = shift;
	my $args = ref $_[0] eq 'HASH' ? $_[0] : {@_};

	my $self = $class->SUPER::new($args);
	$self->_init;
	return $self;
}


sub _init {

	my $self = shift;

	die "your class must be implemented _init.";
}

sub clear_cache {

	my $self = shift;

	warn "your class must be implemented clear_cache. If your class don't need it, override this method.";
}

sub convert {

	my($self, $ref, $opts) = @_;
	my $class = ref($self);

	my $format = ref($opts) eq "HASH" ? $opts->{format} : "dumper";
	my $pretty = ref($opts) eq "HASH" ? $opts->{pretty} : undef;
	my @keys;
	{
		no strict "refs";
		@keys = @{ref($self) . "::KEYS"};
	}

	if ($format eq "json") {
		return ref2json($ref, $pretty);
	} elsif ($format eq "ltsv") {
		return array2ltsv($ref, \@keys);
	} elsif ($format eq "csv") {
		return array2csv($ref, \@keys);
#	} elsif ($format eq "csv2") {
#		return array2csv($ref, [@KEYS], [@KEYS_JP]);
	} else {
		return ref2dumper($ref);
	}
}



sub save_cache {

	my $self = shift;

	warn "your class must be implemented save_cache. If your class don't need it, override this method.";
}

sub DESTROY {

	my $self = shift;
	if ($self->no_store_cache) {
		return;
	}
	$self->save_cache;
}


1;
