/*

    #     ####            ####
    #    #    #          #    #
    #    #    #          #
    #    #    #   ###    #
    #    #    #   ###    #    #
    #     ####    ###     ####

	I/O routines.
*/

/*
 * $Id: io.c,v 3.0.1.8 1995/08/31 16:19:17 ram Exp $
 *
 *  Copyright (c) 1990-1993, Raphael Manfredi
 *  
 *  You may redistribute only under the terms of the Artistic License,
 *  as specified in the README file that comes with the distribution.
 *  You may reuse parts of this distribution only within the terms of
 *  that same Artistic License; a copy of which may be found at the root
 *  of the source tree for mailagent 3.0.
 *
 * $Log: io.c,v $
 * Revision 3.0.1.8  1995/08/31  16:19:17  ram
 * patch42: new routine write_fd() to write mail onto an opened file
 * patch42: write_file() now relies on new write_fd() to do its main job
 * patch42: read_stdin() was made a once routine
 * patch42: emergency_save() now attempts to read mail if not done already
 * patch42: emergency_save() will dump message on stdout as a fall back
 *
 * Revision 3.0.1.7  1995/08/07  17:23:26  ram
 * patch41: forgot to return value in agent_lockfile()
 *
 * Revision 3.0.1.6  1995/08/07  16:09:03  ram
 * patch37: avoid forking of a new mailagent if one is sitting in background
 * patch37: added support for locking on filesystems with short filenames
 *
 * Revision 3.0.1.5  1995/03/21  12:54:19  ram
 * patch35: now relies on USE_WIFSTAT to use WIFEXITED() and friends
 *
 * Revision 3.0.1.4  1995/02/03  17:55:55  ram
 * patch30: avoid closing stdio files if not connected to a tty
 *
 * Revision 3.0.1.3  1994/10/04  17:25:54  ram
 * patch17: now detect and avoid possible queue filename conflicts
 *
 * Revision 3.0.1.2  1994/07/01  14:52:04  ram
 * patch8: now honours the queuewait config variable when present
 *
 * Revision 3.0.1.1  1994/01/26  09:27:13  ram
 * patch5: now only try to include <sys/fcntl.h> when hope is lost
 * patch5: filter will now put itself in daemon state while waiting
 *
 * Revision 3.0  1993/11/29  13:48:10  ram
 * Baseline for mailagent 3.0 netwide release.
 *
 */

#include "config.h"
#include "portable.h"
#include <sys/types.h>
#include "hash.h"
#include "parser.h"
#include "lock.h"
#include "logfile.h"
#include "environ.h"
#include "sysexits.h"
#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>

#ifdef I_SYS_WAIT
#include <sys/wait.h>
#endif

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

#ifdef I_STRING
#include <string.h>
#else
#include <strings.h>
#endif

#ifdef I_SYS_IOCTL
#include <sys/ioctl.h>
#endif

/*
 * The following should be defined in <sys/stat.h>.
 */
#ifndef S_IFMT
#define S_IFMT	0170000		/* Type of file */
#endif
#ifndef S_IFCHR
#define S_IFCHR	0020000		/* Character special (ttys fall into that) */
#endif
#ifndef S_ISCHR
#define S_ISCHR(m)	(((m) & S_IFMT) == S_IFCHR)
#endif

#include "confmagic.h"

#define BUFSIZE		1024			/* Amount of bytes read in a single call */
#define CHUNK		(10 * BUFSIZE)	/* Granularity of pool */
#define MAX_STRING	2048			/* Maximum string's length */
#define MAX_TRYS	1024			/* Maximum attempts for unique queue file */
#define QUEUE_WAIT	60				/* Default waiting time in queue */
#define AGENT_WAIT	"agent.wait"	/* File listing out-of-the-queue mails */
#define DEBUG_LOG	12				/* Lowest debugging log level */
#ifdef FLEXFILENAMES
#define AGENT_LOCK	"perl.lock"		/* Lock file used by mailagent */
#else
#define AGENT_LOCK	"perl!"			/* Same as above, if filename length < 14 */
#endif

/* The following array of stdio streams is used by close_tty() */
private FILE *stream_by_fd[] = {
	stdin,		/* file descriptor 0 */
	stdout,		/* ... 1 */
	stderr,		/* ... 2 */
};
#define STDIO_FDS	(sizeof(stream_by_fd) / sizeof(FILE *))

private char *agent_lockfile();	/* Name of the mailagent lock */
private void pool_realloc();	/* Extend pool zone */
private int get_lock();			/* Attempt to get a lockfile */
private void release_agent();	/* Remove mailagent's lock if needed */
private int process_mail();		/* Process mail by feeding the mailagent */
private void queue_mail();		/* Queue mail for delayed processing */
private char *write_file();		/* Write mail on disk */
private int write_fd();			/* Write mail onto file descriptor */
private char *save_file();		/* Emergency saving into a file */
private void goto_daemon();		/* Disassociate process from tty */

private char *mail = (char *) 0;	/* Where mail is stored */
private int len;					/* Mail length in bytes */
private int queued = 0;				/* True when mail queued safely */

extern int errno;				/* System call error status */
extern char *malloc();			/* Memory allocation */
extern char *realloc();			/* Re-allocation of memory pool */
extern char *logname();			/* User's login name */
extern int loglvl;				/* Logging level */

private void read_stdin()
{
	/* Read the whole stdandard input into memory and return a pointer to its
	 * location in memory. Any I/O error is fatal. Set the length of the
	 * data read into 'len'.
	 *
	 * This routine may be called from two distinct places, but should only
	 * run once, for obvious reasons...
	 */

	int size;					/* Current size of memory pool */
	int amount = 0;				/* Total amount of data read */
	int n;						/* Bytes read by last system call */
	char *pool;					/* Where input is stored */
	char buf[BUFSIZE];
	static int done = 0;		/* Ensure routine is run once only */

	if (done++) return;

	size = CHUNK;
	pool = malloc(size);
	if (pool == (char *) 0)
		fatal("out of memory");

	add_log(19, "reading mail");

	while (n = read(0, buf, BUFSIZE)) {
		if (n == -1) {
			add_log(1, "SYSERR read: %m (%e)");
			fatal("I/O error while reading mail");
		}
		if (size - amount < n)				/* Pool not big enough */
			pool_realloc(&pool, &size);		/* Resize it or fail */
		bcopy(buf, pool + amount, n);		/* Copy read bytes */
		amount += n;						/* Update amount of bytes read */
	}

	len = amount;				/* Indicate how many bytes where read */

	add_log(16, "got mail (%d bytes)", amount);

	mail = pool;				/* Where mail is stored */
}

public void process()
{
	char *queue;						/* Location of mailagent's queue */

	(void) umask(077);					/* Files we create are private ones */

	queue = ht_value(&symtab, "queue");	/* Fetch queue location */
	if (queue == (char *) 0)
		fatal("queue directory not defined");

	read_stdin();						/* Read mail */
	(void) get_lock();					/* Get a lock file */
	queue_mail(queue);					/* Process also it locked */
	release_lock();						/* Release lock file if necessary */
}

public int was_queued()
{
	return queued;			/* Was mail queued? */
}

private int is_main()
{
	/* Test whether we are the main filter (i.e. whether or not we are
	 * entitled to launch a new mailagent process). This is the case when
	 * we were able to grab a filter lock, in which case is_locked() returns
	 * true.
	 *
	 * However, it is also possible a mailagent process put in the background
	 * be processing some mail, albeit the main filter that originally launched
	 * it disappeared. Therefore, we also check for an existing mailagent lock,
	 * when we are locked.
	 */

	char *agentlock;			/* Path of the mailagent lock file */
	struct stat buf;			/* Stat buffer */
	static int done = 0;
	static int result = 0;		/* Assume we're not the main filter */

	if (done)
		return result;
	done = 1;

	if (!is_locked())
		return 0;		/* We're not a main filter, one is already active */

	/*
	 * No filter lock held, we are a candidate for being a main filter!
	 */

	agentlock = agent_lockfile();
	if (-1 == stat(agentlock, &buf)) {
		if (errno != ENOENT) {
			add_log(1, "SYSERR stat: %m (%e)");
			add_log(2, "ERROR cannot stat %s", agentlock);
		}
		return result = 1;	/* No mailagent is currently active */
	}

	if (LOCK_OLD == check_lock(agentlock, "mailagent")) {
		release_agent();
		return result = 1;	/* Old lockfile removed, assume we're the main */
	}

	add_log(5, "NOTICE mailagent seems to be active in background");
	return 0;
}

private void pool_realloc(pool, size)
char **pool;
int *size;
{
	/* Make more room in pool and update parameters accordingly */

	char *cpool = *pool;	/* Current location */
	int csize = *size;		/* Current size */

	csize += CHUNK;
	cpool = realloc(cpool, csize);
	if (cpool == (char *) 0)
		fatal("out of memory");
	*pool = cpool;
	*size = csize;
}

private int get_lock()
{
	/* Try to get a filter lock in the spool directory. Propagate the return
	 * status of filter_lock(): 0 for ok, -1 for failure.
	 */

	char *spool;						/* Location of spool directory */

	spool = ht_value(&symtab, "spool");	/* Fetch spool location */
	if (spool == (char *) 0)
		fatal("spool directory not defined");

	return filter_lock(spool);			/* Get a lock in spool directory */
}

private char *agent_lockfile()
{
	/* Once function used to compute the path of maialagent's lock file */

	char *spool;					/* Location of spool directory */
	static int done = 0;
	static char agentlock[MAX_STRING];	/* Result */

	if (done)
		return agentlock;

	done = 1;

	spool = ht_value(&symtab, "spool");	/* Fetch spool location */
	if (spool == (char *) 0)			/* Should not happen */
		spool = "";

	sprintf(agentlock, "%s/%s", spool, AGENT_LOCK);
	add_log(12, "mailagent lock in %s", agentlock);

	return agentlock;
}

private void release_agent()
{
	/* In case of abnormal failure, the mailagent may leave its lock file
	 * in the spool directory. Remove it if necessary.
	 */

	struct stat buf;				/* Stat buffer */
	char *agentlock = agent_lockfile();

	if (-1 == stat(agentlock, &buf))
		return;						/* Assume no lock file left behind */

	if (-1 == unlink(agentlock)) {
		add_log(1, "SYSERR unlink: %m (%e)");
		add_log(2, "ERROR could not remove mailagent's lock");
	} else
		add_log(5, "NOTICE removed mailagent's lock");
}

private void queue_mail(queue)
char *queue;				/* Location of the queue directory */
{
	char *where;			/* Where mail is stored */
	char real[MAX_STRING];	/* Real queue mail */
	char *base;				/* Pointer to base name */
	struct stat buf;		/* To make sure queued file remains */
	int try = 0;			/* Count attempts to find a unique queue name */

	where = write_file(queue, "Tm");
	if (where == (char *) 0) {
		add_log(1, "ERROR unable to queue mail");
		fatal("try again later");
	}

	/* If we have a lock, create a qm* file suitable for mailagent processing.
	 * Otherwise, create a fm* file and the mailagent will process it
	 * immediately. Because of my paranoid nature, we loop at least MAX_TRYS
	 * to get a unique queue filename (duplicates may happen if mail is
	 * delivered on distinct machines simultaneously with an NFS-mounted queue).
	 */

	for (;;) {
		sprintf(real, "%s/%s%d", queue, is_main() ? "qm":"fm", progpid+try);
		if (-1 == stat(real, &buf))		/* File does not exist */
			break;
		if (++try > MAX_TRYS)
			fatal("unable to find unique queue filename");
	}

	if (-1 == rename(where, real)) {
		add_log(1, "SYSERR rename: %m (%e)");
		add_log(2, "ERROR could not rename %s into %s", where, real);
		fatal("try again later");
	}

	/* Compute base name of queued mail */
	base = rindex(real, '/');
	if (base++ == (char *) 0)
		base = real;

	add_log(4, "QUEUED [%s] %d bytes", base, len);
	queued = 1;

	/* If we got a lock, then no mailagent is running and we may process the
	 * mail. Otherwise, do nothing. The mail will be processed by the currently
	 * active mailagent.
	 */

	if (!is_main())				/* Another mailagent is running */
		return;					/* Leave mail in queue */

	if (0 == process_mail(real)) {
		/* Mailagent may have simply queued the mail for itself by renaming
		 * it, so of course we would not be able to remove it. Hence the
		 * test for ENOENT to avoid error messages when the file does not
		 * exit any more.
		 */
		if (-1 == unlink(real) && errno != ENOENT) {
			add_log(1, "SYSERR unlink: %m (%e)");
			add_log(2, "ERROR could not remove queued mail");
		}
		return;
	}
	/* Paranoia: make sure the queued mail is still there */
	if (-1 == stat(real, &buf)) {
		queued = 0;			/* Or emergency_save() would not do anything */
		add_log(1, "SYSERR stat: %m (%e)");
		add_log(1, "ERROR queue file [%s] vanished", base);
		if (-1 == emergency_save())
			add_log(1, "ERROR mail probably lost");
	} else {
		add_log(4, "WARNING mailagent failed, [%s] left in queue", base);
		release_agent();	/* Remove mailagent's lock file if needed */
	}
}

private int process_mail(location)
char *location;
{
	/* Process mail held in 'location' by invoking the mailagent on it. If the
	 * command fails, return -1. Otherwise, return 0;
	 * Note that we will exit if the first fork is not possible, but that is
	 * harmless, because we know the mail was safely queued, otherwise we would
	 * not be here trying to make the mailagent process it.
	 */
	
	char **envp;			/* Environment pointer */
#ifdef UNION_WAIT
	union wait status;		/* Waiting status */
#else
	int status;				/* Status from command */
#endif
	int xstat;				/* The exit status value */
	int pid;				/* Pid of our children */
	int res;				/* Result from wait */
	int delay;				/* Delay in seconds before invoking mailagent */

	if (loglvl <= 20) {		/* Loggging level higher than 20 is for tests */
		pid = fork();
		if (pid == -1) {	/* Resources busy, most probably */
			release_lock();
			add_log(1, "SYSERR fork: %m (%e)");
			add_log(6, "NOTICE exiting to save resources");
			exit(EX_OK);	/* Exiting will also release sendmail process */
		} else if (pid != 0)
			exit(EX_OK);	/* Release waiting sendmail */
		else
			goto_daemon();	/* Remaining child is to disassociate from tty */
	}

	/*
	 * Compute waiting delay, defaults to QUEUE_WAIT seconds if not defined.
	 */

	delay = get_confval("queuewait", CF_DEFAULT, QUEUE_WAIT);

	/* Now hopefully we detached ourselves from sendmail, which thinks the mail
	 * has been delivered. Not yet, but close. Simply wait a little in case
	 * more mail is comming. This process is going to remain alive while the
	 * mailagent is running so as to trap any weird exit status. But the size
	 * of the perl process (with script compiled) is about 1650K on my MIPS,
	 * so the more we delay the invocation, the better.
	 */

	if (loglvl < DEBUG_LOG)	/* Higher logging level reserverd for debugging */
		sleep(delay);		/* Delay invocation of mailagent */
	progpid = getpid();		/* This may be the child (if fork succeded) */
	envp = make_env();		/* Build new environment */

	pid = vfork();			/* Virtual fork this time... */
	if (pid == -1) {
		add_log(1, "SYSERR vfork: %m (%e)");
		add_log(1, "ERROR cannot run mailagent");
		return -1;
	}

	if (pid == 0) {			/* This is the child */
		execle(PERLPATH, "perl", "-S", "mailagent", location, (char *) 0, envp);
		add_log(1, "SYSERR execle: %m (%e)");
		add_log(1, "ERROR cannot run perl to start mailagent");
		exit(EX_UNAVAILABLE);
	} else {				/* Parent process */
		while (pid != (res = wait(&status)))
			if (res == -1) {
				add_log(1, "SYSERR wait: %m (%e)");
				return -1;
			}

#ifdef USE_WIFSTAT
		if (WIFEXITED(status)) {			/* Exited normally */
			xstat = WEXITSTATUS(status);
			if (xstat != 0) {
				add_log(3, "ERROR mailagent returned status %d", xstat);
				return -1;
			}
		} else if (WIFSIGNALED(status)) {	/* Signal received */
			xstat = WTERMSIG(status);
			add_log(3, "ERROR mailagent terminated by signal %d", xstat);
			return -1;
		} else if (WIFSTOPPED(status)) {	/* Process stopped */
			xstat = WSTOPSIG(status);
			add_log(3, "WARNING mailagent stopped by signal %d", xstat);
			add_log(6, "NOTICE terminating mailagent, pid %d", pid);
			if (-1 == kill(pid, 15))
				add_log(1, "SYSERR kill: %m (%e)");
			return -1;
		} else
			add_log(1, "BUG please report bug 'posix-wait' to author");
#else
#ifdef UNION_WAIT
		xstat = status.w_status;
#else
		xstat = status;
#endif
		if ((xstat & 0xff) == 0177) {		/* Process stopped */
			xstat >>= 8;
			add_log(3, "WARNING mailagent stopped by signal %d", xstat);
			add_log(6, "NOTICE terminating mailagent, pid %d", pid);
			if (-1 == kill(pid, 15))
				add_log(1, "SYSERR kill: %m (%e)");
			return -1;
		} else if ((xstat & 0xff) != 0) {	/* Signal received */
			xstat &= 0xff;
			if (xstat & 0200) {				/* Dumped a core ? */
				xstat &= 0177;
				add_log(3, "ERROR mailagent dumped core on signal %d", xstat);
			} else
				add_log(3, "ERROR mailagent terminated by signal %d", xstat);
			return -1;
		} else {
			xstat >>= 8;
			if (xstat != 0) {
				add_log(3, "ERROR mailagent returned status %d", xstat);
				return -1;
			}
		}
#endif
	}
	
	add_log(19, "mailagent ok");

	return 0;
}

public int emergency_save()
{
	/* Save mail in emeregency files and add the path to the agent.wait file,
	 * so that the mailagent knows where to look when processing its queue.
	 * Return -1 if the mail was not sucessfully saved, 0 otherwise.
	 */

	char *where;			/* Where file was stored (static data) */
	char *home = homedir();	/* Location of the home directory */
	char path[MAX_STRING];	/* Location of the AGENT_WAIT file */
	char *queue;			/* Location of the queue directory */
	char *emergdir;			/* Emergency directory */
	int fd;					/* File descriptor to write in AGENT_WAIT */
	int size;				/* Length of 'where' string */

	/*
	 * It is possible that we come here due to a configuration error, for
	 * instance, and that we had not a chance to read our standard input
	 * yet. So do that now.
	 *
	 * Thanks to Rosina Bignall <bigna@leopard.cs.byu.edu> for finding
	 * this hole at her depend ;-)
	 */

	read_stdin();		/* Read mail if not already done yet */

	if (mail == (char *) 0) {
		say("mail not read, cannot dump");
		return -1;	/* Failed */
	}

	if (queued) {
		add_log(6, "NOTICE mail was safely queued");
		return 0;
	}

	emergdir = ht_value(&symtab, "emergdir");
	if ((emergdir != (char *) 0) && (char *) 0 != (where = save_file(emergdir)))
		goto ok;
	if ((home != (char *) 0) && (char *) 0 != (where = save_file(home)))
		goto ok;
	if (where = save_file("/usr/spool/uucppublic"))
		goto ok;
	if (where = save_file("/var/spool/uucppublic"))
		goto ok;
	if (where = save_file("/usr/tmp"))
		goto ok;
	if (where = save_file("/var/tmp"))
		goto ok;
	if (where = save_file("/tmp"))
		goto ok;

	/*
	 * Attempt dumping on stdout, as a fall back.
	 */

	say("dumping mail on stdout...");
	fflush(stderr);		/* In case they did >file 2>&1 */

	if (-1 != write_fd(1, "stdout")) {
		char *logmsg = "DUMPED to stdout";
		say(logmsg);
		add_log(6, logmsg);
		return 0;
	}

	say("unable to dump mail anywhere");
	return -1;	/* Failed */

ok:
	add_log(6, "DUMPED in %s", where);
	say("DUMPED in %s", where);

	/* Attempt to write path of saved mail in the AGENT_WAIT file */

	queue = ht_value(&symtab, "queue");
	if (queue == (char *) 0)
		return 0;
	sprintf(path, "%s/%s", queue, AGENT_WAIT);
	if (-1 == (fd = open(path, O_WRONLY | O_APPEND | O_CREAT, 0600))) {
		add_log(1, "SYSERR open: %m (%e)");
		add_log(6, "WARNING mailagent ignores where mail was left");
		return 0;
	}
	size = strlen(where);
	where[size + 1] = '\0';			/* Make room for trailing new-line */
	where[size] = '\n';
	if (-1 == write(fd, where, size + 1)) {
		add_log(1, "SYSERR write: %m (%e)");
		add_log(4, "ERROR could not append to %s", path);
		add_log(6, "WARNING mailagent ignores where mail was left");
	} else {
		where[size] = '\0';
		add_log(7, "NOTICE memorized %s", where);
		queued = 1;
	}
	close(fd);

	return 0;
}

private char *save_file(dir)
char *dir;				/* Where saving should be done (directory) */
{
	/* Attempt to write mail in directory 'dir' and return a pointer to static
	 * data holding the path name of the saved file if writing was ok.
	 * Otherwise, return a null pointer and unlink any already created file.
	 */

	struct stat buf;				/* Stat buffer */

	/* Make sure 'dir' entry exists, although we do not make sure it is really
	 * a directory. If 'dir' is in fact a file, then open() will loudly
	 * complain. We only want to avoid spurious log messages.
	 */

	if (-1 == stat(dir, &buf))		/* No entry in file system, probably */
		return (char *) 0;			/* Saving failed */

	return write_file(dir, logname());
}

private char *write_file(dir, template)
char *dir;				/* Where saving should be done (directory) */
char *template;			/* First part of the file name */
{
	/* Attempt to write mail in directory 'dir' and return a pointer to static
	 * data holding the path name of the saved file if writing was ok.
	 * Otherwise, return a null pointer and unlink any already created file.
	 * The file 'dir/template.$$' is created (where '$$' refers to the pid of
	 * the current process). As login name <= 8 and pid is <= 5, we are below
	 * the fatidic 14 chars limit for filenames.
	 */

	static char path[MAX_STRING];	/* Path name of created file */
	int fd;							/* File descriptor */
	int status;						/* Status from write_fd() */
	struct stat buf;				/* Stat buffer */

	sprintf(path, "%s/%s.%d", dir, template, progpid);

	if (-1 == (fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600))) {
		add_log(1, "SYSERR open: %m (%e)");
		add_log(2, "ERROR cannot create file %s", path);
		return (char *) 0;
	}

	status = write_fd(fd, path);		/* Write mail to file descriptor fd */
	close(fd);
	if (status == -1)					/* Something wrong happened */
		goto error;

	add_log(19, "mail in %s", path);	/* We did not detect any error so far */

	/* I don't really trust writes through NFS soft-mounted partitions, and I
	 * am also suspicious about hard-mounted ones. I could have opened the file
	 * with the O_SYNC flag, but the effect on NFS is not well defined either.
	 * So, let's just make sure the mail has been correctly written on the disk
	 * by comparing the file size and the orginal message size. If they differ,
	 * complain and return an error.
	 */

	if (-1 == stat(path, &buf))		/* No entry in file system, probably */
		return (char *) 0;			/* Saving failed */

	if (buf.st_size != len) {		/* Not written entirely */
		add_log(2, "ERROR mail truncated to %d bytes (had %d)",
			buf.st_size, len);
		goto error;					/* Remove file and report error */
	}

	return path;			/* Where mail was writen (static data) */

error:		/* Come here when a write error has been detected */

	if (-1 == unlink(path)) {
		add_log(1, "SYSERR unlink: %m (%e)");
		add_log(4, "WARNING leaving %s around", path);
	}

	return (char *) 0;
}

private int write_fd(fd, path)
int fd;					/* On which file descriptor saving occurs */
char *path;				/* Path name associated with that fd (may be NULL) */
{
	/* Write mail to the specified fd and return 0 if OK, -1 on error */

	register1 char *mailptr;		/* Pointer into mail buffer */
	register2 int length;			/* Number of bytes already written */
	register3 int amount;			/* Amount of bytes written by last call */
	register4 int n;				/* Result from the write system call */

	/* Write the mail onto fd. We do not call a single write on the mail buffer
	 * as in "write(fd, mail, len)" in case the mail length exceeds the maximum
	 * amount of bytes the system can atomically write.
	 */
	
	for (
		mailptr = mail, length = 0;
		length < len;
		mailptr += amount, length += amount
	) {
		amount = len - length;
		if (amount > BUFSIZ)		/* Do not write more than BUFSIZ */
			amount = BUFSIZ;
		n = write(fd, mailptr, amount);
		if (n == -1 || n != amount) {
			if (n == -1)
				add_log(1, "SYSERR write: %m (%e)");
			if (path != (char *) 0)
				add_log(2, "ERROR cannot write to file %s", path);
			return -1;	/* Failed */
		}
	}

	return 0;			/* OK */
}

private void close_tty(fd)
int fd;
{
	/* Close file if attached to a tty, otherwise do nothing. This is used
	 * by goto_daemon() to close file descriptors related to a tty to try
	 * to void any tty associations if other modern methods have failed.
	 * Unfortunately, we cannot just blindly close those descriptors in
	 * case output was redirected to some file...
	 */

	struct stat buf;				/* Stat buffer */

	if (-1 == fstat(fd, &buf)) {
		add_log(1, "SYSERR fstat: %m (%e)");
		add_log(6, "WARNING could not stat file descriptor #%d", fd);
		return;		/* Don't close it then */
	}

	/* Close file descriptor if attached to a tty. Otherwise, flush it if
	 * it is of the standard I/O kind, in case we did some buffered fprintf()
	 * on those.
	 */

	if (S_ISCHR(buf.st_mode)) {		/* File is a character device (tty) */
		if (fd < STDIO_FDS)
			(void) fclose(stream_by_fd[fd]);
		else
			(void) close(fd);
	} else if (fd < STDIO_FDS)
		(void) fflush(stream_by_fd[fd]);
}

private void goto_daemon()
{
	/* Make sure filter process goes into daemon state by releasing its
	 * control terminal and becoming the leader of a new process group
	 * or session.
	 *
	 * Harald Koch <chk@enfm.utcc.utoronto.ca> reported that this was
	 * needed when filter is invoked by zmailer's transport process.
	 * Otherwise the father waiting for his children does not get to see
	 * the EOF on the pipe, hanging forever.
	 */

	int fd;

#ifdef USE_TIOCNOTTY
	/*
	 * Errors from this open are discarded, since it is quite possible
	 * filter be launched without a controling tty, for instance when
	 * called via a daemon process like sendmail... :-)
	 */
	if ((fd = open("/dev/tty", 2)) >= 0) {
		if (-1 == ioctl(fd, TIOCNOTTY, (char *) 0)) {
			add_log(1, "SYSERR ioctl: %m (%e)");
			add_log(6, "WARNING could not release tty control");
		}
		(void) close(fd);
	}
#endif

	(void) close_tty(0);
	(void) close_tty(1);
	(void) close_tty(2);

	if (-1 == setsid()) {
		add_log(1, "SYSERR setsid: %m (%e)");
		add_log(6, "WARNING did not become session leader");
	}
}

#ifndef HAS_RENAME
public int rename(from, to)
char *from;				/* Original name */
char *to;				/* Target name */
{
	(void) unlink(to);
	if (-1 == link(from, to))
		return -1;
	if (-1 == unlink(from))
		return -1;

	return 0;
}
#endif

#ifndef HAS_SETSID
public int setsid()
{
	/* Set the process group ID and create a new session for the process.
	 * This is a pale imitation of the setsid() system call. Actually, we
	 * go into a lot more trouble here than is really needed...
	 */

	int error = 0;

#ifdef HAS_SETPGID
	/*
	 * setpgid() supersedes setpgrp() in OSF/1.
	 */
	error = setpgid(0 ,getpid());
#else
#ifdef HAS_SETPGRP
	/*
	 * Good old way to get a process group leader.
	 */
#ifdef USE_BSDPGRP
	error = setpgrp(0 ,getpid());	/* bsd way */
#else
	error = setpgrp();				/* usg way */
#endif
#endif
#endif

	/*
	 * When none of the above is defined, do nothing.
	 */

	return error;
}
#endif

