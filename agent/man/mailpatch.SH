case $CONFIG in
'')
	if test -f config.sh; then TOP=.;
	elif test -f ../config.sh; then TOP=..;
	elif test -f ../../config.sh; then TOP=../..;
	elif test -f ../../../config.sh; then TOP=../../..;
	elif test -f ../../../../config.sh; then TOP=../../../..;
	else
		echo "Can't find config.sh."; exit 1
	fi
	. $TOP/config.sh
	;;
esac
case "$0" in
*/*) cd `expr X$0 : 'X\(.*\)/'` ;;
esac
echo "Extracting agent/man/mailpatch.$manext (with variable substitutions)"
$rm -f mailpatch.$manext
$spitshell >mailpatch.$manext <<!GROK!THIS!
.so $mansrcexp/mailhelp.$manext
'''
''' $Id: mailpatch.SH,v 3.0.1.1 1995/08/07 15:53:32 ram Exp $
'''
''' Copyright (c) 1990-1993, Raphael Manfredi
''' 
''' You may redistribute only under the terms of the Artistic License,
''' as specified in the README file that comes with the distribution.
''' You may reuse parts of this distribution only within the terms of
''' that same Artistic License; a copy of which may be found at the root
''' of the source tree for mailagent 3.0.
'''
''' $Log: mailpatch.SH,v $
''' Revision 3.0.1.1  1995/08/07  15:53:32  ram
''' patch37: use mansrcexp on the .so line to get full expanded path
'''
''' Revision 3.0  1993/11/29  13:48:30  ram
''' Baseline for mailagent 3.0 netwide release.
'''
!GROK!THIS!
chmod 444 mailpatch.$manext
