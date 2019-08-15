#include "config.h"
/* AIX requires this to be the first thing in the file.  */
#ifndef __GNUC__
# if HAVE_ALLOCA_H
#  include <alloca.h>
# else
#  ifdef _AIX
 #pragma alloca
#  else
#   ifndef alloca /* predefined by HP cc +Olibcalls */
char *alloca ();
#   endif
#  endif
# endif
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "libsmbclient.h"
#include "libauthSamba.h"
#include "config.h"

/* 
 * Ce fichier definit les fonctions d'interface avec libsmbclient.so 
 */

MODULE = Filesys::SmbClient    PACKAGE = Filesys::SmbClient
PROTOTYPES: ENABLE

SMBCCTX *
_init(user, password, workgroup, debug, use_nt_hash)
  char *user
  char *password  
  char* workgroup
  int debug
  int use_nt_hash
CODE:
/* 
 * Initialize things ... 
 */	
SMBCCTX *context;
context = smbc_new_context();
if (!context) {
  XSRETURN_UNDEF;
}
smbc_setDebug(context, 4); //4 gives a good level of trace.
set_fn(workgroup, user, password);
smbc_setFunctionAuthData(context, auth_fn);
smbc_setDebug(context, debug);
smbc_setOptionUseNTHash(context, use_nt_hash);
if (smbc_init_context(context) == 0) {
  smbc_free_context(context, 1); 
  XSRETURN_UNDEF;
} 
RETVAL = context; 
#ifdef VERBOSE
  fprintf(stderr, "! Filesys::SmbClient : "
	          "init %p context\n", context); 
#endif
OUTPUT:
  RETVAL


int
_shutdown( context, flag)
    SMBCCTX * context
    int flag
CODE:
    smbc_free_context(context, flag);
    RETVAL = 1;
OUTPUT:
    RETVAL

int
_set_flags(context, flag)
  SMBCCTX *context
  int flag
CODE:
/* 
 * Create directory fname
 *
 */
#ifdef HAVE_SMBCTXX_FLAG
    context->flags = flag;
#endif
#ifdef VERBOSE
  fprintf(stderr, "! Filesys::SmbClient : "
                  "_set_flags value %d\n", flag); 
#endif
  RETVAL = 1;
OUTPUT:
  RETVAL


int
_mkdir(context, fname, mode)
  SMBCCTX *context
  char *fname
  int mode
CODE:
/* 
 * Create directory fname
 *
 */
RETVAL = context->mkdir(context, fname, mode);
if (RETVAL < 0) {
  RETVAL=0;
#ifdef VERBOSE
  fprintf(stderr, "*** Error Filesys::SmbClient : "
	          "mkdir %s directory : %s\n", fname,strerror(errno)); 
#endif
}
else RETVAL = 1;
OUTPUT:
  RETVAL




int
_rmdir(context, fname)
  SMBCCTX *context
  char *fname
CODE:
/* 
 * Remove directory fname
 *
 */
RETVAL = context->rmdir(context, fname);
if (RETVAL < 0) {
  RETVAL = 0;
#ifdef VERBOSE
  fprintf(stderr, "*** Error Filesys::SmbClient : "
      	          "rmdir %s directory : %s\n", fname,strerror(errno));
#endif
} else RETVAL = 1;
OUTPUT:
  RETVAL



SMBCFILE *
_opendir(context, fname)
  SMBCCTX *context
  char *fname
CODE:
/* 
 * Open directory fname
 *
 */
  RETVAL = context->opendir(context, fname);
#ifdef VERBOSE
  fprintf(stderr, "! Filesys::SmbClient : _opendir: %d\n", RETVAL); 
#endif

  if (RETVAL < 0) { 
    RETVAL = 0;
#ifdef VERBOSE
    fprintf(stderr, "*** Error Filesys::SmbClient : "
                      "Error opendir %s : %s\n", fname, strerror(errno));
#endif
  }
OUTPUT:
  RETVAL




int
_closedir(context, fd)
  SMBCCTX *context
  SMBCFILE *fd
CODE:
/* 
 * Close file descriptor for directory fd
 *
 */
RETVAL = context->closedir(context, fd);
#ifdef VERBOSE
  if (RETVAL < 0) { 
    fprintf(stderr, "*** Error Filesys::SmbClient : "
                    "Closedir : %s\n", strerror(errno)); }
#endif
OUTPUT:
  RETVAL




void
_readdir(context, fd)
  SMBCCTX *context
  SMBCFILE *fd
PREINIT:
/* 
 * Read file descriptor for directory fd and return file type, name and comment
 *
 */
  struct smbc_dirent * dirp;
PPCODE:
#ifdef VERBOSE
  fprintf(stderr, "! Filesys::SmbClient : _readdir: %d\n", fd); 
#endif
// Fix for rt#12221 : macro "readdir" passed 2 arguments, but takes just 1
// Seems only work on linux, not solaris
// Already defined in usr/lib/perl/5.8/CORE/reentr.inc:1322:# define readdir(a)
#if !(defined (__SVR4) && defined (__sun)) && !defined(_AIX)
#undef readdir
#endif
  dirp = (struct smbc_dirent *)context->readdir(context, fd);
  if (dirp) {
    XPUSHs(sv_2mortal(newSVnv(dirp->smbc_type)));
/*
 * 	  original code here produces strings which include NULL as last char
 *        with samba 3. Reported by dpavlin at rot13.org
 *
    XPUSHs(sv_2mortal((SV*)newSVpv(dirp->name, dirp->namelen)));
    XPUSHs(sv_2mortal((SV*)newSVpv(dirp->comment, dirp->commentlen)));
*/
    XPUSHs(sv_2mortal((SV*)newSVpv(dirp->name, strlen(dirp->name))));
    XPUSHs(sv_2mortal((SV*)newSVpv(dirp->comment, strlen(dirp->comment))));
}



void
_stat(context, fname)
  SMBCCTX *context
  char *fname
PREINIT:
/* 
 * _stat(fname) : Get information about a file or directory.
 *
 */
  int i;
  struct stat buf;
PPCODE:
  i = context->stat(context, fname, &buf);
  if (i == 0) {
    XPUSHs(sv_2mortal(newSVnv(buf.st_dev)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_ino)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_mode)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_nlink)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_uid)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_gid)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_rdev)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_size)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_blksize)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_blocks)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_atime)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_mtime)));
    XPUSHs(sv_2mortal(newSVnv(buf.st_ctime)));
} else {
#ifdef VERBOSE
  fprintf(stderr, "! Filesys::SmbClient : Stat: %s\n", strerror(errno)); 
#endif
    XPUSHs(sv_2mortal(newSVnv(0)));
}



void
_fstat(context, fd)
  SMBCCTX *context
  SMBCFILE *fd
PREINIT:
/* 
 * Get information about a file or directory via a file descriptor.
 *
 */
  int i;
  struct stat buf;
PPCODE:
i = context->fstat(context, fd, &buf);
if (i == 0) {
  XPUSHs(sv_2mortal(newSVnv(buf.st_dev)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_ino)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_mode)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_nlink)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_uid)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_gid)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_rdev)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_size)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_blksize)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_blocks)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_atime)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_mtime)));
  XPUSHs(sv_2mortal(newSVnv(buf.st_ctime)));
} else {
  XPUSHs(sv_2mortal(newSVnv(errno)));
}




int
_rename(context, oname, nname)
  SMBCCTX *context
  char *oname
  char *nname
CODE:
/* 
 * Rename old file oname in nname
 *
 */
RETVAL = context->rename(context, oname, context, nname);
if (RETVAL < 0) { 
  RETVAL = 0;
#ifdef VERBOSE	
  fprintf(stderr, "*** Error Filesys::SmbClient : "
 		  "Rename %s in %s : %s\n", oname, nname, strerror(errno)); 
#endif
} else {
  RETVAL = 1;
}
OUTPUT:
  RETVAL


SMBCFILE*
_open(context, fname, mode)
  SMBCCTX *context
  char *fname
  int mode
PREINIT:
/* 
 * Open file fname with perm mode
 *
 */	
  int flags; 
  int seek_end = 0;
CODE:
  /* Mode >> */
  if ( (*fname != '\0') && (*(fname+1) != '\0') &&
     (*fname == '>') && (*(fname+1) == '>')) { 
    flags = O_WRONLY | O_CREAT | O_APPEND; 
    fname+=2; 
    seek_end = 1;
#ifdef VERBOSE
fprintf(stderr, "! Filesys::SmbClient :"
	        "Open append %s : %s\n", fname); 
#endif
  /* Mode > */
  } else if ( (*fname != '\0') && (*fname == '>')) {
    flags = O_WRONLY | O_CREAT | O_TRUNC; fname++; 
  /* Mode < */
  } else if ( (*fname != '\0') && (*fname == '<')) {
    flags = O_RDONLY; fname++; 
  /* Mod < */
  } else flags =  O_RDONLY;
RETVAL = context->open(context, fname, flags, mode);	
#ifdef VERBOSE
  fprintf(stderr, "! Filesys::SmbClient :"
	          "Open %s return %d\n", fname, RETVAL); 
#endif
if (RETVAL < 0) { 
  RETVAL = 0;
#ifdef VERBOSE
 fprintf(stderr, "*** Error Filesys::SmbClient :"
                 "Open %s : %s\n", fname, strerror(errno)); 
#endif
} else if (seek_end) { context->lseek(context, RETVAL, 0, SEEK_END); }
OUTPUT:
  RETVAL


SV*
_read(context,fd, count)
  SMBCCTX *context
  SMBCFILE *fd
  int count
PREINIT:
/* 
 * Read count bytes on file descriptor fd
 *
 */
  char *buf;
  int returnValue;
CODE:
  buf = (char*)alloca(sizeof(char)*(count+1));
  returnValue = context->read(context, fd, buf, count);
  buf[returnValue]='\0';
#ifdef VERBOSE
  if (returnValue <= 0){ 
    fprintf(stderr, "*** Error Filesys::SmbClient: "
                    "Read %s : %s\n", buf, strerror(errno)); 
}
#endif
  if (returnValue<0) {RETVAL=&PL_sv_undef;}
  else {RETVAL=newSVpvn(buf,returnValue);}
OUTPUT:
  RETVAL

int
_write(context, fd, buf, count)
  SMBCCTX *context
  SMBCFILE *fd
  char *buf
  int count
CODE:
/* 
 * Write buf on file descriptor fd
 *
 */
  RETVAL=context->write(context, fd, buf, count);
#ifdef VERBOSE
  fprintf(stderr, "! Filesys::SmbClient :"
	          "write %d bytes: %s\n",count, buf);	
  if (RETVAL < 0) { 
    if (RETVAL == EBADF) 
      fprintf(stderr, "*** Error Filesys::SmbClient: "
		      "write fd non valide\n");
    else if (RETVAL == EINVAL) 
      fprintf(stderr, "*** Error Filesys::SmbClient: "
	              "write param non valide\n");
    else 
      fprintf(stderr, "*** Error Filesys::SmbClient: "
	               "write %d : %s\n", fd, strerror(errno)); 
  }
#endif
OUTPUT:
  RETVAL

int 
_lseek(context, fd,offset,whence)
  SMBCCTX *context
  SMBCFILE *fd
  int offset
  int whence
CODE:
  RETVAL=context->lseek(context, fd, offset, whence);
#ifdef VERBOSE
if (RETVAL < 0) { 
  if (RETVAL == EBADF) 
     fprintf(stderr, "*** Error Filesys::SmbClient: "
                     "lseek fd not open\n");
  else if (RETVAL == EINVAL) 
     fprintf(stderr, "*** Error Filesys::SmbClient: "
	   	    "smbc_init not called or fd not a filehandle\n");
  else 
     fprintf(stderr, "*** Error Filesys::SmbClient: "
	             "write %d : %s\n", fd, strerror(errno)); 
}
#endif
OUTPUT:
  RETVAL


int
_close(context, fd)
  SMBCCTX *context
  SMBCFILE *fd
CODE:
/* 
 * Close file desriptor fd
 *
 */
#ifdef HAVE_CLOSEFN
  RETVAL=context->close_fn(context, fd);
#else
  RETVAL=context->close(context, fd);
#endif
OUTPUT:
  RETVAL



int
_unlink(context, fname)
  SMBCCTX *context
  char *fname
CODE:
/* 
 * Remove file fname
 *
 */
  RETVAL = context->unlink(context, fname);
  if (RETVAL < 0) { 
    RETVAL = 0;
#ifdef VERBOSE	
  fprintf(stderr, "*** Error Filesys::SmbClient: Failed to unlink %s : %s\n", 
          fname, strerror(errno)); 
#endif
  } else RETVAL = 1;
OUTPUT:
  RETVAL


int
_unlink_print_job(context, purl, id)
  SMBCCTX *context
  char *purl
  int id
CODE:
/* 
 * Remove job print no id on printer purl
 *
 */
  RETVAL = smbc_unlink_print_job(purl, id);
#ifdef VERBOSE
  if (RETVAL<0)
    fprintf(stderr, "*** Error Filesys::SmbClient: "
	            "Failed to unlink job id %u on %s, %s, %u\n", 
                    id, purl, strerror(errno), errno);
#endif
OUTPUT:
  RETVAL


int
_print_file(context, purl, printer)
  SMBCCTX *context
  char *purl
  char *printer
CODE:
/* 
 * Print url purl on printer purl
 *
 */
  RETVAL = smbc_print_file(purl, printer);
#ifdef VERBOSE
  if (RETVAL<0)
    fprintf(stderr, "*** Error Filesys::SmbClient *** "
		    "Failed to print file %s on %s, %s, %u\n", 
	            purl, printer, strerror(errno), errno);
#endif
OUTPUT:
  RETVAL


