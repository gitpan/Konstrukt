DESCRIPTION:

This is a small demosite, which gives an insight into the functionality of the
Konstrukt Framework and some of the existing plugins.


INSTALLATION:

1) Copy the directories cache, log and page into a directory of your choice.
	Apache will need read and write access to this directories.
	
2) Create a new vhost for your Apache2 like this:
   (differs slightly for Apache1 -
	See the doc/html/Konstrukt/Doc/Installation.html#CONFIGURATION):
	
	<VirtualHost *>
		ServerName   your.domain
		
		ErrorLog     /path/to/the/demosite/logs/error.log
		TransferLog  /path/to/the/demosite/logs/access.log
		
		# docs
		DocumentRoot /path/to/the/demosite/page
		<Directory "/path/to/the/demosite/page">
			Order allow,deny
			Allow from all
		</Directory>
		
		# do not allow access to *.template, *.form and konstrukt.setting files
		<FilesMatch "(\.template|\.form|konstrukt\.settings)$">
			Deny from All
		</FilesMatch>
		
		# serve html files with the Konstrukt Framework
		<FilesMatch "\.html$">
			SetHandler modperl
			PerlResponseHandler Konstrukt::Handler::Apache
		</FilesMatch>
	</VirtualHost>
	
3) Create a MySQL database according to the settings in the
	page/konstrukt.settings (look at the dbi settings).
	Thats a database called "test" for the user "test" with the password "tset":
	
	CREATE DATABASE test;
	GRANT ALL ON test.* TO test@'%' IDENTIFIED by 'tset';

4) Restart your apache and you're done!


AUTOINSTALLATION:

As the setting 'autoinstall' is enabled in the supplied konstrukt.settings,
the plugins will create the templates, stylesheets and database tables automatically.
So as you use the page, your database and the /templates directory will get filled.

Of course, this will affect the performance negatively. So after every plugin/
page has been used once, you can turn it off (set it to 0 or remove the setting).


USAGE:

To create content (blog entries, calendar entries, bookmarks, wiki pages, ...)
you need to register yourself on the page. That will be done on the
"usermanagement" page.

You will get an email with the password for your account. By default, the
framework will use the `sendmail` command on your server. You can also configure
it to use a local SMTP server (See doc/html/Konstrukt/Lib.html#CONFIGURATION):

	mail/transport smtp


TROUBLESHOOTING:

Any errors will be put into your Apache error.log, as the setting
debug/warn_error_messages is enabled by default.
So this is the first place to look.

In Apache2 the messages will go to the global server log and not to the log
specified in the vhost.