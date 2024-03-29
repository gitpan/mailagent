;# $Id: acs_rqst.pl,v 3.0.1.2 1994/10/04 17:42:43 ram Exp $
;#
;#  Copyright (c) 1990-1993, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: acs_rqst.pl,v $
;# Revision 3.0.1.2  1994/10/04  17:42:43  ram
;# patch17: added support for customized lockfile names
;#
;# Revision 3.0.1.1  1994/07/01  14:56:37  ram
;# patch8: now uses lockmax and lockdelay config variables
;#
;# Revision 3.0  1993/11/29  13:48:32  ram
;# Baseline for mailagent 3.0 netwide release.
;#
;#
;# The basic file locking scheme implemented here by acs_rqst is not completely
;# suitable with NFS if multiple mailagent can run, since they could have the
;# same PID on different machine and both think they got a lock. To make this
;# work with NFS, the ~/.mailagent config file must have the 'nfslock' variable
;# set to 'YES', which will cause the mailagent to include hostname informations
;# in the lock file.
;#
;# The traditional NFS scheme of having a `hostname`.pid file linked to .lock
;# (since the linking operation remains atomic even with NFS) does not seem
;# suitable here, since I want to be able to recover from crashes, and detect
;# out-of-date locks. Therefore, I must be able to know what is the name of the
;# lock file. The link/unlink trick could leave some temporary files around.
;# Since write on disks are atomic anyway, only one process can conceivably
;# obtain a lock with my scheme.
;#
;# The NFS-secure lock is made optional because, in order to get the hostname,
;# perl must fork to exec an appropriate program. This added overhead might not
;# be necessary in all the situations.
;#
;# In order to add customization of locks, an additional parameter may be given
;# to the &acs_rqst and &free_file routines, describing how the lock file is
;# derived from the file to be locked. This additional parameter is given to
;# &lock'file for computation and macro expansion.
;#
# Asks for the exclusive access of a file. The config variable 'nfslock'
# determines whether the locking scheme has to be NFS-secure or not.
# The given parameter (let's say F) is the absolute path of the file we want
# to access. The routine checks for the presence of F.lock. If it exists, it
# sleeps 2 seconds and tries again. After 10 trys, it reports failure by
# returning -1. Otherwise, file F.lock is created and the pid of the current
# process is written. It is checked afterwards.
sub acs_rqst {
	local($file, $format) = @_;		# file to be locked, lock format
	local($max) = $cf'lockmax;		# max number of attempts
	local($delay) = $cf'lockdelay;	# seconds to wait between attempts
	local($mask);		# to save old umask
	local($stamp);		# string written in lock file
	&checklock($file, $format);		# avoid long-lasting locks
	if ($cf'nfslock =~ /on/i) {			# NFS-secure lock wanted
		$stamp = "$$" . &hostname;		# use PID and hostname
	} else {
		$stamp = "$$";					# use PID only (may spare a fork)
	}
	local($lockfile) = $file . $lockext;
	$lockfile = &lock'file($file, $format) if defined $format;
	while ($max) {
		$max--;
		if (-f $lockfile) {
			sleep($delay);				# busy: wait
			next;
		}
		# Attempt to create lock
		$mask = umask(0333);			# no write permission
		if (open(FILE, ">$lockfile")) {
			print FILE "$stamp\n";		# write locking stamp
			close FILE;
			umask($mask);				# restore old umask
			# Check lock
			open(FILE, $lockfile);
			chop($_ = <FILE>);			# read contents
			close FILE;
			last if $_ eq $stamp;		# lock is ok
		} else {
			umask($mask);				# restore old umask
			sleep($delay);				# busy: wait
		}
	}
	if ($max) {
		$result = 0;	# ok
	} else {
		$result = -1;	# could not lock
	}
	$result;			# return status
}

package lock;

# Return the name of the lockfile, given the file name to lock and the custom
# string provided by the user. The following macros are substituted:
#	%D: the file dir name
#   %f: the file name (full path)
#   %F: the file base name (last path component)
#   %p: the process's pid
#   %%: a plain % character
sub file {
	local($file, $_) = @_;
	s/%%/\01/g;				# Protect double percent signs
	s/%/\02/g;				# Protect against substitutions adding their own %
	s/\02f/$file/g;			# %f is the full path name
	s/\02D/&dir($file)/ge;	# %D is the dir name
	s/\02F/&base($file)/ge;	# %F is the base name
	s/\02p/$$/g;			# %p is the process's pid
	s/\02/%/g;				# All other % kept as-is
	s/\01/%/g;				# Restore escaped % signs
	$_;
}

# Return file basename (last path component)
sub base {
	local($file) = @_;
	local($base) = $file =~ m|^.*/(.*)|;
	$base;
}

# Return dirname
sub dir {
	local($file) = @_;
	local($dir) = $file =~ m|^(.*)/.*|;
	$dir;
}

package main;

