# check core module: cgi handler

use strict;
use warnings;

use Test::More tests => 1;

#=== Dependencies
use Cwd;
my $cwd = getcwd();
$cwd .= "/" unless substr($cwd, -1, 1) eq "/";
my $root = "${cwd}t/data/Handler/CGI/";

#File handler
use Konstrukt::Handler::CGI;
my $cgihandler = Konstrukt::Handler::CGI->new($root, '/testfile');
#catch output
my $redirector = Konstrukt::Test::PrintRedirector->new();
$redirector->activate();
my $catcher = Konstrukt::Test::PrintRedirectorCatcher->new();
use Konstrukt::Event;
$Konstrukt::Event->register("Konstrukt::Test::PrintRedirector::print", $catcher, \&Konstrukt::Test::PrintRedirectorCatcher::print);
#process
$cgihandler->handler();
$redirector->deactivate();
like($catcher->{printed}, qr/\r?\n\r?\ntestdata$/, "handler");

package Konstrukt::Test::PrintRedirector;
#test print director to catch the output of the file handler

use Konstrukt::Event;

sub new {
	my ($class) = @_;
	tie(*TESTPRINTREDIRECTOR, 'Konstrukt::Test::PrintRedirector');
	return bless {}, $class;
}

sub activate {
	my ($self) = @_;
	$self->{old_fh} = select(TESTPRINTREDIRECTOR) unless exists($self->{old_fh});
}

sub deactivate {
	my ($self) = @_;
	if (defined($self->{old_fh})) {
		select($self->{old_fh});
		delete($self->{old_fh});
	}
}

sub TIEHANDLE {
	my ($class) = @_;
	return bless {}, $class;
}

sub PRINT {
	my ($self, @data) = @_;
	$Konstrukt::Event->trigger("Konstrukt::Test::PrintRedirector::print", @data);
}

1;

package Konstrukt::Test::PrintRedirectorCatcher;

sub new { bless {}, $_[0] }

sub print { $_[0]->{printed} .= $_[1] }

1;
