#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;

sub name_wo_ext {
	my $x = shift;
	my $l = length($x);
	$l-- while($l && substr($x, $l, 1) ne ".");
	return substr($x, 0, $l) if($l);
	return "";
}

sub syntax {
	print "expected syntax: " . basename($0) . " myfile.c myoutputdirectory/\n";
	exit 1;
}

my $file = $ARGV[0] or syntax;
my $outdir = $ARGV[1] or syntax;
die("error accessing outdir") if(!-d $outdir && !mkdir($outdir));
my $internal_header = name_wo_ext(basename($file)) . "_internal.h";
my $f;
open($f, "<", $file);
my $openbraces = 0;
my @includes;
my $incomment = 0;
my $line = "";
my @statics;
my @typedefs_macros;
my @extern;

sub scanbraces {
	my $shit = shift;
	my @chars = split //, $shit;
	for my $c(@chars) {
		if ($c eq "{") {
			$openbraces++;
		} elsif($c eq "}") {
			$openbraces--;
		}
	}
}

sub writefunc {
	my ($funcname, $code) = @_;
	my $fd;
	open($fd, ">", "$outdir/$funcname.c");
	print {$fd} '#include "' . $internal_header . "\"\n\n";
	print {$fd} $code, "\n";
	close $fd;
}

sub handlesub {
	my $_ = shift;
	my $name = "";
	my $wasstatic = 0;
	while(!$name) {
		my $x = 0;
		$x++ while(substr($_, $x, 1) !~ /\s/);
		my $word = substr($_, 0, $x);
		if($word eq "static" || $word eq "inline") {
			$_ = substr($_, $x);
			s/^\s+//;
			$wasstatic = 1;
			next;
		} else {
			if(/(.*?)([\w_]+)\s*\((.*?)\)\s*\{/) {
				$name = $2;
				my $decl = $1 . $name . "(" . $3 . ");";
				push @statics, $decl if($wasstatic);
				#print $name , "\n" if $wasstatic;
				writefunc($name, $_);
				#print "function $name\n$_";
			} else {
				print "ERROR\n";
				return;
			}
		}
	}
}

sub parseline {
	$_ = shift;
	#print "PL: length line: ". length($line) . "\n";
	return unless defined $_;
	return if $_ eq "";
	if($line eq "" && /^\s*#/) {
		push @typedefs_macros, $_;
		return;
	}
	$line .= $_ . "\n" if(!$openbraces || $line ne "");
	scanbraces $_;
	
	if($line ne "" && !$openbraces) {
		if($line =~ /([;\}]{1})\s*\n*$/) {
			if($1 eq ";") {
				#print $line;
				if ($line =~ /=/ || $line =~ /^\s*static[\s\n]+/) {
					#print "extern!\n";
					$line =~ s/^\s*static\s*//;
					push @extern, $line;
				} else {
					push @typedefs_macros, $line;
				}
				$line = "";
				return;
			}
			handlesub($line);
			$line = "";
		} 
	}
}

while(<$f>) {
	
#	print;
	chomp;
#	print "$openbraces, $incomment\n";
	if (/^\s*#\s*include\s+[<\"]{1}[\w_\-\/\.]+[>\"]{1}/) {
		push @includes, $_;
	} else {
		next if(/^\s*$/); #skip empty lines
		next if(/^\s*\/\//); #skip one line comments.
		# normal source code line.
		if (!$incomment && /(.*?)\/\*(.*?)$/) {
			parseline($1);
			my $rest = $2;
			$incomment = 1 unless $rest =~ /\*\//;
		} elsif($incomment) {
			if(/\*\/(.*?)$/) {
				parseline($2);
				$incomment = 0;
			}
		} else {
			parseline($_);
		}
	}
}
close $f;

my $extfd;
if(@extern) {
	open($extfd, ">", $outdir . "/" . name_wo_ext(basename($file)) . "_variables.c");
	print {$extfd} "#include \"$internal_header\"\n\n";
}

my $destname = "$outdir" . "/" . $internal_header;
my $fd;
open($fd, '>', $destname);
for(@includes) {
	s/\s+\"/ \"\.\.\//;
	print {$fd} $_, "\n";
}
print {$fd} "\n";
for(@typedefs_macros) {
	print {$fd} $_, "\n";
}
print {$fd} "\n";

print {$fd} "\n";
for(@extern) {
	my ($k, $v) = split /=/, $_;
	print {$fd} "extern $k;\n";
	print {$extfd} $_, "\n";
}

for(@statics) {
	print {$fd} $_, "\n";
}
print {$fd} "\n";
print {$fd} "//RcB: DEP \"*.c\"\n\n";
close $fd;
close $extfd if(@extern);

