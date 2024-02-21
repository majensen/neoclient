# Updating Neo4j::Client

To update to a new version of [libneo4j-omni](http://github.com/majensen/libneo4j-omni):

* Run `make realclean`.
* Update git submodule libneo4j-omni in this repo.
* Run `perl nc-update.pl --force` from the neoclient directory.
 * The file [NC-MANIFEST](/NC-MANIFEST) lists the files required from libneo4j-omni to build the appropriate library for Neo4j::Client.
 * `nc-update.pl` subsets these files into the directory [build](/build) and performs some required rewriting.
* Build as usual with `perl Makefile.PL` and `make`.
