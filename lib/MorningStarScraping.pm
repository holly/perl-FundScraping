package MorningStarScraping;

use strict;
use warnings;
use utf8;
use feature qw(say);
use parent qw(Class::Accessor);
use DirHandle;
use Encode;
use Fcntl qw(:DEFAULT :flock :seek);
use File::Spec;
use File::Basename;
use FindBin qw($Script $Bin);
use Selenium::Firefox;
use Time::HiRes qw(gettimeofday tv_interval);
use Text::ParseWords;
use UNIVERSAL::require;
use MorningStarScraping::Util qw(:all);

our $DEFAULT_CACHE_DIR          = File::Spec->catfile($ENV{HOME}, ".mss_cache");
our $SELENIUM_TIMEOUT_MILLISECS = 10000;
our $USER_AGENT                 = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:86.0) Gecko/20100101 Firefox/86.0";

__PACKAGE__->mk_accessors(qw(cache_dir driver stash force verbose));

sub new {

	my $class = shift;
	my $args = ref $_[0] eq 'HASH' ? $_[0] : {@_};

	my $self = $class->SUPER::new($args);
	$self->_init;
	return $self;
}

sub load_classes {

	my $module_path    = File::Spec->rel2abs(dirname(__FILE__));
	my $target_dir     = File::Spec->catfile($module_path, __PACKAGE__);
	my @classes;
	my $d = DirHandle->new($target_dir);
	while (my $entry = $d->read) {
		if ($entry !~ /\.pm$/ || $entry eq "Util.pm") {
			next;
		}
		$entry =~ s/\.pm$//;
		push @classes, __PACKAGE__ . "::" . $entry;
	}
	$d->close;
	return @classes;
}

sub load_subcommands {

	my @classes = load_classes();
	my @subcommands;
	foreach my $class (@classes) {
		my $prefix = __PACKAGE__ . "::";
		$class =~ s/^$prefix//g;
		push @subcommands, decamelize($class);
	}
	return @subcommands;
}

sub load {

	my($self, $subcommand) = @_;
	my $module = __PACKAGE__ . "::" . camelize($subcommand);
	$module->require or die $@;
	return $module->new({ driver => $self->driver, cache_dir => $self->cache_dir, force => $self->force });
}


sub shutdown_selenium {

	my $self = shift;
	{
		local *STDOUT;
		open STDOUT, '>', undef;
		$self->driver->shutdown_binary;
	}
}


sub _init {

	my $self = shift;

	$ENV{MOZ_HEADLESS} = 1;
	my $driver = Selenium::Firefox->new(marionette_enable => 1);
	$driver->ua->agent($USER_AGENT);
	map { $driver->set_timeout($_, $SELENIUM_TIMEOUT_MILLISECS) }  ("script", "implicit", "page load") ;
	$self->driver($driver);

	if (!$self->cache_dir) {
		$self->cache_dir($DEFAULT_CACHE_DIR);
	}
	if (! -e $self->cache_dir) {
		mkdir $self->cache_dir
	}

	$self->stash({ t0 => [gettimeofday()] });
}


sub DESTROY {

	my $self = shift;

	$self->shutdown_selenium;

	my $elapsed = tv_interval($self->stash->{t0}, [gettimeofday()]);
	say "elapsed: $elapsed sec." if $self->verbose;
}

1;