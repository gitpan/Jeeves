package SchemaParser;
use Ast;
#-----------------------------------------------------------------------------
# This file parses a schema file of the following structure:
#
# class Personnel {
#	int x,       // Attribute type and name
#            key = 1, get = 1, set = 1; // Properties
#	double y;
# };
#
# 
# Parse() creates an abstract syntax tree and returns the root object
# of the AST in $ROOT.
# The AST looks like this ...
#     ROOT has a property called "classList" with a list of all classes.
#     Each class has  properties "className" and "attrList"
#     Each attribute is an AST node with properties "attrName" and "attrType"
#                                                               ... Sriram
#-----------------------------------------------------------------------------
sub Parse{
	my ($fileName) = shift;
	my ($ROOT);
	open (P, $fileName) || die "Could not open $fileName : $@";

	$ROOT = Ast::New("Root");
	while (GetLine()) {
		if ($line =~ /^\s*class *(\w*)/) {
			$c = Ast::New($1);
			$c->AddProp("className" => $1);
		} else {
			next;
		}
		$ROOT->AddPropList("classList", $c);
		while (GetLine()) {
			last if ($line =~ /^\s*}/);
			if ($line =~ s/^\s*(\w*)\s*(\w*)//) {
				$a = Ast::New($2);  #attribute name
				$a->AddProp ("attrName", $2);  #attribute type
				$a->AddProp ("attrType", $1);  #attribute type
				$c->AddPropList("attrList", $a);
			}
			$currLine = $line;
			while ($currLine !~ /;/) {
				$currLine .= GetLine();
			}
			@props = split (/[,;]/,$currLine);
			foreach $prop (@props) {
			    	if ($prop =~
					/\s*(\w*)\s*=\s*(.*)\s*/) {
					$a->AddProp($1, $2);
				}
			}
		}
	}
	return ($ROOT);
}

sub GetLine {
	while ($line = <P>) {
		$line =~ s#//.*$##;
		return $line if ($line !~ /^\s*$/);
	}
}
1;


