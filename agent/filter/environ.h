/*

 ######  #    #  #    #     #    #####    ####   #    #          #    #
 #       ##   #  #    #     #    #    #  #    #  ##   #          #    #
 #####   # #  #  #    #     #    #    #  #    #  # #  #          ######
 #       #  # #  #    #     #    #####   #    #  #  # #   ###    #    #
 #       #   ##   #  #      #    #   #   #    #  #   ##   ###    #    #
 ######  #    #    ##       #    #    #   ####   #    #   ###    #    #

	Declarations for envrironment routines.
*/

/*
 * $Id: environ.h,v 3.0 1993/11/29 13:48:08 ram Exp $
 *
 *  Copyright (c) 1990-1993, Raphael Manfredi
 *  
 *  You may redistribute only under the terms of the Artistic License,
 *  as specified in the README file that comes with the distribution.
 *  You may reuse parts of this distribution only within the terms of
 *  that same Artistic License; a copy of which may be found at the root
 *  of the source tree for mailagent 3.0.
 *
 * $Log: environ.h,v $
 * Revision 3.0  1993/11/29  13:48:08  ram
 * Baseline for mailagent 3.0 netwide release.
 *
 */

#ifndef _environ_h_
#define _environ_h_

extern void print_env();			/* Print the environment */
extern void init_env();				/* Initializes the environment table */
extern char **make_env();			/* Make a new system environment */
extern int append_env();			/* Append value to environment */
extern int prepend_env();			/* Prepend value to environment */
extern int set_env();				/* Set environment value */

#endif
