package Neo4j::Client;
use strict;
use warnings;
use base qw( Alien::Base );

our $VERSION = '0.40';

=head1 NAME

Neo4j::Client - Build and use the libneo4j-client library

=head1 SYNOPSIS

 use ExtUtils::MakeMaker;
 use Neo4j::Client;
 
 WriteMakefile(
   LIBS => Neo4j::Client->libs,
   CCFLAGS => Neo4j::Client->cflags,
   ...
 );

=head1 DESCRIPTION

Chris Leishman's
L<libneo4j-client|https://github.com/cleishm/libneo4j-client> is a C
library for communication with a Neo4j server via the Bolt
protocol. 

Installing this module will attempt to build the API portion of the
library on your machine. C<libneo4j-client>'s interactive shell and 
documentation are not built.

Thanks to the miracle of L<Alien::Build>, the library should always
contain OpenSSL support. 

=head1 SEE ALSO

L<Neo4j::Bolt>.

=head1 AUTHOR

 Mark A. Jensen < majensen -at- cpan -dot- org >
 CPAN: MAJENSEN

=head1 ACKNOWLEDGMENT

Thanks L<ETJ|https://metacpanorg/author/ETJ> (a.k.a mohawk) for beaming me aboard.

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

