/*

 #####     ##    #####    ####   ######  #####           #    #
 #    #   #  #   #    #  #       #       #    #          #    #
 #    #  #    #  #    #   ####   #####   #    #          ######
 #####   ######  #####        #  #       #####    ###    #    #
 #       #    #  #   #   #    #  #       #   #    ###    #    #
 #       #    #  #    #   ####   ######  #    #   ###    #    #

	Configuration variable parsing routines.
*/

/*
 * $Id: parser.h,v 3.0.1.1 1994/07/01 14:54:06 ram Exp $
 *
 *  Copyright (c) 1990-1993, Raphael Manfredi
 *  
 *  You may redistribute only under the terms of the Artistic License,
 *  as specified in the README file that comes with the distribution.
 *  You may reuse parts of this distribution only within the terms of
 *  that same Artistic License; a copy of which may be found at the root
 *  of the source tree for mailagent 3.0.
 *
 * $Log: parser.h,v $
 * Revision 3.0.1.1  1994/07/01  14:54:06  ram
 * patch8: new routine get_confval to get integer config variables
 *
 * Revision 3.0  1993/11/29  13:48:19  ram
 * Baseline for mailagent 3.0 netwide release.
 *
 */

#ifndef _parser_h_
#define _parser_h_

extern struct htable symtab;		/* Symbol table */
extern void read_conf();			/* Read configuration file */
extern void set_env_vars();			/* Set correct environment variables */
extern char *homedir();				/* Location of the home directory */
extern int get_confval();			/* Get configuration value */

/*
 * Parameters for get_confval().
 */

#define CF_MANDATORY	0			/* Must be there, or fatal error */
#define CF_DEFAULT		1			/* Use default value if not there */

#endif

