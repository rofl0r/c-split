#!/usr/bin/env perl
use strict;
use warnings;

use File::Basename; 
use Cwd 'abs_path';
use lib dirname(abs_path($0));
use CParser;
use Data::Dump qw(dump);

my $file = $ARGV[0] or die ("need filename");

my $p = CParser->new($file);
$p->parse();
#dump($p);

for(@{$p->{macros}}) {
	print "$_\n";
}

for(@{$p->{typedefs}}) {
	print "$_\n";
}