package TemplateParser;

#-----------------------------------------------------------------------------
# This package parses a template file in the format explained below, and
# translates it into Perl code. See jeeves for where this package fits
# into the scheme of things.
# The template file recognizes the following directives ...
#   (keywords are case insensitive)
#   @OPENFILE <filename> [options] - closes the previous output file, 
#         the new file. 
#         Options: 
#            -append - open the file in append mode
#            -noOverWrite - do not overwrite the file if it already exists. 
#                  This is useful if you want to generate the file only once.
#            -onlyIfDifferent - puts all the output into a temp file, does a 
#                  diff with the given file, and overwrites it if the two 
#                  files differ - useful in a make environment, where you
#                  don't want to unnecessarily touch the file if the contents
#                  are the same, to preserve timestamps
#
#   @PERL <perl code> - Inserts the perl code in the output file untranslated
#   @FOREACH <var> [perl condition code] - iterates thru the array @var, using 
#                  the iterator variable $var_i. The iteration works 
#                  wherever the condition is true.
#
#   @END - terminates the loop
#   @//  - comment line, not reproduced in the intermediate perl file
#   All other lines in the template are left essentially untranslated.
#                                                               ... Sriram
#-----------------------------------------------------------------------------

sub Parse {
    # Args : template file, intermediate perl file
    ($templateFile, $interFile) = @_;
    unless (open (T, $templateFile)) {
	warn "$templateFile : $@";
	return 1;
    }
    open (I, "> $interFile") || 
	die "Error opening intermediate file $interFile : $@";
    
    EmitOpeningStmts();
    while ($line = <T>) {
	$line =~ /^\s*(.)/; # Extract first non space character
	if ($1 ne '@') {
	    EmitText($line);
	    next;
	} 
	next if ($line =~ m|\@//|);
	if ($line =~ /^\s*\@OPENFILE\s*(.*)\s*$/i) {
	    EmitOpenFile ($1);
	} elsif ($line =~ /^\s*\@FOREACH\s*(\w*)\s*(.*)\s*/i) {
	    EmitLoopBegin ($1,$2);
	} elsif ($line =~ /^\s*\@END/i) {
	    EmitLoopEnd();
	} elsif ($line =~ /^\s*\@PERL(.*)/i) {
	    EmitPerl("$1\n");
	};
    }
    EmitClosingStmts();
    
    close(I);
    return 0;
}


# All pieces of output code are within a "here" document terminated 
# by _EOC_
#

#----------------------------------------------------------------------
# EmitOpeningStmts
# ==> Emit ("Convert ROOT's properties to global variable names")
#
sub EmitOpeningStmts {
    Emit("# Created automatically from $templateFile");
    Emit(<<'_EOC_');

use Ast;
use JeevesUtil;

$tmpFile = "jeeves.tmp";

sub Output; # forward declaration
sub OpenFile;
if (! (defined ($ROOT) && $ROOT)) {
    die "ROOT not defined";
}

$file = "> -";
open (F, $file) || die $@;
$code = "";
$ROOT->Visit();
_EOC_
}

#------------------------------------------------------------------------
# EmitOpenFile 
# ==> Emit ("Close the previous file, and open the new filename for output
#

sub EmitOpenFile {
    $file = shift;
    $noOverWrite = ($file =~ s/-noOverwrite//gi) ? 1 : 0;
    $append = ($file =~ s/-append//gi) ? 1 : 0;
    $onlyIfDifferent = ($file =~ s/-onlyIfDifferent//gi) ? 1 : 0;
    $file =~ s/\s*//g;

    Emit (<<"_EOC_");
# Line $.
OpenFile(\"$file\", $noOverWrite, $onlyIfDifferent, $append);
_EOC_
}


#----------------------------------------------------------------------
# EmitLoopBegin
# ==> Emit ("manufacture an iterator name, and visit each element in 
#            that array")
# The best way to understand this code is to execute the schema compiler
# and look at the intermediate perl code.
#

sub EmitLoopBegin {
    $lName = shift; # Name of the list variable
    $condition = shift;
    $lName_i = $lName . "_i";
Emit (<<"_EOC_");
# Line $.
foreach \$$lName_i (\@\${$lName}) {
    \$$lName_i->Visit ();
_EOC_
    if ($condition) {
	Emit ("next if (! ($condition));\n");
    }
}

#----------------------------------------------------------------------
sub EmitLoopEnd {
    Emit(<<"_EOC_");
#Line $.
    Ast::UnVisit();
}
_EOC_
}

#----------------------------------------------------------------------
sub EmitPerl {
    Emit($_[0]);
}

#----------------------------------------------------------------------
sub EmitText {
    chomp $_[0];
    # Escape quotes in the text
    $_[0] =~ s/"/\\"/g;
    $_[0] =~ s/'/\\'/g;
    Emit(<<"_EOC_");
Output "$_[0]\\n";
_EOC_
}

#----------------------------------------------------------------------
sub EmitClosingStmts {
	Emit(<<'_EOC_');
Ast::UnVisit();
close(F);
unlink ($tmpFile);

sub OpenFile {
    local ($aFile, $aNoOverwrite, $aOnlyIfDifferent, $aAppend) = @_;

    #First deal with the file previously opened
    close (F);
    if ($onlyIfDifferent) {
	if (JeevesUtil::Compare ($origFile, $currFile) != 0) {
	    rename ($currFile, $origFile) || 
		die "Error renaming $currFile  to $origFile";
	}
    }

    #Now for the new file ...
    $currFile = $origFile = $aFile;
    $onlyIfDifferent = ($aOnlyIfDifferent && (-f $currFile)) ? 1 : 0;
    $noOverWrite = ($aNoOverwrite && (-f $currFile))  ? 1 : 0;
    $mode =  ($aAppend) ? ">>" : ">";

    if ($onlyIfDifferent) {
	unlink ($tmpFile);
	$currFile = $tmpFile;
    }

    if (! $noOverWrite) {
	open (F, "$mode $currFile") || die "could not open $currFile";
    }
}

sub Output {
    if (! $noOverWrite) {
	print F @_;
    }
}
_EOC_
}

#----------------------------------------------------------------------
sub Emit {
	print I $_[0];
}

1; # returns 1 if successfully compiled












