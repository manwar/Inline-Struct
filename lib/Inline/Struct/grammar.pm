package Inline::Struct::grammar;
use strict;
use warnings;

our $VERSION = '0.11';

sub grammar {
   <<'END';

code: part(s) {1}

part: comment
    | struct
      {
	 my ($perlname, $cname, $fields, @aliases) = @{$item[1]};
         my @fields = map @$_, @$fields;
         push @{$thisparser->{data}{structs}}, $perlname;
	 $thisparser->{data}{struct}{$perlname}{cname} = $cname;
         $thisparser->{data}{struct}{$perlname}{field} = {reverse @fields};
         $thisparser->{data}{struct}{$perlname}{fields} =
            [ grep defined $thisparser->{data}{struct}{$perlname}{field}{$_},
              @fields ];
         Inline::Struct::grammar::typemap($thisparser, $perlname, $cname);
	 Inline::Struct::grammar::alias($thisparser, $cname, $_)
	   for @aliases;
      }
    | typedef
	{
	    my ($type,$alias) = @{$item[1]}[0,1];
	    Inline::Struct::grammar::alias($thisparser, $type, $alias);
	}
    | ALL

struct: 'struct' IDENTIFIER { $thisparser->{data}{current}="@item[1,2]" }
        fields ';'
           {
	    # [perlname, cname, fields]
	      [$item[2], "@item[1,2]", $item[4]]
	   }
	| 'typedef' 'struct' fields IDENTIFIER ';'
	   {
	    # [perlname, cname, fields]
	      [@item[4,4,3]]
	   }
	| 'typedef' 'struct' IDENTIFIER fields IDENTIFIER ';'
	   {
	      # [perlname, cname, fields, alias]
	      [$item[3], "@item[2,3]", $item[4], $item[5]]
	   }

typedef: 'typedef' 'struct' IDENTIFIER IDENTIFIER ';'
	{
	   ["@item[2,3]", $item[4]]
	}

fields: '{' field(s) '}' { [ grep ref, @{$item[2]} ] }

field: comment
     | type IDENTIFIER ';'
       {
         [@item[1,2]]
       }

IDENTIFIER: /[~_a-z]\w*/i

comment:  m{\s* // [^\n]* \n }x
	| m{\s* /\* (?:[^*]+|\*(?!/))* \*/  ([ \t]*)? }x

type: modifier(s?) TYPE star(s?)
	{
         $return = $item[2];
         $return = join ' ',@{$item[1]},$return if @{$item[1]};
         $return .= join '',' ',@{$item[3]} if @{$item[3]};
         return undef
           unless (defined $thisparser->{data}{typeconv}{valid_types}{$return} or
		   $return eq $thisparser->{data}{current} . " *"
		);
	}

modifier: 'extern' | 'unsigned' | 'long' | 'short' | 'const' | 'struct'

star: '*' | '&'

TYPE: /\w+/

ALL: /.*/

END

}

# Adds an entry in these fields of the parser:
# ->{data}{typeconv}{input_expr}
# ->{data}{typeconv}{output_expr}
# ->{data}{typeconv}{valid_types}
# ->{data}{typeconv}{valid_rtypes}
# ->{data}{typeconv}{type_kind}
sub typemap {
    my $parser = shift;
    my $perlname = shift;
    my $cname = shift;

    my $type = "O_OBJECT_$perlname";
    my $TYPEMAP = "$cname *\t\t$type\n";
    my $INPUT = <<'END';
    if (!sv_isobject($arg)) {
	warn ( \"$pname() -- $var is not a blessed reference\" );
	XSRETURN_UNDEF;
    }
    $var = ($type)SvIV((SV*)SvRV( $arg ));
    if (!$var) {
	warn ( \"$pname() -- $var is null pointer\" );
	XSRETURN_UNDEF;
    }
END
    my $OUTPUT = <<END;
        {
            HV *map = get_hv("Inline::Struct::${perlname}::_map_", 1);
            SV *lookup = newSViv((IV)\$var);
            STRLEN klen;
            char *key = SvPV(lookup, klen);
            sv_2mortal(lookup);
            if (hv_exists(map, key, klen)) {
                HV *info = (HV*)SvRV(*hv_fetch(map, key, klen, 0));
                SV *refcnt = *hv_fetch(info, "REFCNT", 6, 0);
                sv_inc(refcnt);
            }
            else {
                HV *info = newHV();
                SV *info_ref = newRV((SV*)info);
                hv_store(info, "REFCNT", 6, newSViv(1), 0);
                hv_store(info, "FREE", 4, newSViv(0), 0);
                hv_store(map, key, klen, info_ref, 0);
            }
        }
        sv_setref_pv( \$arg, "Inline::Struct::$perlname", (void*)\$var );
END

    $parser->{data}{typeconv}{input_expr}{$type} = $INPUT;
    $parser->{data}{typeconv}{output_expr}{$type} = $OUTPUT;
    $parser->{data}{typeconv}{valid_types}{$cname." *"}++;
    $parser->{data}{typeconv}{valid_rtypes}{$cname." *"}++;
    $parser->{data}{typeconv}{type_kind}{$cname." *"} = $type;
}

sub alias {
    my $parser = shift;
    my $type = shift;
    my $alias = shift;
    $type .= " *"; $alias .= " *"; # because I only deal with pointers.
    $parser->{data}{typeconv}{valid_types}{$alias}++;
    $parser->{data}{typeconv}{valid_rtypes}{$alias}++;
    $parser->{data}{typeconv}{type_kind}{$alias} =
      $parser->{data}{typeconv}{type_kind}{$type};
}

1;
