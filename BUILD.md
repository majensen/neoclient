# Updating Neo4j::Client

To update to a new version of [libneo4j-omni](http://github.com/majensen/libneo4j-omni):

* Run `make realclean`.
* Update git submodule libneo4j-omni in this repo.
* Run `perl nc-update.pl --force` from the neoclient directory.
 * The file [NC-MANIFEST](/NC-MANIFEST) lists the files required from libneo4j-omni to build the appropriate library for Neo4j::Client.
 * `nc-update.pl` subsets these files into the directory [build](/build) and performs some required rewriting.
* Build as usual with `perl Makefile.PL` and `make`.


## First step: Prepare the library

Some of the following commands may be helpful for handling the libneo4j-omni
submodule:

```sh
# Populate an empty submodule dir after cloning Neo4j::Client
git submodule init
git submodule update

# Update to the latest commit on the libneo4j-omni main branch:
git submodule update --rebase --remote

# Look at a specific GitHub PR, for trial releases etc.:
git submodule foreach git checkout origin/pr123
git submodule update origin/pr123

# Temporary test build with a local libneo4j-omni branch:
rm -Rf libneo4j-omni
git clone -b BRANCH --depth 1 file://...
```

The submodule directory won't be included in the Perl module tarball.
The module will compile the library from the `build` directory,
which needs to be updated with the `nc-update` staging script.
The Perl version of that script is the newer one;
the shell script with the same name is no longer used.

The staging script requires Autoconf, Automake, Libtool, and m4 to be
installed on the system. The script currently doesn't use the versions
of these tools that are bundled with Neo4j::Client.

```sh
# Install nc-update prerequisites
brew    install automake libtool  # Darwin
apt-get install automake libtool  # Debian
cpanm IPC::Run Path::Tiny

perl nc-update.pl --force
```


## Second step: Prepare the Perl module

For releasing an updated version to CPAN:

- Bump version number in [lib/Neo4j/Client.pm](lib/Neo4j/Client.pm).
- Update [Changes](Changes).  
    (Given that Neo4j::Client bundles libneo4j-omni, significant changes
    in libneo4j-omni since the last Neo4j::Client release should probably
    be described here, *at least* briefly in general terms.)
- Update prereqs and other metadata in [Makefile.PL](Makefile.PL) as appropriate.
- Update [Client.md](lib/Neo4j/Client.md)/[README.md](README.md) with any POD changes:
    ```sh
    sed -e '/local_module_re/s/Neo4j::Bolt/Neo4j::Client/' ../perlbolt/pod2md.PL |
    perl - lib/Neo4j/Client.pm && cp lib/Neo4j/Client.md README.md && echo ok
    ```

For a CPAN trial release, these markers should additionally be added:

- [Client.pm](lib/Neo4j/Client.pm), after the version number line: `# TRIAL`
- [Changes](Changes), after the version number: `(TRIAL RELEASE)`
- [Makefile.PL](Makefile.PL), in the meta hash: `release_status => 'testing',`
- Tarball name, after the version number: `-TRIAL`


## Third step: Build the distribution tarball

```sh
# Install prereqs
cpanm --installdeps Neo4j::Client

# The manifest should be verified manually, to make sure no new files
# are accidentally omitted.
perl Makefile.PL && make realclean
perl Makefile.PL && make manifest
diff MANIFEST.bak MANIFEST

# Revert to old manifest
rm MANIFEST.bak
git checkout -- MANIFEST

# Create and test the dist tarball
# (running `make` or `make test` isn't necessary before `make dist`)
make dist
cpanm --test-only Neo4j-Client-*.tar.gz

# See full test output
cpanm --installdeps --with-develop --with-recommends Neo4j-Client-*.tar.gz
make && prove -b
```
