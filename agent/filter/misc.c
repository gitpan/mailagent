/*

 #    #     #     ####    ####            ####
 ##  ##     #    #       #    #          #    #
 # ## #     #     ####   #               #
 #    #     #         #  #        ###    #
 #    #     #    #    #  #    #   ###    #    #
 #    #     #     ####    ####    ###     ####

	Miscellaneous routines.
*/

/*
 * $Id: misc.c,v 3.0.1.1 1994/09/22 13:45:30 ram Exp $
 *
 *  Copyright (c) 1990-1993, Raphael Manfredi
 *  
 *  You may redistribute only under the terms of the Artistic License,
 *  as specified in the README file that comes with the distribution.
 *  You may reuse parts of this distribution only within the terms of
 *  that same Artistic License; a copy of which may be found at the root
 *  of the source tree for mailagent 3.0.
 *
 * $Log: misc.c,v $
 * Revision 3.0.1.1  1994/09/22  13:45:30  ram
 * patch12: added fallback implementation for strcasecmp()
 *
 * Revision 3.0  1993/11/29  13:48:16  ram
 * Baseline for mailagent 3.0 netwide release.
 *
 */

#include "config.h"
#include "portable.h"
#include <ctype.h>
#include "confmagic.h"

extern char *malloc();				/* Memory allocation */

public char *strsave(string)
char *string;
{
	/* Save string somewhere in memory and return a pointer to the new string
	 * or NULL if there is not enough memory.
	 */

	char *new = malloc(strlen(string) + 1);		/* +1 for \0 */
	
	if (new == (char *) 0)
		fatal("no more memory to save strings");

	strcpy(new, string);
	return new;
}

#ifndef HAS_STRCASECMP
/*
 * This is a rather inefficient version of the strcasecmp() routine which
 * compares two strings in a case-independant manner. The libc routine uses
 * an array, which when indexed by character code, directly yields the lower
 * case version of that character. Here however, since the routine is only
 * used in a few places, we don't bother being as efficient.
 */
public int strcasecmp(s1, s2)
char *s1;
char *s2;
{
	char c1, c2;

	while (c1 = *s1++, c2 = *s2++, c1 && c2) {
		if (isupper(c1))
			c1 = tolower(c1);
		if (isupper(c2))
			c2 = tolower(c2);
		if (c1 != c2)
			break;			/* Strings are different */
	}

	return c1 - c2;			/* Will be 0 if both string ended */
}
#endif

