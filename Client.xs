#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"


MODULE = Neo4j::Client		PACKAGE = Neo4j::Client		

BOOT:
  1;

void
hey_dude()
  CODE:
  {
    printf("Hey dude! XS is so frigging AWESOME. I want to write it everyday!\n");
  }
  

