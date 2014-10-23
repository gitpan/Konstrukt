=head1 NAME

Konstrukt::Plugin::wiki::markup::code - Block plugin to handle code/preformatted sections

=head1 SYNOPSIS
	
	my $code = use_plugin 'wiki::markup::code';
	my $rv = $code->process($block);

=head1 DESCRIPTION

This one will match if the first character of the first line of the block is a
whitespace or a tab.

The block will then be enclosed by <code> and </code>. All child nodes will be
tagged as finished to prevent further wiki parsing on them.

=head1 EXAMPLE

	 although only the first line is indented
	the whole block will be marked as code.

=cut

package Konstrukt::Plugin::wiki::markup::code;

use strict;
use warnings;

use base 'Konstrukt::Plugin::wiki::markup::blockplugin';
use Konstrukt::Plugin; #import use_plugin

use Konstrukt::Parser::Node;

=head1 METHODS

=head2 install

Installs the templates.

B<Parameters:>

none

=cut
sub install {
	my ($self) = @_;
	return $Konstrukt::Lib->plugin_file_install_helper($Konstrukt::Settings->get("wiki/template_path"));
}
# /install

=head2 new

=head2 process

This method will do the work.

B<Parameters>:

=over

=item * $block - Block node (of type L<Konstrukt::Parser::Node>) containing the
(text-)nodes of this block.

=back

=cut
sub process {
	my ($self, $block) = @_;
	
	if (not $block->{first_child}->{wiki_finished} and $block->{first_child}->{type} eq 'plaintext' and $block->{first_child}->{content} =~ /^[ \t]/) {
		#check for every line if it starts with a tab or space and remove it.
		#mark every node as wiki_finished to prevent further processing.
		my $node = $block->{first_child};
		while (defined $node) {
			if (not $node->{wiki_finished} and $node->{type} eq 'plaintext') {
				$node->{content} =~ s/^[ \t]//gm;
				$node->{wiki_finished} = 1;
			}
			$node = $node->{next};
		}
		
		#put the code into the code template
		my $template = use_plugin 'template';
		my $template_path = $Konstrukt::Settings->get("wiki/template_path");
		#create field node and put the block content into it
		my $container = Konstrukt::Parser::Node->new({ type => 'tag', handler_type => '$' });
		$block->move_children($container);
		#create the template node and add it to the block
		my $template_node = $template->node("${template_path}markup/code.template", { content => $container });
		$block->add_child($template_node);

		return 1;
	} else {
		#doesn't match
		return undef;
	}
}
# /process

1;

=head1 AUTHOR

Copyright 2006 Thomas Wittek (mail at gedankenkonstrukt dot de). All rights reserved. 

This document is free software.
It is distributed under the same terms as Perl itself.

=head1 SEE ALSO

L<Konstrukt::Plugin::wiki>

=cut

__DATA__

-- 8< -- textfile: markup/code.template -- >8 --

<nowiki><pre class="wiki"></nowiki><+$ content $+><+$ / $+><nowiki></pre></nowiki>

