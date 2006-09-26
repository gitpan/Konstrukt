#!/usr/bin/perl

#TODO: see bug in the SYNOPSIS

=head1 NAME

Konstrukt::Plugin::sql - Perform SQL queries.

=head1 SYNOPSIS
	
=head2 SELECT queries

	<!-- put query results into a template using the dbi default settings defined in your konstrukt.settings
	     see the Konstrukt::DBI documentation for the configuration of the default settings -->
	<& sql query="SELECT * FROM some_table" template="list_layout.template" / &>
	<!-- you must have a list <+@ sql @+> in your template file to which the results are passed.
	     the fields inside the list must be named like the columns in your query. -->
	
	<!-- but you may also define the listname yourself -->
	<& sql query="SELECT * FROM some_table" template="list_layout.template" list="some_list_name" / &>
	<!-- then you should have a list <+@ some_list_name @+> in your template file. -->
	
	<!-- using custom connection settings -->
	<& sql query="..." template="..." source="dbi_dsn" user="username" pass="password" / &>
	
	<!-- manually define the template.
	     more flexible, but a bit slower.
	     #TODO: actually this one doesn't work correctly at the moment due to a bug in the template plugin -->
	<& template src="some.template" &>
		<& sql query="SELECT some, columns FROM some_table" list="query_results" / &>
		<& sql query="SELECT some, columns FROM some_other_table" list="other_query_results" / &>
		<$ some $>other<$ / $>
		<$ fields $>here<$ / $>
	<& / &>
	<!-- in this mode, the plugin will return the result as a field list, which may
	     be used in template. the returned result will look like this: -->
	<@ list_name @>
		<$ field1 $>value1a<$ / $><$ field2 $>value2a<$ / $>
		<$ field1 $>value1b<$ / $><$ field2 $>value2b<$ / $>
		...
	<@ / @>
	<!-- so you can put this data into a template as done in the example above. -->

=head2 Other queries

	<!-- some query that won't return result data -->
	<& sql query="DELETE FROM some_table WHERE id=23" / &>

=head1 DESCRIPTION

This plugin allows an easy integration of SQL queries. Usually combined with
templates to display the results.

The usage is explained in the L</SYNOPSIS>.

=cut

package Konstrukt::Plugin::sql;

use strict;
use warnings;

use base 'Konstrukt::Plugin'; #inheritance
use Konstrukt::Plugin; #import use_plugin

use Konstrukt::Parser::Node;

=head1 METHODS

=head2 execute_again

Yes, this plugin may return dynamic nodes (i.e. template nodes).

=cut
sub execute_again {
	return 1;
}
#= /execute_again

=head2 prepare

SQL-queries are very volatile data. We don't want to cache it...

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
	
	#settings
	my $query     = $tag->{tag}->{attributes}->{query} || '';
	my $file      = $tag->{tag}->{attributes}->{template};
	my $list      = $tag->{tag}->{attributes}->{list} || 'sql';
	my $db_source = $tag->{tag}->{attributes}->{source};
	my $db_user   = $tag->{tag}->{attributes}->{user};
	my $db_pass   = $tag->{tag}->{attributes}->{pass};
	
	my $dbh = $Konstrukt::DBI->get_connection($db_source, $db_user, $db_pass);
	
	$Konstrukt::Lib->trim($query);
	if (lc(substr($query,0,6)) eq 'select') {
		my $result = $dbh->selectall_arrayref($query, { Columns=>{} });
		#escape values
		foreach my $row (@{$result}) {
			map { $row->{$_} = $Konstrukt::Lib->html_escape($row->{$_}) } keys %{$row}
		}
		#warn $file;
		if (defined $file) {
			my $template = use_plugin 'template';
			#put out result
			$self->add_node($template->node($file, { lists => { $list => [ map { { fields => $_ } } @{$result} ] } }));
		} else {
			my $list_node = Konstrukt::Parser::Node->new({ type => 'tag', handler_type => '@', tag => { type => $list } });
			#put out list and field nodes
			foreach my $row (@{$result}) {
				foreach my $field (keys %{$row}) {
					my $field_node = Konstrukt::Parser::Node->new({ type => 'tag', handler_type => '$', tag => { type => $field } });
					$field_node->add_child(Konstrukt::Parser::Node->new({ type => 'plaintext', content => $row->{$field} }));
					$list_node->add_child($field_node);
				}
			}
			$self->add_node($list_node);
		}
	} else {
		$dbh->do($query);
	}
	
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
