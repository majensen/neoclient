use ExtUtils::MakeMaker;
use Config;
use File::Find;
use File::Spec;
use v5.10;
use IPC::Run qw/run/;
use Carp qw/carp croak/;
use strict;

# need to generalize the extensions

opendir my $src, './build/src/lib';
my @files = grep /\.[ch]$/, readdir $src;
my @src_files = map { "build/src/lib/$_" } @files;
push @src_files, 'Client.c';
my @o_files = map { s/\.c$/.o/;$_ } grep /\.c$/, @files;

my $TLS = '--with-tls';
my $WITH_LIBS = '--with-libs=/usr/local/opt/openssl@1.1/';
my @configure_opts = ($TLS,$WITH_LIBS);
my $LDDLFLAGS = $Config{lddlflags};
if ($^O =~ /darwin/i) {
  $LDDLFLAGS =~ s/bundle/shared/;
}
say $LDDLFLAGS;

WriteMakefile(
  NAME => 'Neo4j::Client',
  VERSION_FROM => 'lib/Neo4j/Client.pm',
  # O_FILES are prefixed with build/src/lib
  OBJECT => '$(O_FILES)',
  LDDLFLAGS => $LDDLFLAGS,
  # LDFROM files are basenames
  LDFROM => join(' ', @o_files, 'Client.o'),
  # both OBJECT and LDFROM are necessary as defined here
  CCFLAGS => '-I/usr/local/opt/openssl@1.1/include',
  LIBS => [join(' ',Lperl(),'-L/usr/local/opt/openssl@1.1/lib -lssl -lcrypto -lperl')],
  DLEXT => $Config{so},
  CONFIGURE => \&_configure,
  PM => {
    'lib/Neo4j/Client.pm' => '$(INST_LIB)/Neo4j/Client.pm',
    'lib/Neo4j/Client.bs' => '$(INST_ARCHLIB)/auto/Neo4j/Client/Client.bs',
    'build/src/lib/neo4j-client.h' => '$(INST_ARCHLIB)/auto/Neo4j/Client/neo4j-client.h',
    "blib/arch/auto/Neo4j/Client/Client.$Config{so}" => "\$(INST_ARCHLIB)/auto/Neo4j/Client/libClient.$Config{so}",
  },
  C => [grep /\.c$/, @src_files],
  H => [(grep /\.h$/, @src_files),'build/config.h'],
  realclean => { FILES => 'build/config.h' },
 );

sub _configure {
  my ($in,$out,$err);
  if (-e 'build/config.h') {
    return {};
  }
  say "Running configure";
  chdir 'build';
  my $rc = run ['./configure',@configure_opts], \$in,\$out,\$err;
  chdir '..';
  if (!$rc) {
    croak "configure failed with this output:\n$err";
  }
  else {
    # kludge away the VERSION define
    open my $f, 'build/config.h' or croak "build/config.h: $!";
    my @lines = <$f>;
    close($f);
    open $f, ">", 'build/config.h';
    for (@lines) {
      next if /#define VERSION/;
      print $f $_;
    }
    close($f);
  }
  return {};
}

sub Lperl {
  # archlib
  my $lib = '';
  find( sub {
	  /libperl/ && ($lib = $File::Find::name);
	}, $Config{archlib});
  my $dir =[File::Spec->splitpath($lib)]->[1];
  $dir =~ s/\/$//;
  return "-L$dir";
}

