;# $Id: parse.pl,v 3.0.1.6 1995/03/21 12:57:06 ram Exp $
;#
;#  Copyright (c) 1990-1993, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: parse.pl,v $
;# Revision 3.0.1.6  1995/03/21  12:57:06  ram
;# patch35: now allows spaces between header field name and the ':' delimiter
;#
;# Revision 3.0.1.5  1995/02/16  14:35:15  ram
;# patch32: new routines header_prepend and header_append
;# patch32: can now fake a missing From: line in header
;#
;# Revision 3.0.1.4  1995/01/25  15:27:08  ram
;# patch27: ported to perl 5.0 PL0
;#
;# Revision 3.0.1.3  1994/09/22  14:33:38  ram
;# patch12: builtins handled in &run_builtins to allow re-entrance
;#
;# Revision 3.0.1.2  1994/07/01  15:04:02  ram
;# patch8: now systematically escape leading From if fromall is ON
;#
;# Revision 3.0.1.1  1994/04/25  15:18:14  ram
;# patch7: global fix for From line escapes to make them configurable
;#
;# Revision 3.0  1993/11/29  13:49:05  ram
;# Baseline for mailagent 3.0 netwide release.
;#
;# 
#
# Parsing mail
#

# Parse the mail and fill-in the Header associative array. The special entries
# All, Body and Head respectively hold the whole message, the body and the
# header of the message.
sub parse_mail {
	local($file_name) = shift(@_);	# Where mail is stored ("" for stdin)
	local($head_only) = shift(@_);	# Optional parameter: parse only header
	local($last_header) = "";		# Name of last header (for continuations)
	local($first_from) = "";		# The first From line in mails
	local($lines) = 0;				# Number of lines in the body
	local($length) = 0;				# Length of body, in bytes
	local($last_was_nl) = 1;		# True when last line was a '\n' (1 for EOH)
	local($fd) = STDIN;				# Where does the mail come from ?
	local($field, $value);			# Field and value for current line
	local($_);
	undef %Header;					# Reset the whole structure holding message

	if ($file_name ne '') {			# Mail spooled in a file
		unless(open(MAIL, $file_name)) {
			&add_log("ERROR cannot open $file_name: $!");
			return;
		}
		$fd = MAIL;
	}
	$Userpath = "";					# Reset path from possible previous @PATH 

	# Pre-extend 'All', 'Body' and 'Head'
	$Header{'All'} = ' ' x 5000;
	$Header{'Body'} = ' ' x 4500;
	$Header{'Head'} = ' ' x 500;
	$Header{'All'} = '';
	$Header{'Body'} = '';
	$Header{'Head'} = '';

	&add_log ("parsing mail") if $loglvl > 18;
	while (<$fd>) {
		$Header{'All'} .= $_;
		if (1../^$/) {						# EOH is a blank line
			next if /^$/;					# Skip EOH marker
			$Header{'Head'} .= $_;			# Record line in header

			if (/^\s/) {					# It is a continuation line
				s/^\s+/ /;					# Swallow multiple spaces
				chop;						# Remove final new-line
				$Header{$last_header} .= "\n$_" if $last_header ne '';
				&add_log("WARNING bad continuation in header, line $.")
					if $last_header eq '' && $loglvl > 4;
			} elsif (/^([\w-]+)\s*:\s*(.*)/) {	# We found a new header
				# Guarantee only one From: header line. If multiple From: are
				# found, keep the last one.
				# Multiple headers like 'Received' are separated by a new-
				# line character. All headers end on a non new-line.
				# Case is normalized before recording, so apparently-to will
				# be recorded as Apparently-To but header is not changed.
				($field, $value) = ($1, $2);	# Bug in perl 5.000 (dataloaded)
				$last_header = &header'normalize($field);	# Normalize case
				if ($last_header eq 'From' && defined $Header{$last_header}) {
					$Header{$last_header} = $value;
					&add_log("WARNING duplicate From in header, line $.")
						if $loglvl > 4;
				} elsif ($Header{$last_header} ne '') {
					$Header{$last_header} .= "\n$value";
				} else {
					$Header{$last_header} .= $value;
				}
			} elsif (/^From\s+(\S+)/) {		# The very first From line
				$first_from = $1;
			}

		} else {
			last if $head_only;		# Stop parsing if only header wanted
			$lines++;								# One more line in body
			$length += length($_);					# Update length of message
			# Protect potentially dangerous lines when asked to do so
			# From could normally be mis-interpreted only after a blank line,
			# but some "broken" User Agents also look for them everywhere...
			# That's where fromall must be set to ON to escape all of them.
			s/^From(\s)/>From$1/ if $last_was_nl && $cf'fromesc =~ /on/i;
			$last_was_nl = /^$/ || $cf'fromall =~ /on/i;
			$Header{'Body'} .= $_;
		}
	}
	close MAIL if $file_name ne '';
	&header_prepend("$FAKE_FROM\n") unless $first_from;
	&header_check($first_from, $lines);	# Sanity checks
}

# Now do some sanity checks:
# - if there is no From: header, fill it in with the first From
# - if there is no To: but an Apparently-To:, copy it also as a To:
# - if an Envelope field was defined in the header, override it (sorry)
#
# We guarantee the following header entries:
#   From:         the value of the From field
#   To:           to whom the mail was sent
#   Lines:        number of lines in the message
#   Length:       number of bytes in the message
#   Reply-To:     the address we may use to reply
#   Sender:       the value of the Sender field, same as From usually
#   Envelope:     the actual sender of the message, empty if cannot compute
#
sub header_check {
	local($first_from, $lines) = @_;	# First From line, number of lines
	unless (defined $Header{'From'}) {
		&add_log("WARNING no From: field, assuming $first_from") if $loglvl > 4;
		$Header{'From'} = $first_from;
		# Fake a From: header line unless prevented to do so. That way, when
		# saving in an MH or MMDF folder (where the leading From is stripped),
		# the user will still be able to identify the source of the message!
		if ($first_from && $cf'fromfake !~ /^off/i) {
			&add_log("NOTICE faking a From: header line") if $loglvl > 5;
			&header_append("From: $first_from\n");
		}
	}

	# There is usually one Apparently-To line per address. Remove all new lines
	# in the header line and replace them with ','. Likewise for To: and Cc:.
	# although it is far less likely to occur.
	local($*) = 1;
	foreach $field ('Apparently-To', 'To', 'Cc') {
		$Header{$field} =~ s/\n/,/g;	# Remove new-lines
		$Header{$field} =~ s/,$/\n/;	# Restore last new-line
	}
	$* = 0;

	# If no To: field, then maybe there is an Apparently-To: instead. If so,
	# make them identical. Otherwise, assume the mail was directed to the user.
	if (!$Header{'To'} && $Header{'Apparently-To'}) {
		$Header{'To'} = $Header{'Apparently-To'};
	}
	unless ($Header{'To'}) {
		&add_log("WARNING no To: field, assuming $cf'user") if $loglvl > 4;
		$Header{'To'} = $cf'user;
	}

	# Set number of lines in body, unless there is already a Lines:
	# header in which case we trust it. Same for Length.
	$Header{'Lines'} = $lines unless defined($Header{'Lines'});
	$Header{'Length'} = $length unless defined($Header{'Length'});

	# If there is no Reply-To: line, then take the address in From, if any.
	# Otherwise use the address found in the return-path
	if (!$Header{'Reply-To'}) {
		local($tmp) = (&parse_address($Header{'From'}))[0];
		$Header{'Reply-To'} = $tmp if $tmp ne '';
		$Header{'Reply-To'} = (&parse_address($Header{'Return-Path'}))[0]
			if $tmp eq '';
	}

	# Unless there is already a sender line, fake one using From field
	if (!$Header{'Sender'}) {
		$Header{'Sender'} = $first_from;
		$Header{'Sender'} = $Header{'From'} unless $first_from;
	}

	# Now override any Envelope header and grab it from the first From field
	# If such a field was defined in the message header, then sorry but it
	# was a mistake: RFC 822 doesn't define it, so it should have been
	# an X-Envelope instead.

	$Header{'Envelope'} = $first_from;
}

# Append given field to the header structure, updating the whole mail
# text at the same time, hence keeping the %Header table.
# The argument must be a valid formatted RFC-822 mail header field.
sub header_append {
	local($hline) = @_;
	$Header{'Head'} .= $hline;
	$Header{'All'} = $Header{'Head'} . "\n" . $Header{'Body'};
}

# Prepend given field to the whole mail, updating %Header fields accordingly.
sub header_prepend {
	local($hline) = @_;
	$Header{'Head'} = $hline . $Header{'Head'};
	$Header{'All'} = $hline . $Header{'All'};
}

