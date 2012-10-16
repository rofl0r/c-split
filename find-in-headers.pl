#!/usr/bin/env perl
use strict;
use warnings;

use File::Basename; 
use Cwd 'abs_path';
use lib dirname(abs_path($0));
use CParser;
use Data::Dump qw(dump);

my $file = $ARGV[0] or die ("need filename");
my $dir = $ARGV[1] or die ("need dir with headers as second arg");

my $p = CParser->new($file);
$p->parse();

my @hdrs=`find $dir -name '*.h'`;
for(@hdrs) {
	chomp;
	#print "processing $_\n";
	#next unless /unistd/; 
	my $h = CParser->new($_);
	$h->parse();
	#dump $h;
	#exit;
	for(keys %{$p->{funcs}}) {
		print "$_ defined in $file and $h->{cfile}\n" if(defined($h->{funcs}->{$_}));
	}
}
