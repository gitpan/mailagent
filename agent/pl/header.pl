;# $Id: header.pl,v 3.0.1.1 1994/07/01 15:00:51 ram Exp $
;#
;#  Copyright (c) 1990-1993, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: header.pl,v $
;# Revision 3.0.1.1  1994/07/01  15:00:51  ram
;# patch8: fixed leading From date format (spacing problem)
;#
;# Revision 3.0  1993/11/29  13:48:49  ram
;# Baseline for mailagent 3.0 netwide release.
;#
;# 
package header;

# This package implements a header checker. To initialize it, call 'reset'.
# Then, call 'valid' with a header line and the function returns 0 if the
# line is not part of a header (which means all the lines seen since 'reset'
# are not part of a mail header). If the line may still be part of a header,
# returns 1. Finally, -1 is returned at the end of the header.

sub init {
	# Main header fields which should be looked at when parsing a mail header
	%Mailheader = (
		'From', 1,
		'To', 1,
		'Subject', 1,
		'Date', 1,
	);
}

# Reset header checking status
sub reset {
	&init unless $init_done++;		# Initialize private data
	$last_was_header = 0;			# Previous line was not a header
	$maybe = 0;						# Do we have a valid part of header?
	$line = 0;						# Count number of lines in header
}

# Is the current line still part of a valid header ?
sub valid {
	local($_) = @_;
	return 1 if $last_was_header && /^\s/;	# Continuation line
	return -1 if /^$/;						# End of header
	$last_was_header = /^([\w\-]+):/ ? 1 : 0;
	# Activate $maybe when essential parts of a valid mail header are found
	# Any client can check 'maybe' to see if what has been parsed so far would
	# be a valid RFC-822 header, even though syntactically correct.
	$maybe |= $Mailheader{$1} if $last_was_header;
	$last_was_header = /^From\s+\S+/
		unless $last_was_header || $line;	# First line may be special
	++$line;								# One more line
	$last_was_header;						# Are we still inside header?
}

# Produce a warning header field about a specific item
sub warning {
	local($field, $added) = @_;
	local($warning);
	local(@field) = split(' ', $field);
	$warning = 'X-Filter-Note: ';
	if ($added && @field == 1) {
		$warning .= "Header $field added at ";
	} elsif ($added && @field > 1) {
		$field = join(', ', @field);
		$field =~ s/^(.*), (.*)/$1 and $2/;
		$warning .= "Headers $field added at ";
	} else {
		$warning .= "Parsing error in original previous line at ";
	}
	$warning .= &main'domain_addr;
	$warning;
}

# Make sure header contains vital fields. The header is held in an array, on
# a line basis with final new-line chopped. The array is modified in place,
# setting defaults from the %Header array (if defined, which is the case for
# digests mails) or using local defaults.
sub clean {
	local(*array) = @_;					# Array holding the header
	local($added) = '';					# Added fields

	$added .= &check(*array, 'From', $cf'user, 1);
	$added .= &check(*array, 'To', $cf'user, 1);
	$added .= &check(*array, 'Date', &fake_date, 0);
	$added .= &check(*array, 'Subject', '<none>', 1);

	&push(*array, &warning($added, 1)) if $added ne '';
}

# Check presence of specific field and use value of %Header as a default if
# available and if '$use_header' is set, otherwise use the provided value.
# Return added field or a null string if nothing is done.
sub check {
	local(*array, $field, $default, $use_header) = @_;
	local($faked);						# Faked value to be used
	if ($use_header) {
		$faked = (defined $'Header{$field}) ? $'Header{$field} : $default;
	} else {
		$faked = $default;
	}

	# Try to locate field in header
	local($_);
	foreach (@array) {
		return '' if /^$field:/;
	}

	&push(*array, "$field: $faked");
	$field . ' ';
}

# Push header line at the end of the array, without assuming any final EOH line
sub push {
	local(*array, $line) = @_;
	local($last) = pop(@array);
	push(@array, $last) if $last ne '';	# There was no EOH
	push(@array, $line);				# Insert header line
	push(@array, '') if $last eq '';	# Restore EOH
}

# Compute a valid date field suitable for mail header
sub fake_date {
	require 'ctime.pl';
	local($date) = &'ctime(time);
	# Traditionally, MTAs add a ',' right after week day
	# Moreover, RFC-822 and RFC-1123 require a leading 0 if hour < 10
	$date =~ s/^(\w+)(\s)/$1,$2/;
	$date =~ s/\s(\d:\d\d:\d\d)\b/0$1/;
	chop($date);					# Ctime adds final new-line
	$date;
}

# Normalizes header: every first letter is uppercase, the remaining of the
# word being lowercased, as in This-Is-A-Normalized-Header. Note that RFC-822
# does not impose such a formatting.
sub normalize {
	local($field_name) = @_;			# Header to be normalized
	$field_name =~ s/(\w+)/\u\L$1/g;
	$field_name;						# Return header name with proper case
}

# Format header field to fit into 78 columns, each continuation line being
# indented by 8 chars. Returns the new formatted header string.
sub format {
	local($field) = @_;			# Field to be formatted
	local($tmp);				# Buffer for temporary formatting
	local($new) = '';			# Constructed formatted header
	local($kept);				# Length of current line
	local($len) = 78;			# Amount of characters kept
	local($cont) = ' ' x 8;		# Continuation lines starts with 8 spaces
	# Format header field, separating lines on ',' or space.
	while (length($field) > $len) {
		$tmp = substr($field, 0, $len);		# Keep first $len chars
		$tmp =~ s/^(.*)([,\s]).*/$1$2/;		# Cut at last space or ,
		$kept = length($tmp);				# Amount of chars we kept
		$tmp =~ s/\s*$//;					# Remove trailing spaces
		$tmp =~ s/^\s*//;					# Remove leading spaces
		$new .= $cont if $new;				# Continuation starts with 8 spaces
		$len = 70;							# Account continuation for next line
		$new .= "$tmp\n";
		$field = substr($field, $kept, 9999);
	}
	$new .= $cont if $new;					# Add 8 chars if continuation
	$new .= $field;							# Remaining information on one line
}

# Scan the head of a file and try to determine whether there is a mail
# header at the beginning or not. Return true if a header was found.
sub main'header_found {
	local($file) = @_;
	local($correct) = 1;				# Were all the lines from top correct ?
	local($_);
	open(FILE, $file) || return 0;		# Don't care to report error
	&reset;								# Initialize header checker
	while (<FILE>) {					# While still in a possible header
		last if /^$/;					# Exit if end of header reached
		$correct = &valid($_);			# Check line validity
		last unless $correct;			# No, not a valid header
	}
	close FILE;
	$correct;
}

package main;

