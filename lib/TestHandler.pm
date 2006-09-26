#!/usr/bin/perl
package TestHandler;
sub handler {
	warn tell DATA;
	return 0;
}
1;
__DATA__
foobarbaz
