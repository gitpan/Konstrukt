#!/usr/bin/perl

use Module::Build;

my $build = Module::Build->new(
	module_name => 'Konstrukt',
	dist_author => 'Thomas Wittek <mail@gedankenkonstrukt.de>',
	dist_abstract => 'Web application/design framework',
	license => 'perl',
	build_requires => {
		'Test::More'          => 0,
		'Test::Pod'           => 0,
		'Test::Pod::Coverage' => 0,
		'Cwd'                 => 0,
	},
	requires => {
		#'Some::Module'   => '1.23',
		#'Other::Module'  => '>= 1.2, != 1.5, < 2.0',
		
		'perl'                => '5.6.1',
		
		'CGI'                 => '3.10',
		'Date::Calc'          => '5.4',
		'Devel::UseAnyFunc'   => '1.00',
		'Storable'            => '2.1',
		'Time::HiRes'         => '1.5',
		'Time::Zone'          => '2.00',
	},
	recommends => {
		'Clone'               => '0.20',
		'Clone::PP'           => '1.00',
		'Data::Dump'          => '1.00',
		'DBI'                 => '1.48',
		'Digest::SHA'         => '5.32',
		'Digest::HMAC_MD5'    => '1.01',
		'HTTP::BrowserDetect' => '0.98',
		'Image::Magick'       => '6.2.4',
		'Mail::Sender'        => '0.8.13',
		'Text::Diff'          => '0.35',
		'Time::Local'         => '1.11',
		'Scalar::Util::Clone' => '0.04',
		'Session'             => '0.01'
	},
	create_readme => 1,
);

$build->create_build_script;
