# The SUBST command

# $Id: subst.t,v 3.0 1993/11/29 13:49:52 ram Exp $
#
#  Copyright (c) 1990-1993, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#  You may reuse parts of this distribution only within the terms of
#  that same Artistic License; a copy of which may be found at the root
#  of the source tree for mailagent 3.0.
#
# $Log: subst.t,v $
# Revision 3.0  1993/11/29 13:49:52  ram
# Baseline for mailagent 3.0 netwide release.
#

do '../pl/cmd.pl';
unlink 'output';

&add_header('X-Tag: subst');
`$cmd`;
$? == 0 || print "1\n";
-f "$user" && print "2\n";
-f 'output' || print "3\n";
chop ($output = `cat output 2>/dev/null`);
$output eq 'ram@eiffel.fr,melting ice technology?,melting ice technology?'
	|| print "4\n";

unlink 'mail', 'output';
print "0\n";

