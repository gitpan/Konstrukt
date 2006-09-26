# check module loading

use strict;
use warnings;

use Test::More tests => 90;

#list generated using:
# find -type f -iname "*pm" | perl -ne '$line = $_; $line = substr($line, 2, length($line)-6); $line =~ s/\//::/g; print "use_ok(\"$line\");\n"' | sort

BEGIN {
	use_ok("Konstrukt");
	use_ok("Konstrukt::Cache");
	use_ok("Konstrukt::DBI");
	use_ok("Konstrukt::Debug");
	use_ok("Konstrukt::Event");
	use_ok("Konstrukt::File");
	use_ok("Konstrukt::Handler");
	
    SKIP: {
        eval {
			require Apache::Constants;
			require Apache::Cookie;
        };

        skip "Apache::Constants and/or Apache::Cookie not installed but needed to test for mod_perl", 1 if $@;
        
		$ENV{MOD_PERL} = 1;
		use_ok("Konstrukt::Handler::Apache");
    }
	
    SKIP: {
        eval {
			require Apache2::RequestRec;
			require Apache2::RequestIO;
			require Apache2::RequestUtil;
			require Apache2::Const;
			require Apache2::Cookie;
        };

        skip "At least one of Apache2::RequestRec, Apache2::RequestIO, Apache2::RequestUtil, Apache2::Const or Apache2::Cookie not installed but needed to test for mod_perl 2", 1 if $@;
        
		$ENV{MOD_PERL} = 2;
		$ENV{MOD_PERL_API_VERSION} = 2;
		use_ok("Konstrukt::Handler::Apache");
    }
    
	use_ok("Konstrukt::Handler::CGI");
	use_ok("Konstrukt::Handler::File");
#	use_ok("Konstrukt::Handler::Test");
	use_ok("Konstrukt::Lib");
	use_ok("Konstrukt::Parser");
	use_ok("Konstrukt::Parser::Node");
	use_ok("Konstrukt::Plugin");
	use_ok("Konstrukt::SimplePlugin");
	use_ok("Konstrukt::Plugin::blog");
	use_ok("Konstrukt::Plugin::blog::DBI");
	use_ok("Konstrukt::Plugin::bookmarks");
	use_ok("Konstrukt::Plugin::bookmarks::DBI");
	use_ok("Konstrukt::Plugin::browserstats");
	use_ok("Konstrukt::Plugin::browserstats::DBI");
	use_ok("Konstrukt::Plugin::calendar");
	use_ok("Konstrukt::Plugin::calendar::DBI");
#	use_ok("Konstrukt::Plugin::_crlf2br");
	use_ok("Konstrukt::Plugin::date");
	use_ok("Konstrukt::Plugin::diff");
	use_ok("Konstrukt::Plugin::perl");
	use_ok("Konstrukt::Plugin::env");
	use_ok("Konstrukt::Plugin::formvalidator");
#	use_ok("Konstrukt::Plugin::_forum");
#	use_ok("Konstrukt::Plugin::forum::content");
#	use_ok("Konstrukt::Plugin::forum::content::mysql");
#	use_ok("Konstrukt::Plugin::forum::userdata");
#	use_ok("Konstrukt::Plugin::forum::userdata::anicheck");
#	use_ok("Konstrukt::Plugin::forum::userdata::mysql");
	use_ok("Konstrukt::Plugin::guestbook");
	use_ok("Konstrukt::Plugin::guestbook::DBI");
	use_ok("Konstrukt::Plugin::hitstats");
	use_ok("Konstrukt::Plugin::hitstats::DBI");
	use_ok("Konstrukt::Plugin::if");
#	use_ok("Konstrukt::Plugin::incomplete::browser");
#	use_ok("Konstrukt::Plugin::incomplete::language");
#	use_ok("Konstrukt::Plugin::incomplete::shrinkhtml");
	use_ok("Konstrukt::Plugin::kill");
	use_ok("Konstrukt::Plugin::log");
	use_ok("Konstrukt::Plugin::log::DBI");
	use_ok("Konstrukt::Plugin::mail::obfuscator");
	use_ok("Konstrukt::Plugin::param");
	use_ok("Konstrukt::Plugin::perlvar");
	use_ok("Konstrukt::Plugin::sortlines");
	use_ok("Konstrukt::Plugin::sql");
	use_ok("Konstrukt::Plugin::svar");
	use_ok("Konstrukt::Plugin::template");
	use_ok("Konstrukt::Plugin::test");
	use_ok("Konstrukt::Plugin::upcase");
	use_ok("Konstrukt::Plugin::usermanagement");
	
    SKIP: {
        eval {
			require Digest::SHA;
        };

        skip "Digest::SHA not installed but needed to test plugin 'usermanagement::basic'", 2 if $@;
        
		use_ok("Konstrukt::Plugin::usermanagement::basic");
		use_ok("Konstrukt::Plugin::usermanagement::basic::DBI");
    }
    
	use_ok("Konstrukt::Plugin::usermanagement::level");
	use_ok("Konstrukt::Plugin::usermanagement::level::DBI");
	use_ok("Konstrukt::Plugin::usermanagement::personal");
	use_ok("Konstrukt::Plugin::usermanagement::personal::DBI");
#	use_ok("Konstrukt::Plugin::vdr");
#	use_ok("Konstrukt::Plugin::vdr::DBI");
	use_ok("Konstrukt::Plugin::wiki");
	use_ok("Konstrukt::Plugin::wiki::backend");
	use_ok("Konstrukt::Plugin::wiki::backend::article");
	use_ok("Konstrukt::Plugin::wiki::backend::article::DBI");
	use_ok("Konstrukt::Plugin::wiki::backend::file");
	use_ok("Konstrukt::Plugin::wiki::backend::file::DBI");
	use_ok("Konstrukt::Plugin::wiki::backend::image");
	use_ok("Konstrukt::Plugin::wiki::backend::image::DBI");
	use_ok("Konstrukt::Plugin::wiki::markup::acronym");
	use_ok("Konstrukt::Plugin::wiki::markup::basic");
	use_ok("Konstrukt::Plugin::wiki::markup::basic_string");
	use_ok("Konstrukt::Plugin::wiki::markup::blockplugin");
	use_ok("Konstrukt::Plugin::wiki::markup::code");
	use_ok("Konstrukt::Plugin::wiki::markup::definition");
	use_ok("Konstrukt::Plugin::wiki::markup::headline");
	use_ok("Konstrukt::Plugin::wiki::markup::hr");
	use_ok("Konstrukt::Plugin::wiki::markup::htmlescape");
	use_ok("Konstrukt::Plugin::wiki::markup::inlineplugin");
	use_ok("Konstrukt::Plugin::wiki::markup::link");
	use_ok("Konstrukt::Plugin::wiki::markup::link::article");
	use_ok("Konstrukt::Plugin::wiki::markup::link::external");
	use_ok("Konstrukt::Plugin::wiki::markup::link::file");
	use_ok("Konstrukt::Plugin::wiki::markup::link::image");
	use_ok("Konstrukt::Plugin::wiki::markup::link::nolink");
	use_ok("Konstrukt::Plugin::wiki::markup::linkplugin");
	use_ok("Konstrukt::Plugin::wiki::markup::list");
	use_ok("Konstrukt::Plugin::wiki::markup::list_template");
	use_ok("Konstrukt::Plugin::wiki::markup::paragraph");
	use_ok("Konstrukt::Plugin::wiki::markup::quote");
	use_ok("Konstrukt::Plugin::wiki::markup::replace");
	use_ok("Konstrukt::PrintRedirector");
	use_ok("Konstrukt::Request");
	use_ok("Konstrukt::Response");
	use_ok("Konstrukt::Session");
	use_ok("Konstrukt::Settings");
	use_ok("Konstrukt::TagHandler");
	use_ok("Konstrukt::TagHandler::Plugin");
}
