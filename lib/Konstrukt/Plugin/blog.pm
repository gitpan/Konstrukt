#!/usr/bin/perl

#TODO: use <& tags / &> in templates instead of writing code to pass the data to the templates?
#TODO: rss/rdf-"export": benchmark
#FEATURE: headline for each new day
#FEATURE: small list of topics
#FEATURE: count entry views
#FEATURE: calendar
#FEATURE: rss/rdf-"export": multiple categories
#FEATURE: rss/rdf-"export": link to an overview filtered by a category
#FEATURE: wiki markup also in comments?

=head1 NAME

Konstrukt::Plugin::blog - Konstrukt blogging engine

=head1 SYNOPSIS
	
	<& blog / &>
	
=head1 DESCRIPTION

This Konstrukt Plug-In provides blogging-facilities for your website.

You may simply integrate it by putting
	
	<& blog / &>
	
somewhere in your website.

To show a form to filter the entries put

	<& blog show="filter" / &>
	
in your page source.

If you want to get your content as an RSS 2.0 compliant XML file you may want
to put

	<& blog show="rss2" / &>

alone in a separate file.

The HTTP parameters "email" and "pass" will be used to log on the user before
retrieving the entries. This will also return private entries.

	http://domain.tld/blog_rss2.ihtml?email=foo@bar.baz;pass=23

=head1 CONFIGURATION

You may do some configuration in your konstrukt.settings to let the
plugin know where to get its data and which layout to use. Default:

	#backend
	blog/backend                  DBI
	
	#layout
	blog/entries_per_page         5
	blog/template_path            /templates/blog/
	
	#user levels
	blog/userlevel_write          1
	blog/userlevel_admin          2
	
	#rss export
	blog/rss2_template            /templates/blog/export/rss2.template
	blog/rss2_entries             20 #number of exported entries
	
	#prefix for cached rendered article markup
	blog/cache_prefix             blog_article_cache/
	
	#use a captcha to prevent spam
	blog/use_captcha              1 #you have to put <& captcha / &> inside your add-template

See the documentation of the backend modules
(e.g. L<Konstrukt::Plugin::blog::DBI/CONFIGURATION>) for their configuration.

=cut

package Konstrukt::Plugin::blog;

use strict;
use warnings;

use base 'Konstrukt::Plugin'; #inheritance
use Konstrukt::Plugin; #import use_plugin

use POSIX; #needed for ceil

use Konstrukt::Cache;
use Konstrukt::Debug;

=head1 METHODS


=head2 execute_again

Yes, this plugin may return dynamic nodes (i.e. template nodes).

=cut
sub execute_again {
	return 1;
}
#= /execute_again


=head2 init

Initializes this object. Sets $self->{backend} and $self->{template_path}.
init will be called by the constructor.

=cut
sub init {
	my ($self) = @_;
	
	#dependencies
	$self->{user_basic}    = use_plugin 'usermanagement::basic'    or return undef;
	$self->{user_level}    = use_plugin 'usermanagement::level'    or return undef;
	$self->{user_personal} = use_plugin 'usermanagement::personal' or return undef;
	
	#set default settings
	$Konstrukt::Settings->default("blog/backend"          => 'DBI');
	$Konstrukt::Settings->default("blog/entries_per_page" => 5);
	$Konstrukt::Settings->default("blog/template_path"    => '/templates/blog/');
	$Konstrukt::Settings->default("blog/userlevel_write"  => 1);
	$Konstrukt::Settings->default("blog/userlevel_admin"  => 2);
	$Konstrukt::Settings->default("blog/rss2_entries"     => 20);
	$Konstrukt::Settings->default("blog/rss2_template"    => $Konstrukt::Settings->get("blog/template_path") . "export/rss2.template");
	$Konstrukt::Settings->default("blog/cache_prefix"     => '/blog_article_cache/');
	$Konstrukt::Settings->default("blog/use_captcha"      => 1);
	
	$self->{backend}       = use_plugin "blog::" . $Konstrukt::Settings->get('blog/backend') or return undef;
	$self->{template_path} = $Konstrukt::Settings->get("blog/template_path");
	
	return 1;
}
#= /init

=head2 install

Installs the templates.

B<Parameters:>

none

=cut
sub install {
	my ($self) = @_;
	return $Konstrukt::Lib->plugin_file_install_helper($self->{template_path});
}
# /install

=head2 prepare

Prepare method

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

All the work is done in the execute step.

B<Parameters>:

=over

=item * $tag - Reference to the tag (and its children) that shall be handled.

=back

=cut
sub execute {
	my ($self, $tag) = @_;

	#reset the collected nodes
	$self->reset_nodes();

	my $show = $tag->{tag}->{attributes}->{show} || '';
	
	if ($show eq 'rss2') {
		$self->export_rss();
	} elsif ($show eq 'filter') {
		$self->filter_show();
	} else {
		my $action = $Konstrukt::CGI->param('action') || '';
		
		#user logged in?
		if ($self->{user_basic}->id() and $self->{user_level}->level() >= $Konstrukt::Settings->get('blog/userlevel_write')) {
			#operations that are accessible to "bloggers"
			if ($action eq 'showadd') {
				$self->add_entry_show();
			} elsif ($action eq 'add') {
				$self->add_entry();
			} elsif ($action eq 'showedit') {
				$self->edit_entry_show();
			} elsif ($action eq 'edit') {
				$self->edit_entry();
			} elsif ($action eq 'showdelete') {
				$self->delete_entry_show();
			} elsif ($action eq 'delete') {
				$self->delete_entry();
			} elsif ($action eq 'show') {
				$self->show_entry();
			} elsif ($action eq 'addcomment') {
				$self->add_comment();
			} elsif ($action eq 'deletecomment') {
				$self->delete_comment();
			} else {
				$Konstrukt::Debug->error_message("Invalid action '$action'!") if Konstrukt::Debug::ERROR and $action;
				$self->show_entries();
			}
		} else {
			#operations that are accessible to all visitors
			if ($action eq 'show') {
				$self->show_entry();
			} elsif ($action eq 'addcomment') {
				$self->add_comment();
			} else {
				$self->show_entries();
			}
		}
	}
	
	return $self->get_nodes();
}
#= /handler


=head2 add_entry_show

Displays the form to add an article.

=cut
sub add_entry_show {
	my ($self) = @_;
	
	my $template = use_plugin 'template';
	$self->add_node($template->node("$self->{template_path}layout/entry_add_form.template"));
}
#= /add_entry_show


=head2 add_entry

Takes the HTTP form input and adds a new blog entry.

Desplays a confirmation of the successful addition or error messages otherwise.

=cut
sub add_entry {
	my ($self) = @_;
	
	my $form = use_plugin 'formvalidator';
	$form->load("$self->{template_path}layout/entry_add_form.form");
	$form->retrieve_values('cgi');
	my $log = use_plugin 'log';
	
	if ($form->validate()) {
		my $template = use_plugin 'template';
		my $tags     = use_plugin 'tags';
		my $wiki     = use_plugin 'wiki';
		
		#get data
		my ($title, $description, $content, $private, $tagstring) = map { $form->get_value($_); } qw/title description content private tags/;
		my $author = $self->{user_basic}->id();
		
		#add entry
		my $id = $self->{backend}->add_entry($title, $description, $content, $author, $private);
		if (defined $id and $tags->set('blog', $id, $tagstring)) {
			#success
			my $author_name = $self->{user_basic}->email();
			$log->put(__PACKAGE__ . '->add_entry', "$author_name added a new blog entry with the title '$title'.", $author_name, $id, $title);
			$self->add_node($template->node("$self->{template_path}messages/entry_add_successful.template"));
		} else {
			#failed
			$self->add_node($template->node("$self->{template_path}messages/entry_add_failed.template"));
		}
		$self->show_entries();
	} else {
		$self->add_node($form->errors());
	}
}
#= /add_entry


=head2 edit_entry_show

Grabs the article from the backend and puts it into a form from which the
user may edit the article.

Displays the form to edit an article.

=cut
sub edit_entry_show {
	my ($self) = @_;

	my $id  = $Konstrukt::CGI->param('id');
	if ($id) {
		my $template = use_plugin 'template';
		my $tags     = use_plugin 'tags';

		#get entry
		my $entry = $self->{backend}->get_entry($id);
		#prepare data
		$entry->{title} = $Konstrukt::Lib->html_escape($entry->{title});
		my $data = {
			fields => $entry,
			tags => [ map { { title => $Konstrukt::Lib->html_escape($_) } } @{$tags->get('blog', $id)} ]
		};
		#put out the template node
		$self->add_node($template->node("$self->{template_path}layout/entry_edit_form.template", $data));
	} else {
		$Konstrukt::Debug->error_message('No id specified!') if Konstrukt::Debug::ERROR;
	}
}
#= /edit_entry_show


=head2 edit_entry

Takes the HTTP form input and updates the requested blog entry.

Displays a confirmation of the successful update or error messages otherwise.

=cut
sub edit_entry {
	my ($self) = @_;
	
	my $form = use_plugin 'formvalidator';
	$form->load("$self->{template_path}layout/entry_edit_form.form");
	$form->retrieve_values('cgi');
	
	if ($form->validate()) {
		my $template = use_plugin 'template';
		my $tags     = use_plugin 'tags';
		
		#get data
		my ($id, $title, $description, $content, $private, $update, $tagstring) = map { $form->get_value($_); } qw/id title description content private update_date tags/;
		
		#delete cache file for this article as the content may have changed
		$self->delete_cache_content($id);
		
		my $entry = $self->{backend}->get_entry($id);
		if ($entry->{author} == $self->{user_basic}->id()) {
			if ($self->{backend}->update_entry($id, $title, $description, $content, $private, $update) and $tags->set('blog', $id, $tagstring)) {
				#success
				$self->add_node($template->node("$self->{template_path}messages/entry_edit_successful.template"));
			} else {
				#failed
				$self->add_node($template->node("$self->{template_path}messages/entry_edit_failed.template"));
			}
		} else {
			#permission denied
			$self->add_node($template->node("$self->{template_path}messages/entry_edit_failed_permission_denied.template"));
		}
		$self->show_entries();
	} else {
		$self->add_node($form->errors());
	}
}
#= /edit_entry


=head2 delete_entry_show

Displays the confirmation form to delete an article.

=cut
sub delete_entry_show {
	my ($self) = @_;
	
	my $id    = $Konstrukt::CGI->param('id');
	if ($id) {
		my $template = use_plugin 'template';
		my $article  = $self->{backend}->get_entry($id);
		if (keys %{$article}) {
			$self->add_node($template->node("$self->{template_path}layout/entry_delete_form.template", { title => $article->{title}, id => $id }));
		} else {
			$Konstrukt::Debug->error_message("Entry $id does not exist!") if Konstrukt::Debug::ERROR;
		}
	} else {
		$Konstrukt::Debug->error_message('No id specified!') if Konstrukt::Debug::ERROR;
		$self->show_entries();
	}
}
#= / delete_entry_show


=head2 delete_entry

Deletes the specified entry.

Displays a confirmation of the successful removal or error messages otherwise.

=cut
sub delete_entry {
	my ($self) = @_;
	
	my $form = use_plugin 'formvalidator';
	$form->load("$self->{template_path}layout/entry_delete_form.form");
	$form->retrieve_values('cgi');
	
	if ($form->validate()) {
		my $template = use_plugin 'template';
		my $tags     = use_plugin 'tags';
		
		my $id       = $form->get_value('id');
		my $entry    = $self->{backend}->get_entry($id);
		if ($entry->{author} == $self->{user_basic}->id() or $self->{user_level}->level() >= $Konstrukt::Settings->get('blog/userlevel_admin')) {
			#delete cache
			$self->delete_cache_content($id);
			#delete entry
			if ($id and $self->{backend}->delete_entry($id) and $tags->delete('blog', $id)) {
				#success
				$self->add_node($template->node("$self->{template_path}messages/entry_delete_successful.template"));
			} else {
				#failed
				$self->add_node($template->node("$self->{template_path}messages/entry_delete_failed.template"));
			}
		} else {
			#permission denied
			$self->add_node($template->node("$self->{template_path}messages/entry_delete_failed_permission_denied.template"));
		}
		$self->show_entries();
	} else {
		$self->add_node($form->errors());
	}
}
#= /delete_entry


=head2 show_entry

Shows the requested blog entry including its comments

Displays the entry or error messages otherwise.

B<Parameters>:

=over

=item * $id - ID of the entry to show (optional)

=back

=cut
sub show_entry {
	my ($self, $id) = @_;
	
	if (!$id) {
		my $form = use_plugin 'formvalidator';
		$form->load("$self->{template_path}layout/entry_show.form");
		$form->retrieve_values('cgi');
		
		if ($form->validate()) {
			$id = $form->get_value('id');
		}
	}
	
	if ($id) {
		my $template   = use_plugin 'template';
		my $tags       = use_plugin 'tags';
		my $entry      = $self->{backend}->get_entry($id);
		my $may_edit   = ($entry->{author} == $self->{user_basic}->id());
		my $may_delete = ($may_edit or $self->{user_level}->level() >= $Konstrukt::Settings->get('blog/userlevel_admin'));
		if (not $entry->{private} or $may_edit) {
			#prepare data
			$entry->{author_id}  = $entry->{author};
			$entry->{author}     = $self->{user_personal}->data($entry->{author_id})->{nick} || undef;
			$entry->{content}    = $self->format_and_cache_content($id, $entry->{content});
			$entry->{may_edit}   = $may_edit;
			$entry->{may_delete} = $may_delete;
			map { $entry->{$_} = $Konstrukt::Lib->html_escape($entry->{$_}) } qw/title description/;
			map { $entry->{$_} = sprintf("%02d", $entry->{$_}) } qw/month day hour minute/;
			my @tags = map { $Konstrukt::Lib->html_escape($_) } @{$tags->get('blog', $id)};
			my $data = { fields => $entry, tags => [ map { { title => $_ } } @tags ] };
			
			#put entry node
			$self->add_node($template->node("$self->{template_path}layout/entry_full.template", $data));
			
			#put add comment form
			$self->add_comment_show($id);
			
			#put comments
			my $comments = $self->{backend}->get_comments($id);
			if (@{$comments}) {
				foreach my $comment (@{$comments}) {
					#get username from db, if comment was written by a registered user
					$comment->{author} ||= $self->{user_personal}->data($comment->{user})->{nick} if $comment->{user};
					map { $comment->{$_} = $Konstrukt::Lib->html_escape($comment->{$_}) } qw/email author text/;
					map { $comment->{$_} = sprintf("%02d", $comment->{$_}) } qw/month day hour minute/;
					$comment->{author_id}   = $comment->{user};
					$comment->{may_delete}  = $may_delete;
					$comment->{lastcomment} = ($comment eq $comments->[-1]);
				}
				$self->add_node($template->node("$self->{template_path}layout/comments.template", { comments => [ map { { fields => $_ } } @{$comments} ] }));
			} else {
				$self->add_node($template->node("$self->{template_path}layout/comments_empty.template"));
			}
		}
	}
}
#= /show_entry


=head2 show_entries

Shows the blog entries

Displays the entries or error messages otherwise.

=cut
sub show_entries {
	my ($self) = @_;
	
	my $template = use_plugin 'template';
	my $tags     = use_plugin 'tags';
	
	#filters?
	my $tagstring = $Konstrukt::CGI->param('tags');
	my $author    = $Konstrukt::CGI->param('author');
	my $year      = $Konstrukt::CGI->param('year');
	my $month     = $Konstrukt::CGI->param('month');
	my $text      = $Konstrukt::CGI->param('text');
	my $select;
	$select->{tags}   = $tagstring if defined $tagstring and length($tagstring);
	$select->{author} = $author    if defined $author    and $author   > 0;
	$select->{year}   = $year      if defined $year      and $year     > 0;
	$select->{month}  = $month     if defined $month     and $month    > 0 and $month < 13;
	$select->{text}   = $text      if defined $text      and length($text);
	
	#calculate page range
	my $page  = $Konstrukt::CGI->param('page') || 0;
	$page = 1 unless $page > 0;
	my $count = $Konstrukt::Settings->get('blog/entries_per_page') || 10;
	my $pages = ceil(($self->{backend}->get_entries_count() || 0) / $count);
	my $start = ($page - 1) * $count;
	
	#show admin features?
	if ($self->{user_basic}->id() and $self->{user_level}->level() >= $Konstrukt::Settings->get('blog/userlevel_admin')) {
		#$self->add_node($template->node("$self->{template_path}layout/category_manage_link.template"));
		$self->add_node($template->node("$self->{template_path}layout/entry_add_link.template"));
	}
	
	#show entries
	my $entries = $self->{backend}->get_entries($select, $start, $count);
	if (@{$entries}) {
		my $uid = $self->{user_basic}->id();
		my $is_admin = $self->{user_level}->level() >= $Konstrukt::Settings->get('blog/userlevel_admin');
		foreach my $entry (@{$entries}) {
			#private entries will only be visible to the author
			my $may_edit   = ($entry->{author} == $uid);
			my $may_delete = ($may_edit or $is_admin);
			if (not $entry->{private} or $may_edit) {
				#prepare data
				$entry->{author_id}  = $entry->{author};
				$entry->{author}     = $self->{user_personal}->data($entry->{author_id})->{nick} || undef;
				$entry->{content}    = $self->format_and_cache_content($entry->{id}, $entry->{content});
				$entry->{may_edit}   = $may_edit;
				$entry->{may_delete} = $may_delete;
				map { $entry->{$_} = $Konstrukt::Lib->html_escape($entry->{$_}) } qw/author title description/;
				map { $entry->{$_} = sprintf("%02d", $entry->{$_}) } qw/month day hour minute/;
				
				#get tags
				my @tags = map { $Konstrukt::Lib->html_escape($_) } @{$tags->get('blog', $entry->{id})};
				
				#put entry node
				my $data = { fields => $entry, tags => [ map { { title => $_ } } @tags ] };
				$self->add_node($template->node("$self->{template_path}layout/entry_short.template", $data));
			}
		}
		$self->add_node($template->node("$self->{template_path}layout/entries_nav.template", { prev_page => ($page > 1 ? $page - 1 : 0), next_page => ($page < $pages ? $page + 1 : 0) })) if $pages > 1;
	} else {
		$self->add_node($template->node("$self->{template_path}layout/entries_empty.template"));
	}
}
#= /show_entries


=head2 format_and_cache_content

Take plain text and formats it using the wiki plugin. Caches the result.
If a cached file already exists, the cached result will be used.

Returns a field tag node contatining the formatted output nodes.

B<Parameters>:

=over

=item * $id - The ID of the article

=item * $content - The (plaintext) content

=back

=cut
sub format_and_cache_content {
	my ($self, $id, $content) = @_;
	
	#get cached wiki markup or create it
	my $cached_filename = $Konstrukt::Settings->get("blog/cache_prefix") . $id;
	$cached_filename = $Konstrukt::File->absolute_path($cached_filename);
	my $cached = $Konstrukt::Cache->get_cache($cached_filename);
	if (defined $cached) {
		#we're already done with this file
		$Konstrukt::File->pop();
	} else {
		#render article and cache it.
		#put markup into a field container
		my $cont = Konstrukt::Parser::Node->new({ type => 'tag', handler_type => '$' });
		$cont->add_child(Konstrukt::Parser::Node->new({ type => 'plaintext', content => $content }));
		#render content
		$cached = (use_plugin 'wiki')->convert_markup($cont);
		#cache it
		$Konstrukt::Cache->write_cache($cached_filename, $cached);
	}
	
	return $cached;
}
#= /format_and_cache_content


=head2 delete_cache_content

Deletes the content cache for a given article

B<Parameters>:

=over

=item * $id - The ID of the article

=back

=cut
sub delete_cache_content {
	my ($self, $id) = @_;
	
	#get cached wiki markup or create it
	my $cached_filename = $Konstrukt::Settings->get("blog/cache_prefix") . $id;
	$cached_filename = $Konstrukt::File->absolute_path($cached_filename);
	return $Konstrukt::Cache->delete_cache($cached_filename);
}
#= /delete_cache_content


=head2 add_comment_show

Takes the specified entry ID or HTTP form input and shows the form to add a comment.

Displays the form to add a comment.

B<Parameters>:

=over

=item * $id - ID of the entry, which shall be commented. (optional)

=back

=cut
sub add_comment_show {
	my ($self, $id) = @_;
	
	if (!$id) {
		my $form = use_plugin 'formvalidator';
		$form->load("$self->{template_path}layout/entry_show.form");
		$form->retrieve_values('cgi');
		
		if ($form->validate()) {
			$id = $form->get_value('id');
		} else {
			$self->add_node($form->errors());
			return;
		}
	}
	
	if ($id) {
		my $template = use_plugin 'template';
		my $uid    = $self->{user_basic}->id();
		if ($uid) {
			$self->add_node($template->node("$self->{template_path}layout/comment_add_form_registered.template", { id => $id, author => $self->{user_personal}->data($uid)->{nick}, email => $Konstrukt::Lib->html_escape($self->{user_basic}->data($uid)->{email}) }));
		} else {
			$self->add_node($template->node("$self->{template_path}layout/comment_add_form.template", { id => $id }));
		}
	}
}
#= /add_comment_show


=head2 add_comment

Takes the HTTP form input and adds a new comment.

Displays a confirmation of the successful addition or error messages otherwise.

=cut
sub add_comment {
	my ($self) = @_;
	
	my $form = use_plugin 'formvalidator';
	$form->load("$self->{template_path}layout/comment_add_form.form");
	$form->retrieve_values('cgi');
	my $log = use_plugin 'log';
	
	if ($form->validate()) {
		my $template = use_plugin 'template';
		my $userid   = $self->{user_basic}->id();
		my $id       = $form->get_value('id');
		my $author   = $form->get_value('author');
		my $email    = $form->get_value('email');
		my $text     = $form->get_value('text');
		if (not $Konstrukt::Settings->get('blog/use_captcha') or (use_plugin 'captcha')->check()) {
			if ($self->{backend}->add_comment($id, $userid, $author, $email, $text)) {
				#success
				my $author_name = join '/', ($author, (($userid ? $self->{user_basic}->email() : undef) || $email) || ());
				my $entry_title = $self->{backend}->get_entry($id)->{title} || '';
				$log->put(__PACKAGE__ . '->add_comment', "$author_name added a new comment to blog entry '$entry_title'.", $id, $entry_title, $author_name);
				$self->add_node($template->node("$self->{template_path}messages/comment_add_successful.template"));
			} else {
				#failed
				$self->add_node($template->node("$self->{template_path}messages/comment_add_failed.template"));
			}
		} else {
			#captcha not solved
			$self->add_node($template->node("$self->{template_path}messages/comment_add_failed_captcha.template"));
		}
		$self->show_entry($id);
	} else {
		$self->add_node($form->errors());
	}
}
#= /add_comment


=head2 delete_comment

Takes the HTTP form input and removes an existing comment.

Displays a confirmation of the successful removal or error messages otherwise.

=cut
sub delete_comment {
	my ($self) = @_;
	
	my $template = use_plugin 'template';
	
	if ($self->{user_level}->level() >= $Konstrukt::Settings->get('blog/userlevel_admin')) {
		
		my $form = use_plugin 'formvalidator';
		$form->load("$self->{template_path}layout/comment_delete_form.form");
		$form->retrieve_values('cgi');
		
		if ($form->validate()) {
			my $id = $form->get_value('id');
			my $comment = $self->{backend}->get_comment($id);
			if ($self->{backend}->delete_comment($id)) {
				#success
				$self->add_node($template->node("$self->{template_path}messages/comment_delete_successful.template"));
			} else {
				#failed
				$self->add_node($template->node("$self->{template_path}messages/comment_delete_failed.template"));
			}
			$self->show_entry($comment->{entry});
		} else {
			$self->add_node($form->errors());
			return $form->errors();
		}
	} else {
		$self->add_node($template->node("$self->{template_path}messages/comment_delete_failed_permission_denied.template"));
	}
}
#= /delete_comment


=head2 filter_show

Displays the form to select articles.

=cut
sub filter_show {
	my ($self) = @_;
	
	my $template = use_plugin 'template';
	my $authors = $self->{backend}->get_authors();

	#get author names
	foreach my $author (@{$authors}) {
		$author = {
			id => $author,
			name => $Konstrukt::Lib->html_escape($self->{user_personal}->data($author)->{nick}) || undef
		};
	}
	#sort authors
	$authors = [ sort { ($a->{name} || '') cmp ($b->{name} || '') } @{$authors} ];
	
	$self->add_node($template->node("$self->{template_path}layout/filter_form.template", { authors => [ map { { fields => $_ } } @{$authors} ] }));
}
#= /filter_show


=head2 export_rss

Generates an RSS 2.0 compliant XML file with the content from the database.

=cut
sub export_rss {
	my ($self) = @_;
	
	my $template = use_plugin 'template';

	#try to log on user, if parameters specified
	my ($email, $pass) = ($Konstrukt::CGI->param('email'), $Konstrukt::CGI->param('pass'));
	if ($email and $pass) {
		$self->{user_basic}->login($email, $pass);
	}

	#get entries
	my $limit = $Konstrukt::Settings->get('blog/rss2_entries') || 20;
	my $entries = $self->{backend}->get_entries(undef, 0, $limit);
	
	#prepare data
	my $data;
	if (@{$entries}) {
		$data->{fields}->{date} = $Konstrukt::Lib->w3c_date_time($entries->[0]->{year}, $entries->[0]->{month}, $entries->[0]->{day}, $entries->[0]->{hour}, $entries->[0]->{minute});
	} else {
		$data->{fields}->{date} = '0000-00-00';
	}
	#items
	my @items;
	foreach my $entry (@{$entries}) {
		if (!$entry->{private}) {
			#"generate" author
			my $autor_data = $self->{user_personal}->data($entry->{author});
			my $firstname  = $autor_data->{firstname};
			my $lastname   = $autor_data->{lastname};
			my $nick       = $autor_data->{nick};
			my $email      = $autor_data->{email};
			my $author     = undef;
			if ($nick) {
				$author = $nick;
			}
			if ($firstname and $lastname) {
				$author .= ($author ? " ($firstname $lastname)" : "$firstname $lastname");
			}
			push @items, {
				id          => $entry->{id},
				title       => $Konstrukt::Lib->xml_escape($entry->{title}),
				description => $Konstrukt::Lib->xml_escape($entry->{description}),
				content     => $Konstrukt::Lib->xml_escape($entry->{content}),
				author      => $Konstrukt::Lib->xml_escape($author),
				date        => $Konstrukt::Lib->w3c_date_time($entry->{year}, $entry->{month}, $entry->{day}, $entry->{hour}, $entry->{minute})
			};
		}
	}
	$self->add_node($template->node($Konstrukt::Settings->get('blog/rss2_template'), { items => \@items }));

	$Konstrukt::Response->header('Content-Type' => 'text/xml');
}
#= /export_rss

1;

=head1 AUTHOR

Copyright 2006 Thomas Wittek (mail at gedankenkonstrukt dot de). All rights reserved. 

This document is free software.
It is distributed under the same terms as Perl itself.

=head1 SEE ALSO

L<Konstrukt::Plugin::blog::DBI>, L<Konstrukt::Plugin>, L<Konstrukt>

=cut

__DATA__

== 8< == textfile: export/rss2.template == >8 ==

<?xml version="1.0" encoding="ISO-8859-15"?>
<rss version="2.0" 
	xmlns:admin="http://webns.net/mvcb/"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:sy="http://purl.org/rss/1.0/modules/syndication/"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:content="http://purl.org/rss/1.0/modules/content/">
	<channel>
		<title>untitled website</title>
		<link>http://your.website/</link>
		<description>no description</description>
		<!-- <category>???</category> -->
		<webMaster>mail@some.host</webMaster>
		<ttl>60</ttl>
		<admin:generatorAgent rdf:resource="http://your.website/?v=1.0"/>
		<admin:errorReportsTo rdf:resource="mailto:mail@some.host"/>
		<dc:language>en</dc:language>
		<dc:creator>mail@some.host</dc:creator>
		<dc:rights>Copyright 2000-2050</dc:rights>
		<dc:date><+$ date / $+></dc:date>
		<sy:updatePeriod>hourly</sy:updatePeriod>
		<sy:updateFrequency>1</sy:updateFrequency>
		<sy:updateBase>2000-01-01T12:00+00:00</sy:updateBase>
		<image>
			<url>http://your.website//gfx/logo.jpg</url>
			<title>untitled</title>
			<link>http://your.website/</link>
			<width>350</width>
			<height>39</height>
		</image>
		<+@ items @+><item rdf:about="http://your.website/blog/?action=show;id=<+$ id / $+>">
			<title><+$ title / $+></title>
			<link>http://www.gedankenkonstrukt.de/blog/?action=show;id=<+$ id / $+></link>
			<description><+$ description / $+></description>
			<!--  <category domain="<+$ category_id / $+>"><+$ category_name / $+></category> -->
			<guid isPermaLink="true">http://your.website/blog/?action=show;id=<+$ id / $+></guid>
			<comments>http://your.website/blog/?action=show;id=<+$ id / $+></comments>
			<dc:date><+$ date / $+></dc:date>
			<dc:creator><+$ author / $+></dc:creator>
			<!-- <dc:subject><+$ category_name / $+></dc:subject> -->
			<content:encoded><![CDATA[ <+$ content / $+> ]]></content:encoded>
		</item><+@ / @+>
	</channel>
</rss>

== 8< == textfile: layout/comment_add_form.form == >8 ==

$form_name = 'addcomment';
$form_specification =
{
	author      => { name => 'Author (not empty)', minlength => 1, maxlength => 64,    match => '' },
	email       => { name => 'Email address'     , minlength => 0, maxlength => 256,   match => '' },
	text        => { name => 'Text (not empty)'  , minlength => 1, maxlength => 65536, match => '' },
	id          => { name => 'ID (number)'       , minlength => 1, maxlength => 8,     match => '^\d+$' },
};

== 8< == textfile: layout/comment_add_form.template == >8 ==

<& formvalidator form="comment_add_form.form" / &>
<div class="blog form">
	<h1>Add comment</h1>
	<p><strong>Note:</strong> The email address is optional!</p>
	<form name="addcomment" action="" method="post" onsubmit="return validateForm(document.addcomment)">
		<input type="hidden" name="action" value="addcomment" />
		<input type="hidden" name="id"     value="<+$ id $+>0<+$ / $+>" />
		
		<label>Author:</label>
		<input name="author" maxlength="255" />
		<br />
		
		<label>Email:</label>
		<input name="email" maxlength="255" />
		<br />
		
		<label>Text:</label>
		<textarea name="text"></textarea>
		<br />
		
		<& captcha template="comment_add_form_captcha_js.template" / &>
		
		<label>&nbsp;</label>
		<input value="Add!" type="submit" class="submit" />
		<br />
	</form>
</div>

== 8< == textfile: layout/comment_add_form_captcha.template == >8 ==

<label>Antispam:</label>
<div>
<p>Please type the text '<+$ answer / $+>' into this field:</p>
<input name="captcha_answer" />
<input name="captcha_hash" type="hidden" value="<+$ hash / $+>" />
</div>

== 8< == textfile: layout/comment_add_form_captcha_js.template == >8 ==

<script type="text/javascript">
<& perl &>
	#generate encrypted answer
	my $answer  = $template_values->{fields}->{answer};
	my $key     = $Konstrukt::Lib->random_password(8);
	my $enctext = $Konstrukt::Lib->uri_encode($Konstrukt::Lib->xor_encrypt("<input name=\"captcha_answer\" type=\"hidden\" class=\"xxl\" value=\"$answer\" />\n", $key), 1);
	print "\tvar enctext = \"$enctext\";\n";
	print "\tvar key = \"$key\";";
<& / &>
	function xor_enc(text, key) {
		var result = '';
		for(i = 0; i < text.length; i++)
			result += String.fromCharCode(key.charCodeAt(i % key.length) ^ text.charCodeAt(i));
		return result;
	}
	document.write(xor_enc(unescape(enctext), key));
</script>

<noscript>
	<label>Antispam:</label>
	<div>
	<p>Please type the text '<+$ answer / $+>' into this field:</p>
	<input name="captcha_answer" />
	</div>
</noscript>

<input name="captcha_hash" type="hidden" value="<+$ hash / $+>" />

== 8< == textfile: layout/comment_add_form_registered.template == >8 ==

<& formvalidator form="comment_add_form.form" / &>
<div class="blog form">
	<h1>Add comment:</h1>
	<p><strong>Note:</strong> The email address is optional!</p>
	<form name="addcomment" action="" method="post" onsubmit="return validateForm(document.addcomment)">
		<input type="hidden" name="action" value="addcomment" />
		<input type="hidden" name="id"     value="<+$ id $+>0<+$ / $+>" />
		
		<label>Author:</label>
		<input name="author" maxlength="255" value="<+$ author $+>(No name)<+$ / $+>" readonly="readonly" />
		<br />
		
		<label>Email:</label>
		<input name="email" maxlength="255" value="<+$ email $+><+$ / $+>" />
		<br />
		
		<label>Text:</label>
		<textarea name="text"></textarea>
		<br />
		
		<label>&nbsp;</label>
		<input type="submit" class="submit" value="Add!" />
		<br />
	</form>
</div>

== 8< == textfile: layout/comment_delete_form.form == >8 ==

$form_name = 'delcomment';
$form_specification =
{
	id => { name => 'ID' , minlength => 1, maxlength => 8, match => '^\d+$' },
};

== 8< == textfile: layout/comments.template == >8 ==

<div class="blog comments">
	<h1>Comments</h1>
	
	<+@ comments @+>
	<table>
		<colgroup>
			<col width="100" />
			<col width="*"   />
		</colgroup>
		<tr>
			<th>Author:</th>
			<td><a href="mailto:<+$ email / $+>"><+$ author $+>(No author)<+$ / $+></a></td>
		</tr>
		<tr>
			<th>Date:</th>
			<td><+$ year / $+>-<+$ month / $+>-<+$ day / $+> at <+$ hour / $+>:<+$ minute / $+>.</td>
		</tr>
		<tr>
			<th>Comment:</th>
			<td><+$ text $+>(No text)<+$ / $+></td>
		</tr>
		<& if condition="<+$ may_delete / $+>" &>
		<tr>
			<th>&nbsp;</th>
			<td><a href="?action=deletecomment;id=<+$ id $+>0<+$ / $+>">Delete comment</a></td>
		</tr>
		<& / &>
	</table>
	<+@ / @+>

</div>

== 8< == textfile: layout/comments_empty.template == >8 ==

<p>Currently no comments.</p>

== 8< == textfile: layout/entries_empty.template == >8 ==

<p>Currently no entries (for the current filter conditions).</p>

== 8< == textfile: layout/entries_nav.template == >8 ==

<& if condition="'<+$ prev_page $+>0<+$ / $+>'" &>
	<div style="float: left;">
		<a href="?page=<+$ prev_page $+>0<+$ / $+>">Newer entries</a>
	</div>
<& / &>

<& if condition="'<+$ next_page $+>0<+$ / $+>'" &>
	<div style="float: right;">
		<a href="?page=<+$ next_page $+>0<+$ / $+>">Older entries</a>
	</div>
<& / &>

<p class="clear" />

== 8< == textfile: layout/entry_add_form.form == >8 ==

$form_name = 'add';
$form_specification =
{
	title       => { name => 'Title (not empty)'  , minlength => 1, maxlength => 256,   match => '' },
	description => { name => 'Summary (not empty)', minlength => 1, maxlength => 4096,  match => '' },
	content     => { name => 'Content (not empty)', minlength => 1, maxlength => 65536, match => '' },
	tags        => { name => 'Tags'               , minlength => 0, maxlength => 512,   match => '' },
	private     => { name => 'Private'            , minlength => 0, maxlength => 1,     match => '' },
};

== 8< == textfile: layout/entry_add_form.template == >8 ==

<& formvalidator form="entry_add_form.form" / &>
<div class="blog form">
	<h1>Add entry</h1>
	<form name="add" action="" method="post" onsubmit="return validateForm(document.add)">
		<input type="hidden" name="action" value="add" />
		
		<label>Title: (plain text)</label>
		<input name="title" maxlength="255" />
		<br />
		
		<label>Summary:<br />(plain text)</label>
		<textarea name="description"></textarea>
		<br />
		
		<label>Text:<br />(Wiki syntax)</label>
		<textarea name="content"></textarea>
		<br />
		
		<label>Tags:</label>
		<div>
	    	<input name="tags" id="tags" maxlength="512" />
	    	<br />
	    	<p>Tags used so far:</p>
	    	<br />
	    	<& tags plugin="blog" /&>
    	</div>
    	<br />
    	
		<label>Private:</label>
		<div>
		<input id="private" name="private" type="checkbox" class="checkbox" value="1" />
		<label for="private" class="checkbox">This entry is only visible for me.</label>
		<p>(Useful, if you want to revise the entry before you publish it.)</p>
		</div>
		<br />
		
		<label>&nbsp;</label>
		<input value="Add!" type="submit" class="submit" />
		<br />
	</form>
</div>

== 8< == textfile: layout/entry_add_link.template == >8 ==

<p style="text-align: right;"><a href="?action=showadd">[ Create new entry ]</a></p>

== 8< == textfile: layout/entry_delete_form.form == >8 ==

$form_name = 'del';
$form_specification =
{
	id           => { name => 'ID (not empty)', minlength => 1, maxlength => 256, match => '^\d+$' },
	confirmation => { name => 'Confirmation'  , minlength => 0, maxlength => 1,   match => '1' },
};

== 8< == textfile: layout/entry_delete_form.template == >8 ==

<& formvalidator form="entry_delete_form.form" / &>
<div class="blog form">
	<h1>Confirmation: Delete article</h1>
	<p>Shall the article '<+$ title $+>(no title)<+$ / $+>' really be deleted?</p>
	
	<form name="del" action="" method="post" onsubmit="return validateForm(document.del)">
		<input type="hidden" name="action" value="delete" />
		<input type="hidden" name="id"     value="<+$ id / $+>" />
		
		<input id="confirmation" name="confirmation" type="checkbox" class="checkbox" value="1" />
		<label for="confirmation" class="checkbox">Yeah, kill it!</label>
		<br />
		
		<input value="Big red button" type="submit" class="submit" />
		<br />
	</form>
</div>

== 8< == textfile: layout/entry_edit_form.form == >8 ==

$form_name = 'edit';
$form_specification =
{
	id          => { name => 'ID (not empty)'     , minlength => 1, maxlength => 256,   match => '^\d+$' },
	title       => { name => 'Title (not empty)'  , minlength => 1, maxlength => 256,   match => '' },
	description => { name => 'Summary (not empty)', minlength => 1, maxlength => 4096,  match => '' },
	content     => { name => 'Content (not empty)', minlength => 1, maxlength => 65536, match => '' },
	update_date => { name => 'Update date'        , minlength => 0, maxlength => 1,     match => '' },
	tags        => { name => 'Tags'               , minlength => 0, maxlength => 512,   match => '' },
	private     => { name => 'Private'            , minlength => 0, maxlength => 1,     match => '' },
};

== 8< == textfile: layout/entry_edit_form.template == >8 ==

<& formvalidator form="entry_edit_form.form" / &>
<div class="blog form">
	<h1>Edit entry:</h1>
	<form name="edit" action="" method="post" onsubmit="return validateForm(document.edit)">
		<input type="hidden" name="action" value="edit" />
		<input type="hidden" name="id"     value="<+$ id $+>0<+$ / $+>" />
		
		<label>Title: (plain text)</label>
		<input name="title" maxlength="255" value="<+$ title / $+>" />
		<br />
		
		<label>Summary:<br />(plain text)</label>
		<textarea name="description"><+$ description / $+></textarea>
		<br />
		
		<label>Text:<br />(Wiki syntax)</label>
		<textarea name="content"><+$ content / $+></textarea>
		<br />
		
		<label>Tags:</label>
		<div>
	    	<input name="tags" id="tags" maxlength="512" value="<+@ tags @+><+$ title $+>(Kein Titel)<+$ / $+> <+@ / @+>" />
	    	<br />
	    	<p>Tags used so far:</p>
	    	<br />
	    	<& tags plugin="blog" /&>
    	</div>
    	<br />
		
		<label>Private:</label>
		<div style="width: 500px">
		<input id="private" name="private" type="checkbox" class="checkbox" value="1" <& if condition="<+$ private $+>0<+$ / $+>" &>checked="checked"<& / &> />
		<label for="private" class="checkbox">This entry is only visible for me.</label>
		<p>(Useful, if you want to revise the entry before you publish it.)</p>
		</div>
		<br />
		
		<label>Update publication date:</label>
		<input id="update_date" name="update_date" type="checkbox" class="checkbox" value="1" />
		<label for="update_date" class="checkbox">Set the publication date of this entry to now.</label>
		<br />
		
		<label>&nbsp;</label>
		<input value="Update!" type="submit" class="submit" />
		<br />
	</form>
</div>

== 8< == textfile: layout/entry_full.template == >8 ==

<div class="blog entry">
	<h1>
		<a href="/blog/?action=show;id=<+$ id $+>0<+$ / $+>"><+$ title $+>(Kein Titel)<+$ / $+></a>
		<& if condition="<+$ private $+>0<+$ / $+>" &>(private)<& / &>
		<& if condition="<+$ may_edit $+>0<+$ / $+>" &><a href="?action=showedit;id=<+$ id $+>0<+$ / $+>">[ edit ]</a><& / &>
		<& if condition="<+$ may_delete $+>0<+$ / $+>" &><a href="?action=showdelete;id=<+$ id $+>0<+$ / $+>">[ delete ]</a><& / &>
	</h1>
	<div class="description"><p><+$ description $+>(No summary)<+$ / $+></p></div>
	<div class="content"><+$ content $+>(No content)<+$ / $+></div>
	<div class="foot">
		Written on <+$ year / $+>-<+$ month / $+>-<+$ day / $+> at <+$ hour / $+>:<+$ minute / $+> by <+$ author $+>(unknown author)<+$ / $+> (author id: <+$ author_id $+>0<+$ / $+>)</a>.
		<& perl &>
			my @tags = @{$template_values->{lists}->{tags}};
			if (@tags) {
				print "Tag" . (@tags > 1 ? 's' : '') . ": ";
				print join ", ", (map { "<a href=\"?tags=" . $Konstrukt::Lib->uri_encode($_->{fields}->{title}) . "\">$_->{fields}->{title}</a>" } @tags);
				print "."
			};
		<& / &>
		<a href="?action=show;id=<+$ id $+>0<+$ / $+>">Comments: <+$ comment_count $+>(none yet)<+$ / $+></a>
	</div>
</div> 

== 8< == textfile: layout/entry_short.template == >8 ==

<div class="blog entry">
	<h1>
		<a href="/blog/?action=show;id=<+$ id $+>0<+$ / $+>"><+$ title $+>(Kein Titel)<+$ / $+></a>
		<& if condition="<+$ private $+>0<+$ / $+>" &>(private)<& / &>
		<& if condition="<+$ may_edit $+>0<+$ / $+>" &><a href="?action=showedit;id=<+$ id $+>0<+$ / $+>">[ edit ]</a><& / &>
		<& if condition="<+$ may_delete $+>0<+$ / $+>" &><a href="?action=showdelete;id=<+$ id $+>0<+$ / $+>">[ delete ]</a><& / &>
	</h1>
	<div class="description"><p><+$ description $+>(No summary)<+$ / $+></p></div>
	<div class="content"><+$ content $+>(No content)<+$ / $+></div>
	<div class="foot">
		Written on <+$ year / $+>-<+$ month / $+>-<+$ day / $+> at <+$ hour / $+>:<+$ minute / $+> by <+$ author $+>(unknown author)<+$ / $+> (author id: <+$ author_id $+>0<+$ / $+>)</a>.
		<& perl &>
			my @tags = @{$template_values->{lists}->{tags}};
			if (@tags) {
				print "Tag" . (@tags > 1 ? 's' : '') . ": ";
				print join ", ", (map { "<a href=\"?tags=" . $Konstrukt::Lib->uri_encode($_->{fields}->{title}) . "\">$_->{fields}->{title}</a>" } @tags);
				print "."
			};
		<& / &>
		<a href="?action=show;id=<+$ id $+>0<+$ / $+>">Comments: <+$ comment_count $+>(none yet)<+$ / $+></a>
	</div>
</div> 

== 8< == textfile: layout/entry_show.form == >8 ==

$form_name = 'show';
$form_specification =
{
	id => { name => 'ID (not empty)' , minlength => 1, maxlength => 8, match => '^\d+$' },
};

== 8< == textfile: layout/filter_form.template == >8 ==

<script type="text/javascript">
<!--
function submitFilter () {
	if (document.filter.text.value == 'Search text...') {
		document.filter.text.value = '';
	}
	return true;
}
function showFilter () {
	document.getElementById("filterlink").style.display = 'none';
	document.getElementById("filterbox").style.display  = 'block';
}
function hideFilter () {
	document.getElementById("filterlink").style.display = 'block';
	document.getElementById("filterbox").style.display  = 'none';
}
-->
</script>
<div id="filterbox" style="display: none;">
	<div class="blog form" id="filterbox">
		<h1>Find entry</h1>
		<form name="filter" action="" method="post" onsubmit="return submitFilter()">
			<label>Tags: (<a href="#" onclick="if (document.getElementById('tagexplain').style.display == 'block') { document.getElementById('tagexplain').style.display = 'none' } else { document.getElementById('tagexplain').style.display = 'block' }">Help</a>)</label>
			<input name="tags" id="tags" value="<& param var="tags" &><& / &>" />
			<br />
			<label>&nbsp;</label>
			<div>
			<& tags plugin="blog" / &>
			<div id="tagexplain" style="width: 500px; display: none;">
				<h2>Description of the tag filter:</h2>
				<p>Multiple tags, which the entry you're looking for must have (AND combination), have to be separated by whitespaces.</p>
				<p>Tags, which contain whitespaces themselves, have to be quoted using doublequotes.</p>
				<p>If you want to define a set of tags of which only at least one has to exist for that entry (OR combination), you have to enclose the tags in curly braces.</p>
				<h2>Example:</h2>
				<p><em>tag1 tag2 tag3 "tag with whitespaces" {tag4 tag5 tag6} {tag7 tag8 tag9}</em></p>
				<h2>Explanation:</h2>
				<p>Only those entries will be selected, that have the tags "tag1", "tag2", "tag3" and "tag with whitespaces" as well as at least one tag of the first and at least one of the second set.</p>
			</div>
			</div>
			<br />
			
			<label>Author:</label>
			<select name="author" size="1">
				<option value="-1">Autor:</option>
				<& perl &>
					foreach my $item (@{$template_values->{lists}->{authors}}) {
						my $id   = defined $item->{fields}->{id}   ? $item->{fields}->{id}   : 0;
						my $name = defined $item->{fields}->{name} ? $item->{fields}->{name} : '(Kein Name)';
						my $author = $Konstrukt::CGI->param('author');
						print "\t\t<option value=\"$id\"" . (defined $author and $id == $author ? " selected=\"selected\"" : "") . ">$name</option>\n";
					}
				<& / &>
			</select>
			<br />
			
			<label>Date:</label>
			<select name="year" size="1" class="s">
				<option value="-1">Year:</option>
				<& perl &>
					my $year_now = (localtime(time))[5] + 1900;
					my $year     = $Konstrukt::CGI->param('year');
					for (0 .. 4) {
						print "\t\t<option value=\"" . ($year_now - $_) . "\"" . (defined $year and $year == $year_now - $_ ? " selected=\"selected\"" : "") . ">" . ($year_now - $_) . "</option>\n";
					}
				<& / &>
			</select>
			<select name="month" size="1" class="s">
				<option value="-1">Month:</option>
				<& perl &>
					my @month_name = qw/January February March April May June July August September October November December/;
					my $month = $Konstrukt::CGI->param('month');
					for (1 .. 12) {
						print "\t\t<option value=\"$_\"" . (defined $month and $month == $_ ? " selected=\"selected\"" : "") . ">$month_name[$_-1]</option>\n";
					}
				<& / &>
			</select>
			<br />
		
			<label>Text:</label>
			<input name="text" value="<& param var="text" &><& / &>" />
			<br />
			
			<label>&nbsp;</label>
			<input type="submit" class="submit" value="Filter!" />
			<br />
		</form>
		
		<a href="#" onclick="hideFilter();">(hide)</a>
	</div>
</div>

<p style="text-align: right; margin-bottom: 5px;"><a href="#" id="filterlink" onclick="showFilter();">[ Find entry ]</a></p>

== 8< == textfile: messages/comment_add_failed.template == >8 ==

<div class="blog message failure">
	<h1>Comment not added</h1>
	<p>An internal error occurred while adding your comment</p>
</div>

== 8< == textfile: messages/comment_add_failed_captcha.template == >8 ==

<div class="blog message failure">
	<h1>Comment not added</h1>
	<p>The comment could not be added, as the antispam question has not been answered (correctly)!</p>
</div>

== 8< == textfile: messages/comment_add_successful.template == >8 ==

<div class="blog message success">
	<h1>Comment added</h1>
	<p>Your comment has been added successfully!</p>
</div>

== 8< == textfile: messages/comment_delete_failed.template == >8 ==

<div class="blog message failure">
	<h1>Comment not deleted</h1>
	<p>An internal error occurred while deleting the comment.</p>
</div>

== 8< == textfile: messages/comment_delete_failed_permission_denied.template == >8 ==

<div class="blog message failure">
	<h1>Comment not deleted</h1>
	<p>The comment hasn't been deleted, because it can only be deleted by an administator</p>
</div>

== 8< == textfile: messages/comment_delete_successful.template == >8 ==

<div class="blog message success">
	<h1>Comment deleted</h1>
	<p>The comment has been deleted successfully!</p>
</div>

== 8< == textfile: messages/entry_add_failed.template == >8 ==

<div class="blog message failure">
	<h1>Entry not added</h1>
	<p>An internal error occurred while adding this entry.</p>
</div>

== 8< == textfile: messages/entry_add_successful.template == >8 ==

<div class="blog message success">
	<h1>Entry added</h1>
	<p>The entry has been added successfully!</p>
</div>

== 8< == textfile: messages/entry_delete_failed.template == >8 ==

<div class="blog message failure">
	<h1>Entry not deleted</h1>
	<p>An internal error occurred while deleting the entry.</p>
</div>

== 8< == textfile: messages/entry_delete_failed_permission_denied.template == >8 ==

<div class="blog message failure">
	<h1>Entry not deleted</h1>
	<p>The entry could not be deleted, because it can only be deleted by an administrator!</p>
</div>

== 8< == textfile: messages/entry_delete_successful.template == >8 ==

<div class="blog message success">
	<h1>Entry deleted</h1>
	<p>The entry has been deleted successfully!</p>
</div>

== 8< == textfile: messages/entry_edit_failed.template == >8 ==

<div class="blog message failure">
	<h1>Entry not updated</h1>
	<p>An internal error occurred while updating the entry.</p>
</div>

== 8< == textfile: messages/entry_edit_failed_permission_denied.template == >8 ==

<div class="blog message failure">
	<h1>Entry not updated</h1>
	<p>The entry has not been updated, because it can only be updated by its author or an administrator!</p>
</div>

== 8< == textfile: messages/entry_edit_successful.template == >8 ==

<div class="blog message success">
	<h1>Entry updated</h1>
	<p>The entry has been updated successfully</p>
</div>

== 8< == textfile: /blog/rss2/index.html == >8 ==

<& blog show="rss2" / &>

== 8< == binaryfile: /img/blog/rss2.gif == >8 ==

R0lGODlhMgAPALMAAGZmZv9mAP///4mOeQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAACwAAAAAMgAPAAAEexDISau9OFvBu/9gKI6dJARoqq4sKgxwLM/0IJhtnr91T9+Ak26Y4vmO
NpyLo+oUmUVZ52eUKgPC7Eq4rVV5VRiQ63w2ua4ZRy3+XU9o17Yp9bbVbzkWuo9/p0ZrbkFEhWFI
g3GFLIeIVoSLOo2OYiYkl5iZQBqcnZ4TEQA7

== 8< == textfile: /styles/blog.css == >8 ==

/* CSS definitions for the Konstrukt blog plugin */

div.blog h1 {
	margin-top: 0;
}

div.blog.entry, div.blog.comments {
	background-color: #eef0f2;
	padding: 15px;
	border: 1px solid #3b8bc8;
	margin: 20px 0 20px 0;
}

div.blog.entry div.description {
	font-style: italic;
}

div.blog.entry div.content {
	margin-top: 10px;
}

div.blog.entry div.foot {
}

img.blog_icon {
	vertical-align: middle;
}
