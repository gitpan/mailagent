;# $Id: emergency.pl,v 3.0.1.2 1997/01/07 18:32:40 ram Exp $
;#
;#  Copyright (c) 1990-1993, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: emergency.pl,v $
;# Revision 3.0.1.2  1997/01/07  18:32:40  ram
;# patch52: now pre-extend memory by using existing message size
;#
;# Revision 3.0.1.1  1996/12/24  14:51:14  ram
;# patch45: don't dataload the emergency routine to avoid malloc problems
;# patch45: now log the signal trapping even when invoked manually
;#
;# Revision 3.0  1993/11/29  13:48:41  ram
;# Baseline for mailagent 3.0 netwide release.
;#
;# 
#
# Emergency situation routines
#

# Perload OFF
# (Better not be dynamically loaded as it is a signal handler)

# Emergency signal was caught
sub emergency {
	local($sig) = @_;			# First argument is signal name
	if ($has_option) {			# Mailagent was invoked "manually"
		&resync;				# Resynchronize waiting file if necessary
		&add_log("ERROR trapped SIG$sig") if $loglvl;
		exit 1;
	}
	&fatal("trapped SIG$sig");
}

# Perload ON

# In case something got wrong
sub fatal {
	local($reason) = shift;		# Why did we get here ?
	local($preext) = 0;
	local($added) = 0;
	local($curlen) = 0;

	# Make sure the lock file does not last. We don't need any lock now, as
	# we are going to die real soon anyway.
	unlink $lockfile if $locked;

	# Assume the whole message has not been read yet
	$fd = STDIN;				# Default input
	if ($file_name ne '') {
		$Header{'All'} = '';	# We're about to re-read the whole message
		open(MSG, $file_name);	# Ignore errors
		$fd = MSG;
		$preext = -s MSG;
	}
	if ($preext <= 0) {
		$preext = 100000;
		&add_log ("preext uses fixed value ($preext)") if $loglvl > 19;
	} else {
		&add_log ("preext uses file size ($preext)") if $loglvl > 19;
	}

	# We have to careful here, because when reading from STDIN
	# $Header{'All'} might not be empty
	$curlen = length($Header{'All'});
	&add_log ("pre-extended retaining $curlen old bytes") if $loglvl > 19;
	$Header{'All'} .= ' ' x $preext;
	substr($Header{'All'}, $curlen) = '';

	unless (-t $fd) {			# Do not get mail if connected to a tty
		while (<$fd>) {
			$added += length($_);
			if ($added > $preext) {
				$curlen = length($Header{'All'});
				&add_log ("extended after $curlen bytes") if $loglvl > 19;
				$Header{'All'} .= ' ' x $preext;
				substr($Header{'All'}, $curlen) = '';
				$added = $added - $preext;
			}
			$Header{'All'} .= $_;
		}
	}

	# It can happen that we get here before configuration file was read
	if (defined $loglvl) {
		&add_log("FATAL $reason") if $loglvl;
		-t STDIN && print STDERR "$prog_name: $reason\n";
	}

	# Try an emergency save, if mail is not empty
	if ($Header{'All'} ne '' && 0 == &emergency_save) {
		# The stderr should be redirected to some file
		$file_name =~ s|.*/(.*)|$1|;	# Keep only basename
		$file_name = "<stdin>" if $file_name eq '';
		print STDERR "**** $file_name not processed ($reason) ****\n";
		print STDERR $Header{'All'};
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
			localtime(time);
		$date = sprintf("%.2d/%.2d/%.2d %.2d:%.2d:%.2d",
			$year,++$mon,$mday,$hour,$min,$sec);
		print STDERR "---- $date ----\n";
	}

	&resync;			# Resynchronize waiting file if necessary
	# Give an error exit status to filter
	exit 1;
}

# Emergency saving of message held in $Header{'All'}. If the 'emergdir'
# configuration parameter in ~/.mailagent is set to an existing directory, the
# first saving attempt is made there (each mail in a separate file).
sub emergency_save {
	return 0 unless (defined $cf'home);	# ~/.mailagent not processed
	return 1 if -d "$cf'emergdir" && &dump_mbox("$cf'emergdir/ma$$");
	return 1 if &dump_mbox(&mailbox_name);
	return 1 if &dump_mbox("$cf'home/mbox.urgent");
	return 1 if &dump_mbox("$cf'home/mbox.urg$$");
	return 1 if &dump_mbox("/usr/spool/uucppublic/mbox.$cf'user");
	return 1 if &dump_mbox("/var/spool/uucppublic/mbox.$cf'user");
	return 1 if &dump_mbox("/usr/tmp/mbox.$cf'user");
	return 1 if &dump_mbox("/var/tmp/mbox.$cf'user");
	return 1 if &dump_mbox("/tmp/mbox.$cf'user");
	&add_log("ERROR unable to save mail in any emergency mailbox") if $loglvl;
	0;
}

# Dump $Header{'All'} in emergency mailbox
sub dump_mbox {
	local($mbox) = shift(@_);
	local($ok) = 0;						# printing status
	local($existed) = 0;				# did the mailbox exist already ?
	local($old_size);					# Size the old mailbox had
	local($new_size);					# Size of the mailbox after saving
	local($should);						# Size it should have if saved properly
	$existed = 1 if -f $mbox;
	$old_size = $existed ? -s $mbox : 0;
	if (open(MBOX, ">>$mbox")) {
		(print MBOX $Header{'All'}) && ($ok = 1);
		print MBOX "\n";				# allow parsing by other mail tools
		close(MBOX) || ($ok = 0);
		$new_size = -s $mbox;			# Stat new mbox file, grab its size
		$should = $old_size +			# New ideal size is old size plus...
			length($Header{'All'}) +	# ... the length of the message saved
			1;							# ... the trailing new-line
		if ($should != $new_size) {
			&add_log("ERROR $mbox has $new_size bytes (should have $should)")
				if $loglvl;
			$ok = 0;					# Saving failed, sorry...
		}
		if ($ok) {
			&add_log("DUMPED in $mbox") if $loglvl > 5;
			return 1;
		} else {
			if ($existed) {
				&add_log("WARNING imcomplete mail appended to $mbox")
					if $loglvl > 5;
			} else {
				unlink "$mbox";			# remove incomplete file
			}
		}
	}
	0;
}

# Resynchronizes the waiting file if necessary (i.e if it exists and %waiting
# is not an empty array).
sub resync {
	local(@key) = keys %waiting;	# Keys of H table are file names
	local($ok) = 1;					# Assume resync is ok
	local($printed) = 0;			# Nothing printed yet
	return if $#key < 0 || "$cf'queue" eq '' || ! -f "$cf'queue/$agent_wait";
	&add_log("resynchronizing the waiting file") if $loglvl > 11;
	if (open(WAITING, ">$cf'queue/$agent_wait~")) {
		foreach (@key) {
			if ($waiting{$_}) {
				print WAITING "$_\n" || ($ok = 0);
				$printed = 1;
			}
		}
		close(WAITING) || ($ok = 0);
		if ($printed) {
			if (!$ok) {
				&add_log("ERROR could not update waiting file") if $loglvl;
				unlink "$cf'queue/$agent_wait~";
			} elsif (rename("$cf'queue/$agent_wait~","$cf'queue/$agent_wait")) {
				&add_log("waiting file has been updated") if $loglvl > 18;
			} else {
				&add_log("ERROR cannot rename waiting file") if $loglvl;
			}
		} else {
			unlink "$cf'queue/$agent_wait";
			unlink "$cf'queue/$agent_wait~";
			&add_log ("removed waiting file") if $loglvl > 18;
		}
	} else {
		&add_log("ERROR unable to write new waiting file") if $loglvl;
	}
}

