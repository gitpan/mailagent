;# $Id: locate.pl,v 3.0 1993/11/29 13:48:56 ram Exp $
;#
;#  Copyright (c) 1990-1993, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: locate.pl,v $
;# Revision 3.0  1993/11/29  13:48:56  ram
;# Baseline for mailagent 3.0 netwide release.
;#
;# 
# If the file name does not start with a '/', then it is assumed to be found
# in the mailfilter directory if defined, maildir otherwise, and the home
# directory finally. The function returns the full path of the file derived
# from those rules but does not actually check whether file exists or not.
sub locate_file {
	local($filename) = @_;			# File we are trying to locate
	$filename =~ s/~/$cf'home/g;	# ~ substitution
	unless ($filename =~ m|^/|) {	# Do nothing if already a full path
		if (defined($XENV{'mailfilter'}) && $XENV{'mailfilter'} ne '') {
			$filename = $XENV{'mailfilter'} . "/$filename";
		} elsif (defined($XENV{'maildir'}) && $XENV{'maildir'} ne '') {
			$filename = $XENV{'maildir'} . "/$filename";
		} else {
			$filename = $cf'home . "/$filename";
		}
	}
	$filename =~ s/~/$cf'home/g;	# ~ substitution
	$filename;
}

