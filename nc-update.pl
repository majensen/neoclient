#!/usr/bin/env perl
use v5.10;
use Getopt::Long;
use Pod::Usage;
use Carp qw/croak carp/;
use Path::Tiny qw/path cwd/;
use IPC::Run qw/run/;
use strict;
use warnings;

our $VERSION='0.42';

=head1 NAME

nc-update.pl - Subset libneo4j-omni for neoclient

=head1 SYNOPSIS

 Usage: nc-update.pl [--dry-run] [--force] 
   [--manifest <mani-of-desired-files-and-dirs>]
   [--libneo <lib-nc top-level dir>] [<top-level-dir>]
 Read from libneo4j-omni repo directory; place filtered code in
 build subdirectory

 Defaults:
   --manifest:      ./NC-MANIFEST
   --libneo:        ./libneo4j-omni/
   <top-level-dir>  .

=head1 DESCRIPTION

Create code subset of libneo4j-omni for neoclient Rewrite some
configuration details to enable access to internal functions and to
remove troublesome settings.  Pull only code needed for the library,
not the shell.

Put the code in the C<./build> directory.

=cut

my ($libneo,$manif,$force,$dryrun);

GetOptions( "force" => \$force,
	    "dry-run" => \$dryrun,
	    "libneo:s" => \$libneo,
	    "manifest:s" => \$manif,
	   )
  or pod2usage(2);

$libneo //= "libneo4j-omni";
$manif //= "NC-MANIFEST";

my $cwd = cwd;
my $dir = shift;

$dir = ($dir ? path($dir) : path('.'));
$dir->exists or croak "can't find $dir";
$dir->is_dir or croak "arg must be a dir";


$libneo = path($libneo);
$libneo->exists or croak "can't find $libneo";

$manif = path($manif);
$manif->exists or croak "can't find $manif";

my $build = $dir->child('build');

($force || $dryrun) ||
  croak("build directory exists (use --force to overwrite")
  if $build->exists;

say "mkdir $build";
$build->mkpath unless $dryrun;

## Copy according to manifest:
my %dirs;
foreach ($manif->lines) {
  chomp;
  my $pth = path($_);
  if ($libneo->child($pth)->is_dir) {
    replicate_below($libneo,$pth,$build);
  }
  else {
    my $dn = path($_)->parent->stringify;
    my $bn = path($_)->basename;
    # convert globs to regexes
    if ($bn =~/[*]/) {
      $bn =~ s/[.]/\\./g;
      $bn =~ s/[*]/.*/g;
      $bn = qr/$bn/;
    }
    else {
      $bn = qr/\Q$bn\E/;
    }
    $dirs{"$libneo"}++;
    for my $file ($libneo->child($dn)->children($bn)) {
      next unless $file->exists;
      my $dst = $build->child($file->relative($libneo));
      my $par = $dst->parent;
      if (!$dirs{"$par"}) {
	$dirs{"$par"}++;
      }
      say "mkdir $par" unless $dirs{"$par"};
      unless ($dryrun) {
	$dst->parent->mkpath unless $dst->parent->exists;
      }
      say "copy $file -> $dst";
      $file->copy($dst) unless $dryrun;
    }
  }
}

## Rewrite

my $tgt = $build->child('Makefile.am');
say "update $tgt";
$tgt->edit_lines(sub{ /SUBDIRS.*shell/ and $_="" }) unless $dryrun;

$tgt = $build->child('configure.ac');
say "update $tgt";
!$dryrun && do {
    $tgt->edit_lines(
      sub{
	/hidden/ && s/-fvisibility=hidden//;
	/warning-option/ && s/-Wno-unknown-warning-option//;
	/stringop-truncation/ && s/-W.*stringop-truncation//;
	/^DX/ and $_="";
      });
    $tgt->edit_lines(
      sub{
	state $rm;
	$_="" if $rm;
	/AC_CONFIG_FILES/ and $rm=1;
      });
    my $th = $tgt->filehandle(">>");
    print $th <<EOF;
	Makefile \\
	lib/Makefile \\
	lib/src/Makefile \\
	lib/src/neo4j-client.h
])
AC_OUTPUT
EOF
    };

$tgt->edit_lines(
  sub{
    state $nsp;
    state $mns;
    if ($nsp) {
      $_="";
      undef $nsp;
    };
    if ($mns) {
      $_="";
      undef $mns;
    }
    /SO_NOSIGPIPE/ && do {
      s/\Q[AC_DEFINE([HAVE_SO_NOSIGPIPE],[1],\E/[],/;
      $nsp=1;
    };
    /MSG_NOSIGNAL/ && do {
      s/\Q[AC_DEFINE([HAVE_MSG_NOSIGNAL],[1],\E/[],/;
      $mns=1;
    };
  }) unless $dryrun;


$tgt = $build->child(qw/lib src Makefile.am/);
say "update $tgt";
$tgt->edit_lines(
    sub{
      /^include_HEADERS/ and
	$_ = "include_HEADERS = neo4j-client.h atomic.h buffering_iostream.h chunking_iostream.h client_config.h connection.h deserialization.h iostream.h job.h logging.h memory.h messages.h metadata.h network.h print.h posix_iostream.h render.h result_stream.h ring_buffer.h serialization.h thread.h tofu.h transaction.h uri.h util.h values.h\n";
    }) unless $dryrun;


{
  # Add neo4j_openssl_version() function for t/030_sslversion.t

  $tgt = $build->child('lib/src/openssl.c');
  say "update $tgt";
  $tgt->edit_lines( sub {
    m{#include <openssl/crypto.h>} and $_ = <<END;
#include <openssl/crypto.h>
#include <openssl/opensslv.h>
END
  }) unless $dryrun;
  $tgt->append_raw(<<END) unless $dryrun;

const char *neo4j_openssl_version(int t)
{
#if OPENSSL_VERSION_NUMBER >= 0x10100000L /* 1.1.0 or later */
    return OpenSSL_version(t > 0 ? t : OPENSSL_VERSION);
#else
    return SSLeay_version(t > 0 ? t : SSLEAY_VERSION);
#endif
}
END

  $tgt = $build->child('lib/src/neo4j-client.h.in');
  say "update $tgt";
  $tgt->edit_lines( sub {
    m{#pragma GCC visibility pop} and $_ = <<END;
const char *neo4j_openssl_version(int t); /* Internal - DO NOT USE */

#pragma GCC visibility pop
END
  }) unless $dryrun;
}


## Configure

say "create new lib/Makefile.am";
$build->child('lib','Makefile.am')->exists or (!$dryrun && do {
  my $mamf =   $build->child('lib','Makefile.am')->filehandle(">");
  print $mamf "SUBDIRS = src\n";
  close($mamf);
});

say "chmod autogen.sh";
$build->child('autogen.sh')->chmod(0755) unless $dryrun;

for my $scr (qw/install-sh missing depcomp test-driver compile config.guess config.sub/) {
  say "chmod build-aux/$scr";
  $build->child('build-aux',$scr)->chmod(0755) unless $dryrun;
}

my ($in,$out,$err);
say "cd $build";
chdir "$build" unless $dryrun;
say "run ./autogen";
unless ($dryrun) {
  run [qw|./autogen.sh|],\$in,\$out,\$err;
  carp "autogen borked: $err" if $err;
}

undef $err;
say "run automake";
unless ($dryrun) {
  run [qw|automake|],\$in,\$out,\$err;
  carp "automake borked: $err" if $err;
}

END {
  chdir "$cwd";
}

## subs

sub replicate_below {
  my ($src,$pth,$dst) = @_;
  my $it = $src->child($pth)->iterator({recurse=>1});
  say "mkdir ".$dst->child($pth);
  $dst->child($pth)->mkpath unless $dryrun;
  while (my $p = $it->()) {
    my $d = $dst->child($p->relative($src));
    if ($p->is_dir) {
      say "mkdir $d";
      $d->mkpath unless $dryrun;
    }
    else {
      say "copy $p -> $d";
      $p->copy($d) unless $dryrun;
    }
  }
  1;
}





