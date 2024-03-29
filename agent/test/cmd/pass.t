# The PASS command

# $Id: pass.t,v 3.0.1.2 1994/10/10 10:26:01 ram Exp $
#
#  Copyright (c) 1990-1993, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#  You may reuse parts of this distribution only within the terms of
#  that same Artistic License; a copy of which may be found at the root
#  of the source tree for mailagent 3.0.
#
# $Log: pass.t,v $
# Revision 3.0.1.2  1994/10/10  10:26:01  ram
# patch19: added various escapes in strings for perl5 support
#
# Revision 3.0.1.1  1994/04/25  15:25:22  ram
# patch7: now make sure From line escaping is correctly removed
#
# Revision 3.0  1993/11/29  13:49:37  ram
# Baseline for mailagent 3.0 netwide release.
#

do '../pl/misc.pl';
unlink 'output';

&add_header('X-Tag: pass');
&add_option("-o 'fromesc: OFF'");
open(MAIL, '>>mail');
print MAIL <<EOM;

>From test bug reported by Andy Seaborne <afs\@hplb.hpl.hp.com>
EOM
close MAIL;
`$cmd`;
$? == 0 || print "1\n";
-f 'output' || print "2\n";		# Where mail is saved
`grep -v X-Filter: output > comp`;
$? == 0 || print "3\n";
`grep -v and mail > ok`;
# SAVE adds extra final new-line, but the leading '>' from From is removed
(-s 'comp') == -s 'ok' || print "4\n";
-s 'comp' != -s 'output' || print "5\n";	# Casually check X-Filter was there
&get_log(6, 'output');
&check_log('^From test bug', 7) == 1 || print "8\n";

unlink 'output', 'mail', 'ok', 'comp';
print "0\n";
