package Ast;

#-----------------------------------------------------------------------------
# This package is used  to create a simple Abstract Syntax tree. Each node
# in the AST is an associative array and supports two kinds of properties -
# scalars and lists of scalars.
# See SchemParser.pm for an example of usage.
#                                                               ... Sriram
#-----------------------------------------------------------------------------

sub BEGIN {
	$currLevel = 0;
	$indent = " " x 2;
}

# Constructor 
# e.g AST::New ("personnel")
# Stores the argument in a property called astNodeName whose sole purpose
# is to support Print()

sub New {
	my ($this) = {"astNodeName" => $_[0]};
	bless ($this);
	return $this;
}

# Add a property to this object
# $astNode->AddProp("className", "Employee");

sub AddProp {
	my ($this) = $_[0];
	$this->{$_[1]} = $_[2];
}

# Equivalent to AddProp, except the property name is associated
# with a list of values
# $classAstNode->AddProp("attrList", $attrAstNode);

sub AddPropList {
	my ($this) = $_[0];
	if (! exists $this->{$_[1]}) {
		$this->{$_[1]} = [];
	}
	push (@{$this->{$_[1]}}, $_[2]);
}

# Returns a list of all the property names of this object
sub GetProps {
	my ($this) = $_[0];
	return keys %{$this};
}

sub Visit {
    # Converts each of this AstNode's properties into global variables.
    # The global variables are introduced into package "main"
    # At the same time, a piece of code is  formed to undo this work above -
    # $endCode essentially contains the values of these global variables
    # before  they are mangled. endCode gets pushed into a stack (endCodes),
    # which is unwound by UnVisit().

    local ($this) = @_;
    $code = ""; $endCode = "";
    foreach $k (keys %{$this}) {
	if (defined $$k) {
	    $endCode .= '$main::' . $k . ' = "' . ${"main::$k"} . '";';
	} else {
	    $endCode .= '$main::'. $k . ' = " ";';
	}
	$code .= '$main::' . $k . "= \$this->{\"$k\"};";
    }
    push (@endCodes, $endCode);
    eval($code) if $code;
}

sub UnVisit {
    $code = pop(@endCodes);
    eval($code) if ($code);
}

# Recursively prints the entire AST tree.
sub Print {
	my ($this) = $_[0];
	my($currIndent);
	my($i), my($o), my($prop);
	$currIndent = $indent x $currLevel;
	print "${currIndent}name :", $this->{"astNodeName"}, "\n";
	$currIndent .= $indent ;
	++$currLevel;
	foreach $prop (keys %$this) {
		next if ($prop eq "astNodeName");
		$o = $this->{"$prop"};
		if (ref($o) eq "Ast") {
			$o->Print();
		} elsif (ref($o) eq "ARRAY") {
			foreach $i (@{$o}) {
				$i->Print();
			}
		} else {
			print "${currIndent}$prop: $o \n";
		}
	}
	--$currLevel;
}


1;
