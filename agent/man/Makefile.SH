: Makefile.SH generated from Jmake.tmpl and Jmakefile [jmake 3.0 PL48]
: $X-Id: Jmake.tmpl,v 3.0.1.2 1995/01/11 14:50:21 ram Exp ram $

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
CURRENT=agent/man
DIR=`echo $CURRENT/ | sed -e 's/\.\///g'`
echo "Extracting ${DIR}Makefile (with variable substitutions)"

INSTALL=`echo $install | sed -e 's,\./i,\$(TOP)/i,'`
DATE=`date`

$spitshell >Makefile <<!GROK!THIS!
########################################################################
# Makefile generated from Makefile.SH on $DATE

SHELL = /bin/sh
JMAKE = jmake
TOP = ../..
CURRENT = $CURRENT
DIR = $DIR
INSTALL = $INSTALL

########################################################################
# Parameters set by Configure -- edit config.sh if changes are needed

CTAGS = ctags
L = $manext
MANSRC = $installmansrc
MAKE = make
MV = $mv
RM = $rm -f

########################################################################
# Automatically generated parameters -- do not edit

MANPAGE =  \$(MPAGES)

########################################################################
# New suffixes and associated building rules -- edit with care

.SUFFIXES: .SH .$manext

.SH.$manext:
	/bin/sh \$<

!GROK!THIS!
$spitshell >>Makefile <<'!NO!SUBS!'
########################################################################
# Jmake rules for building libraries, programs, scripts, and data files
# $X-Id: Jmake.rules,v 3.0.1.2 1995/01/11 14:49:55 ram Exp ram $

########################################################################
# Start of Jmakefile

# $X-Id: Jmakefile,v 3.0.1.1 1994/09/22 13:52:52 ram Exp ram $
#
#  Copyright (c) 1990-1993, Raphael Manfredi
#  
#  You may redistribute only under the terms of the Artistic License,
#  as specified in the README file that comes with the distribution.
#  You may reuse parts of this distribution only within the terms of
#  that same Artistic License; a copy of which may be found at the root
#  of the source tree for mailagent 3.0.
#
# $X-Log: Jmakefile,v $
# Revision 3.0.1.1  1994/09/22  13:52:52  ram
# patch12: new manual page for edusers
#
# Revision 3.0  1993/11/29  13:48:25  ram
# Baseline for mailagent 3.0 netwide release.
#

MPAGES = mailagent.$(L) maildist.$(L) maillist.$(L) mailhelp.$(L) \
	mailpatch.$(L) package.$(L) edusers.$(L)

all:: $(MPAGES)

local_realclean::
	$(RM) $(MPAGES)

install.man::
	@if test "$(MANSRC)"; then \
		case '${MFLAGS}' in *[i]*) set +e;; esac; \
		for file in $(MPAGES); do \
			(set -x; $(INSTALL) -c -m 444 $$file $(MANSRC)); \
		done; \
	else exit 0; fi

deinstall.man::
	@if test "$(MANSRC)"; then \
		case '${MFLAGS}' in *[i]*) set +e;; esac; \
		for file in $(MPAGES); do \
			(set -x; $(RM) $(MANSRC)/$$file); \
		done; \
	else exit 0; fi

########################################################################
# Common rules for all Makefiles -- do not edit

emptyrule::

clean: local_clean
realclean: local_realclean
clobber: local_clobber

local_clean::
	$(RM) core *~ *.o

local_realclean:: local_clean

local_clobber:: local_realclean
	$(RM) Makefile config.sh

Makefile.SH: Jmakefile
	-@if test -f $(TOP)/.package; then \
		if test -f Makefile.SH; then \
			echo "	$(RM) Makefile.SH~; $(MV) Makefile.SH Makefile.SH~"; \
			$(RM) Makefile.SH~; $(MV) Makefile.SH Makefile.SH~; \
		fi; \
		echo "	$(JMAKE) -DTOPDIR=$(TOP) -DCURDIR=$(CURRENT)" ; \
		$(JMAKE) -DTOPDIR=$(TOP) -DCURDIR=$(CURRENT) ; \
	else touch $@; exit 0; fi

Makefile: Makefile.SH
	/bin/sh Makefile.SH

tags::
	$(CTAGS) -w *.[ch]
	$(CTAGS) -xw *.[ch] > tags

local_clobber::
	$(RM) tags

########################################################################
# Empty rules for directories with no sub-directories -- do not edit

install::
	@echo "install in $(CURRENT) done."

deinstall::
	@echo "deinstall in $(CURRENT) done."

install.man::
	@echo "install.man in $(CURRENT) done."

deinstall.man::
	@echo "deinstall.man in $(CURRENT) done."

Makefiles::

Makefiles.SH::

!NO!SUBS!
chmod 644 Makefile
$eunicefix Makefile

