/*

 #        ####    ####   #    #           ####
 #       #    #  #    #  #   #           #    #
 #       #    #  #       ####            #
 #       #    #  #       #  #     ###    #
 #       #    #  #    #  #   #    ###    #    #
 ######   ####    ####   #    #   ###     ####

	Lock file handling.
*/

/*
 * $Id: lock.c,v 3.0.1.4 1995/08/07 16:10:04 ram Exp $
 *
 *  Copyright (c) 1990-1993, Raphael Manfredi
 *  
 *  You may redistribute only under the terms of the Artistic License,
 *  as specified in the README file that comes with the distribution.
 *  You may reuse parts of this distribution only within the terms of
 *  that same Artistic License; a copy of which may be found at the root
 *  of the source tree for mailagent 3.0.
 *
 * $Log: lock.c,v $
 * Revision 3.0.1.4  1995/08/07  16:10:04  ram
 * patch37: exported check_lock() for external mailagent lock checks in io.c
 * patch37: added support for locking on filesystems with short filenames
 *
 * Revision 3.0.1.3  1995/01/03  17:55:11  ram
 * patch24: now correctly includes <sys/fcntl.h> as a last option only
 *
 * Revision 3.0.1.2  1994/09/22  13:44:52  ram
 * patch12: typo fix to enable correct lockfile timeout printing
 *
 * Revision 3.0.1.1  1994/07/01  14:52:28  ram
 * patch8: now honours the lockhold config variable if present
 *
 * Revision 3.0  1993/11/29  13:48:12  ram
 * Baseline for mailagent 3.0 netwide release.
 *
 */

#include "config.h"
#include "portable.h"
#include "parser.h"
#include "lock.h"
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifdef I_FCNTL
#include <fcntl.h>
#endif
#ifdef I_SYS_FILE
#include <sys/file.h>
#endif

#ifndef I_FCNTL
#ifndef I_SYS_FILE
#include <sys/fcntl.h>	/* Try this one in last resort */
#endif
#endif

#include "confmagic.h"

#define MAX_STRING	2048		/* Max string length */
#define MAX_TIME	3600		/* One hour */

private char lockfile[MAX_STRING];		/* Location of lock file */
private int locked = 0;					/* Did we lock successfully? */

extern int errno;						/* System error status */
extern Time_t time();					/* Current time */

public int filter_lock(dir)
char *dir;						/* Where lockfile should be written */
{
	/* Note: this locking is not completly safe w.r.t. race conditions, but the
	 * mailagent will do its own locking checks in a rather safe way.
	 * Return 0 if locking succeeds, -1 otherwise.
	 */

	int fd;

	/*
	 * Be consistent with mailagent's behaviour: when flexible filenames are
	 * available, the locking extenstion is .lock. However, when filenames are
	 * limited in length, it is reduced to the single '!' character. Here,
	 * the name filter.lock is smaller than 14 characters anyway, so it would
	 * not matter much.
	 */
#ifdef FLEXFILENAMES
	sprintf(lockfile, "%s/filter.lock", dir);
#else
	sprintf(lockfile, "%s/filter!", dir);
#endif

	(void) check_lock(lockfile, "filter");
	if (-1 == (fd = open(lockfile, O_CREAT | O_EXCL, 0))) {
		if (errno != EEXIST)
			add_log(1, "SYSERR open: %m (%e)");
		return -1;
	}
	locked = 1;					/* We did lock successfully */
	close(fd);					/* Close dummy file descriptor */

	return 0;
}

public void release_lock()
{
	if (locked && -1 == unlink(lockfile)) {
		add_log(1, "SYSERR unlink: %m (%e)");
		add_log(4, "WARNING could not remove lockfile %s", lockfile);
	}
	locked = 0;
}

public int is_locked()
{
	return locked;			/* Do we have a lock file active or not? */
}

public int check_lock(file, name)
char *file;
char *name;		/* System name for which the lock is checked */
{
	/* Make sure the lock file is not older than MAX_TIME seconds, otherwise
	 * unlink it (something must have gone wrong). If the lockhold parameter
	 * is set in ~/.mailagent, use that instead for timeout.
	 *
	 * Returns LOCK_OK if lockfile was ok or missing, LOCK_ERR on error and
	 * LOCK_OLD if it was too old and got removed.
	 */

	struct stat buf;
	int hold;			/* Lockfile timeout */
	int ret = LOCK_OK;	/* Returned value */

	if (-1 == stat(file, &buf)) {		/* Stat failed */
		if (errno == ENOENT)			/* File does not exist */
			return LOCK_OK;
		add_log(1, "SYSERR stat: %m (%e)");
		add_log(2, "could not check lockfile %s", file);
		return LOCK_ERR;
	}

	/*
	 * Get lockhold if defined, or use hardwired MAX_TIME.
	 */

	hold = get_confval("lockhold", CF_DEFAULT, MAX_TIME);

	/*
	 * Break lock if older than 'hold' seconds, otherwise honour it.
	 */

	if (time((Time_t *) 0) - buf.st_mtime > hold) {
		if (-1 == unlink(lockfile)) {
			add_log(1, "SYSERR unlink: %m (%e)");
			add_log(4, "WARNING could not remove old lock %s", lockfile);
			ret = LOCK_ERR;
		} else {
			add_log(6, "UNLOCKED %s (lock older than %d seconds)", name, hold);
			ret = LOCK_OLD;		/* File was removed */
		}
	} else
		add_log(16, "lockfile for %s is recent (%d seconds or less)",
			name, hold);

	return ret;		/* Lock file ok, removed, or error status */
}

