;# $Id: period.pl,v 3.0 1993/11/29 13:49:05 ram Exp $
;#
;#  Copyright (c) 1990-1993, Raphael Manfredi
;#  
;#  You may redistribute only under the terms of the Artistic License,
;#  as specified in the README file that comes with the distribution.
;#  You may reuse parts of this distribution only within the terms of
;#  that same Artistic License; a copy of which may be found at the root
;#  of the source tree for mailagent 3.0.
;#
;# $Log: period.pl,v $
;# Revision 3.0  1993/11/29  13:49:05  ram
;# Baseline for mailagent 3.0 netwide release.
;#
;# 
# Compute the number of seconds in the period. An atomic period is a digit
# possibly followed by a modifier. The default modifier is 'd'.
# Here are the available modifiers (case is significant):
#  m  minute
#  h  hour
#  d  day
#  w  week
#  M  month (30 days of 24 hours)
#  y  year
sub seconds_in_period {
	local($_) = @_;				# The string to parse
	s|^(\d+)||;
	local ($number) = int($1);	# Number of elementary periods
	$_ = 'd' unless /^\s*\w$/;	# Period modifier (defaults to day)
	local($sec);				# Number of seconds in an atomic period
	if ($_ eq 'm') {
		$sec = 60;				# One minute = 60 seconds
	} elsif ($_ eq 'h') {
		$sec = 3600;			# One hour = 3600 seconds
	} elsif ($_ eq 'd') {
		$sec = 86400;			# One day = 24 hours
	} elsif ($_ eq 'w') {
		$sec = 604800;			# One week = 7 days
	} elsif ($_ eq 'M') {
		$sec = 2592000;			# One month = 30 days
	} elsif ($_ eq 'y') {
		$sec = 31536000;		# One year = 365 days
	} else {
		$sec = 86400;			# Unrecognized: defaults to one day
	}
	$number * $sec;				# Number of seconds in the period
}

