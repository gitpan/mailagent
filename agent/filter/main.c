/*

 #    #    ##       #    #    #           ####
 ##  ##   #  #      #    ##   #          #    #
 # ## #  #    #     #    # #  #          #
 #    #  ######     #    #  # #   ###    #
 #    #  #    #     #    #   ##   ###    #    #
 #    #  #    #     #    #    #   ###     ####

	The main entry point.
*/

/*
 * $Id: main.c,v 3.0.1.4 1997/01/07 18:26:49 ram Exp $
 *
 *  Copyright (c) 1990-1993, Raphael Manfredi
 *  
 *  You may redistribute only under the terms of the Artistic License,
 *  as specified in the README file that comes with the distribution.
 *  You may reuse parts of this distribution only within the terms of
 *  that same Artistic License; a copy of which may be found at the root
 *  of the source tree for mailagent 3.0.
 *
 * $Log: main.c,v $
 * Revision 3.0.1.4  1997/01/07  18:26:49  ram
 * patch52: don't use my_exit() when printing version number
 *
 * Revision 3.0.1.3  1996/12/24  13:58:44  ram
 * patch45: use more portable real uid/gid setting
 *
 * Revision 3.0.1.2  1995/08/31  16:19:51  ram
 * patch42: now uses say() to print messages onto stderr
 *
 * Revision 3.0.1.1  1995/01/03  17:55:44  ram
 * patch24: added a -V option to print out the version and patchlevel
 *
 * Revision 3.0  1993/11/29  13:48:15  ram
 * Baseline for mailagent 3.0 netwide release.
 *
 */

#include "config.h"
#include "portable.h"

#ifdef I_STRING
#include <string.h>
#else
#include <strings.h>
#endif

#include <stdio.h>
#include <signal.h>
#include <sys/types.h>
#include <errno.h>
#include "logfile.h"
#include "io.h"
#include "hash.h"
#include "msg.h"
#include "parser.h"
#include "sysexits.h"
#include "lock.h"
#include "confmagic.h"
#include "patchlevel.h"

#define MAX_STRING	2048	/* Maximum string length */

private Signal_t handler();	/* Signal handler */
private void set_signal();	/* Set up the signal handler */
private int set_real_uid();	/* Reset real uid */
private int set_real_gid();	/* Reset real gid */

extern void env_home();		/* Only for tests */
extern int errno;

public void main(argc, argv, envp)
int argc;
char **argv;
char **envp;
{
	/* This is the main entry point for the mail filter */

	char *value;						/* Symbol value */
	int euid, uid;						/* Current effective and real uid */
	int egid, gid;						/* Effective and real gid */

	/* Compute program name, removing any leading path to keep only the name
	 * of the executable file.
	 */
	progname = rindex(argv[0], '/');	/* Only last name if '/' found */
	if (progname++ == (char *) 0)		/* There were no '/' */
		progname = argv[0];				/* This must be the filename then */
	progpid = getpid();					/* Program's PID */

	/* Security precautions. Look who we are and who we pretend to be */
	uid = getuid();
	gid = getgid();
	euid = geteuid();
	egid = getegid();

	/* The '-t' option means we are in test mode: set the home directory by
	 * using the environment HOME variable, so that we may provide our own
	 * configuration file elsewhere. Of course, this cannot be used if the
	 * filter is setuid and invoked by an uid different than the owner of the
	 * filter program.
	 *
	 * The '-V' option prints out the version and patchlevel, for sanity
	 * checks (to make sure the latest filter is installed, for instance).
	 */
	if (argc > 1) {
		if (0 == strcmp(argv[1], "-t")) {
			if (uid != euid || gid != egid) {
				say("no option allowed when set%s", uid != euid ? "uid":"gid");
				my_exit(EX_USAGE);
			}
			env_home();					/* Get HOME from environment */
		} else if (0 == strcmp(argv[1], "-V")) {
			printf("filter %.1f PL%d\n", VERSION, PATCHLEVEL);
			exit(EX_OK);
		}
	}

	set_signal();						/* Set up signal handler */
	read_conf(argv[0], ".mailagent");	/* Read configuration file */

	add_log(11, "starting processing");

	/* We'll be invoking a perl script with the -S switch, and perl will not
	 * allow us to do that if it detects "setuidness". Some sendmail programs
	 * are broken and do not reset the uid/gid correctly when they process
	 * their queue. This is why it is important to set the setuid and setgid
	 * bits on the filter program.
	 */

	/* Make sure our gid matches the effective gid */
	if (egid != gid && -1 == set_real_gid(egid)) {
		add_log(1, "SYSERR setgid: %m (%e)");
		add_log(4, "WARNING cannot set GID to %d, continuing as %d", egid, gid);
	} else if (egid != gid)
		add_log(6, "NOTICE reset GID from %d to %d", gid, egid);

	/* Make sure our uid matches the effective uid */
	if (euid != uid && -1 == set_real_uid(euid)) {
		add_log(1, "SYSERR setuid: %m (%e)");
		add_log(4, "WARNING cannot set UID to %d, continuing as %d", euid, uid);
	} else if (euid != uid)
		add_log(6, "NOTICE reset UID from %d to %d", uid, euid);

	value = ht_value(&symtab, "queue");		/* Fetch queue location */
	if (value == (char *) 0)
		fatal("queue directory not defined");

	set_env_vars(envp);						/* Set environment variables */
	process();								/* Process mail */

	my_exit(EX_OK);		/* We did it */
}

private int set_real_uid(ruid)
int ruid;
{
#ifdef HAS_SETRUID
	return setruid(ruid);
#endif
	return setuid(ruid);
}

private int set_real_gid(rgid)
int rgid;
{
#ifdef HAS_SETRGID
	return setrgid(rgid);
#endif
	return setgid(rgid);
}

private void set_signal()
{
	/* Set up the signal handler */

#ifdef SIGHUP
	signal(SIGHUP, handler);
#endif
#ifdef SIGINT
	signal(SIGINT, handler);
#endif
#ifdef SIGQUIT
	signal(SIGQUIT, handler);
#endif
#ifdef SIGTERM
	signal(SIGTERM, handler);
#endif
}

private Signal_t handler(sig)
int sig;
{
	/* A signal was caught */

	release_lock();					/* Release lock file if necessary */
	fatal("caught signal #%d", sig);
}

