#!/usr/bin/perl

=head1 NAME

Konstrukt::Plugin::date - Displays the current date

=head1 SYNOPSIS
	
	<& date / &>

=head1 DESCRIPTION

This plugin will display the current date (in german notation).

=cut

package Konstrukt::Plugin::date;

use strict;
use warnings;

use base 'Konstrukt::Plugin'; #inheritance

use Konstrukt::Parser::Node;

=head1 METHODS

=head2 prepare

The date is a very volatile data. We don't want to cache it...

B<Parameters>:

=over

=item * $tag - Reference to the tag (and its children) that shall be handled.

=back

=cut
sub prepare {
	my ($self, $tag) = @_;
	
	#Don't do anything beside setting the dynamic-flag
	$tag->{dynamic} = 1;
	
	return undef;
}
#= /prepare

=head2 execute

Put out the date.

B<Parameters>:

=over

=item * $tag - Reference to the tag (and its children) that shall be handled.

=back

=cut
sub execute {
	my ($self, $tag) = @_;

	#reset the collected nodes
	$self->reset_nodes();
	
	#Return Date and Time
	my (@months)     = (0,'January','February','March','April','May','June','July','August','September','October','November','December');
	my (@months_ger) = (0,'Januar', 'Februar', 'März', 'April','Mai','Juni','Juli','August','September','Oktober','November','Dezember');
	my ($thissec,$thismin,$thishour,$mday,$mon,$thisyear) = localtime(time);
	$mon++;
	$thisyear += 1900;
	my ($thisdate)     = "$months[$mon] $mday, $thisyear";
	my ($thisdate_ger) = "$mday. $months_ger[$mon] $thisyear";
	if (length($thishour) < 2) {	$thishour = "0$thishour"; }
	if (length($thismin)  < 2) {	$thismin  = "0$thismin"; }
	if (length($thissec)  < 2) {	$thissec  = "0$thissec"; }	
	my ($thistime) = "$thishour:$thismin:$thissec";

	$self->add_node("$thisdate_ger - $thistime");
	
	return $self->get_nodes();
}
#= /execute

return 1;

=head1 AUTHOR

Copyright 2006 Thomas Wittek (mail at gedankenkonstrukt dot de). All rights reserved. 

This document is free software.
It is distributed under the same terms as Perl itself.

=head1 SEE ALSO

L<Konstrukt::Plugin>, L<Konstrukt>

=cut
