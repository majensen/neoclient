#!/usr/bin/env perl
use Neo4j::Client;
use Getopt::Long;
use Pod::Usage;
use strict;
use warnings;

no warnings 'once';
my ($libs, $inc, $ssl_libs);
GetOptions(
  "libs|l" => \$libs,
  "inc|i" => \$inc,
  "lssl|ssl|s" => \$ssl_libs
 ) or pod2usage(1);

print join(' ', ($libs ? $Neo4j::Client::LIBS : ()),
	   ($inc ? $Neo4j::Client::INC : ()),
	   ($ssl_libs ? $Neo4j::Client::LIBS_SSL : ()));
1;

=head1 NAME

neoclient.pl - get compiler and linker options provided by Neo4j::Client

=head1 SYNOPSIS

 $ neoclient.pl [--libs] [--inc] [--lssl]
 
 Print compiler and linker flags pointing to libneo4j-client and libssl to
 stdout

=head1 SEE ALSO

L<Neo4j::Client>

=head1 AUTHOR

 Mark A. Jensen
 CPAN: MAJENSEN

=cut

