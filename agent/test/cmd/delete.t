# Test DELETE command

# $Id: delete.t,v 3.0 1993/11/29 13:49:30 ram Exp $
#
#  Copyright (c) 1990-1993, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#  You may reuse parts of this distribution only within the terms of
#  that same Artistic License; a copy of which may be found at the root
#  of the source tree for mailagent 3.0.
#
# $Log: delete.t,v $
# Revision 3.0  1993/11/29  13:49:30  ram
# Baseline for mailagent 3.0 netwide release.
#

do '../pl/cmd.pl';

&add_header('X-Tag: delete');
`$cmd`;
$? == 0 || print "1\n";
-f "$user" && print "2\n";		# Mail deleted

unlink 'mail';
print "0\n";
