# has to provide: access to the dynamic lib
#                 access to neo4j-client.h
package Neo4j::Client;
use base DynaLoader;
use File::ShareDir qw/module_dir/;

use strict;
use warnings;

BEGIN {
  $Neo4j::Client::VERSION="0.1";
}
if ($^O =~ /darwin/i) {
  $DynaLoader::dl_dlext = 'dylib';
}

__PACKAGE__->bootstrap;

sub dir {
  return module_dir('Neo4j::Client');
}

=head1 NAME

Neo4j::Client - build libneo4j-client on your machine

=head1 SYNOPSIS

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
