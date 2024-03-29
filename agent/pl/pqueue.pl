;# $Id: pqueue.pl,v 3.0.1.1 1994/07/01 15:04:20 ram Exp $
;#
;#  Copyright (c) 1990-1993, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: pqueue.pl,v $
;# Revision 3.0.1.1  1994/07/01  15:04:20  ram
;# patch8: now honours new queuehold config variable
;#
;# Revision 3.0  1993/11/29  13:49:09  ram
;# Baseline for mailagent 3.0 netwide release.
;#
;# 
# Process the queue
sub pqueue {
	local($length);						# Length of message, in bytes
	undef %waiting;						# Reset waiting array
	local(*DIR);						# File descriptor to list the queue
	unless (opendir(DIR, $cf'queue)) {
		&add_log("ERROR unable to open $cf'queue: $!") if $loglvl;
		return 0;						# No file processed
	}
	local(@dir) = readdir DIR;			# Slurp the all directory contents
	closedir DIR;

	# The qm files are put there by the filter and left in case of error
	# Only files older than 30 minutes are re-parsed (because otherwise it
	# might have just been queued by the filter). The fm files are normal
	# queued file which may be processed immediately.

	# Prefix each file name with the queue directory path
	local(@files) = grep(s|^fm|$cf'queue/fm|, @dir);
	local(@filter_files) = grep(s|^qm|$cf'queue/qm|, @dir);
	undef @dir;							# Directory listing not need any longer

	foreach $file (@filter_files) {
		($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
			$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
		if ((time - $mtime) > $cf'queuehold) {
			# More than queue timeout -- there must have been a failure
			push(@files, $file);		# Add file to the to-be-parsed list
		}
	}

	# In $agent_wait are stored the names of the mails outside the queue
	# directory, waiting to be processed.
	if (-f "$cf'queue/$agent_wait") {
		if (open(WAITING, "$cf'queue/$agent_wait")) {
			while (<WAITING>) {
				chop;
				push(@files, $_);		# Process this file too
				$waiting{$_} = 1;		# Record it comes from waiting file
			}
			close WAITING;
		} else {
			&add_log("ERROR cannot open $cf'queue/$agent_wait: $!") if $loglvl;
		}
	}
	return 0 unless $#files >= 0;

	&add_log("processing the whole queue") if $loglvl > 11;
	$processed = 0;
	foreach $file (@files) {
		&add_log("dealing with $file") if $loglvl > 19;
		$file_name = $file;
		if ($waiting{$file} && ! -f "$file") {
			# We may have already processed this file without having resynced
			# agent_wait or the file has been removed.
			&add_log ("WARNING could not find $file") if $loglvl > 4;
			$waiting{$file} = 0;	# Mark it as processed
			next;					# And skip it
		}
		if (0 == &analyze_mail($file_name)) {
			unlink $file;
			++$processed;
			$waiting{$file} = 0 if $waiting{$file};
			$file =~ s|.*/(.*)|$1|;	# Keep only basename
			$length = $Header{'Length'};
			&add_log("FILTERED [$file] $length bytes") if $loglvl > 4;
		} else {
			$file =~ s|.*/(.*)|$1|;	# Keep only basename
			&add_log("ERROR leaving [$file] in queue") if $loglvl > 0;
			unlink $lockfile;
			&resync;				# Resynchronize waiting file
			exit 0;					# Do not continue now
		}
	}
	if ($processed == 0) {
		&add_log("was unable to process queue") if $loglvl > 5;
	}
	&resync;			# Resynchronize waiting file
	$processed;			# Return the number of files processed
}

