#!/usr/bin/perl

=head1 NAME

Konstrukt::Plugin::env.pm - Access to the environment variables

=head1 SYNOPSIS
	
	<!-- set value -->
	<& env var="var_name" set="value"/ &>

	<!-- print out value -->
	<& env var="var_name" / &>

=head1 DESCRIPTION

This plugin will set or display specified environment variables.

=cut

package Konstrukt::Plugin::env;

use strict;
use warnings;

use base 'Konstrukt::Plugin'; #inheritance

use Konstrukt::Parser::Node;

=head1 METHODS

=head2 prepare

An environment variable is volatile. We don't want to cache it...

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

Put out the value of the passed ENV-variable or sets an ENV-variable.

Checks the passed tag for attributes like var="varname" and set="value".

With only var being passed, the according value of the environment will be put out.

With additionaly set being passed, the according value of the environment will be changed and nothing will be put out.

B<Parameters>:

=over

=item * $tag - Reference to the tag (and its children) that shall be handled.

=back

=cut
sub execute {
	my ($self, $tag) = @_;

	#reset the collected nodes
	$self->reset_nodes();

	if (exists($tag->{tag}->{attributes}->{var}) and defined($tag->{tag}->{attributes}->{var})) {
		#var attribute is set
		if (exists($tag->{tag}->{attributes}->{set}) and defined($tag->{tag}->{attributes}->{set})) {
			#set attribute is also set. only set the value
			$Konstrukt::Handler->{ENV}->{$tag->{tag}->{attributes}->{var}} = $tag->{tag}->{attributes}->{set};
		} else {
			#only var attribute. no set
			#return the value if defined
			if (defined $Konstrukt::Handler->{ENV}->{$tag->{tag}->{attributes}->{var}}) {
				$self->add_node($Konstrukt::Handler->{ENV}->{$tag->{tag}->{attributes}->{var}});
			} else {
				$Konstrukt::Debug->debug_message("The environment variable '$tag->{tag}->{attributes}->{var}' is not defined!") if Konstrukt::Debug::INFO;
			}
		}
	}
	
	#return result
	return $self->get_nodes();
}
#= /execute

1;

=head1 AUTHOR

Copyright 2006 Thomas Wittek (mail at gedankenkonstrukt dot de). All rights reserved. 

This document is free software.
It is distributed under the same terms as Perl itself.

=head1 SEE ALSO

L<Konstrukt::Plugin>, L<Konstrukt>

=cut
