package FundScraping::Base;

use strict;
use warnings;
use utf8;
use feature qw(say);
use parent qw(Class::Accessor);
use FundScraping::Util qw(:all);
use Storable qw(lock_nstore lock_retrieve);

__PACKAGE__->mk_accessors(qw(driver cache_dir force keys store_cache updated _cache));

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

sub cache_file {

	my $self = shift;

	if (exists $self->{_cache_file}) {
		return $self->{_cache_file};
	}

	my $class = ref($self);
	my $pkg_last = (split /::/, $class)[-1];
	$self->{_cache_file} = File::Spec->catfile($self->cache_dir, sprintf("%s.cache", decamelize($pkg_last)));
	return $self->{_cache_file};
}

sub clear_cache {

	my $self = shift;

	warn "your class must be implemented clear_cache. If your class don't need it, override this method.";
}

sub convert {

	my($self, $ref, $opts) = @_;
	my $class = ref($self);

	my($format, $pretty, $arrayref);
	$format   = ref($opts) eq "HASH" ? $opts->{format} : "dumper";
	$pretty   = ref($opts) eq "HASH" ? $opts->{pretty} : undef;
	$arrayref = ref($opts) eq "HASH" && ref($opts->{keys}) eq "ARRAY" ? $opts->{keys} : $self->keys;
	#if (scalar(@keys) == 0) {
	#	{
	#		no strict "refs";
	#		@keys = @{ref($self) . "::KEYS"};
	#	}
	#}

	if ($format eq "json") {
		return ref2json($ref, $pretty);
	} elsif ($format eq "ltsv") {
		return ref2ltsv($ref, $arrayref);
	} elsif ($format eq "csv") {
		return ref2csv($ref, $arrayref);
#	} elsif ($format eq "csv2") {
#		return ref2csv($ref, [@KEYS], [@KEYS_JP]);
	} else {
		return ref2dumper($ref);
	}
}


sub read_cache {

	my $self = shift;

	my $cache = -e $self->cache_file ? lock_retrieve($self->cache_file) : {};
	$self->_cache($cache);
}

sub save_cache {

	my $self = shift;

	lock_nstore($self->_cache, $self->cache_file);
}

sub DESTROY {

	my $self = shift;

	if ($self->store_cache) {
		$self->save_cache;
	}
}


1;
