# has to provide: access to the lib
#                 access to neo4j-client.h
package Neo4j::Client;
use Neo4j::ClientTLS;
use File::ShareDir qw/module_dir/;
use File::Spec;

use strict;
use warnings;

$Neo4j::Client::VERSION="0.1";

$Neo4j::Client::LIBS =
  "-L".module_dir(__PACKAGE__)." -lClient";

$Neo4j::Client::INC =
  "-I".module_dir(__PACKAGE__);

sub dir { module_dir(__PACKAGE__) }

=head1 NAME

Neo4j::Client - build libneo4j-client on your machine

=head1 SYNOPSIS

 use Neo4j::Client;
 $Neo4j::Client::LIBS;
 $Neo4j::Client::INC;
 $Neo4j::Client::LIBS_SSL;

=head1 DESCRIPTION

Chris Leishman's
L<libneo4j-client|https://github.com/cleishm/libneo4j-client> is a C
library for communication with a Neo4j (<v4.0) server via the Bolt
protocol. Installing this module will attempt to build the library on your
machine for use with L<Neo4j::Bolt>.

=head1 AUTHOR

 Mark A. Jensen < majensen -at- cpan -dot- org >
 CPAN: MAJENSEN

=cut

1;
