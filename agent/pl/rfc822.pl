;# $Id: rfc822.pl,v 3.0.1.2 1995/09/15 14:05:10 ram Exp $
;#
;#  Copyright (c) 1990-1993, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: rfc822.pl,v $
;# Revision 3.0.1.2  1995/09/15  14:05:10  ram
;# patch43: internet_info now assumes local user when facing a single login
;#
;# Revision 3.0.1.1  1994/04/25  15:22:39  ram
;# patch7: now also understands @domain:user@other addresses
;# patch7: more accurate for group name parsing
;#
;# Revision 3.0  1993/11/29  13:49:13  ram
;# Baseline for mailagent 3.0 netwide release.
;#
;#
;# The following routines do some parsing on RFC822 headers (such as the
;# ones provided by sendmail).
;#

# Parse an address and returns (internet, comment)
# Examples:
#    ram@eiffel.com (Raphael Manfredi)  -> (ram@eiffel.com, Raphael Manfredi)
#    Raphael Manfredi <ram@eiffel.com>  -> (ram@eiffel.com, Raphael Manfredi)
# Note that we try to parse malformed RFC822 addresses to the best we can, by
# giving priority to anything between <> for correct e-mail address detection.
# Common errors include having a '<>' construct as part of the comment attached
# to the address as "name <surname> lastname", but this can only be followed
# by a <> address and the regexp is built so that it will skip the first <>
# and match only the last one on the line.
sub parse_address {
	local($_) = shift(@_);		# The address to be parsed
	local($comment);
	local($internet);
	if (/^\s*(.*)\s+<(\S+)>[^()]*$/) {		# comment <address>
		$comment = $1;
		$internet = $2;
		$comment =~ s/^"(.*)"/$1/;			# "comment" -> comment
		($internet, $comment);
	} elsif (/^\s*([^()]+)\s+\((.*)\)/) {	# address (comment) 
		$comment = $2;
		$internet = $1;
		# Construct '<address> (comment)' is invalid but... priority to <>
		# This will also take care of "comment" <address> (other-comment)
		$internet =~ /<(\S+)>/ && ($internet = $1);
		($internet, $comment);
	} elsif (/^\s*<(\S+)>\s*(.*)/) {		# <address> ...garbage...
		($1, $2);
	} elsif (/^\s*\((.*)\)\s+<?(.*)>?/) {	# (comment) [address or <address>]
		($2, $1);
	} else {								# plain address, grab first word
		/^\s*(\S+)\s*(.*)/;
		($1, $2);
	}
}

# Parses an internet address and returns the login name of the sender. When
# facing an RFC 822 group addressing (like To: group:;), it returns the group
# name when mailbox is not specified.
sub login_name {
	local($_) = shift(@_);				# The internet address
	if (/^(\S+):(\S*);/) {				# rfc-822-group:mailbox;
		if ($2 eq '') {
			&last_name($1);				# empty mailbox name, use phrase
		} else {
			&login_name($2);			# mailbox name
		}
	} elsif (s/^@\S+://) {				# @domain:user@other
		&login_name($_);				# parse user@other
	} elsif (s/^"(\S+)"@\S+/$1/) {		# "user@domain"@other
		&login_name($_);				# parse user@domain
	} elsif (s/^(\S+)@\S+/$1/) {		# user@domain.name
		&login_name($_);				# parse user
	} elsif (s/^(\S+)%\S+/$1/) {		# user%domain.name
		&login_name($_);				# parse user
	} elsif (s/^\S+!(\S+)/$1/) {		# ...!backbone!user
		&last_name($_);					# user can only be a simple name
	} else {							# everything else must be a single name
		&last_name($_);					# keep only last name
	}
}

# Extract last name from a login name like First_name.Last_name and put it
# in lowercase. Hence, Raphael.Manfredi will become manfredi. Since '_' or '.'
# characters could be legitimely used in a login name (or distribution list),
# we remove it only when followed by an upper-cased letter.
sub last_name {
	local($_) = shift(@_);			# The sender's login name
	s/.*\.([A-Z]\w*)/$1/;			# Keep only the last name (. separation)
	s/.*_([A-Z]\w*)/$1/;			# Same as above (_ separation)
	tr/A-Z/a-z/;					# And lowercase it
	$_;
}

# Parse an e-mail address and return a three element array:
#   ($host, $domain, $country)
sub internet_info {
	local($_) = shift(@_);				# The internet address
	local($login) = &login_name($_);	# Get the address login name
	local($internet);					# The internet part of the address
	# Try with uucp form first, to detect things like eiffel!ram@inria.fr
	# We use the login name to anchor the last '!' or the first '@' or '%'
	($internet) = /([^!]*)!$login/i;
	($internet) = /$login[@%]([\w.-]*)/i unless $internet;
	$internet = &myhostname . $mydomain unless $internet;
	$internet =~ tr/A-Z/a-z/;				# Always lower-cased
	local(@parts) = split(/\./, $internet);	# Break on dots
	if (@parts == 1) {						# Only a host name
		# Maybe this is a local address, maybe this is a uucp name. Assume that
		# it is local if there is an '@' sign, as in 'ram@lyon'. Otherwise, it
		# is a uucp name, as in 'eiffel!ram'.
		push(@parts, 'uucp') if /!$login/;	# UUCP name
		push(@parts, split(/\./, $mydomain)) if @parts == 1;
	}
	unshift(@parts, '') if @parts == 2;		# No host name
	@parts[($#parts - 2) .. $#parts];		# ($host, $domain, $country)
}

