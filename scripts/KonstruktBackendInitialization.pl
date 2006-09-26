#!/usr/bin/perl

#TODO: POD documentation and link to it from Installation.pod
package Konstrukt::BackendInitializer;

use strict;
use warnings;

use Cwd;

use Konstrukt::Handler::File;

help() unless @ARGV;

#"parse" command line
my $action = '';
if (@ARGV) {
	if ($ARGV[0] eq 'delete') {
		$action = 1;
	} elsif ($ARGV[0] eq 'delete_and_create') {
		$action = 2;
	} elsif ($ARGV[0] eq 'create') {
		$action = 3;
	} else {
		#assume that it's a plugin and ask for the action
		$action = '';
	}
	shift @ARGV if $action;
}

#what to do?
while ($action !~ /^[1-4]$/) {
	print "What do you want to do?\n1) Delete the backend stores\n2) Delete and re-create the backend stores\n3) Create the backend stores\n4) Quit\n";
	$action = <STDIN>; chomp $action;
}
our ($autoinit_create, $autoinit_delete);
if ($action == 1) {
	$autoinit_delete = 1;
} elsif ($action == 2) {
	$autoinit_delete = 1;
	$autoinit_create = 1;
} elsif ($action == 3) {
	$autoinit_create = 1;
} else {
	exit;
}

#initialization is easy now.
#we just turn on auto-initialization and load every plugin, which in turn
#initializes itself.
our $autoinit = 1;

#leave the settings at the default (delete = 0, create = 1) for the filehandler
#initialization to get a working session management, which will be needed by
#the plugins.

#create file handler to init the framework (load modules, settings, init session...)
my $filehandler = Konstrukt::Handler::File->new(getcwd(), 'doesnt_matter');

#now update settings according to the selected action
$Konstrukt::Settings->set('autoinit/delete' => $autoinit_delete);
$Konstrukt::Settings->set('autoinit/create' => $autoinit_create);

my $dont_ask;
#all plugins that have a backend
my @plugins = qw/
	blog
	bookmarks
	browserstats
	calendar
	guestbook
	hitstats
	log
	tags
	usermanagement::basic
	usermanagement::level
	usermanagement::personal
	wiki
/;
#plugin backends that should be deleted for each plugin.
#these must be listed explicitly as we cannot rely on the use_plugin dependencies here
my $also_delete = {
	'blog'                     => [qw/blog::DBI/],
	'bookmarks'                => [qw/bookmarks::DBI/],
	'browserstats'             => [qw/browserstats::DBI/],
	'calendar'                 => [qw/calendar::DBI/],
	'guestbook'                => [qw/guestbook::DBI/],
	'hitstats'                 => [qw/hitstats::DBI/],
	'log'                      => [qw/log::DBI/],
	'tags'                     => [qw/tags::DBI/],
	'usermanagement'           => [qw/usermanagement::basic::DBI usermanagement::level::DBI usermanagement::personal::DBI/],
	'usermanagement::basic'    => [qw/usermanagement::basic::DBI/],
	'usermanagement::level'    => [qw/usermanagement::level::DBI/],
	'usermanagement::personal' => [qw/usermanagement::personal::DBI/],
	'wiki'                     => [qw/wiki::backend::article::DBI wiki::backend::file::DBI wiki::backend::image::DBI/],
};
#plugins specified on commandline?
if (@ARGV) {
	$dont_ask = 1;
	@plugins = @ARGV if $ARGV[0] ne 'all';
}
#list available plugins, if selection needed. ask user for selection.
my @actions = ($autoinit_delete ? "delete" : (), $autoinit_create ? "create" : ());
unless ($dont_ask) {
	print "Available plugins for initialization:\n";
	for (my $i = 1; $i <= @plugins; $i++) {
		print "$i) $plugins[$i-1]\n";
	}
	print "Enter the space separated numbers of the plugins you want to " . join (" and ", @actions) . " (type \"all\" for all): ";
	$_ = <STDIN>; chomp;
	if (/all/) {
		$ARGV[0] = 'all';
	} else {
		@plugins = map { $plugins[$_ - 1] } split /\s+/;
	}
}
#go through each plugin
foreach my $plugin (@plugins) {
	print ucfirst(join " and ", map { substr($_, 0, length($_) - 1) . "ing" } @actions) . " backend for plugin $plugin...\n";
	#delete/create the backend of this plugin
	my $p = $Konstrukt::TagHandler::Plugin->load_plugin($plugin);
	#deletion will not be done automatically through use_plugin to
	#avoid cascaded deletion of plugins that are loaded by this plugin.
	$p->init_backend() if $autoinit_delete;
	#also explicitly delete/create the backends of related plugins
	if ($autoinit_delete and $also_delete->{$plugin}) {
		foreach $plugin (@{$also_delete->{$plugin}}) {
			$Konstrukt::TagHandler::Plugin->load_plugin($plugin)->init_backend();
		}
	}
}

#explicitly release the session as it segfaults otherwise ...
#TODO: find bug/reason?
$Konstrukt::Session->release()
	if $Konstrukt::Settings->get('session/use');

#finally also delete/create the session backends as all plugins have been processed now
$Konstrukt::Session->init_backend()
	if defined $ARGV[0] and $ARGV[0] eq 'all';

print "Done.\n";

sub help {
print <<HELP;
Invocation: $0 [action] [plugins]

Where "action" can be:
 delete            - Delete the backend stores
 delete_and_create - Delete and re-create the backend stores
 create            - Create the backend stores

"plugins" are the plugins to which the actions should be applied.
The keyword "all" will apply the initialization to all available plugins and
additionally to the session backend.

If no action is given, you will be prompted to select the action.
If no plugins are given, you will be prompted to select the plugins to initialize

Creation:
The plugins will be initialized according to the konstrukt.settings located in
the current working dir. So when your plugin uses a DBI backend, only this
backend will be created. Also all plugins, which a plugin depends on, will be
initialized.
The session backend will always be created if activated in the settings as
most plugins depend on it.

Deletion:
All backends for the specified plugin will be deleted as it is much more
complicated to determine which backends should be deleted for a specific plugin
than in the case of backend creation, where _all_ subsequently loaded
plugins/backends get initialized, what would be far too much for deletion.
The session backend will only be deleted if you specify the "all" keyword.

HELP
}
