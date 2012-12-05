package CParser;

use strict;
use warnings;

sub file_ext {
	my $x = shift;
	my $l = length($x);
	$l-- while($l && substr($x, $l, 1) ne ".");
	return substr($x, $l) if($l);
	return "";
}


sub new {
	my ($pkg, @args) = @_;
	die("need C file name as arg") if(scalar(@args) != 1);
	my $isheader = file_ext($args[0]) eq ".h";
	my $self = {
		cfile => $args[0],
		isheader => $isheader,
		printerrors => 0,

		openbraces => 0,
		incomment => 0,
		line => "",

		includes => [],
		statics => [],
		extern => [],
		typedefs => [],
		macros => [],
		funcs => undef,
	};
	bless $self, $pkg;
}

sub addfunc {
	my ($self, $funcname, $code) = @_;
	$self->{funcs}->{$funcname} = $code;
}

sub handlesub {
	my $self = shift;
	my $_ = shift;
	my $name = "";
	my $wasstatic = 0;
	while(!$name) {
		my $x = 0;
		$x++ while(substr($_, $x, 1) !~ /\s/);
		my $word = substr($_, 0, $x);
		my $extern = 1 if($word eq "extern");
		if($word eq "static" || $word eq "inline") {
			$_ = substr($_, $x);
			s/^\s+//;
			$wasstatic = 1 unless $extern;
			next;
		} else {
			if(/(.*?)([\w_]+)\s*\(([\w\s_,\*\[\]\.\(\)]*?)\)\s*\{/
				|| ($self->{isheader} &&
					/(.*?)([\w_]+)\s*\((.*?)\)\s*;/)
			) {
				$name = $2;
				my $decl = $1 . $name . "(" . $3 . ");";
				push @{$self->{statics}}, $decl if($wasstatic);
				#print $name , "\n" if $wasstatic;
				$self->addfunc($name, $_);
				#print "function $name\n$_";
			} elsif($self->{isheader}) {
				return;
			} else {
				warn "ERROR: $_\n" if $self->{printerrors};
				return;
			}
		}
	}
}

sub scanbraces {
	my $self = shift;
	my $shit = shift;
	my @chars = split //, $shit;
	for my $c(@chars) {
		if ($c eq "{") {
			$self->{openbraces}++;
		} elsif($c eq "}") {
			$self->{openbraces}--;
		}
	}
}

sub strip_macro {
	my $x = shift;
	$x =~ s/^\s*//;
	$x =~ s/\s*$//;
	$x =~ s/\s+/ /g;
	return $x;
}

sub parseline {
	my $self = shift;
	$_ = shift;
	#printf "parse line: %s, is header: %d\n", $_, $self->{isheader};
	#print "PL: length line: ". length($line) . "\n";
	return unless defined $_;
	return if $_ eq "";
	if(/^\s*#\s*(\w+)/) {
		my $kw = $1;
		if($kw eq "if" || $kw eq "ifdef" || $kw eq "elif" || $kw eq "else" || $kw eq "endif") {
			push @{$self->{macros}}, strip_macro($_);
			return;
		}
#		$self->{line} = "" if $self->{isheader};
#		return;
	}
	if($_ =~ /extern \"C\"/) {
#		$self->{line} = "";
		return;
	}
	#$self->{line} .= $_ . "\n" if(!$self->{openbraces} || $self->{line} ne "");
	#printf "%d\n", $self->{openbraces};
	$self->{line} .= $_ . "\n" if(!$self->{openbraces} || $self->{line} ne "");
	$self->scanbraces($_) unless $self->{line} =~ /^\s*#define/;

	#print "$_ , line is $self->{line}\n";
	
	if($self->{line} ne "" && !$self->{openbraces}) {
		#print "A $self->{line}\n";
		if($self->{line} =~ /^\s*#/) {
			if($self->{line} =~ /\\\s*$/) {

			} else {
				push @{$self->{macros}}, strip_macro($self->{line});
				$self->{line} = ""
			}
		} elsif($self->{line} =~ /([;\}]{1})\s*\n*$/) {
			if($1 eq ";") {
				#print $self->{line};
				if ($self->{line} =~ /=/ || $self->{line} =~ /^\s*static[\s\n]+/) {
					#print "extern!\n";
					$self->{line} =~ s/^\s*static\s*//;
					push @{$self->{extern}}, $self->{line};
				} elsif($self->{isheader}) {
					if(
						$self->{line} =~ /^\s*typedef\s+/
						|| $self->{line} =~ /^\s*union\s+/
						|| $self->{line} =~ /^\s*struct\s+/
					) {
						push @{$self->{typedefs}}, strip_macro($self->{line});
					} else {
						$self->handlesub($self->{line});
					}
				} else {
					push @{$self->{typedefs}}, $self->{line};
				}
				$self->{line} = "";
				return;
			}
			$self->handlesub($self->{line});
			$self->{line} = "";
		} 
	} #elsif($self->{isheader} && !$self->{openbraces} && $self->{line} eq "" &&
	#	/(extern\w){0, 1}
}

sub parse {

	my $self = shift;

	my $f;
	open($f, "<", $self->{cfile});

	while(<$f>) {
		
	#	print;
		chomp;
	#	print "$openbraces, $incomment\n";
		if (/^\s*#\s*include\s+[<\"]{1}[\w_\-\/\.]+[>\"]{1}/) {
			push @{$self->{includes}}, $_;
		} else {
			next if(/^\s*$/); #skip empty lines
			next if(/^\s*\/\//); #skip one line comments.
			# normal source code line.
			if (!$self->{incomment} && /(.*?)\/\*(.*?)$/) {
				$self->parseline($1);
				my $rest = $2;
				$self->{incomment} = 1 unless $rest =~ /\*\//;
			} elsif($self->{incomment}) {
				if(/\*\/(.*?)$/) {
					$self->parseline($2);
					$self->{incomment} = 0;
				}
			} else {
				$self->parseline($_);
			}
		}
	}
	close $f;
}

1;