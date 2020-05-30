# Notes on building the libneo4j-client library

Machete through the automake cruft to determine what is actually required, set and run.

- which files (.ac, .am, .in) are in fact created by the dev?
  - config.ac
  - Makefile.am

What needs to be tested for at config time? openssl-1.0

* Only build the library
  - ignore the interactive client
  - ignore the man files
  - ignore the doxygen docs

Basic idea, to translate the automake processes into EU::MM processes.

Installation - 
- want to install library in a regular system location?
- in an perl Auto directory?
  - How to insure that Neo4j::Bolt is correctly linked to that? Does just "use Neo4j::Client;" work? Why or why not?

Autoconf smackdown

- bring desired portions of code to build subdir, maintaining the dir structure
- idea: run autoconf tools to create a stripped down configure 
  - need configure, so to create the config.h and neo4j-client.h
  - I think we can discard the Makefiles generate, and use EU::MM.

to generate the configure, need to bring over
 configure.ac - modified to configure for the library only (no tools, no doxygen), modified the registered target files
 Makefile.am - a skeleton of its former self, with all manual and doc targets removed
 Makefile.in - as created by automake
 neo4j-client.pc
 src/lib/Makefile.am
 m4/ (this is key, many custom macros)
 
     $ cd build
	 $ automake --add-missing # possibly
	 $ autoreconf --install
	 $ ./configure # should work
	 
(commit the whole shebang - user will not run autoreconf, only ./configure)

The point is to generate the header files. Need then to grok how to tell EU::MM to link, what lib to create and where to install.

The CONFIGURE key in EU::MM points to a coderef an returns a hashref of options. Use this as a hook to run configure.

OBJECT
LDFROM
LDDLFLAGS
MYEXTLIB

Exploring DynaLoader

Idea: have the extension building (XS) machinery create a shared library associated with the module (i.e., Client.dylib, Client.so), that is just a version of libneo4j-client.so. 

Hope that loading Neo4j::Client will expose the symbols defined in the shared library to the XS code in Neo4j::Bolt - perhaps without having to explicitly link it in.

The machinery really depends on the existence of a Client.xs
- for DynaLoader to actually complete loading, there need to be a symbol provided by the library `_boot_Neo4j__Client` or some such. This in in the object created by the XS machinery (Client.xs -> Client.c -> Client.o)

- so make a stubby Client.xs. It has to be in the top-level of the distribution for Makefile to find it.

There was a mismatch between the kind of shared lib/arch stored in Config
(i.e., used when the perl was created) and that required for things to work.
- `$Config{lddlflags}` contains the option "-bundle", want "-shared" instead.
- EU::MM uses the `%Config` hash to create defaults, so needed to kludge away the "-bundle" and add "-shared", an custom set LDDLFLAGS
- `$Config{so}` is "dylib" and not "bundle". EU::MM pod says that is the default, but I had to explicitly set DLEXT => `$Config{so}`. Note without the swap in LDDLFLAGS, a .bundle gets created (no matter what it's called). 

Both libneo4j-client and XS machinery generate a macro called VERSION. This leads to a compile time conflict. The _configure sub deletes the libneo4j-client #define from the config.h file.

For DynaLoader to complete loading the module, it needs to know where the external libraries (for openssl) are. Evidently, this is where the notion of the "Bootstrap" for DL comes in.

Supposedly, pushing library paths to `@DynaLoader::dl_resolve_using` is enough to clue the DL in, but experiments suggested that these had to be loaded explicitly. This has to be done before the module extension itself is loaded (hence "bootstrap" I guess).

The .bs script is a hook where these DL instructions go. It is just Perl. It is eval'ed in the DL bootstrap method on the module (so the dl_* do not have
to be qualified with the namespace; that is already there at the eval point).

EU::Mkbootstrap::Mkbootstrap() builds this .bs file automatically - supposedly. If one wants to add code to it, one is meant to create a (Perl) file called `<module_base>_BS`. In it, the code you wish to add must be 
in a string var, `$bscode`.

The problem is, Mkbootstrap() apparently won't run at all unless some var
called BSLOADLIBS is defined. 

	-e "Mkbootstrap('$(BASEEXT)','$(BSLOADLIBS)');"

This is a seeming no-op otherwise. If BSLOADLIBS is non-empty, then Mkbootstrap() will pick up the _BS file as advertised.

The .bs file then must be staged for installation alongside the extension library in at `<inst_archlib>/auto/<mod>/<mod>/<base>/<base>.bs`. 

Maybe if LIBS is set, then everything will just work without the _BS kludge. 
You would think, but this does set BSLOADLIBS. (ExtUtils::Liblist::ext() 
returns '' in the array element meant for BSLOADLIBS.) 

    EXTRALIBS = -L/usr/local/opt/openssl@1.1/lib -lssl -lcrypto
    LDLOADLIBS = -L/usr/local/opt/openssl@1.1/lib -lssl -lcrypto
    BSLOADLIBS = 
    LD_RUN_PATH = /usr/local/opt/openssl@1.1/lib

This will work: Set BSLOADLIBS as an env var, use the -e switch with make, and make the target itself.

    BSLOADLIBS="-L/usr/local/opt/openssl@1.1/lib -lssl -lcrypto"  make -e Client.bs
	
but it's too late.

I find you can explicitly write your own .bs script, and insure it gets
installed correctly by including it in the PM attribute:

    PM => {
       'lib/Neo4j/Client.pm' => '$(INST_LIB)/Neo4j/Client.pm',
       'lib/Neo4j/Client.bs' =>'$(INST_ARCHLIB)/auto/Neo4j/Client/Client.bs',
      },

The DL will pick it up and run it.


Loading doesn't magically make symbols available to other XS modules. So we can have Neo4j::Client at least provide a variable that is the path of Client.dylib (Client.so), that can be used in the LIBS attribute of the Inline modules.

so maybe the of the lib should be libClient.{so}, so can pass -lClient to LIBS, and Neo4j::Client should provide the auto/Neo4j/Client directory for the -L option to use.

Neo4j::Client::LFLAGS() could yield "-L.../auto/Neo4j/Client -lClient".

Inline might be more trouble than it's worth.

Had to patch Inline::C to allow the EU::MM attribute 'DLEXT'
through. (to call Client.dylib .dylib and not .bundle)

# Steps for build

* Ship with libneo4j-client @ v2.2.0 in toplevel dir
	* Along with copies (not links) of depcomp, install-sh,
      libtool,ltmain.sh,config.sub, alocal.m4, m4/
	* Basically, run autoreconf --install in libneo4j-client and
      commit this.
* Copy libneo4j-client/src/lib/* to build/
* Find the directories for libperl, libssl, libcrypto libraries.

