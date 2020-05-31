use ExtUtils::MakeMaker;
use ExtUtils::CChecker;
use Try::Tiny;
use File::Temp qw/tempfile tempdir/;
use Config;
use File::Find;
use File::Spec;
use File::Copy;
use Cwd qw/realpath/;
use v5.10;
use IPC::Run qw/run/;
use Carp qw/carp croak/;
use strict;


# Find openssl or exclude TLS support
my @try_libdirs = ("", qw{/usr/lib /usr/local/opt/openssl/lib});
my @try_incdirs = ("", qw{/usr/include /usr/local/opt/openssl/include});

my $ssl_flags = find_openssl(\@try_incdirs, \@try_libdirs);
say STDERR "Building without TLS - openssl not found" unless $ssl_flags;
my ($tls_cc, $tls_ld, $tls_libd);
(($tls_cc, $tls_ld, $tls_libd) = @$ssl_flags) if $ssl_flags;
my  $TLS = ($ssl_flags ? '--with-tls' : '--without-tls');
my  $WITH_LIBS = ($tls_libd ? "--with-libs=$tls_libd" : '');

_neo4j_client_tls();

my @configure_opts = ($TLS,$WITH_LIBS || ());

my $libdir = File::Spec->catdir(qw/build src lib/);
opendir my $src, $libdir;
my @files = grep /\.[ch]$/, readdir $src;
if (!$ssl_flags) { # remove openssl files
  @files = grep !/openssl/, @files;
}
# stage the libneo4client source+headers
copy (File::Spec->catfile($libdir,$_), File::Spec->curdir) for @files;

# config.h will be in the curdir - hack the staged files
for (@files) {
  system "$^X -i -ne 's{\.\./\.\./config\.h}{config\.h};print;' $_";
  croak $! unless !$?;
}

my @src_files = grep /\.c$/, @files;
my @o_files = map { s/\.c/\.o/;$_ } @src_files;
my $LDDLFLAGS = $Config{lddlflags};

WriteMakefile(
  NAME => 'Neo4j::Client',
  VERSION_FROM => 'lib/Neo4j/Client.pm',
  BUILD_REQUIRES => {
    'ExtUtils::MakeMaker' => 0,
  },
  CONFIGURE_REQUIRES => {
    'ExtUtils::CChecker' => 0,
    'Try::Tiny' => 0,
    'IPC::Run' => 0
    },
  OBJECT => join(' ',@o_files),
  LDDLFLAGS => $LDDLFLAGS,
  LDFROM => join(' ', @o_files),
  LINKTYPE => 'static',
  
  ($tls_cc ? (CCFLAGS => $tls_cc) : ()),
  ($tls_ld ? (LIBS => $tls_ld) : ()),
  CONFIGURE => \&_configure,
  PM => {
    'lib/Neo4j/Client.pm' => '$(INST_LIB)/Neo4j/Client.pm',
    'lib/Neo4j/ClientTLS.pm' => '$(INST_LIB)/Neo4j/ClientTLS.pm',
    'build/src/lib/neo4j-client.h' => '$(INST_ARCHLIB)/auto/Neo4j/Client/neo4j-client.h',
    "blib/arch/auto/Neo4j/Client/Client.a" => "\$(INST_ARCHLIB)/auto/Neo4j/Client/libClient.a",
    'bin/neoclient.pl' => '$(INST_SCRIPT)/neoclient.pl',
  },
  C => [grep /\.c$/, @src_files],
  H => [(grep /\.h$/, @src_files),'config.h'],
  realclean => { FILES => ['a.out','config.h', 'build/config.h',@files,'lib/Neo4j/ClientTLS.pm'] },
 );

sub _configure {
  my ($in,$out,$err);
  if (-e 'build/config.h') {
    return {};
  }
  say "Running configure";
  chdir 'build';
  $DB::single=1;
  my $rc = run ['./configure',@configure_opts], \$in,\$out,\$err;
  chdir '..';
  if (!$rc) {
    croak "configure failed with this output:\n$err";
  }
  else {
    # kludge away the VERSION define
    open my $f, File::Spec->catfile(qw'build config.h') or croak "build/config.h: $!";
    my @lines = <$f>;
    close($f);
    open $f, ">", 'config.h'; # create in the toplevel dir
    for (@lines) {
      next if /#define VERSION/;
      print $f $_;
    }
    close($f);
  }
  return {};
}

sub _neo4j_client_tls {
  my $tls =<<TLS;
package Neo4j::ClientTLS;
use Cwd qw{realpath};
\$Neo4j::Client::LIBS_SSL='$tls_ld';
sub Neo4j::Client::LIBS_SSL_ARY { split /\\s+/,\$Neo4j::Client::LIBS_SSL }
1;
TLS
  open my $f,">",File::Spec->catfile(qw/lib Neo4j ClientTLS.pm/) or croak $!;
  print $f $tls;
  close $f;
  return 1;
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

sub find_openssl {
  my ($try_incdirs, $try_libdirs) = @_;

  my ($in,$out,$err);
  
  if (run([qw/pkg-config --variable=libdir openssl/],\$in,\$out,\$err)) {
    print $out;
    chomp $out;
    push @{$try_libdirs}, $out;
  }
  if (run([qw/pkg-config --variable=includedir openssl/],\$in,\$out,\$err)) {
    print $out;
    chomp $out;
    push @{$try_incdirs}, $out;
  }
  
  my $cc = ExtUtils::CChecker->new( quiet => 1);
  my ($inc_found, $lib_found);
  $cc->push_extra_linker_flags('-lssl');
  $cc->push_extra_linker_flags('-lcrypto');
  my $tryc =<<'TRY';
#include <openssl/crypto.h>
int main() {
  printf("SSL Version: %s\n", OpenSSL_version(0));
  return 0;
}
TRY
  my $libd;
  open(OLDERR,">&",\*STDERR);
  close(STDERR);
  for my $incdir (@$try_incdirs) {
    $cc->push_extra_compiler_flags("-I$incdir") if $incdir;
    if (eval { $cc->try_compile( source => $tryc ) }) {
      $inc_found = 1;
      last;
    }
    $cc->pop_extra_compiler_flags if $incdir;
  }

  unless ($inc_found) {
    open(STDERR, ">&OLDERR");
    return;
  }
  
  for my $libdir (@$try_libdirs) {
    $libdir = realpath $libdir;
    $cc->unshift_extra_linker_flags( "-L".$libdir ) if $libdir;
    if ($cc->try_compile_run( source => $tryc )) {
      $lib_found=1;
      $libd = $libdir;
      $libd =~ s/lib$//;
      last;
    }
    $cc->shift_extra_linker_flags if $libdir
  }
  if ($lib_found) {
    open(STDERR, ">&OLDERR");
    return [join( ' ', @{$cc->extra_compiler_flags}),
	    join( ' ', @{$cc->extra_linker_flags}),
	   $libd];
  }
  open(STDERR, ">&OLDERR");  
  return;
}

sub ExtUtils::CChecker::try_compile {
  my $self = shift;
  my %args = @_;
  return unless $args{source};
  my $dir = tempdir( CLEANUP => 1);
  my ($fh, $fn) = tempfile('',DIR=>$dir,SUFFIX => '.c',UNLINK=>1) or die $!;
  print $fh $args{source};
  close($fh);
  $args{source} = $fn;
  try {
    return $self->compile(%args);
  } catch {
    return 0;
  };
}

# monkey patches for ExtUtils::CChecker

sub ExtUtils::CChecker::unshift_extra_linker_flags {
  my $self = shift;
  unshift @{$self->{extra_linker_flags}},@_;
}

sub ExtUtils::CChecker::shift_extra_linker_flags {
  my $self = shift;
  shift @{$self->{extra_linker_flags}};
}

sub ExtUtils::CChecker::pop_extra_compiler_flags {
  my $self = shift;
  pop @{$self->{extra_compiler_flags}};
}

sub ExtUtils::CChecker::pop_include_dirs {
  my $self = shift;
  pop @{$self->{include_dirs}};
}

