#!/usr/bin/perl

#TODO: documentataion for CGI configuration

=head1 NAME

Konstrukt - Web application/design framework

=head1 SYNOPSIS

use Konstrukt;

=head1 DESCRIPTION

The basic idea (which is not new) is to compose each page with the aid of
special tags that offer functionalities beyond the plain markup of HTML.

The tags are used to structure the pages and the content, add dynamics to your
website and encapsulate complex applications and common functionalities in
plugins, which can very easily be integrated in your website.
Additionally strict separation of code, content and layout is maintained.

Covered functionalitys include:

=over

=item * A powerful templating system

=item * Blog

=item * Wiki

=item * Calendar

=item * Guestbook

=item * Embedded Perl

=item * and much more...

=back 

You may build powerful web sites in an instant and have full control over the
look and feel through the template system.

You may also nest (and thus combine) the tags/plugins into each other, which makes it a very
powerful but still easy to use system.

=head2 Further information

For more in-depth information you may want to take a look at L<Konstrukt::Doc>
and the docs/ directory in this package.

There you will find information on the usage of this
framework and on plugin development as well as on the framework internals.

=cut

package Konstrukt;
$Konstrukt::VERSION = 0.5;

require 5.006; #TODO: Check supported perl versions

use strict;
use warnings;

return 1;

=head1 BUGS

Many... Currently tracked for each module at its beginning:

	#FIXME: ...
	#TODO: ...
	#FEATURE: ...

You may get an overview of these by using the supplied C<todo_list.pl> script.

=head1 AUTHOR

Thomas Wittek

mail at gedankenkonstrukt dot de

http://gedankenkonstrukt.de

=head1 AUTHOR

Copyright 2006 Thomas Wittek (mail at gedankenkonstrukt dot de). All rights reserved. 

=head1 LICENSE

This document is free software.
It is distributed under the same terms as Perl itself.

=head1 SEE ALSO

L<Konstrukt::Doc>, L<HTML::Mason>, L<Embperl>, L<perl>

=cut

