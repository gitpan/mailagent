;# $Id: secure.pl,v 3.0.1.3 1995/03/21 12:57:42 ram Exp $
;#
;#  Copyright (c) 1990-1993, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: secure.pl,v $
;# Revision 3.0.1.3  1995/03/21  12:57:42  ram
;# patch35: symbolic directories are now correctly followed
;#
;# Revision 3.0.1.2  1994/10/04  17:55:19  ram
;# patch17: wrong stat command could cause errors when checking symlinks
;#
;# Revision 3.0.1.1  1994/09/22  14:38:04  ram
;# patch12: symbolic directories are now specially handled
;#
;# Revision 3.0  1993/11/29  13:49:16  ram
;# Baseline for mailagent 3.0 netwide release.
;#
;# Requires pl/cdir.pl to derive paths when following symbolic links.
;# 
# A file "secure" if it is owned by the user and not world writable. Some key
# file within the mailagent have to be kept secure or they might compromise the
# security of the user account. Additionally, for 'root' users or if the
# 'secure' parameter in the config file is set to ON, checks are made for
# group writable files and suspicious directory as well.
# Return true if the file is secure or missing, false otherwise.
sub file_secure {
	local($file, $type) = @_;	# File to be checked
	return 1 unless -e $file;	# Missing file considered secure
	if (-l $file) {				# File is a symbolic link
		&add_log("WARNING sensitive $type file $file is a symbolic link")
			if $loglvl > 5;
		return 0;		# Unsecure file
	}
	local($ST_MODE) = 2 + $[;	# Field st_mode from inode structure
	unless (-O _) {				# Reuse stat info from -e
		&add_log("WARNING you do not own $type file $file") if $loglvl > 5;
		return 0;		# Unsecure file
	}
	local($st_mode) = (stat(_))[$ST_MODE];
	if ($st_mode & $S_IWOTH) {
		&add_log("WARNING $type file is world writable!") if $loglvl > 5;
		return 0;		# Unsecure file
	}

	return 1 unless $cf'secure =~ /on/i || $< == 0;

	# Extra checks for secure mode (or if root user). We make sure the
	# file is not writable by group and then we conduct the same secure tests
	# on the directory itself
	if ($st_mode & $S_IWGRP) {
		&add_log("WARNING $type file is group writable!") if $loglvl > 5;
		return 0;		# Unsecure file
	}
	local($dir);		# directory where file is located
	$dir = '.' unless ($dir) = ($file =~ m|(.*)/.*|);
	unless (-O $dir) {
		&add_log("WARNING you do not own directory of $type file")
			if $loglvl > 5;
		return 0;		# Unsecure directory, therefore unsecure file
	}
	$st_mode = (stat(_))[$ST_MODE];
	return 0 unless &check_st_mode($dir, 1);

	# If linkdirs is OFF, we do not check further when faced with a symbolic
	# link to a directory.
	if (-l $dir && $cf'linkdirs !~ /^off/i && !&symdir_secure($dir, $type)) {
		&add_log("WARNING directory of $type file $file is an unsecure symlink")
			if $loglvl > 5;
		return 0;		# Unsecure directory
	}

	1;		# At last! File is secure...
}

# Is a symbolic link to a directory secure?
sub symdir_secure {
	local($dir, $type) = @_;
	if (&symdir_check($dir, 0)) {
		&add_log("symbolic directory $dir for $type file is secure")
			if $loglvl > 11;
		return 1;
	}
	0;	# Not secure
}

# A symbolic directory (that is a symlink pointing to a directory) is secure
# if and only if:
#   - its target is a symlink that recursively proves to be secure.
#   - the target lies in a non world-writable directory
#   - the final directory at the end of the symlink chain is not world-writable
#   - less than $MAX_LINKS levels of indirection are needed to reach a real dir
# Unfortunately, we cannot check for group writability here for the parent
# target directory since the target might lie in a system directory which may
# have a legitimate need to be read/write for root and wheel, for instance.
# The routine returns 1 if the file is secure, 0 otherwise.
sub symdir_check {
	local($dir, $level) = @_;	# Directory, indirection level
	return 0 if $level++ > $MAX_LINKS;
	local($ndir) = readlink($dir);
	unless (defined $ndir) {
		&add_log("SYSERR readlink: $!") if $loglvl;
		return 0;
	}
	$dir =~ s|(.*)/.*|$1|;		# Suppress link component (tail)
	$dir = &cdir($ndir, $dir);	# Follow symlink to get its final path target
	local($still_link) = -l $dir;
	unless (-d $dir || $still_link) {
		&add_log("ERROR inconsistency: $dir is a plain file?") if $loglvl;
		return 0;		# Reached a plain file while following links to a dir!
	}
	unless (-d "$dir/..") {
		&add_log("ERROR inconsistency: $dir/.. is not a directory?") if $loglvl;
		return 0;		# Reached a file hooked nowhere in the file system!
	}
	# Check parent directory
	local($ST_MODE) = 2 + $[;	# Field st_mode from inode structure
	$st_mode = (stat(_))[$ST_MODE];
	return 0 unless &check_st_mode("$dir/..", 0);
	# Recurse if still a symbolic link
	if ($still_link) {
		return 0 unless &symdir_check($dir, $level);
	} else {
		$st_mode = (stat($dir))[$ST_MODE];
		return 0 unless &check_st_mode($dir, 1);
	}
	1;	# Ok, link is secure
}

# Returns true if mode in $st_mode does not include world or group writable
# bits, false otherwise. This helps factorizing code used in both &file_secure
# and &symdir_check. Set $both to true if both world/group checks are desirable,
# false to get only world checks.
sub check_st_mode {
	local($dir, $both) = @_;
	if ($st_mode & $S_IWOTH) {
		&add_log("WARNING directory of $type file $dir is world writable!")
			if $loglvl > 5;
		return 0;		# Unsecure directory
	}
	return 1 unless $both;
	if ($st_mode & $S_IWGRP) {
		&add_log("WARNING directory of $type file $dir is group writable!")
			if $loglvl > 5;
		return 0;		# Unsecure directory
	}
	1;
}

