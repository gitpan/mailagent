# This tests mathching on list selectors like To or Newsgroups.

# $Id: list.t,v 3.0 1993/11/29 13:50:01 ram Exp $
#
#  Copyright (c) 1990-1993, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#  You may reuse parts of this distribution only within the terms of
#  that same Artistic License; a copy of which may be found at the root
#  of the source tree for mailagent 3.0.
#
# $Log: list.t,v $
# Revision 3.0  1993/11/29  13:50:01  ram
# Baseline for mailagent 3.0 netwide release.
#

do '../pl/filter.pl';

for ($i = 1; $i <= 8; $i++) {
	unlink "$user.$i";
}

&add_header('X-Tag: list');
`$cmd`;
$? == 0 || print "1\n";
-f "$user.1" || print "2\n";
unlink "$user.1";

&replace_header('To: uunet!eiffel.com!max, other@max.com');
`$cmd`;
$? == 0 || print "3\n";
-f "$user.2" || print "4\n";
unlink "$user.2";

&replace_header('To: root@eiffel.com (Super User), max <other@max.com>');
`$cmd`;
$? == 0 || print "5\n";
-f "$user.3" || print "6\n";
unlink "$user.3";

# Following is illeaal in RFC-822: should be "root@eiffel.com" <maxime>
&replace_header('To: riot@eiffel.com (Riot Manager), root@eiffel.com <maxime>');
`$cmd`;
$? == 0 || print "7\n";
-f "$user.4" || print "8\n";
unlink "$user.4";

&replace_header('To: other, me, riotintin@eiffel.com, and, so, on');
`$cmd`;
$? == 0 || print "9\n";
-f "$user.5" || print "10\n";
unlink "$user.5";

&replace_header('To: other, me, chariot@eiffel.com, and, so, on');
`$cmd`;
$? == 0 || print "11\n";
-f "$user.6" || print "12\n";
unlink "$user.6";

&replace_header('To: other, me, abricot@eiffel.com, and, so, on');
&add_header('Newsgroups: comp.lang.perl, news.groups, news.lists');
`$cmd`;
$? == 0 || print "13\n";
-f "$user.7" || print "14\n";
unlink "$user.7";

&replace_header('Newsgroups: comp.lang.perl, news.groups, news.answers');
`$cmd`;
$? == 0 || print "15\n";
-f "$user.8" || print "16\n";
unlink "$user.8";

unlink 'mail';
print "0\n";
