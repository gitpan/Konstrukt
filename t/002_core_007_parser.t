# check core module: parser

#TODO: more comprehensive tests. test syntax errors.

use strict;
use warnings;

use Test::More tests => 10;

#=== Dependencies
use Cwd;
my $cwd = getcwd();
$cwd .= "/" unless substr($cwd, -1, 1) eq "/";
my $root = "${cwd}t/data/Parser/";
use Konstrukt::TagHandler::Plugin;
use Konstrukt::File;
$Konstrukt::File->set_root($cwd);
$Konstrukt::File->{current_file} = ['002_core_007_parser.t'];
use Konstrukt::PrintRedirector;
use Konstrukt::Event;

#use fake Konstrukt::Plugin::test_dummy
unshift @INC, "${root}lib";

#Parser
use Konstrukt::Parser;
$Konstrukt::Handler->{filename} = "test";

#init
is($Konstrukt::Parser->init(), 1, "init");

#parse_tag
my $opening_tag = "template src=\"blah.template\" foo=\"bar baz\"";
my $closing_tag = "/foo";
my $singleclosing_tag = "date /";

is_deeply($Konstrukt::Parser->parse_tag($opening_tag),
{
  attributes => { foo => "bar baz", src => "blah.template" },
  type => "template",
}
, "parse_tag: opening");

is_deeply($Konstrukt::Parser->parse_tag($closing_tag), { closing => 1, type => "foo" }, "parse_tag: closing");
is_deeply($Konstrukt::Parser->parse_tag($singleclosing_tag), { singleclosing => 1, type => "date" }, "parse_tag: singleclosing");


is_deeply(
	$Konstrukt::Parser->parse_tag('foo $'),
	{ type => 'foo', attributes => { '$' => undef } },
	'parse_tag: attributes without value'
);
is_deeply(
	$Konstrukt::Parser->parse_tag('foo "1"'),
	{ type => 'foo', attributes => { '"1"' => undef } },
	'parse_tag: value without attribute name'
);
is_deeply(
	$Konstrukt::Parser->parse_tag('foo bar"'),
	{ type => 'foo', attributes => { 'bar"' => undef } },
	'parse_tag: wrong quoted value without attribute name'
);


#prepare
my $text = <<EOT;
foo<& test_dummy &>bar<& / &>baz
EOT

my $actions = { '&' => $Konstrukt::TagHandler::Plugin };

my $prepared = $Konstrukt::Parser->prepare(\$text, $actions);
is($prepared->tree_to_string(),
<<EOT
* root
  children below this tag:
  * plaintext: foo
  * tag: (final) - type: & test_dummy - dynamic: 1 - execution_stage: (not defined)
    children below this tag:
    * plaintext: bar
  * plaintext: baz

EOT
, "prepare");

#execute
my $executed = $Konstrukt::Parser->execute($prepared, $actions);
is($executed->tree_to_string(),
<<EOT
* root
  children below this tag:
  * plaintext: foo
  * plaintext: executed
  * plaintext: baz

EOT
, "execute");

#execution levels

#default order
$text = 
'<& perl &>$Konstrukt::test = "";<& / &>' .
'<& perl &>$Konstrukt::test .= "a";<& / &>' .
'<& perl &>$Konstrukt::test .= "b";<& / &>' .
'<& perl &>print $Konstrukt::test;<& / &>';
$prepared = $Konstrukt::Parser->prepare(\$text, $actions);
$executed = $Konstrukt::Parser->execute($prepared, $actions);
is($executed->children_to_string(), "ab" , "execution levels: default order");

#reverse order
$text = 
'<& perl &>$Konstrukt::test = "";<& / &>' .
'<& perl execution_stage="2" &>$Konstrukt::test .= "a";<& / &>' .
'<& perl &>$Konstrukt::test .= "b";<& / &>' .
'<& perl execution_stage="3" &>print $Konstrukt::test;<& / &>';
$prepared = $Konstrukt::Parser->prepare(\$text, $actions);
$executed = $Konstrukt::Parser->execute($prepared, $actions);
is($executed->children_to_string(), "ba" , "execution levels: reverse order");

#nested tags
$text = 
'<& perl &>$Konstrukt::test = "";<& / &>' .
'<& perl &><& perl execution_stage="3" &>$Konstrukt::test .= "b";<& / &> $Konstrukt::test .= "a";<& / &>' .
'<& perl &>$Konstrukt::test .= "c";<& / &>' .
'<& perl execution_stage="4" &>print $Konstrukt::test;<& / &>';
$prepared = $Konstrukt::Parser->prepare(\$text, $actions);
$executed = $Konstrukt::Parser->execute($prepared, $actions);
is($executed->children_to_string(), "cba" , "execution levels: nested tags");

#prelim tags
$text = 
'<& perl &>$Konstrukt::test = "";<& / &>' .
'<& perl foo="<& perl execution_stage="2" &>$Konstrukt::test .= "b";<& / &>" &>$Konstrukt::test .= "a";<& / &>' .
'<& perl &>$Konstrukt::test .= "c";<& / &>' .
'<& perl execution_stage="3" &>print $Konstrukt::test;<& / &>';
$prepared = $Konstrukt::Parser->prepare(\$text, $actions);
$executed = $Konstrukt::Parser->execute($prepared, $actions);
is($executed->children_to_string(), "cba" , "execution levels: preliminary tags");

exit;
