# has to provide: access to the lib
#                 access to neo4j-client.h
package Neo4j::Client;
use Neo4j::ClientLocal;
use Cwd qw/realpath/;
use File::ShareDir qw/module_dir/;
use File::Spec;

use strict;
use warnings;

$Neo4j::Client::VERSION="0.1";

$Neo4j::Client::LIBS =
  join(' ', "-L".realpath(module_dir(__PACKAGE__))." -lClient",
       $Neo4j::Client::LOCAL_LIBS);

$Neo4j::Client::CCFLAGS =
  join(' ', "-I".realpath(module_dir(__PACKAGE__)),
       $Neo4j::Client::LOCAL_CCFLAGS);

sub Neo4j::Client::LIBS_ARY { split /\s+/,$Neo4j::Client::LIBS }
sub Neo4j::Client::CCFLAGS_ARY { split /\s+/,$Neo4j::Client::CCFLAGS }

sub dir { realpath(module_dir(__PACKAGE__)) }

=head1 NAME

Neo4j::Client - Build and use the libneo4j-client library

=head1 SYNOPSIS

 use Neo4j::Client;
 $Neo4j::Client::LIBS;
 $Neo4j::Client::CCFLAGS;

=head1 DESCRIPTION

Chris Leishman's
L<libneo4j-client|https://github.com/cleishm/libneo4j-client> is a C
library for communication with a Neo4j (<v4.0) server via the Bolt
protocol. Installing this module will attempt to build the (static)
library on your machine for use with L<Neo4j::Bolt>.

=head1 AUTHOR

 Mark A. Jensen < majensen -at- cpan -dot- org >
 CPAN: MAJENSEN

=head1 LICENSE

This packaging software is Copyright (c) 2020 by Mark A. Jensen.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

The L<libneo4j-client|https://github.com/clieshm/libneo4j-client> software 
is Copyright (c) by Chris Leishman. 

It is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut

1;
