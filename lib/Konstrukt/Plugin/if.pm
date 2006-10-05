#TODO: execute_again really not needed?
#TODO: perl-interface to create if-nodes

=head1 NAME

Konstrukt::Plugin::if - Conditional blocks

=head1 SYNOPSIS
	
B<Usage:>

	<!-- will put out "elsif1" -->
	<& if condition="0" &>
		<$ then $>then<$ / $>
		<$ elsif condition="1" $>elsif1<$ / $>
		<$ elsif condition="1" $>elsif2<$ / $>
		<$ else $>else<$ / $>
	<& / &>

	<!-- shortcut, when only using "then" and no elsif or else -->
	<!-- will put out "The condition is true!" -->
	<& if condition="2 > 1" &>
		The condition is true!
	<& / &>

B<Result:>

	<!-- will put out "elsif1" -->
	elsif1
	
	<!-- shortcut, when only using "then" and no elsif or else -->
	<!-- will put out "The condition is true!" -->
		The condition is true!

=head1 DESCRIPTION

Will put out the appropriate content for the conditions. Will delete the block,
if no condition matches and no else block is supplied.

The condition will be C<eval>'ed. So if you only want to check if a value is
true, you might want to encapsulate it in quotes, so that it won't be interpreted
as perl code:

	<& if condition="'some value'" &>true<& / &>

Of course this will lead into problems, when the data between the quotes contains
qoutes itself. So you really should be careful with the values that are put into
the condition, as they will be executed as perl code. You'd better never pass conditions,
that contain any strings entered by a user.

=cut

package Konstrukt::Plugin::if;

use strict;
use warnings;

use base 'Konstrukt::Plugin'; #inheritance

use Konstrukt::Parser::Node;
use Konstrukt::Debug;

=head1 METHODS

=head2 prepare

Everything will be done here as we can already parse for <$ then $> and so on
in the prepare run.

If the if-tag is preliminary (i.e. when there is a tag inside the tag) this method
will actually be called in the execute run.

B<Parameters>:

=over

=item * $tag - Reference to the tag (and its children) that shall be handled.

=back

=cut
sub prepare { 
	my ($self, $tag) = @_;

	#parse for <$ then $>, <$ elsif $> and <$ else $>
	my $actions = { '$' => undef };
	my $prepared = $Konstrukt::Parser->prepare($tag, $actions);
	
	#extract then, elsif and else
	my ($then, @elsif, $else);
	my $node = $prepared->{first_child};
	while (defined $node) {
		if ($node->{type} eq 'tag' and $node->{handler_type} eq '$') {
			if ($node->{tag}->{type} eq 'then') {
				if (defined $then) {
					$Konstrukt::Debug->debug_message("Skipping <\$ then \$> because of double definition.") if Konstrukt::Debug::NOTICE;
				} else {
					$then = $node;
				}
			} elsif ($node->{tag}->{type} eq 'elsif') {
				push @elsif, $node;
			} elsif ($node->{tag}->{type} eq 'else') {
				if (defined $else) {
					$Konstrukt::Debug->debug_message("Skipping <\$ else \$> because of double definition.") if Konstrukt::Debug::NOTICE;
				} else {
					$else = $node;
				}
			}
		}
		$node = $node->{next};
	}
	
	#use tag content if no <$ then $> has been specified
	$then = $tag unless defined $then;
	
	#decide which block to use.
	#this can be done in the prepare-method, as this method will just be called
	#when the tag is fully parsed, thus not preliminary and so we've got the condition.
	#actually the prepare-method will be called in the execute run, when the tag
	#was preliminary in the prepare run.
	if (defined $tag->{tag}->{attributes}->{condition} and eval $tag->{tag}->{attributes}->{condition}) {
		#return the tag, that will be replaced by its children
		return $then;
	} else {
		#process elsifs
		foreach my $node (@elsif) {
			if (defined $node->{tag}->{attributes}->{condition} and eval $node->{tag}->{attributes}->{condition}) {
				#return the elsif node, that will be replaced by its children
				return $node;
			}
		}
		#return the else node, that will be replaced by its children
		return $else if defined $else;
		#return an empty node, that will be deleted.
		return Konstrukt::Parser::Node->new();
	}
}
#= /prepare

1;

=head1 AUTHOR

Copyright 2006 Thomas Wittek (mail at gedankenkonstrukt dot de). All rights reserved. 

This document is free software.
It is distributed under the same terms as Perl itself.

=head1 SEE ALSO

L<Konstrukt::Plugin>, L<Konstrukt>

=cut
