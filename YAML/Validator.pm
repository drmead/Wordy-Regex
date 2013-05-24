# YAML::Validator version 2012-09-24
#
# RENAMING:
#
# This module was called YAML_validator.pm
# That module is now frozen.
#

# RECENT CHANGE(S) NOTICE:
#
# (1) Compact vs. Kwalify schemas
#
#   This module used to accept schemas in compact or kwalify formats, and
#   automagically determine whether the schema is compact, kwalify or mixed.
#
#   The default behaviour has changed so that schemas are assumed to be in compact
#   format unless:
#         - this module is notified by an option, or
#         - the schema explicitly states kwalify: yes
#
# (2) Unload functionality improved
#   The still-somewhat-experimental unload method now has the ability to unload
#   tables in the YAML-extended format that the load functions accept.
#   The current version exports a table as an array of strings, which is acceptable
#   but different from the multi-line text block that may be the most popular
#   format for tables.
#
# (3) Support for data type timestamp (a date followed by a time)
#
# (4) CSV format input and output.
#       csv: boolean
#       csv_with_header: boolean
#       unload_format: csv | csv_with_header
#     The expected method of use for csv input is to define the csv file as a table.
#     The file contents are then loaded into an array of hashes, with keys
#       based on column name, with any validation errors reported.
#     The unload method and the unload_data function allow a table (i.e. an
#       array of hashes) to be unloaded into csv format


# IMPENDING CHANGES WARNING:
#
# (1) Implied values lists
#
#   This module currently allows lists of allowed data values to be specified
#   as a simple comma-separated list without any keyword.
#   It will change to require the keyword 'values' (or 'enum') before a list.
#
# (2) Relaxed and Update options
#
#   The current default is to apply relaxed rules for data, even if update
#   is false. This will change, as it carries serious misinterpretation risks.
#   For example, the number 12,345 would be accepted as an integer - but Perl
#   would treat it as the number 12.
#
#   The new default will mean that 'relaxed' will default to false if 'update'
#   is false.
#   The caller can explicitly specify the combination of relaxed: true with
#   update: false. This might be appropriate, for example, when the data being
#   validated is only going to be displayed.

package YAML::Validator;
my $this_package_name = 'YAML::Validator';
require Exporter;
use vars qw(@ISA @EXPORT_OK $YAML_LIB);   # Support ancient Perl!
(@ISA) = ("Exporter");
(@EXPORT_OK) = qw(errors_in_data load_and_validate unload_data);

use strict;
use warnings;
use Time::Local;
use YAML::Tiny;

my $DEFAULT_YAML_LIB = 'Tiny';
##$YAML_LIB = 'Tiny';
##use YAML::XS qw(Load);

print "YAML::Validator module invoked as a program - does nothing\n" unless caller();

=format

YAML::Validator

This module validates data against a schema.

The data to be validated and the schema may be in YAML format, or either or both
may already have been loaded into Perl structures. 

If the data is found to be invalid according to the schema, the validator
produces error message text for each error that attempts to explain why the
data is not valid, and where in the structure the invalid data is located.

The validator uses YAML::Tiny or YAML::XS to load YAML into Perl structures. If
YAML::Tiny is selected, YAML data and schemas must conform to the YAML subset
that YAML::Tiny supports, and the error text may be cryptic if invalid YAML is
supplied.

Two schema notations are supported - compact and kwalify.

Compact schema notation aspires to be as human-friendly as possible, within the
self-imposed architectural limitation that the notation has to be valid YAML.

Kwalify schemas are supported: they are the format used internally within the
validator for performance reasons; they support a few facilities not yet 
supported by compact schemas; and they are simpler to generate in the situation 
where the schema itself is being created by code.


Examples of use:

    # OO-interface
        # Create a validator object based on a schema...
    
        my $validator_x = YAML_validator->new($schema);
    
        # ...which is then used to validate data
    
        if ( $validator_x->data_is_invalid($data) ){
            # The data (or the schema) is invalid
            # Print an intelligible error message
            die $validator_x->errors();
        }
        # ...or to validate data and return a structure containing the data
        my $data_ref = $validator_x->load_data($data) or die $validator_x->errors(); 


    # Procedural interface
        ($data_ref, $errors) = load_and_validate($data, $schema)
        die $errors if $errors;
    
    In the examples above, $schema and $data can be:
        - a reference to a Perl structure containing the data or schema, or
        - a YAML-format text string (the schema or data itself), or
        - < and the name of a text file containing the schema or data in YAML, or
        - a file handle of a text file containing the schema or data in YAML


SYNOPSIS:
=========

OO interface:
------------

    validator = YAML::Validator->new(schema, [options])
    
    (loaded_data, errs) = validator->load_data(data, [options])
     loaded_data        = validator->load_data(data, [options])

     errs        = validator->data_is_invalid(data, [options])
    
     errs        = validator->errors()  # any errors from preceding call
     errs        = validator->errors(data, [options]) # any errors in this data
     
    (unloaded_data , errs) = validator->unload(data, [options])
     

Procedural interface:
--------------------

    (loaded_data, errs)   = load_and_validate (data, schema, options)
    (unloaded_data, errs) = unload_data       (data, schema, options)
     errs                 = errors_in_data    (data, schema, options)
    

Options:
--------

    The general idea is that there are two ways of using this module:

        (1) to just validate the data
        (2) to validate the data, and also convert it to a more convenient form
    
    If you just want to validate the data, you may want to be certain that
    the data is not modified in any way by this module. If update is false,
    this module does not do any intentional modifications to the data. However,
    there is some risk that it could unintentionally modify the data, for
    example due to auto-vivification.

    Update defaults to true when the user calls:
       load_data()          -- the OO method
       load_and_validate()  -- the procedural routine
       
    Update defaults to false when the user calls:
       errors(), or
       errors_in_data(), or
       data_is_invalid()


update:    boolean
            True means the data structure can be updated
            Default is true for load_and_validate() and obj->load_data()
            Default is false for errors_in_data()

relaxed: boolean
        True means data values are treated as valid if they make sense, even
        if they don't strictly conform to the YAML spec, e.g. commas in numbers.
        If update is also true, the data will be updated, e.g. the commas will
        be removed.
        
        For dates, relaxation means allowing e.g. 20/02/14 or 20 Feb 2012
        as well as the standard YAML 2014-02-20 format.

dates:
    external:  default ddmmyy  values ddmmyy, mmddyy, US, UK, Aus, NZ
            Allow dates to be entered in a format other than yyyy-mm-dd
			
			mmddyy or US specify US-formatted dates, so that 01/02/2013 would be 
			treated as being 2nd January 2013
			
			ddmmyy or UK or Aus or NZ specify British dates, so that 01/02/2013
			would be treated as being 1st February 2013
			

    internal:  epoch, excel
            Dates will be converted into this internal format (if update true)

enumerations:           
   case:
       insensitive: boolean
       force:       upper, lower, title, no=false=off [not implemented, might not be]
   punctuation:
       ignore: boolean
       strip:  boolean
keys:
   case:
       insensitive: boolean
       force:       upper, lower, title, no=false=off [not implemented, might not be]
   punctuation:
       ignore: boolean
       strip:  boolean
scalar:
    sequence=seq=array: boolean
        Allows a scalar found when a sequence is expected
        A scalar will be split on newlines, pipes or commas
    map=mapping=hash:   boolean
        Allows a scalar found when a map is expected. A scalar will be parsed
        into keys and values
      
internalise: boolean
        # True means that data will be converted to internal formats, e.g. dates
        # will be converted to epoch seconds or Excel days, and booleans will be
        # converted to values that evaluate true or false. Ignored if update is
        # false.

        # Relaxation doesn't change the data, it just determines whether
        # data in a different format is acceptable. Internalisation actually
        # changes the data, so it is only done if both internalise and update
        # are true.

Notes on update
    True means the data structure can be updated
         Data updates are done to support:
            Default values
                If a hash key is omitted but the schema specifies a default, the
                default value is inserted into the hash in the data
            Data conversion to internal format
                number:  remove commas
                boolean: convert to values that are true or false in Perl
                date:    convert to internal format (epoch seconds, or Excel)
            Case matching of enumerated values
                Values will have their case changed to match the schema
            Case matching of mapping keys
                Keys will have their case changed to match the schema
            Case forcing of scalar data
                Data can be forced to upper, lower or title case [not implemented]
            Punctuation matching of enumerated values
                Values will have their punctuation changed to match the schema
            Punctuation matching of mapping keys
                Keys will have their punctuation changed to match the schema
            Equivalent keys
                Keys that are equivalents are replaced by the first key.
                For example, if the schema specifies post=mail:
                      mail: in the data will be changed to post:
            Equivalent enumerated values
                Values that are equivalents are replaced by the first value.
                For example, if the schema contains 'values M=Male, F=Female'
                then Male in the data would be changed to M
            Scalars supplied when a sequence/array was expected
            Scalars supplied when a map/hash was expected
            Tabular data entry
                Data in a table will be loaded into an array of hashes, one
                per row. Each hash has one entry for each column
        
         

Compact Schema Notation
=======================

#
# Compact schema - simple example 1
# ---------------------------------


# Illustrates:
#   Types (such as 'int', 'date' and 'number')
#   Implicit types (if not stated, it is 'scalar', which allows multi-line strings)
#   Required fields
#   Minimum and maximum values (e.g. for 'quantity')
#   Patterns: regular expressions (e.g. for 'state' and 'sku')
#   Length limits
#   Enumerations: a comma-delimited list of values (e.g. for 'mode')
#   Mappings: defined by providing the allowable keys
#   Sequences: defined by providing a sequence (e.g. order-lines)
#   Comments: introduced by a hash symbol '#'

invoice : required int
date    : required date
bill-to :
    given   :
    family  :
    address :
        lines    : # This is a text field, not a sequence
        city     :
        state    : /[A-Z][A-Z]/ 
        postcode :
order-lines :
    # This is a sequence, with one order line per entry
    -
      sku         : / [A-Z] [A-Z] \d{3,4} [A-Z] /x
      quantity    : int min 1 max 999
      description : length 1 to 120
      price       : number
tax   : number
total : required number
mode  : post, "air mail", courier
comments: 

#
# Sample valid data for example schema 1
# --------------------------------------

invoice: 34843
date   : 2001-01-23
bill-to:
    given  : Chris
    family : Dumars
    address:
        lines: |
            458 Walkman Dr.
            Suite #292
        city     : Royal Oak
        state    : MI
        postcode : 48046
mode   : air mail
order-lines:
    - sku         : BL394D
      quantity    : 4
      description : Basketball
      price       : 450.00
    - sku         : BL4438H
      quantity    : 1
      description : Super Hoop
      price       : 2392.00
tax  : 251.42
total: 4443.52
comments: |
    Late afternoon is best.
    Backup contact is Nancy
    Billsmer @ 338-4338.



Confession: YAML_validator is not really a YAML validator.
---------------------------------------------------------

1) YAML_validator doesn't have the smarts to actually validate YAML.
2) YAML_validator validates a data structure against a schema, but neither the
   data nor the schema have to be in YAML format
   
This module is a structure validator that *supports* YAML. Any YAML you supply
is passed to a YAML module to be converted to a structure before this module
uses it, and if the YAML is not well-formed you will just be given the error
text from the YAML module.

One useful side-effect of this is that you can use this module to check data
that is being passed to you as a reference to a Perl structure.

This module does have a dependency on a YAML library. Even if your data and
schema are in Perl structures, this module uses YAML::Tiny or YAML.pm for its
internal purposes.



Tabular data
------------
    This is an extension to YAML that allows data to be entered in rows and
    columns. Each row of data has two or more columns, which can be separated by
    commas or pipe (vertical bar) characters.

    The data is entered as a array/sequence with a line of text for each row: if
    you select the update option, each row will be loaded into a hash/map with
    each column keyed by its column name.
        
    Each row within a table has the same columns, but each column can have its
    own validation rules.
    
    Within a compact schema you define a table by defining a sequence, with the
    definition of each column starting with its name within angle brackets. So
    to define a table of people with columns for name and position:
    
        # Compact schema defining a table
        
        people:
            - <name>, <position> 
            
        # Data to be entered into a table
        
        people:
            - Peter Smith,   Secretary
            - Anna Gables,   Treasurer
            - Mary Black,    Chair
        
    If the data fields contain any commas, use pipes to separate the fields
    
        # Data (with commas) to be entered into a table
        
        people:
            - Dr. Peter Smith, PhD  | Secretary
            - Ms. Anna Gables       | Treasurer
            - Dr. Mary Black, MBChB | Chair

    

====
Q&As
====

Q) What were the design aims?
A) To provide an easy-to-use validation capability in Perl for the simple sorts
   of YAML that are used for config files, data persistence and inter-program
   communication.

Q) Why does it support YAML::Tiny as well as YAML.pm?
A) - To allow it to be useful within programs that already use YAML::Tiny
   - To avoid a dependency on a really big module
   - For performance (YAML::Tiny is about 5x faster than YAML.pm)
   
Q) Can I have a version that uses YAML::XS (or some other YAML module)?
A) This version supports the use of YAML::XS, YAML::Tiny or YAML.pm for
   loading and unloading YAML data. The mechanism is clunky (you have to
   assign a code value to $YAML::Validator::YAML_LIB) and is likely to
   change when I find a cleaner way to do it.
   You can use your preferred YAML module to load your data and
   schema into Perl structures, then just pass those to this module.
   Note that the Validator currently needs YAML::Tiny for its own purposes: this
   dependency should be removed when the mechanism which chooses which YAML
   module to use is tidied up.

Q) Why does it support two different schema notations?
A) Compact schema notation is shorter, easier to create, and more intelligible.
   Kwalify schema notation has some options that are not available in compact
   schemas, although they are gradually being made available in compact schemas.
   It started out supporting just kwalify, but I wanted something that was
   closer to YAML's philosophy of human-friendliness. It uses kwalify schemas
   internally - compact schemas are converted when they are loaded.

Q) When do I have to use kwalify schema notation?
A) For the following features that are not (yet) available in compact notation:
     
     - to use the define/use feature for anything other than a plain scalar
     - to specify a minimum and/or maximum number of entries in a sequence or
       keys in a mapping.

Q) Why does it refer to hashes as mappings, and arrays as sequences?
A) That's the standard YAML terminology, and YAML isn't tied to any particular
   programming language. There is an option to output Perl terminology in error
   messages. 

Q) What intentional differences are between the way the kwalify notation
   as implemented by this module and the kwalify.rb validator implemented in
   Ruby?
A) - kwalify.rb types are exclusive: e.g. it won't accept the data value 123
     in a field of type 'str', because it is a valid number. Similarly,
     kwalify.rb won't allow 'no' as a text field because it is a valid boolean.
     This module has inclusive types, e.g. it accepts a number as a valid str.
     
   - This module requires patterns to match the entire field unless the pattern
     is delimited by double slashes (//), whereas kwalify.rb matches
     patterns to any sub-part of the field unless there are explicit start and
     end markers ( ^ and $ ) in the pattern.
   
   - This module supports define: and use:. Kwalify.rb supports the standard
     YAML & (anchor) and * (alias) notation, so it doesn't need define: and use:.
     YAML::Tiny doesn't support & and *, so this module provides define: and use: 
     as an alternative way of allowing parts of schemas to be re-used.

Q) How do I tell the module whether I'm supplying a compact schema or a
   kwalify one?
A) You don't, usually: it works out whether each part of the schema is in
   compact or kwalify notation using its own heuristics. If it gets it wrong,
   you can override it by adding a kwalify: false or kwalify: true key to a
   hash.

Q) What are the main limitations of YAML::Tiny?
A) - No multi-line plain scalars: you have to use a | or > indicator
   - No flow style mappings using { and }
   - No flow style sequences using [ and ] 
   - No quoted keys for mappings
   - No anchor (&) or alias (*)
   - Error messages are sometimes cryptic

Q) Can I have a recursive schema?
A) Only by using define: and use: - if you make a schema recursive by use of the
   YAML anchor and alias (& and *) facility, the module will go into an infinite
   loop.
   

Security Alert
==============

Patterns within a schema are allowed to contain arbitrary regular expressions in
Perl format, so they could include embedded Perl code which will be executed.
User-supplied schemas allow a user to execute Perl code that they supply, so
they should be allowed only within controlled environments. This only applies
to the schemas: there are no known security issues with the data.

#
# Kwalify-style schema - simple example 1
# ---------------------------------------
#
# This is functionally identical to the compact schema shown above.
# You normally won't have to use kwalify-style schemas, as compact schema
# notation provides almost the same functionality.
# Compact schemas are converted to kwalify-style schemas internally by the
# validator, and can be output for debugging purposes (also see schema2k.pl)

type: map
mapping:
    bill-to:
        type: map
        mapping:
            address:
                mapping:
                    city:
                    lines:
                    postal:
                    state:
                        pattern: '/[A-Z][A-Z]/'
                type: map
            family:
            given:
    comments:
    date:
        type: date
    invoice:
        range:
            max: 99999
            min: 1000
        type: int
    mode:
        enum:
            - post
            - 'air mail'
            - courier
    order-lines:
        type: seq
        sequence:
            -
                mapping:
                    description:
                        length:
                            max: 120
                            min: 1
                    price:
                        type: number
                    quantity:
                        range:
                            max: 999
                            min: 1
                        type: int
                    sku:
                        pattern: '/ [A-Z] [A-Z] \d{3,4} [A-Z] /x'
                type: map
    tax:
        type: number
    total:
        type: number

=cut


# Get the options schema 

my $options_schema_ref = _options_schema();

# Get and pre-process the meta schema
            
my $meta_schema_ref = _get_meta_ref();
$meta_schema_ref->{mapping}{options} = $options_schema_ref;

my %meta_anchor_hash;
my @meta_error_array;

    
my $SCHEMA_FORMAT_AUTO           = 0;
my $SCHEMA_FORMAT_STRICT_KWALIFY = 1;
my $SCHEMA_FORMAT_COMPACT_ONLY   = 2;

# Pre-process the meta-schema, but only to find anchors
my $pre_processed_meta_schema_ref = _pre_process_schema($meta_schema_ref,
                                    \@meta_error_array,
                                    \%meta_anchor_hash,
                                    $SCHEMA_FORMAT_STRICT_KWALIFY,
                                    ##$SCHEMA_FORMAT_AUTO,
                                    '/meta/',
                                    );    
            


# Global constants
my $BOOLEAN_TRUE_VALUES  = 'y|Y|yes|Yes|YES|t|T|true|True|TRUE|1';
my $BOOLEAN_TRUE_REGEX   = "^(?:$BOOLEAN_TRUE_VALUES)\$";
my $BOOLEAN_FALSE_VALUES = 'n|N|no|No|NO|f|F|false|False|FALSE|0';
my $BOOLEAN_FALSE_REGEX  = "^(?:$BOOLEAN_FALSE_VALUES)\$";

my $PERL_NAMES = 0;

my $MAP_WORD        = $PERL_NAMES ? 'hash'     : 'map';
my $SEQUENCE_WORD   = $PERL_NAMES ? 'array'    : 'sequence';
my $A_SEQUENCE_WORD = $PERL_NAMES ? 'an array' : 'a sequence';


# Currently a global constant, might be changeable via an option sometime
# Controls whether sequence positions in error messages start at zero or 1.
# 'Zero' make sense for Perl developers, as sequences are loaded into Perl
# arrays starting with [0].
# 'One' makes sense to non-programmers, as the ordinal position of the first
# entry in a sequence.
# So which is appropriate depends on who is going to be reading the messages.
my $SEQUENCE_MESSAGE_BASE = 0;

# Similarly for column numbers - but even developers would probably expect
# the first column to be column 1. 
my $COLUMN_NUMBER_MESSAGE_BASE  = 1;
# If the column data is loaded into a Perl array the first entry will be 
# determined by this value.
# If set to 1, the table will have undef in every column [0].
my $COLUMN_NUMBER_LOADING_BASE  = 0;

=format
Indented regex versions of the type regexes:

date
    start-of-string 
    optional  0 1 2 
    digit 
    : 
    0-5 
    digit 
    optional  
        0-5 
        digit 
    optional  
        whitespace-char 
        'AM' 'am' 'PM' 'pm' 
    either
        optional newline
        end-of-string
    or 
        one or more spaces
        '#'

time
    start-of-string 
    optional  0 1 2 
    digit 
    : 
    0-5 
    digit 
    optional  
        0-5 
        digit 
    optional  
        whitespace-char 
        'AM' 'am' 'PM' 'pm' 
    either
        optional newline
        end-of-string
    or 
        one or more spaces 
        '#'
=cut

my %REGEX_TYPES = (
                    ## Some of these regexes handle trailing comments as part of
                    ## the data field, although text and string fields do not.
                    ## Better to have a table which decides whether comments
                    ## are allowed, and strip them out before they hit the regex
                    str     => qr/.*/,
                    string  => qr/.*/,
                    text    => qr/^[\x09\x0a\x0d\x20-\x7e\x85\xa0-\xff]*$/,
                    int     => qr/^[+-]?\d+(?:$|[ ]+\#)/,
                    ## integer => "^[+-]?\\d+\$",
                    float   => qr/^[+-]?\d+[.]\d+(?:$|[ ]+\#)/,
                    number  => qr/^[+-]?\d+[.]?\d*(?:$|[ ]+\#)/,
                    ## num     => "^[+-]?\\d+[.]?\\d*\$",
                    bool    => qr/^(?:$BOOLEAN_TRUE_VALUES|$BOOLEAN_FALSE_VALUES)(?:$|[ ]+\#)/,
                    ## boolean => "^(?:$BOOLEAN_TRUE_VALUES|$BOOLEAN_FALSE_VALUES)\$",
                    scalar  => qr/.*/,
                    date    => qr/^(?:19|20)\d{2}-\d{2}-\d{2}(?:$|[ ]+\#)/,
                    ## time    => qr/ ^ [012]?\d : [0-5]\d : [0-5]\d (?: \s (?: AM|am|PM|pm))?(?:$|[ ]+\#)/x,
                    time    => qr/ ^ (?: [01]?\d | 2[0-3] )  # hour:   0 to 9, 00 to 09, or 10 to 19, or 20 to 23
                                        : [0-5] \d           # minute: colon then 00 to 59
                                        : [0-5] \d           # second: colun then 00 to 59
                                        (?: $ | [ ]+ \# )/x,                                        # end-of-string or trailing comment
                    timestamp
                            => qr/ ^                       # start of string
                                (?:19|20)\d{2}-\d{2}-\d{2} # date
                                [ ]+                       # space(s)
                                (?: [01]?\d | 2[0-3] )     # hour:   0 to 9, 00 to 09, or 10 to 19, or 20 to 23
                                            : [0-5] \d     # minute: colon then 00 to 59
                                            : [0-5] \d     # second: colun then 00 to 59
                                (?: $ | [ ]+ \# )/x,                                        
                                                             # end-of-string or trailing comment
                  );


my %TYPE_SYNONYMS = (
                    string   => "str",
                    mapping  => "map",
                    sequence => "seq",
                    integer  => "int",
                    num      => "number",
                    boolean  => "bool",
                    );

my %TYPE_UPDATERS = (
                    int       => \&_update_int,
                    float     => \&_update_float,
                    number    => \&_update_num,
                    bool      => \&_update_bool,
                    boolean   => \&_update_bool,
                    date      => \&_update_date,
                    time      => \&_update_time,
                    timestamp => \&_update_timestamp,
                     );
my %TYPE_IS_NUMERIC = (
                    str       => 0,
                    text      => 0,
                    int       => 1,
                    float     => 1,
                    number    => 1,
                    bool      => 0,
                    scalar    => 0,
                    date      => 0,
                    time      => 0,
                    timestamp => 0,
                          );

# Constants for update routines
my $RELAXED = 1;
my $INTERNALISE = 0;

my %SCHEMA_VALID_KEYS = 
     map { ($_ => 1) } qw{required enum pattern type map mapping seq sequence
                          range length assert unique name desc class default
                          ident size define use
                          columns
                         };
    
my $yaml_load_imported = 0;

sub _choose_YAML_lib {
    if (! defined $YAML_LIB) {
        $YAML_LIB = $DEFAULT_YAML_LIB;
    }
    if ($YAML_LIB =~ /Tiny/ix) {
        require YAML::Tiny;
        
    } elsif ($YAML_LIB =~ /XS/ix) {
        require YAML::XS;
        YAML::XS->import(qw(Load)) unless $yaml_load_imported++;
    } elsif ($YAML_LIB =~ /YAML/ix) {
        require YAML;
        YAML->import(qw(Load))  unless $yaml_load_imported++;
    } else {
        print "YAML lib: $YAML_LIB\n";
    }
}
# --------------------------------------------------------------------
sub _YAML_load {
    my ($arg) = @_;
    my $no_newline   = $arg !~ /   \n       /x;
    my $leading_dash = $arg =~ / ^ \s* - \s /x;
    my $prepend_dash = $no_newline && ! $leading_dash;
    $arg = '- ' . $arg if $prepend_dash;
    
    _choose_YAML_lib();
    
    if ($YAML_LIB =~ /Tiny/ix) {

        my $loaded_tiny;

        eval { $loaded_tiny = YAML::Tiny->read_string("$arg\n") };
        my $err = $@;
        if ($err) {
            return (undef, $err)
        } else {
            $err = YAML::Tiny->errstr();
            if ($err) {
                return (undef, $err)
            } 
            if ($prepend_dash) {
                return( $loaded_tiny->[0][0], $err);    
            } else {
                return( $loaded_tiny->[0],    $err);    
            }
        }        
    } elsif ($YAML_LIB =~ /XS/ix) {
        my @loaded;
        eval { (@loaded) = YAML::XS::Load($arg) };
        my $err = $@;
        if ($err) {
            my $pause = 1;
        }
        if ($prepend_dash) {
            return( $loaded[0][0], $err);    
        } else {
            return( $loaded[0],    $err);    
        }
    } elsif ($YAML_LIB =~ /YAML/ix) {
        my @loaded;
        if (substr($arg, -1, 1) ne "\n") {
            $arg .= "\n";
        }
        eval { (@loaded) = YAML::Load($arg) };
        my $err = $@;
        if ($err) {
            my $pause = 1;
        }
        if ($prepend_dash) {
            return( $loaded[0][0], $err);    
        } else {
            return( $loaded[0],    $err);    
        }        
    } else {
        return( undef, "Unrecognided YAML lib name: $YAML_LIB");
    }
}

# --------------------------------------------------------------------
sub _YAML_dump {
    # Returns a string containing a YAML representation of the structure
    # passed as the only argument.
    # Makes use of YAML::Tiny, YAML::XS or YAML.pm depending on the value of $YAML_LIB
    #
    

    my ($arg) = @_;
    if ($YAML_LIB =~ /Tiny/ix ) {
        my $yaml_schema = YAML::Tiny->new();
        $yaml_schema->[0] = $arg;
        my $dumped_tiny;
        eval {$dumped_tiny = $yaml_schema->write_string()};
        ##    my $dumped_tiny;
        ##    eval { $dumped_tiny = YAML::Tiny->write_string($arg) };
        my $err = $@;
        if ($err) {
            return (undef, $err)
        } else {
            $err = YAML::Tiny->errstr();
            if ($err) {
                return wantarray ? (undef, $err) : undef;
            } else {
                return wantarray ? ($dumped_tiny, $err) : $dumped_tiny;
            }
        }
    } elsif ($YAML_LIB =~ /XS/ix) {
        my $dumped;
        eval { $dumped = YAML::XS->Dump($arg) };
        my $err = $@;
        return wantarray ? ($dumped, $err) : $dumped;
    } else {
        my $dumped;
        eval { $dumped = YAML->Dump($arg) };
        my $err = $@;
        return wantarray ? ($dumped, $err) : $dumped;
    }
}


# --------------------------------------------------------------------
sub new {
    
    # new:  OO constructor
    #
    # Expects:
    #
    #   1) Schema
    #       The schema that will be used by the validation.
    #       Can be supplied as any of the following:
    #           - A string (in YAML format)
    #           - A structure (with the schema pre-loaded)
    #           - a file-name (a text string starting with '<', of a file
    #                          containing the schema in YAML format)
    #           - a file handle (of a file containing the schema in YAML format)
    #   
    #   2) Options
    #       
    #       An optional hash containing some of the following elements:
    #           ## NOT YET ## notation: 'compact', 'auto' (the default) or 'kwalify'
    #           lib:      a reference to a YAML_validator object to use as a
    #                     library of definitions
    #
    #       TO DO: 
    #              Store options in object
    #              Make later method calls use stored options as defaults
    # Returns:
    #
    #   A validator object.
    #
    #   If any errors are detected, a subsequent call to the error() method
    #   will return a text description of the error - even if there has been an
    #   intervening call to the data_is_invalid method.
    
    # Pre-process schema, create schema and definitions structures
    #
    # Validate the schema against a meta-schema
    #

    my ($class, $schema, $opts_ref) = @_;
    
    my $self = { };
    
    my @error_array = ();    # empty array of error messages
    
    my ($pre_processed_schema_ref, $updated_options_ref, $anchors_ref) =
      _setup_schema($schema, $opts_ref, _default_options_common(), \@error_array );
     

    if (scalar @error_array) {
        $self->{'schema-errors'} = \@error_array;
    } else {
        $self->{'schema'}  = $pre_processed_schema_ref;
        $self->{'anchors'} = $anchors_ref;
        $self->{'options'} = $updated_options_ref;
    }
    
    bless ($self, $class);
    return $self;
}
# --------------------------------------------------------------------
sub _setup_schema {
    
    
    # Passed:
    #
    #   1) a schema-describing argument
    #   2) an options-describing argument, or undef
    #   3) default options
    #   4) a reference to the error array
    # Returns references to:
    #   1) the schema
    #   2) an options structure
    #   3) an anchors structure
    #
    # Parses the options-describing argument and applies default options
    # Parses the schema-describing argument
    # Pre-processes the schema
    # Validates the schema against the meta schema
    # Populates the error array if any errors found
    
    my ($schema, $opts_ref, $defaults, $error_array_ref) = @_;
    
    my ($updated_options_ref, $options_errors)
            = _check_options($opts_ref, $defaults );
    if ($options_errors) {
        push @{$error_array_ref}, split( /\n/, $options_errors);
        return (undef, undef, undef);
    }
    my $schema_updated_ref;
    my $schema_error_text = '';
    ($schema_error_text, $schema_updated_ref) = _accept_or_parse_arg($schema);
    
    if ($schema_error_text) {
        # Could not interpret the schema argument
        push @{$error_array_ref}, split(/\n/, $schema_error_text);
        return (undef, undef, undef);
    } else {
        # Could read schema
        # Pre-process the schema
        
        my %this_schema_anchors;
        my $anchor_ref;
        
        if ( $updated_options_ref->{'lib'} ) {
            my $ref_opts_ref = ref $updated_options_ref->{'lib'};
            if ( $ref_opts_ref eq $this_package_name ) {
                # Passed a validator object - so use its anchor table
                $anchor_ref = $updated_options_ref->{'lib'}{'anchors'};
            } elsif ( $ref_opts_ref eq 'HASH' ) {
                # Passed a hash - use the hash itself
                $anchor_ref = $updated_options_ref->{'lib'}
            } else {
                $error_array_ref->[0] = "Options error: lib is not a $this_package_name or a hash";
            }
        } else {
            $anchor_ref = \%this_schema_anchors;
        }
        my $pre_processed_schema_ref = _pre_process_schema(
                                                   $schema_updated_ref,
                                                   $error_array_ref,
                                                   $anchor_ref,
                                                   undef,           # auto
                                                   'preprocess/',
                                                          );
        if (scalar @{$error_array_ref}) {
            # Pre-processor found errors in schema
            return (undef, undef, undef);
        } else {
            # Pre-processor updated schema OK
            # Check the updated schema against the meta-schema   

            my $meta_options_ref = ## {update=> 1, relaxed => 1, internalise => 1};
                              {update => 1,
                               relaxed => 1,
                               internalise => 1,
                               keys  => {equivalents => 1},
                               enumerations => {equivalents => 1},
                               scalar => {map => 1, sequence => 1},
                              }; 
            my $actual_result = _is_structure_invalid(
                                                    $pre_processed_schema_ref,
                                                    $meta_schema_ref,
                                                    $error_array_ref,
                                                    'schema/',                                        
                                                    undef,
                                                    \%meta_anchor_hash,
                                                    $meta_options_ref,
                                                     );
            if (scalar @{$error_array_ref} ) {
                return (undef, undef, undef);
            } else {
                return ($pre_processed_schema_ref,
                        $updated_options_ref,
                        $anchor_ref
                       );
            }
        }
    }
}
# --------------------------------------------------------------------
sub data_is_invalid {

    # data_is_invalid:  OO method
    #
    #
    # Expects:
    #
    #   1) Data
    #       The data to be validated.
    #       It can be supplied as any of the following:
    #           - A string (in YAML format)
    #           - A structure (with the data pre-loaded)
    #           - a file-name (a text string starting with '<', of a file
    #                          containing the data in YAML format)
    #           - a file handle (of a file containing the data in YAML format)    
    #   
    #   2) Options
    #       An optional hash. Option supplied to this method over-ride
    #       the option supplied to the constructor.
    #
    # Returns:
    #   Error Text (which will evaluate as True) if:
    #       The schema was not successfully loaded during object creation, or
    #       The data was found to be invalid
    #   A null string (which will evaluate as False) if:
    #       The schema was successfully loaded during object creation, and
    #       The data was found to be valid
    #
    # Side-effects:
    #   Errors from a previous call to this method are cleared.
    #   Errors from this validation attempt are stored.
    #   Note that errors from a failure to load the schema are never cleared
    #   by this method, so a schema-load failure will cause all calls to
    #   data_is_invalid() to return true.
    
    my ($self, $data, $opts_ref) = @_;
    
    if ( ! exists $opts_ref->{update} ) {
        $opts_ref->{update} = 'No';
    }
    
    my ($data_loaded_ref, $error_text) = $self->load_data($data, $opts_ref);

    ## return ($data_loaded_ref, $error_text); ## ??? Why the list return ??? ##
    return scalar $error_text;
}

# --------------------------------------------------------------------
sub _default_options_update {
    return "update: 1\n"
         . "internalise: 1\n"
         . "relaxed:   1\n"
         . _default_options_common();
}
# --------------------------------------------------------------------
sub _default_options_not_update {
    return "update: 0\n"
         . "internalise: 0\n"
         . "relaxed:   0\n"    
         . _default_options_common();
}
# --------------------------------------------------------------------
sub _default_options_common {
    return "
dates:
    external:  ddmmyy
enumerations:
    case:
        insensitive: 1
    punctuation:
        ignore: 1
    equivalents: 1        
keys:
    case:
        insensitive: 1
    punctuation:
        ignore: 1
    equivalents: 1
scalar:
    sequence: 1
    map:      1
unload_format: YAML+
";
}
# --------------------------------------------------------------------
sub load_data {
#    $val->load_data($data) : returns the data loaded into a structure and
#                            (optionally) updated. If called in a list context,
#                            returns data structure and error text
    # load_data:  OO method
    #
    # Expects:
    #
    #   1) Data
    #       The data to be validated.
    #       It can be supplied as any of the following:
    #           - A string (in YAML format)
    #           - A structure (with the data pre-loaded)
    #           - a file-name (a text string starting with '<', of a file
    #                          containing the data in YAML format)
    #           - a file handle (of a file containing the data in YAML format)    
    #   
    #   2) Options
    #       An optional hash of options.
    #       Options supplied to this method over-ride the options supplied to
    #       the constructor.
    #       The option 'update' defaults to true
    #
    # Returns:
    #   If called in a scalar context:
    #       - A reference to data, loaded into a structure
    #   If called in a list context:
    #       - A reference to data, loaded into a structure
    #       - Error text 
    #
    # Side-effects:
    #   Previous data errors are cleared.
    #   Errors from this validation attempt are stored.
    #   Note that errors from a failure to load the schema are never cleared
    #   by this method.
    
    my ($self, $data, $opts_ref) = @_;
    
    my ($updated_options_ref, $options_errors)
            = _check_options($opts_ref,  _default_options_update() );
    if ($options_errors) {
        $self->{'data-errors'} = $options_errors;       # Save errors for errors() calls
        return wantarray ? (undef, $options_errors) : $options_errors;
    }
    if ( defined $self->{'schema-errors'} ) {
        # Bad schema, don't try to do anything
        my $errors_string = join ',', @{$self->{'schema-errors'}};
        return wantarray ? (undef, $errors_string) : $errors_string;
    } else {
        # Clear out previous data errors
        $self->{'data-errors'} = undef;
        
        # Validate
        
        my ($data_updated_ref, $arg_error_text);
        my $csv_option = $updated_options_ref->{csv_with_header} ? 'header'
                       : $updated_options_ref->{csv}             ? 'no_header'
                       : 0;
       ($arg_error_text, $data_updated_ref) = _accept_or_parse_arg($data, $csv_option);
    
        if ($arg_error_text) {
            $self->{'data-errors'} = [$arg_error_text];
            return wantarray ? (undef, $arg_error_text) : $arg_error_text;
        } else {
            my @error_array = ();    # empty array of error messages
            my $actual_result = _is_structure_invalid(
                                    $data_updated_ref,
                                    $self->{'schema'},
                                    \@error_array,
                                    undef,
                                    undef,
                                    $self->{'anchors'},
                                    $updated_options_ref,
                                    \$data_updated_ref,
                                                    );
            my $error_text = '';
            if (scalar @error_array) {
                $error_text = join ("\n", @error_array) . "\n";
                $self->{'data-errors'} = \@error_array;
            }
            return wantarray ? ($data_updated_ref, $error_text)
                             :  $data_updated_ref;
        }
    }
}
                          

# --------------------------------------------------------------------
sub errors {
    
    #  $validator_obj->errors();
    #  $validator_obj->errors($data);   ### ?????????????
    #  $validator_obj->errors($data, $options); ### ?????????
    #
    #  errors:  OO method
    #   
    # If called with no arguments, returns any errors found by the most recent
    # call with data, or any errors that were found when the schema was loaded
    #
    # If called with data, validates that data first then returns any errors.
    #
    # If there are no errors, returns an empty string

    my ($self, $data, $opts_ref) = @_;
    
    if (defined $opts_ref) {
        my $option_update = $opts_ref->{update};
        
    } else {
        $opts_ref = {};
    }
    
    
    $self->data_is_invalid($data, $opts_ref) if defined $data;
    my $schema_errors_ref = $self->{'schema-errors'};
    my $data_errors_ref   = $self->{'data-errors'};

    my $schema_errors = defined $schema_errors_ref ? join("\n", @{$schema_errors_ref}) : '';
    my $data_errors   = defined $data_errors_ref   ? join("\n", @{$data_errors_ref  }) : '';
    return $schema_errors . $data_errors;

}
# --------------------------------------------------------------------
sub schema_text {
    
    # schema_text: OO method
    #
    # Returns the schema in kwalify notation
    #
    # ## PROBABLY BROKEN by alternate module changes
    
    my ($self, $opts_ref) = @_;
    
    if ( $self->{'schema-errors'} ) {
        # Bad schema, don't try to do anything
        return "Schema errors";
    }
    my $yaml_schema = YAML::Tiny->new();
    $yaml_schema->[0] = $self->{'schema'};
    my $result_schema_str;
    eval {$result_schema_str = $yaml_schema->write_string()};
    my $err = $@;
    if ($@) {
        # YAML died and left a message in $@)
        return "Result Schema Error: $@\n";
    }
    return $result_schema_str;
}
# --------------------------------------------------------------------
sub kwalify_schema_ref {
    
    # kwalify_schema_ref: OO method
    #
    # Returns a reference to the schema in kwalify format, or rather
    # the somewhat extended and mutated kwalify format that this module
    # now uses.
    # Provided for access, so that the interface can be left unchanged if the
    # implementation is changed - but the exact format of the structure is
    # an implementation detail that is subject to change.
    my ($self) = @_;
    return $self->{'schema'};
}
# --------------------------------------------------------------------
sub _say {
    my ($line) = @_;
    print $line . "\n";
}
# --------------------------------------------------------------------
sub _get_next_token {
    
# Passed a string, an optionally a delimiter
# Returns:
#    - the first token from the string
#    - the remainder of the string
#    - the delimiter
#    - any quote used
#
# Tokens are delimited by white space and/or commas, except that:
#   - a single-quoted string is a single token
#   - a double-quoted string is a single token
#   - a string within angle-brackets < > is a single token
#   - a pattern enclosed within / characters is a single token
#   - a comma preceded and followed by decimal digits is not a delimiter 
#   - if a delimiter is specified, white space does not delimit tokens
# Leading and trailing spaces of the line are discarded
#
# If the delimiter is a comma (possibly preceded or followed by spaces), the
# delimiter returned will be a single comma with no spaces.
#
# If the token was delimited by one or more spaces or end-of-string, the
# delimiter returned will be a null string.
#
# If the token does not parse as valid (e.g. mismatched starting and ending quotes)
# then the entire string is passed back as the token

    my ($in_line, $specified_delimiter) = @_;
    
    my $first_token  = '';
    my $delim = '';
    my $rest_of_line = '';
    my $quote = '';
    
    $in_line =~ s/^\s+//;
    $in_line =~ s/\s+$//;
    
    if (length $in_line == 0) {
        # No line left
        return ('', '', '');
    } else {
        # Some line left
        my $leading_char = substr($in_line, 0, 1);
        if       ($leading_char eq '"') {
            # Double-quoted string (no embedded escaped double-quotes allowed)
            $quote = '"';
            # Remove the double quotes
            ($first_token, $delim, $rest_of_line) = ($in_line =~ /  ["] ( [^"]* ) ["]  [\s]* ( [,]? ) [\s]* ( .* ) /msx );
        } elsif  ($leading_char eq "'") {
            # Single-quoted string (no embedded escaped single-quotes allowed)
            $quote = "'";
            # Remove the single quotes
            ($first_token, $delim, $rest_of_line) = ($in_line =~ /  ['] ( [^']* ) [']  [\s]* ( [,]? ) [\s]* ( .* ) /msx );
        } elsif  ($leading_char eq "<") {
            # angle-quoted string
            $quote = "<";
            # Remove the angle quotes
            ($first_token, $delim, $rest_of_line) = ($in_line =~ /  [<] ( [^>]* ) [>]  [\s]* ( [,]? ) [\s]* ( .* ) /msx );
                        
        } elsif  ($leading_char eq "/") {
            # Pattern starting and ending with / and optionally followed by any of the letters 'misx'
            ($first_token, $delim, $rest_of_line) = ($in_line =~ m< ( //? .+ //? [misx]* )  [\s]* ( [,]? ) [\s]* ( .* ) >msx );
        } else {
            if (! $specified_delimiter) {
                # Token delimited by white space and/or comma
                ($first_token, $delim, $rest_of_line) = ($in_line =~ / ( [^\s,]* ) [\s]* ( [,]? ) ( .* ) /msx );
            } else {
                # Token delimited by specified delimiter
                ($first_token, $delim, $rest_of_line) = ($in_line =~ / ( [^$specified_delimiter]* ) [\s]* ( [$specified_delimiter] ) ( .* ) /msx );
            }
            $first_token = '' unless defined $first_token;
            while ($first_token     =~ / \d $ /x
                   && $delim eq ','
                   && $rest_of_line =~ / ^ \d /x
                   ) {
                # Comma surrounded by decimal digits
                my $next_token;
                
                ($next_token, $delim, $rest_of_line) = ($rest_of_line =~ / ( [^\s,]* ) [\s]* ( [,]? ) ( .* ) /msx );
                $first_token .= ",$next_token";
            }
        }
    }
    if (length ( $first_token || '') || length ($delim || '') || length ($rest_of_line || '') ) {
        return ($first_token , $rest_of_line , $delim , $quote || '');
    } else {
        return ($in_line     , ''            , ''     , ''    );
    }
}
# --------------------------------------------------------------------
sub _schema_from_string {
    
    # Handles a compact-format schema string
    
    ## The interface to this routine needs to be refactored, partly due to
    ## kwalify notation being no longer needed if not actually deprecated.
    ##
    ##   - There is a need to pass extra control information
    ##   - Error reporting is limited (non-existent?)

    # If the string starts with a column name in angle brackets, it assumes
    # that the string defines columns - so it splits the string using angle
    # brackets and passes each chunk separately to _schema_from_string_single.

    # If the string starts with <control>, it assumes that the string defines
    # columns. So it processes the control information, then splits the rest
    # using angle brackets and passes each chunk separately to
    # _schema_from_string_single.
    
    # Otherwise it just passes the entire string to _schema_from_string_single.
    
    my ($scalar_schema, $navigation, $errors_ref) = @_;

    my %row_structure = (type => 'row');
    my $array_def_ref = {type => 'seq', sequence => [] };
            
    if (defined $scalar_schema && lc substr($scalar_schema, 0, 9) eq '<control>') {
        my $control_text = substr($scalar_schema, 9);
        my $up_ref = $array_def_ref;
        my ($errs, $rest) = _handle_control_line($control_text, $up_ref, 1);
        if ($errs) {
            push @{$errors_ref}, "[$navigation] $errs";
            return $scalar_schema;
        }
        $scalar_schema = $rest;
        if (substr($rest, 0, 1) ne '<') {
            # A scalar schema can't just have <control> information
            push @{$errors_ref}, "[$navigation] No column details after <control>";
            return $scalar_schema;
        }
    } 
    
    if (! defined $scalar_schema || substr($scalar_schema, 0, 1) ne '<' )  {
        return _schema_from_string_single($scalar_schema, $navigation, $errors_ref);    
    } else {
        # Schema string starts with < or [, so it is defining columns for a row

        ##  Defunct code to handle a header starting with a pipe.
        ##my ($header) = $scalar_schema =~ /  ^ \s* (  [|] .* $ ) /mx;
        ##

        ##if (defined $header) {
        ##    $row_structure{pattern} = $header;
        ##    $scalar_schema =~ s/ ^ \s* [|] .* $ //mx;     # Remove the header line
        ##}
        

        
        my $failure_count = 0;
        my $col_number = 0;
        for my $column_string (split('<', substr($scalar_schema, 1))) {
            
            $column_string =~ s/ [,] [ ]* $ //x; # Drop trailing comma
            my ($col_name, $col_schema) = split('>', $column_string);
            
            my $schema_col_ref = _schema_from_string_single(
                                    "$col_schema",
                                    $navigation . '/' . ($col_number
                                                 + $COLUMN_NUMBER_MESSAGE_BASE),
                                    $errors_ref);
            my $ref_col_ref = ref $schema_col_ref;
            if ($ref_col_ref eq "HASH") {
                $row_structure{columns}[$col_number] = $schema_col_ref;
                $row_structure{columns}[$col_number]{name} = $col_name;
            } else {
                $failure_count++;
            }
            $col_number++;
        }
        if ($failure_count == 0) {
            # All schema strings were converted

            $array_def_ref->{sequence}[0] = \%row_structure;
            ##return \%row_structure;
            return $array_def_ref; 
        } else {
            # At least one schema string caused an error
            return $scalar_schema;
        }
    }
}
# --------------------------------------------------------------------
sub _schema_from_string_single {
    
    my ($scalar_schema, $navigation, $errors_ref) = @_;

    
    # Converts a compact-format schema string to a kwalify-format hash
    #
    # If the scalar is not interpretable as a compact schema entry,
    # just returns the string passed in, unchanged.
    #
    # If the scalar is interpretable as a compact schema entry, returns
    # a reference to a hash containing the equivalent kwalify-format schema.
    
    # The string can contain multiple lines
    #
    # The string is in two parts, both optional:
    #   - Keyword entries, delimited by white space
    #   - Enumeration entries, delimited by commas
    #   
    # Keyword entries:
    #   <type>
    #       int, float, number,
    #       str, text, scalar,
    #       date, time,
    #       boolean  
    #   required
    #   optional
    #   default
    
  
    #
    # [<type>] [required|optional] <enum1>, <enum2>, <enum3>...
    # [<type>] [required|optional] /<pattern>/
    # [int|float|number|str|text|scalar] [required] <min> to <max>
    # str [required] length <min-length> to <max-length>
    # e.g.
    # blood: A, B, AB, O
    #   is converted to
    # blood:
    #     type: str
    #     enum:
    #       - A
    #       - B
    #       - AB
    #       - O
    #
    # bottle-size-ml: required int 50, 100, 250
    #   is converted to
    # bottle-size-ml:
    #     type: int
    #     required: yes
    #     enum:
    #       - 50
    #       - 100
    #       - 250
    #
    # method: str default Fischer-Tropsch

        
    my %hash_to_return = (type => 'scalar');
    my $original_schema_str = $scalar_schema;
    if ( ! defined $scalar_schema) {
        return \%hash_to_return;
    }

    # Look for leading type,
    #                  required/optional,
    #                  pattern,
    #                  min/max/min-ex/max-ex,
    #                  length n [to m]
    # enums are not valid following:
    #    - a pattern
    #    - min and/or max entries
    #    - a length entry
    #
    # A type entry is redundant if there are enums
    #
    # integer min/max values should imply type int, but they don't yet
    # float   min/max values should imply type number, but they don't yet
    #
    # enum values containing spaces &/or commas must be quoted
    #

    my $token = '';
    my $delimiter = '';
    my $comma = ',';
    
    ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
    my $handling_non_enum_tokens = 1;
    my $enums_allowed = 1;
    my $enum_delimiter = '';

    while ( $token ne '' && $handling_non_enum_tokens
           ## ## ## && $delimiter ne $comma
           ) {
        my $first_char = substr($token, 0, 1);
        my $lc_token = lc $token;
        if ( $first_char eq '/' ) {
            # token is a pattern    
            $hash_to_return{pattern} = $token;
            $enums_allowed = 0;
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
        } elsif ( $first_char eq '#' ) {
            # It's a comment - discard the rest of the line
            ($token, $scalar_schema, $delimiter) = ( '', '', '' );
        } elsif (exists $REGEX_TYPES{$lc_token}
                 || exists $TYPE_SYNONYMS{$lc_token}
                 || $lc_token eq 'any') {
            # token is a type
            $hash_to_return{'type'} = $TYPE_SYNONYMS{$lc_token} || $lc_token;
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
        } elsif ($token =~ / ^ max | min | max-ex | min-ex $ /ix ) {
            my $range_token;
            my $quote;
            ($range_token, $scalar_schema, undef, $quote) = _get_next_token($scalar_schema);

            if ($range_token ne '') {
                $hash_to_return{'range'}{lc $token} = "$quote$range_token$quote";
            } else {
                push @{$errors_ref}, "[$navigation] Missing $token value";
                return $original_schema_str;
            }
            $enums_allowed = 0;
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
        } elsif ( $lc_token eq 'length'   ) {
            my $length_token;
            ($length_token, $scalar_schema) = _get_next_token($scalar_schema);
            if ($length_token =~ / [\d]+/x) {
                $hash_to_return{'length'}{'min'} = $length_token;
                $hash_to_return{'length'}{'max'} = $length_token;
            } else {
                push @{$errors_ref}, "[$navigation] Missing $token value";
                return $original_schema_str;
            }
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
            $lc_token = lc $token;
            if (lc $token eq 'to') {
                my $to_token;
                ($to_token, $scalar_schema) = _get_next_token($scalar_schema);
                if ($to_token =~ / [\d]+/x) {
                    $hash_to_return{'length'}{'max'} = $to_token;
                } else {
                    push @{$errors_ref}, "[$navigation] Missing 'to' value";
                    return $original_schema_str;
                }
                ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
            }
        } elsif ( lc $token eq 'required' ) {
            $hash_to_return{required} = 'yes';
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
        } elsif ( lc $token eq 'optional' ) {
            $hash_to_return{required} = 'no';
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
        } elsif ( lc $token eq 'unique' ) {
            $hash_to_return{unique} = 'yes';
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
        } elsif ( $token eq 'define' || $token eq 'use' ) {
            my $name_token;
            ($name_token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
            $hash_to_return{$token} = $name_token;
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
        } elsif ( lc $token eq 'values' || lc $token eq 'enum') {
            # Keyword starting list of enums.
            # Not essential, but allows list to be space rather than comma delimited
            # If the rest of the line contains any commas not between digits,
            # force the use of commas as value delimiter
            $handling_non_enum_tokens = 0;
            if ($scalar_schema =~ / \D [,] \D /x) {
               $enum_delimiter = ','; 
            }
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema, $enum_delimiter);
        } elsif ( lc $token eq 'default' ) {
            my $default_value;
            ($default_value, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
            $hash_to_return{default} = $default_value;
            ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema);
        } else {

            if ($delimiter eq $comma) {
                $handling_non_enum_tokens = 0;
                $enum_delimiter = ',';
                
                ## push @{$errors_ref}, "[$navigation] Schema text '$original_schema_str' Error: missing values keyword?";
                ## return $original_schema_str;
                
            } elsif ($scalar_schema =~ / \D [,] \D /x) {
                # There is at least one comma (not between digits) in rest of line
                # so treat rest of line as enums (implied values/enum)
                # and assume there was a single space after token
                $handling_non_enum_tokens = 0;
                $enum_delimiter = ',';
                my $token_part_2;
                ($token_part_2, $scalar_schema, $delimiter) = _get_next_token($scalar_schema, ',');
                $token .= " $token_part_2";
                
                ## push @{$errors_ref}, "[$navigation] Schema text '$original_schema_str' Error: missing values keyword?";
                ## return $original_schema_str;
                
            } else {
                # Token not recognised, and not the first of a list of enums because
                # it is not followed by a comma
                push @{$errors_ref}, "[$navigation] Schema text '$original_schema_str' Error: mis-spelt keyword or missing comma?";
                return $original_schema_str;
            }
        }
    }
    # Enums, or have run out of tokens
    if ( $token ne '' ) {

        if ( $enums_allowed ) {
            while ( $token ne '') {
                push @{$hash_to_return{'enum'}}, $token;
                ($token, $scalar_schema, $delimiter) = _get_next_token($scalar_schema, $enum_delimiter);
            }
        }
    }
    return \%hash_to_return;
 }
# --------------------------------------------------------------------
sub load_and_validate {
    my ($data, $schema, $opts_ref) = @_;
    my ($errors_text, $updated_data_ref);
    ($errors_text, $updated_data_ref) = errors_in_data($data,
                                                       $schema,
                                                       $opts_ref,
                                                       \&_default_options_update);

    return wantarray ? ($updated_data_ref, $errors_text)
                      : $updated_data_ref;
}
# --------------------------------------------------------------------
sub _number_commas_acceptable {
    
    # Returns true if the string passed has no commas,
    # or is a number with a comma placed before each group of three digits
    # except after a decimal point
    #
    # Locale is ignored, so 
    
    my ($num_to_check) = @_;
    
    return 1 if (! defined $num_to_check || $num_to_check !~ / [,] /x);    # No commas
    
    return 1 if ($num_to_check =~ / ^ [-+]? \d?\d?\d (,\d\d\d)* $ /x );
    
    return 0;
    
    
}
# --------------------------------------------------------------------
sub errors_in_data {
    
    # Passed data, a schema and an options hash
    #
    # Returns a null string if the data is valid according to the schema
    #  otherwise (possibly multi-line) error text
    #
    # If called in a list context, returns the errors string and a
    # reference to the data in a structure. If the data is not able
    # to be loaded, it returns the errors string and undef.
    
    # Validates data, which may be supplied as:
    #
    #      a string (containing the data in YAML format)
    #   or a filename (where the file contains the data in YAML format)
    #   or a filehandle (of a file that contains the data in YAML format)
    #   or a structure (containing the data)
    #
    # against a schema, which may be supplied as:
    #
    #      a string (containing the schema in YAML format)
    #   or a filename (where the file contains the schema in YAML format)
    #   or a filehandle (of a file that contains the schema in YAML format)
    #   or a structure (containing the schema)
    #
    #

    my ($data, $schema, $opts_ref, $defaults_sub_ref) = @_;
    
    my ($data_updated_ref, $schema_updated_ref, $arg_error_text);
    

    my @error_array = ();    # empty array of error messages
    my $global_anchors_ref;
    my $err;
    if (defined $defaults_sub_ref) {
        if (ref $defaults_sub_ref ne 'CODE') {
            $err = 'Invalid call to errors_in_data: 4th arg must be a coderef';
            return wantarray() ? ($err, undef) : $err;
        }
    } else {
        $defaults_sub_ref = \&_default_options_not_update;
    }
    my ($schema_ref, $updated_options_ref, $anchors_ref) =
     _setup_schema($schema, $opts_ref, $defaults_sub_ref->(), \@error_array );
     
    my $csv_option = $updated_options_ref->{csv} || 0;
    ($arg_error_text, $data_updated_ref) = _accept_or_parse_arg($data, $csv_option);
    return $arg_error_text if $arg_error_text;
    
    if (scalar @error_array == 0) {
        # Validate the data against the schema
        # [ This doesn't allow aliases in the schema at present - we do tree-walk the
        # [ schema in advance during pre-processing but that code isn't integrated

        my $actual_result = _is_structure_invalid(
                                        $data_updated_ref,
                                        $schema_ref,
                                        \@error_array,
                                        undef,
                                        undef,
                                        $anchors_ref,
                                        $updated_options_ref,
                                        \$data_updated_ref,
                                              );
    }    
    $err = join ("\n", @error_array) . "\n";
    
    $err =~ s/ ^ \s+   //x;  # strip leading white space
    $err =~ s/   \s+ $ //x;  # strip trailing white space
    
    return wantarray() ? ($err, $data_updated_ref) : $err;
    
}

# --------------------------------------------------------------------
sub _accept_or_parse_arg {
    # Converts a non-structure argument to a structure
    # A structure (hash or array) is returned unchanged
    # Filehandles are used to load YAML
    # Filenames (preceded by <)are used to open a file and load YAML from it
    # Strings are treated as being YAML text, and loaded into a structure
    #
    # Passed:
    #   1) A structure or string or glob
    #   2) A flag: 'header' means csv with a header line that will be ignored
    #              'no_header' means csv with no header line
    #              false means not csv
    #
    # Returns:
    #   1) Result: null if OK, error text if not
    #   2) A reference to the converted structure

    
    my ($arg, $csv_option) = @_;

    my $scalar;
    my $RESULT_UNRECOGNISED_ARGUMENT = 'unrecognised argument';
    my $RESULT_COULD_NOT_OPEN_FILE   = 'Could not open file: ';
    
    return ('', undef) if (! defined $arg);
    
    my $ref_arg   = lc ref $arg;
    
    if      ($ref_arg eq 'hash') {
        # It's a hash: just use it
        return ('', $arg);
    } elsif ($ref_arg eq 'array') {
        # It's an array: just use it
        return ('', $arg);
    } elsif ($ref_arg eq 'glob') {
        # It's a glob: try using it as a filehandle
        eval {
            local $/;
            undef $/;   # Slurp mode
            $scalar = <$arg>;
        };
    } elsif ($ref_arg eq 'scalar') {
        # It's a reference to a scalar: use the scalar
        $scalar = ${$arg};
    } elsif ($ref_arg eq '') {
        # It's a scalar: delve deeper to decide desired deeds
        $scalar = $arg;
    } else {
        # It's not anything we recognise
        return ($RESULT_UNRECOGNISED_ARGUMENT, $arg);
    }    
    
    # We have a scalar of some sort
    # If it's a string starting with "<" with no newlines and no ">"
    #   use it as a filename
    # If csv option is true,
    #   just leave it as a raw scalar (possibly trimming header line)
    # If it's a string containing some sort of line breaks (not necessarily the
    #   standard newlines for this platform, because it might be a YAML file
    #   using a different newline convention), try parsing it as YAML data
    # Otherwise treat it as a single line of YAML
    
    my $scalar_has_newline    = ($scalar =~ / [\012\015] /x);
    my $scalar_has_leading_lt = substr($scalar, 0, 1) eq '<';
    my $scalar_has_gt         = ($scalar =~ / > /x);
    
    my ($yaml_scalar, $err);    

    
    if ( $scalar_has_leading_lt
        && ! $scalar_has_newline
        && ! $scalar_has_gt) {
        # scalar starts with < and has no newlines or >
        # treat it as a filename
        my $filename = substr($scalar, 1);
        my $in_file;
        if ($filename eq '-') {
            # Asking for stdin
            eval {
                local $/;
                undef $/;   # Slurp mode
                $scalar = <STDIN>;
            };
            
        } else {
            open (INP, "<$filename")    # Support ancient Perl!
                or return ($RESULT_COULD_NOT_OPEN_FILE . $filename, $arg);
            eval {
                local $/;
                undef $/;   # Slurp mode
                $scalar = <INP>;
            };
            close INP;
        }
        $scalar_has_newline = 1;
    }
    
    if ($csv_option) {
        if ($csv_option eq 'header') {
            # Expecting header - just ignore it
            $scalar =~ s/ [^\n]* \n //x;
        }
        return ($err, $scalar);
    }
    
    if ($scalar_has_newline ) {
        # scalar has newline(s)
        # treat it as YAML
        # Tidy up any trailing spaces from end of lines, as YAML::Tiny doesn't
        # seem to cope with them
        $scalar =~ s/ [\t ]+ [\012] [\015]? /\n/gix;
        ($yaml_scalar, $err) = _YAML_load( "$scalar\n" );
        if ($err) {
            # YAML died and left a message in $@)
            return ($err, $arg, 0);
        } else {
            # YAML did not die
            #$err = YAML->errstr();
            #if ($err) {
            #    return ($err, $arg);
            #} else {
                ## return ('', $yaml_scalar->[0], 0);
                return ('', $yaml_scalar, 0);
            #}
        }    
    } else {
        # scalar has no newlines
        
        if ( $scalar_has_leading_lt && 0 && 0 && 0 && 0 && 0 && 0 ) {
    
            ## Missing code to handle file?
            
            return ('Missing code: _accept_or_parse_arg', '')
        } else {
            
            # scalar has no newlines and no leading '<'
            # Treat it as a plain string - but it might be a one-line hash, e.g.
            #       key-name: int
            # or a one-line array definition, e.g.
            #       - text values fox, wolf, dog
            # or a scalar
            #       text values fox, wolf, dog
            #
        
            ## eval {$yaml_scalar = YAML->read_string( "dummy:  $scalar\n")};
            ##($yaml_scalar, $err) = _YAML_load( "dummy:  $scalar\n");
            ##if ($err) {
            ##    # YAML died and left a message in $@)
            ##    return ($err, $arg);
            ##} else {
            ##    return ('', $yaml_scalar->{'dummy'});
            ##}
            ##($yaml_scalar, $err) = _YAML_load( "$scalar\n");
            ##if ($err) {
            ##    # YAML died and left a message in $@)
            ##    return ($err, $arg);
            ##} else {
            ##    return ('', $yaml_scalar);
            ##}
            
            ($yaml_scalar, $err) = _YAML_load( $scalar);

            return ($err, $yaml_scalar);
        }       
    }
}
# --------------------------------------------------------------------
sub _is_structure_invalid {
    
    # ######################
    # _is_structure_invalid
    # ######################
    #
    # This is a procedural (non-OO) low-level interface to the validator
    # that is called by OO routines.
    #
    # There are higher-level procedural interfaces (errors_in_data and
    # load_and_validate), which are intended to be called by end-users who
    # prefer a non-OO interface
    #
    #
    # Passed:
    #       ref to data structure
    #       ref to schema structure
    #       ref to an errors array
    #       navigation text prefix
    #       ref to unique values hash
    #       ref to hash of anchors
    #       ref to hash of options
    #       ref to modifiable data structure
    #
    # Returns:
    #
    #      -1 if an error is found in the schema
    #          Note that the schema is not specifically validated - this return
    #          value is used if this routine fails because of a schema error
    #       0 if the data structure is valid according to the schema
    #       1 if the data structure is not valid according to the schema
    #
    
    # Options can supplied in two ways - passed in by the caller, and as an
    # 'options: ' key within the schema.
    #
    # The 'update: ' option is not allowed within the schema.
    #
    # Other options in the schema override the same options passsed in.
    
    
    ## Still does things that were appropriate when it might be passed a
    ## non-kwalify schema, in an attempt to interpret the schema as compact or
    ## mixed compact/kwalify. These actions are obsolete, given that callers
    ## will have already validated schemas and pre-processed them to convert
    ## them to kwalify format before calling this routine.
    ##
    
    my ($data_ref,
        $schema_ref,
        $errors_ref,
        $navigation,        
        $uniqueness_ref,
        $anchor_ref,
        $opts_ref,
        $modifiable_ref,
        ) = @_;
    
    if (not defined $errors_ref) {
        $errors_ref = [];
    }
    if (not defined $navigation) {
        $navigation = '/';
    }
    if (not defined $uniqueness_ref) {
        $uniqueness_ref = {};
    }
    if (not defined $opts_ref) {
        $opts_ref = {};
    }

    my $RESULT_STRUCTURE_IS_VALID   =  0;
    my $RESULT_STRUCTURE_IS_INVALID =  1;
    my $RESULT_SCHEMA_HAS_ERROR     = -1;

    my $option_update;
    my $option_relaxed;
    my $option_internalise;
    my $option_case_insensitive_enums;
    my $option_case_insensitive_keys;
    my $option_ignore_punctuation_enums;
    my $option_ignore_punctuation_map_keys;
    my $option_allow_equivalent_keys;
    my $option_allow_equivalent_enums;
    my $option_allow_scalar_as_sequence;
    my $option_allow_scalar_as_map;
    my $option_dates_external;
    my $option_dates_internal;
   
   
    if (ref $schema_ref ne 'HASH' && defined $schema_ref) {
        my $schema_not_hash_or_undef_pause = 1;
    }
    $option_update      = $opts_ref->{update};      # Conversions wanted, data
                                                    # is allowed to be modified
    if (ref $schema_ref eq 'HASH'
        && exists $schema_ref->{options} ) {
        
        # Schema has options, so give them priority (except for update)
                                                   
        $option_relaxed                     = $schema_ref->{relaxed};
        $option_internalise                 = $schema_ref->{internalise};
        $option_case_insensitive_enums      = $schema_ref->{enumerations}{case}{insensitive};
                                            # Match case of enums case-insensitively
        $option_case_insensitive_keys       = $schema_ref->{keys}{case}{insensitive};
        $option_ignore_punctuation_enums    = $schema_ref->{enumerations}{punctuation}{ignore};
                                            # Ignore some punctuation within enums
        $option_ignore_punctuation_map_keys = $schema_ref->{keys}{punctuation}{ignore};
                                            # Ignore some punctuations within mapping keys
        $option_allow_equivalent_keys       = $schema_ref->{keys}{equivalents};
        $option_allow_equivalent_enums      = $schema_ref->{enumerations}{equivalents};
        $option_allow_scalar_as_sequence    = $schema_ref->{scalar}{sequence};
        $option_allow_scalar_as_map         = $schema_ref->{scalar}{map};
        $option_dates_external              = $schema_ref->{dates}{external};
        $option_dates_internal              = $schema_ref->{dates}{internal};

        if (ref $opts_ref eq 'HASH') {                                               
            $option_relaxed                     =   $opts_ref->{relaxed}
                                                    unless defined $option_relaxed; 
            $option_internalise                 =   $opts_ref->{internalise}
                                                    unless defined $option_internalise;
            $option_case_insensitive_enums      =   $opts_ref->{enumerations}{case}{insensitive}
                                                    unless defined $option_case_insensitive_enums;
            $option_case_insensitive_keys       =   $opts_ref->{keys}{case}{insensitive}
                                                    unless defined $option_case_insensitive_keys;
            $option_ignore_punctuation_enums    =   $opts_ref->{enumerations}{punctuation}{ignore}
                                                    unless defined $option_ignore_punctuation_enums;
            $option_ignore_punctuation_map_keys =   $opts_ref->{keys}{punctuation}{ignore}
                                                    unless defined $option_ignore_punctuation_map_keys;
            $option_allow_equivalent_keys       =   $opts_ref->{keys}{equivalents}
                                                    unless defined $option_allow_equivalent_keys;
            $option_allow_equivalent_enums      =   $opts_ref->{enumerations}{equivalents}
                                                    unless defined $option_allow_equivalent_enums;
            $option_allow_scalar_as_sequence    =   $opts_ref->{scalar}{sequence}
                                                    unless defined $option_allow_scalar_as_sequence;
            $option_allow_scalar_as_map         =   $opts_ref->{scalar}{map}
                                                    unless defined $option_allow_scalar_as_map;
            $option_dates_external              =   $opts_ref->{dates}{external}
                                                    unless defined $option_dates_external;
            $option_dates_internal              =   $opts_ref->{dates}{internal}
                                                    unless defined $option_dates_internal;
        }

    } else {
        # No schema-level options supplied
        if (ref $opts_ref eq 'HASH') {
            $option_relaxed                     = $opts_ref->{relaxed}; 
            $option_internalise                 = $opts_ref->{internalise};
            $option_case_insensitive_enums      = $opts_ref->{enumerations}{case}{insensitive};
                                                  # Match case of enums case-insensitively
            $option_case_insensitive_keys       = $opts_ref->{keys}{case}{insensitive} ;
            $option_ignore_punctuation_enums    = $opts_ref->{enumerations}{punctuation}{ignore};
                                                  # Ignore some punctuation within enums
            $option_ignore_punctuation_map_keys = $opts_ref->{keys}{punctuation}{ignore};
                                                  # Ignore some punctuations with mapping keys
            $option_allow_equivalent_keys       = $opts_ref->{keys}{equivalents};
            $option_allow_equivalent_enums      = $opts_ref->{enumerations}{equivalents};
            
            $option_allow_scalar_as_sequence    = $opts_ref->{scalar}{sequence};
            $option_allow_scalar_as_map         = $opts_ref->{scalar}{map};
            $option_dates_external              = $opts_ref->{dates}{external};
            $option_dates_internal              = $opts_ref->{dates}{internal};
        }
    }
    my $number_of_errors_found = 0;
    
    # Default type is scalar, so any string is allowed even if it could
    # also be interpreted as a valid number, date, boolean etc.
    my $DEFAULT_TYPE = 'scalar';
    
    my $ref_schema_ref = ref $schema_ref;
    
    if ($ref_schema_ref eq 'ARRAY') {
        # Passed an array as the schema
        # Force it into the form
        #   type: seq
        #   sequence: whatever
        $schema_ref = {type => 'seq', sequence => $schema_ref };
    } elsif (not $ref_schema_ref) {
        # Scalar passed instead of schema reference
        # so try to turn it into a schema structure
        ## Obsolete due to schema pre-processing ?? ##
        if ($ref_schema_ref) {
            my $pause_obsolete = 1;
        }
        $schema_ref = _schema_from_string($schema_ref, $navigation, $errors_ref);
    }
    $ref_schema_ref = ref $schema_ref;

    if ( $ref_schema_ref ne 'HASH') {
        
        push @{$errors_ref}, "[$navigation] Schema is not a mapping";
        return $RESULT_SCHEMA_HAS_ERROR;
    }
        
    if ( exists $schema_ref->{use} ) {
        # Schema passed is an alias
        my $alias_text = $schema_ref->{use};
        my $ref_alias_text = lc ref $alias_text;
        if (ref $alias_text) {
            push @{$errors_ref}, "[$navigation] Schema error: 'use' should be scalar, is $ref_alias_text";
            return $RESULT_SCHEMA_HAS_ERROR;
        }
        
        if ( defined $anchor_ref ) {
            if ( exists $anchor_ref->{$alias_text} ) {
                $schema_ref = $anchor_ref->{$alias_text};
                $ref_schema_ref = ref $schema_ref;
            } else {
                push @{$errors_ref}, "[$navigation] Schema error: attempt to use $alias_text, but it is not defined";
                return $RESULT_SCHEMA_HAS_ERROR;
            }

        } else {
            push @{$errors_ref}, "[$navigation] Schema has 'use: $alias_text' but no definitions supplied";
            return $RESULT_SCHEMA_HAS_ERROR;
        }
    }
    # my $invalid_schema_keys = _not_in_hash($schema_ref, \%SCHEMA_VALID_KEYS);
    # if ($invalid_schema_keys) {
    #     push @{$errors_ref}, "[$navigation] Schema has invalid key(s): $invalid_schema_keys";
    #     return $RESULT_SCHEMA_HAS_ERROR;
    # }
    my $schema_type;
    my $schema_regex = '';
    
    if (exists $schema_ref->{type} ) {
        my $type_reftype = lc ref $schema_ref->{type};
        if ($type_reftype) {
            push @{$errors_ref}, "[$navigation] Schema error: type should be a scalar but is $type_reftype";
            return $RESULT_SCHEMA_HAS_ERROR;
        }
        # type specified as scalar or undef
        $schema_type = $schema_ref->{type};
        if (defined $schema_type) {
            # schema type is scalar and defined
            if (exists $REGEX_TYPES{$schema_type}) {
                # schema type has a value that allows us to
                # check the data content with a regex
                $schema_regex = $REGEX_TYPES{$schema_type};
            } elsif ($schema_type eq 'seq' || $schema_type eq 'sequence') {
                # seq
            } elsif ($schema_type eq 'map' || $schema_type eq 'mapping') {
                # map
            } elsif ($schema_type eq 'row') {
                # row
            } elsif ($schema_type eq 'any') {
                # any
            } else {
                push @{$errors_ref}, "[$navigation] Schema error: unknown type $schema_type";
                return $RESULT_SCHEMA_HAS_ERROR;
            }
        } else {
            $schema_type = $DEFAULT_TYPE;
        }
    } else {
        # key 'type:' not present in hash
        $schema_type = $DEFAULT_TYPE;
        $schema_regex = $REGEX_TYPES{$schema_type};
    }
    my $schema_required =
      (exists $schema_ref->{required}) && $schema_ref->{required} =~ $BOOLEAN_TRUE_REGEX;
    my $schema_unique   =
      (exists $schema_ref->{unique})   && $schema_ref->{unique}   =~ $BOOLEAN_TRUE_REGEX;
    my $schema_updater = $TYPE_UPDATERS{$schema_type};
    my $debug_type = $schema_type;
    my $schema_enum    = $schema_ref->{enum} || '';
    my $schema_pattern = $schema_ref->{pattern} || '';
    chomp $schema_pattern;
    my $schema_pattern_text = $schema_pattern;
    my $schema_pattern_modes = '';
    if ( $schema_pattern
        && $schema_type ne 'row'
        && $schema_pattern !~ m< \A / .+ / [ismx]* \Z >msx ) {
        push @{$errors_ref}, "[$navigation] Schema error: pattern is not valid: $schema_pattern_text";
        return $RESULT_SCHEMA_HAS_ERROR;
    }
    
    if ($schema_pattern && $schema_type ne 'row') {
        ($schema_pattern, $schema_pattern_modes) = $schema_pattern =~ m< / ( .+ ) / (.*) >msx;
        if ( $schema_pattern =~ m< \A / .+ / \z >x ) {
            # Pattern has leading and trailing /
            # so it must originally have started with leading and trailing //
            # so it is signalling that it doesn't want to match entire field
            # so we just remove the surrounding /
            ($schema_pattern) = ($schema_pattern =~ m< \A / (.+) / \Z >x );
        } else {
            # Pattern was not originally surrounded by //
            # So make it match full field
            $schema_pattern = '\A' . $schema_pattern . '\z';
        }
        $schema_pattern = "(?$schema_pattern_modes:$schema_pattern)";
        # Check for Perl code embedded within the regex via the (?{ syntax,
        # allowing for embedded spaces and comments, and alternatives such as
        # (??{  and  (?p{
        if ($schema_pattern =~ / [(]   \s* (?: [#].*)? \s*
                                 [?]   \s* (?: [#].*)? \s*
                                 [?p]? \s* (?: [#].*)? \s*
                                 [{]
                               /x ) {
            push @{$errors_ref}, "[$navigation] Schema error: pattern is not allowed: $schema_pattern_text";
            return $RESULT_SCHEMA_HAS_ERROR;
        }
    }
    my $schema_name = $schema_ref->{name} || '';

    if ($schema_regex) {
        if (ref $data_ref) {
            my $ref_data_ref = ref $data_ref;
            my %ref_type_texts = (ARRAY => $A_SEQUENCE_WORD, HASH => "a $MAP_WORD", SCALAR => 'a reference');
            my $ref_type_text = $ref_type_texts{$ref_data_ref} || 'unknown';
            push @{$errors_ref}, "[$navigation] $schema_name should be a $schema_type, is $ref_type_text";
            return $RESULT_STRUCTURE_IS_INVALID;
        } else {
            # DATA IS SCALAR
            # data_ref is not actually a reference - it is a scalar
            # Copy it into a variable with a less confusing name
            my $data_scalar = $data_ref;
            my $unmodified_data = $data_scalar; # Copy for error messages
            if ( ! defined $data_scalar) {
                # data is undef
                if ($schema_required) {
                    push @{$errors_ref}, "[$navigation] $schema_name is not allowed to be omitted";
                    return $RESULT_STRUCTURE_IS_INVALID;
                } elsif ($schema_ref->{default} && $option_update) {
                    $data_scalar = $schema_ref->{default};
                }
            }
            if ( defined $data_scalar) {
                # Original data was defined, or it was undef and there is a default
                
                if ( $schema_pattern ) {
                    my $regex_err_text = _regex_errors($data_ref, $schema_pattern, $schema_pattern_text);

                    if ($regex_err_text) {
                        push @{$errors_ref}, "[$navigation] $schema_name $regex_err_text";
                        return $RESULT_STRUCTURE_IS_INVALID;
                    }
                }
                if (defined $schema_updater && $option_relaxed) {
                    # relaxed, e.g. remove commas from numbers,
                    #               convert dd/mm/yy to yyyy-mm-dd
                    my $relaxation_error;
                    ($data_scalar, $relaxation_error)
                         = $schema_updater->($RELAXED,
                                             $data_scalar,
                                             $option_dates_external,
                                             $option_dates_internal);
                    if ($relaxation_error) {
                        push @{$errors_ref}, "[$navigation] $relaxation_error";
                        return $RESULT_STRUCTURE_IS_INVALID;
                    }
                }
                my $regex_result = ($data_scalar !~ $schema_regex);

                if ($regex_result) {
                    my %type_text = (int => 'integer',
                                     text => 'text field (non-ASCII character)',
                                     bool => 'boolean', num => 'number');
                    my $msg_type_text = $type_text{$schema_type} || $schema_type;
                    if ($schema_name) {
                        push @{$errors_ref}, "[$navigation] $schema_name is not a valid $msg_type_text: $unmodified_data";
                    } else {
                        push @{$errors_ref}, "[$navigation] Not a valid $msg_type_text: $unmodified_data";     
                    }
                    return $RESULT_STRUCTURE_IS_INVALID;
                }
                # Do any range and/or length checks on relaxed data
                $number_of_errors_found
                    += _min_max_error_count (
                        $schema_ref, 'range', $data_scalar,         $schema_type,
                        $navigation, $errors_ref, $schema_updater)
                     + _min_max_error_count (
                        $schema_ref, 'length', length($data_scalar),'length',
                        $navigation, $errors_ref);

                if ($schema_enum) {
                    my $ref_schema_enum = ref $schema_enum;
                    if ($ref_schema_enum) {
                        if ($ref_schema_enum eq 'ARRAY') {
                            # OK
                        } else {
                            push @{$errors_ref}, "[$navigation] Schema error: enum is not $A_SEQUENCE_WORD";
                            return $RESULT_SCHEMA_HAS_ERROR;
                        }
                    } else {
                        # enum is scalar - assume text list
                        ## Obsolete due to schema pre-processing ?? ##
                        my @enum_values = split( /,[ ]*/ , $schema_enum );
                        if (scalar @enum_values == 1) {
                            # Not comma delimited - try spaces
                            my @enum_values = split( /\s/ , $schema_enum );
                        }
                        $schema_enum = \@enum_values;
                    }
                    my $enum_found = 0;
                    ENUM:
                    for my $enum_value (@{$schema_enum}) {
                        # Check value supplied against enumeration value
                        
                        # We compare relaxed versions of the value
                        # supplied and the enumeration value.
                        
                        if (defined $schema_updater) {
                            $enum_value = $schema_updater->($RELAXED,
                                                            $enum_value);
                        }
                        if ( $TYPE_IS_NUMERIC{$schema_type} ) {
                            if ($data_scalar == $enum_value) {
        
                                $enum_found = 1;
                                last ENUM;
                            }
                        } else {
                            my $schema_enum_has_equivs =
                                    ($option_allow_equivalent_enums
                                     && $enum_value =~ / [=] /x );
                            if ($data_scalar eq $enum_value
                                && ! $schema_enum_has_equivs) {
                                # Exact match found, and equivs not applicable
                                $enum_found = 1;
                                last ENUM;
                            } elsif (    $option_case_insensitive_enums
                                       || $option_ignore_punctuation_enums
                                       || $option_allow_equivalent_enums ) {
                                my $matched_enum = _compare_case_punc(
                                                    $enum_value,
                                                    $data_scalar,
                                                    $option_case_insensitive_enums,
                                                    $option_ignore_punctuation_enums,
                                                    $option_allow_equivalent_enums,
                                                   );
                                if ($matched_enum ne '') {
                                    $enum_found = 1;
                                    if ($option_update) {
                                        # Change the case and/or punctuation of
                                        # the data to match enum, or the equivalent
                                        # to the value that matched
                                        $$modifiable_ref = $matched_enum;
                                    }
                                    last ENUM;
                                }
                            }
                        }
                    }
                    if (not $enum_found) {
                        my $x = join('', @{$schema_enum});
                        my $str_enums;
                        if ($x =~ / ^ \d+ $ /x) {
                            $str_enums = ': ' . join( ', ' , sort { $a <=> $b } @{$schema_enum} );
                        } else {        
                            $str_enums = ': ' . join( ', ' , sort @{$schema_enum} );
                        }
                        $str_enums = '' if length $str_enums > 80;
                        push @{$errors_ref}, "[$navigation] '$data_ref' is not one of the allowed values$str_enums";
                        $number_of_errors_found++;
                    }
                }
                if ($schema_unique) {
                    # Uniqueness constraint applies to this field
                    
                    if (ref $uniqueness_ref ne 'HASH') {
                        push @{$errors_ref}, "[$navigation] Schema error: uniqueness";
                        $number_of_errors_found++;
                    } else {
                        if (exists $uniqueness_ref->{$data_ref}) {
                            push @{$errors_ref}, "[$navigation] '$data_ref' is not unique";
                            $number_of_errors_found++;
                        } else {
                            $uniqueness_ref->{$data_ref}++;
                        }
                    }
                }
        
                if ($option_update) {
                    if (defined $schema_updater && $option_internalise) {
                    # Do any required conversions to internal format
                        my ($internalised_ref, $internalisation_err)
                             = $schema_updater->($INTERNALISE,
                                                 $data_scalar,
                                                 $option_dates_external,
                                                 $option_dates_internal);
                        if ($internalisation_err) {
                            push @{$errors_ref}, "[$navigation] $internalisation_err";
                            $number_of_errors_found++;
                        } else {
                            # No error on internalisation
                            if (ref $modifiable_ref ne 'SCALAR') {
                                print "Non-scalar-ref\n";
                                my $pause = 1;
                            }
                            eval {$$modifiable_ref = $internalised_ref;};
                            if ($@) {
                                print "err: $@\n";
                                print "data_scalar: $data_scalar\n";
                                my $ref = ref $modifiable_ref;
                                print "ref: $ref\n";
                                print "mod_ref: $$modifiable_ref\n";
                                print "debug_type: $debug_type\n";
                            }    
                        }
                    } elsif ($schema_ref->{default}
                             && ! defined $unmodified_data ) {
                        # There is a default which has been applied and does not
                        # need relaxation so update the returned data with it
                        $$modifiable_ref = $data_scalar;
                    }
                }
            }
        }
        
        if ($schema_type ne 'any' && ref $data_ref) {
            my $ref_data_ref = ref $data_ref;
            my $type_text = $ref_data_ref eq 'HASH'  ? "a $MAP_WORD"
                          : $ref_data_ref eq 'ARRAY' ? "$A_SEQUENCE_WORD"
                          : 'unknown';
            # Schema specifies scalar, but data is not scalar
            push @{$errors_ref}, "[$navigation] $schema_name '$data_ref' is $type_text, should be scalar";
            return $RESULT_STRUCTURE_IS_INVALID;
        }
    }
    if ($schema_type eq 'map' || $schema_type eq 'mapping') {
        # LOOKING FOR A MAP
        my $schema_mapping_ref = $schema_ref->{mapping} || $schema_ref->{map};
        if (! defined $schema_mapping_ref) {
            push @{$errors_ref}, "[$navigation] Schema error: type map but no mapping: ";
            return $RESULT_SCHEMA_HAS_ERROR;
        }
        my $ref_schema_mapping_ref = ref $schema_mapping_ref || 'scalar';
        if ($ref_schema_mapping_ref ne 'HASH') {
            push @{$errors_ref}, "[$navigation] Schema error: 'mapping:' is a $ref_schema_mapping_ref not a mapping";
            return $RESULT_SCHEMA_HAS_ERROR;
        }
        
        my $ref_data_ref = ref $data_ref;
        if ($ref_data_ref eq 'ARRAY') {
            # Array in data instead of the expected hash
            push @{$errors_ref}, "[$navigation] Data is $A_SEQUENCE_WORD, expected a $MAP_WORD";
            return $RESULT_STRUCTURE_IS_INVALID;

        } elsif ($ref_data_ref eq 'HASH') {
            # Expected a mapping, and that is what we found
            
        ## } elsif (length $ref_data_ref == 0) {
        } elsif (! defined $data_ref) {
            # expected a mapping, found undef
            push @{$errors_ref}, "[$navigation] Expected a $MAP_WORD, but found an empty field";
            return $RESULT_STRUCTURE_IS_INVALID;

        } else {
            # expected a mapping, found neither a mapping nor a sequence
            if ($option_allow_scalar_as_map) {
                my ($split_data_ref, $split_error_text) = _split_scalar_into_map($data_ref);
                if ($split_error_text) {
                    my $shortie = substr($data_ref, 0, 50);
                    push @{$errors_ref}, "[$navigation] Expected a $MAP_WORD, found a scalar: '$shortie'";
                    return $RESULT_STRUCTURE_IS_INVALID;
                } else {
                    if ($option_update) {
                        # Update the data in place
                        $$modifiable_ref  = $split_data_ref;
                    } else {
                        # Use a temporary array to validate the data we just split
                        # without updating the original data
                    }
                    $data_ref = $split_data_ref;
                    $ref_data_ref = ref $data_ref;
                }
            } else {
                my $shortie = substr($data_ref, 0, 50);
                $shortie =~ s/\n.*/.../;
                push @{$errors_ref}, "[$navigation] Expected a $MAP_WORD, found a scalar: '$shortie'";
                return $RESULT_STRUCTURE_IS_INVALID;
            }
        }
        # Check each entry in the schema against the data
               
        my @data_keys = sort keys %{$data_ref};
        my %data_keys_unmatched;
        for my $x (@data_keys) {
            $data_keys_unmatched{$x}++;
        }
        my @schema_mapping_keys = sort keys %{$schema_mapping_ref};
        my $number_of_keys_in_data = scalar keys %{$data_ref};

        $number_of_errors_found
            += _min_max_error_count($schema_ref, 'size', $number_of_keys_in_data,
                                    $schema_type, $navigation, $errors_ref);
        
        my $has_wild_card_key
           =   (scalar @schema_mapping_keys == 1
             && $schema_mapping_keys[0] =~ / ^ (?: < [^>]+ [>] | [=] ) $  /x);
           
        my $has_enum_of_keys
           =    (ref $schema_enum eq 'ARRAY'
              && scalar @{$schema_enum} > 0);
        
        ##if ($number_of_mapping_keys == 1
        ##    ###&& ($schema_enum && exists )
        ##    ## && $schema_mapping_keys[0] =~ /^<[^>]+>|^[=]$|^[\a]YAML[\a]VALUE[\a]$/) {
        ##    && $schema_mapping_keys[0] =~ / ^ < [^>]+ [>] | ^ [=] $ /x) {
            
        if ($has_wild_card_key
            && ! $has_enum_of_keys) {
            
            # Angle-bracketted mapping key (<example>:), or anonymous default (=:)
            # and no enum of allowable keys
            # Allow any key that matches pattern
            my $key_name = $schema_mapping_keys[0];
            $key_name = $key_name eq '=' ? 'default'
                                         : substr($key_name, 1, length($key_name) - 2);
            
            if (scalar @data_keys == 0 && $schema_required) {
                push @{$errors_ref}, "[$navigation] Required $MAP_WORD $schema_name is empty";
                return $RESULT_STRUCTURE_IS_INVALID;
            }
            my $uniqueness_ref = {};    # Empty hash for uniqueness checks
            for my $data_key (@data_keys) {
                if ($schema_pattern) {
                    my $regex_err_text = _regex_errors($data_key, $schema_pattern, $schema_pattern_text);
                    if ($regex_err_text) {
                        push @{$errors_ref}, "[$navigation] $key_name $regex_err_text";
                        $number_of_errors_found++;
                    }
                }
                my $structure_error = _is_structure_invalid(
                        $data_ref->{$data_key},
                        $schema_mapping_ref->{$schema_mapping_keys[0]},
                        $errors_ref,
                        "$navigation$data_key/",
                        $uniqueness_ref,
                        $anchor_ref,
                        $opts_ref,
                        \$data_ref->{$data_key},
                        );
                $number_of_errors_found++ if $structure_error;
            }
            
        } else {
            # mapping key is not <angle-bracketted>, or it also has an
            # enumeration of valid keys.
            
            # Allow only keys that appear in schema, and check that
            # all required keys are present in data

            ## To support case-forcing of keys supplied in the data, we have to
            ## check every key in the schema against every key in the data,
            ## at least if a hash lookup fails

            my $wild_card_key;
            if ($has_wild_card_key && $has_enum_of_keys) {
                $wild_card_key = $schema_mapping_keys[0];
                @schema_mapping_keys = sort @{$schema_enum};
                
                my $pause9 = 9;
            }
            for my $schema_key (@schema_mapping_keys) {

                my $selected_schema_key = $schema_key;
                my $data_key_to_check   = $schema_key;
                my $schema_key_has_equivs = ($option_allow_equivalent_keys
                                              && $schema_key =~ / [=] /x
                                            );
                
                if ( ! $schema_key_has_equivs
                    && exists $data_ref->{$schema_key} ) {
                    # This schema_key does not have equivalents
                    # and there is a key that matches exactly
                    # so we are happy - just remove it from the unmatched keys hash
                    delete $data_keys_unmatched{$schema_key};
                } else {
                
                    # There is no key in the data that exactly matches the
                    # schema key we are checking, or we are allowing equivalents
                    # and this schema has them.
                    # Check other data keys and align case, punctuation and
                    # equivalent by renaming the hash entry in the data.
                    
                    if (   $option_case_insensitive_keys
                        || $option_ignore_punctuation_map_keys
                        || $option_allow_equivalent_keys ) {
                        # Case or punctuation forcing wanted
                        # or equivalent keys allowed
                        # so we have to do a serial scan
                        my $match_count = 0;
                        my (@matches, @matched_keys);
                        for my $data_key (@data_keys) {
                            # Check each data key against the schema key
                            # Count how many match
                            #
                            # Example schema:
                            #       UK=GB=united kingdom=great britain: int
                            #       USA=us: int
                            #       France: int
                            # Example data:
                            #       United-Kingdom : 42
                            #   Matches third entry in list (case+punc insensitive),
                            #   but returns 'UK' as the value matching so that
                            #   the hash can be updated
                            #   Rejects data that has map entries for more than one equivalent
                            
                            my $matched_key = _compare_case_punc(
                                                   $schema_key,
                                                   $data_key,
                                                   $option_case_insensitive_keys,
                                                   $option_ignore_punctuation_map_keys,
                                                   $option_allow_equivalent_keys,
                                                   );
                            if ($matched_key ne '' ){
                                # Key is present in data with a possibly differently
                                # cased or punctuated or equivalent key
                                $match_count++;
                                push @matches, $data_key;
                                push @matched_keys, $matched_key;
                                delete $data_keys_unmatched{$data_key};
                            }
                        }
                        if ($match_count > 1) {
                            # More than one data key matches this schema key
                            ## BUT - we don't currently check if a data key
                            ##       matches more than one schema key
                            push @{$errors_ref},
                                  "[$navigation] Conflicting keys: "
                                  . join(', ', @matches);
                            $number_of_errors_found++;
                            $data_key_to_check = $matches[0];   # Prevent unmatched error
                            my $pause = 43;
                        } elsif ($match_count == 1) {
                            my $data_key = $matches[0];
                            if ($option_update) {
                                # Exactly one match, and we want to update data.
                                # Rename the entry in the hash to have the key from
                                # the schema rather than the one from the data that
                                # is differently cased
                                
                                my $to_key   = $matched_keys[0];
                                $selected_schema_key = $matched_keys[0];
                                $data_key_to_check = $to_key;
                                if ($data_key ne $to_key) {
                                    $data_ref->{$to_key} = $data_ref->{$data_key};
                                    delete $data_ref->{$data_key};
                                }
                            } else {
                                $data_key_to_check = $data_key;
                            }
                         }
                    }
                    # then if it is still missing...
                    if ( exists $data_ref->{$data_key_to_check} ) {
                        # not missing
                    } else {
                        # key is missing from data
                        if ($option_update
                            && ref $schema_mapping_ref->{$selected_schema_key} eq 'HASH'
                            && exists $schema_mapping_ref->{$selected_schema_key}
                            && exists $schema_mapping_ref->{$selected_schema_key}{default}
                            ) {
                            # key is missing from data
                            # but a default value is supplied and shoud be applied
                            $data_ref->{$selected_schema_key} = $schema_mapping_ref->{$schema_key}{default};
                        }
                    }
                }
            
                if (exists $data_ref->{$data_key_to_check} ) {
                    # Key is present in data now
                    # Check the value that is associated with this key, which
                    # might be a scalar or a structure
                    
                    my $structure_error = _is_structure_invalid(
                                $data_ref->{$data_key_to_check},
                                $schema_mapping_ref->{$wild_card_key || $schema_key},
                                $errors_ref,
                                "$navigation$data_key_to_check/",
                                $uniqueness_ref,
                                $anchor_ref,
                                $opts_ref,
                                \$data_ref->{$data_key_to_check},
                                );
                    $number_of_errors_found++ if $structure_error;
                } else {
                    # key not present in data
                    if (ref $schema_ref->{mapping}{$schema_key} eq 'HASH' 
                            && exists $schema_ref->{mapping}{$schema_key}{required} 
                            && $schema_ref->{mapping}{$schema_key}{required} =~ $BOOLEAN_TRUE_REGEX) {
                        my $name_text = $schema_name ? "from $schema_name" : '';
                        push @{$errors_ref}, "[$navigation] Required key '$schema_key:' is missing $name_text";
                        $number_of_errors_found++;
                    }
                }
            }
            for my $data_key (keys %data_keys_unmatched) {
                # one or more data keys are not present in schema
                ##my $str_keys = ': ' . join ', ', sort keys %{$schema_ref->{mapping}};
                my $str_keys = ': ' . join ', ', @schema_mapping_keys;
                $str_keys = substr($str_keys, 0, 80) . '...' if length ($str_keys) > 80;
                push @{$errors_ref}, "[$navigation] '$data_key' is not one of the allowed keys$str_keys" ;
                $number_of_errors_found++;
                if ($has_wild_card_key) {
                    # Wild card keys, but enumerated. The key values are not
                    # those expected, but we can still check the entries because
                    # they are all the same
                    my $structure_error = _is_structure_invalid(
                                $data_ref->{$data_key},
                                $schema_mapping_ref->{$wild_card_key},
                                $errors_ref,
                                "$navigation$data_key/",
                                $uniqueness_ref,
                                $anchor_ref,
                                $opts_ref,
                                \$data_ref->{$data_key},
                                );
                    $number_of_errors_found++ if $structure_error;
                }
            }
        }
    ####################################
    # Handle a Sequence
    ####################################
    } elsif ($schema_type eq 'seq') {
        # Handle a sequence
        my $schema_sequence_ref = $schema_ref->{sequence};
        ##if (! defined $schema_sequence_ref) {
        ##    # No sequence: entry, so try for seq: entry
        ##    $schema_sequence_ref = $schema_ref->{seq};
        ##}
        if (! defined $schema_sequence_ref) {
            
            # If a node with type: seq does not have a sequence: or seq: node 
            # we auto-vivify the sequence as an empty array
            ## May not be necessary now that we pre-process the schema
            $schema_ref->{sequence} = [];
            $schema_sequence_ref = $schema_ref->{sequence};
        }
        my $ref_schema_sequence_ref = lc ref $schema_sequence_ref;
        if ($ref_schema_sequence_ref ne 'array') {
            push @{$errors_ref}, "[$navigation] Schema error: 'sequence:' is a $ref_schema_sequence_ref not $A_SEQUENCE_WORD";
            return $RESULT_SCHEMA_HAS_ERROR;
        }
        if (scalar @{$schema_ref->{sequence}} > 1) {
            push @{$errors_ref}, "[$navigation] Schema error: 'sequence:' has more than one entry";
            return $RESULT_SCHEMA_HAS_ERROR;
        }
        # Validate each entry in the sequence
        
        my $ref_data_ref = ref $data_ref;
        if ($ref_data_ref eq 'HASH') {
            push @{$errors_ref}, "[$navigation] Expected $A_SEQUENCE_WORD, found a $MAP_WORD";
            return $RESULT_STRUCTURE_IS_INVALID;
        }

        my $data_to_pass_ref = $data_ref;
        if (defined $data_ref
            && ! $ref_data_ref
            && $option_allow_scalar_as_sequence) {
            # Data supplied is scalar, we expected a sequence, but we allow scalar
            # Split the scalar into chunks
            
            my $scalar_data = $data_ref;    # It is not a reference, name it better
            my $csv_lines_split = $opts_ref->{csv} || $opts_ref ->{csv_with_header};
            my $split_data_ref
                = _split_scalar($scalar_data,
                                    {newlines => $csv_lines_split} );
            if ($option_update) {
                # Update the data in place
                $$modifiable_ref  = $split_data_ref;
            } else {
                # Use a temporary array to validate the data we just split
                # without updating the original data
            }
            $data_to_pass_ref = $split_data_ref;
            $ref_data_ref = ref $data_to_pass_ref;
        }
        if ($ref_data_ref eq 'ARRAY') {

            my $number_of_entries_in_data_sequence = scalar @{$data_to_pass_ref};
            my $uniqueness_checker_ref = {};

            ## my $inner_type = $schema_ref->{sequence}[0]{type}; ## DEBUG ##
            ## if ($inner_type eq 'row') {
            ##    my $row_pause = '';
            ## }
            ## Consider allowing comments in sequences
            ## If only leading and trailing lines, we could detect them here and
            ## pop or shift the entries. Embedded comments would require a new
            ## array to be built
            ## _split_scalar already discards comment lines
            for my $seq ( 0 .. $number_of_entries_in_data_sequence - 1 ) {
                
                my $structure_error = _is_structure_invalid(
                                                $data_to_pass_ref->[$seq],
                                                $schema_ref->{sequence}[0],
                                                $errors_ref,
                                                $navigation
                                                . ($seq + $SEQUENCE_MESSAGE_BASE)
                                                . "/",
                                                $uniqueness_checker_ref,
                                                $anchor_ref,
                                                $opts_ref,
                                                \$data_to_pass_ref->[$seq],
                                                           );
                $number_of_errors_found++ if $structure_error;
 
            }
            $number_of_errors_found
               += _min_max_error_count($schema_ref, 'size',
                    $number_of_entries_in_data_sequence, $schema_type,
                    $navigation, $errors_ref);
            
        } else {
            if (defined $data_ref) {
                $ref_data_ref = lc $ref_data_ref || 'scalar';
                
                if ($ref_data_ref ne 'scalar') {
                    push @{$errors_ref}, "[$navigation] Expected $A_SEQUENCE_WORD, found a $ref_data_ref";
                    return $RESULT_STRUCTURE_IS_INVALID;    
                } else {
                    # Scalar found where sequence expected
                    
                    if (! $option_allow_scalar_as_sequence) {
                        return $RESULT_STRUCTURE_IS_INVALID;    
                    } else {
                        # Allowed to have scalar when sequence expected
                    }
                }
            } else {
                # Expected a sequence, found undef
                # Check whether sequence is required
                if (exists $schema_ref->{required}) {
                    my $schema_required = $schema_ref->{required} || '';
                    if (ref $schema_required eq '') {
                        # 'required' entry is a scalar
                        if ($schema_required =~ $BOOLEAN_TRUE_REGEX) {
                            # required: yes
                            # but the sequence is not present
                            push @{$errors_ref}, "[$navigation] Required $SEQUENCE_WORD is missing";
                            $number_of_errors_found++;
                        }
                    }
                }
            }
        }
    ##################################
    # Handle a Row
    ##################################
    } elsif ($schema_type eq 'row') {
        my $pause = 1;
        # EXPECTING A ROW
        
        # If we get a scalar, we split it into a sequence and then check each
        # entry in turn against the corresponding column entry
        
        # If we get a sequence, we check each entry in turn against the
        # corresponding column entry
        
        # If we get a map, we could check each entry in turn against the
        # correspondingly named column entry ??


        my $data_to_pass_ref = $data_ref;
        my $ref_data_ref     = ref $data_ref;
        if (defined $data_ref
            && ! $ref_data_ref ) {
            
            # Data supplied is scalar, which is what we expected
            # Split the scalar into chunks using complicated delimiter rules
            
            my $scalar_data = $data_ref;    # It is not a reference
            my $csv_opt     = $opts_ref->{csv}
                              || $opts_ref->{csv_with_header};
            my $split_data_ref
                 = _split_scalar($scalar_data,
                                 {csv_commas => $csv_opt} );
            if ($option_update) {
                # Update the data in place
                $$modifiable_ref  = $split_data_ref;
                $data_to_pass_ref = $split_data_ref;
            } else {
                # Use a temporary array to validate the data we just split
                # without updating the original data
                $data_to_pass_ref = $split_data_ref;
            }
            $ref_data_ref = ref $data_to_pass_ref;
        }
        
        $ref_data_ref     = ref $data_to_pass_ref;
        if (defined $data_to_pass_ref) {
            if ($ref_data_ref eq 'ARRAY' ) {
                # We have split a scalar row, or were passed an array
                # Now check each entry in turn against the corresponding schema entry
                
                my $number_of_columns_in_data   = scalar @{$data_to_pass_ref};
                my $number_of_columns_in_schema = scalar @{$schema_ref->{columns}};
                my $number_of_named_columns = 0;
                
                for my $col (0..$number_of_columns_in_schema - 1){
                    my $schema_col_ref = $schema_ref->{columns}[$col];
                    $number_of_named_columns++ if exists $schema_col_ref->{name};
                
                    my $data_col_ref   = $data_to_pass_ref->[$col];
                    
                    my $uniqueness_checker_ref = {};
                    my $structure_error = _is_structure_invalid(
                                            $data_col_ref,
                                            $schema_col_ref,
                                            $errors_ref,
                                            $navigation
                                              . ($col + $COLUMN_NUMBER_MESSAGE_BASE)
                                              . "/",
                                            $uniqueness_checker_ref,
                                            $anchor_ref,
                                            $opts_ref,
                                            \$data_to_pass_ref->[$col],
                                                           );
                    $number_of_errors_found++ if $structure_error;
                    
                    my $pause = 3;
                }
                if ($number_of_columns_in_data != $number_of_columns_in_schema) {
                    push @{$errors_ref}, "[$navigation]"
                         . " Expected $number_of_columns_in_schema columns,"
                         . " Found $number_of_columns_in_data columns";
                    $number_of_errors_found++;
                } 
                
                # Convert the array to a hash
                if ($option_update) {
                    
                    my %data_as_map;
                    for my $col (0..$number_of_columns_in_data - 1){
                        my $col_name = $schema_ref->{columns}[$col]{name};
                        if (   ! defined $col_name
                            || $col_name eq ''
                            || $col >= $number_of_columns_in_schema) {
                            $col_name = 'Column_' . ($col + $COLUMN_NUMBER_MESSAGE_BASE)
                        }
                        $data_as_map{$col_name} = $data_to_pass_ref->[$col];
                    }
                    $$modifiable_ref  = \%data_as_map;
                    my $pause = 2;
                }
            
                my $pause = 4;
            #
            # elsif we were passed a hash
            #    for each entry in columns array
            #       add column name to check hash
            #       if hash key exists in data
            #           validate column data
            #       else
            #           error 'missing column data'
            #    for each key in hash
            #       if key not in check hash
            #           error 'key does not match a column'
            
            } elsif ($ref_data_ref eq 'HASH') {
            
                my $number_of_columns_in_schema = scalar @{$schema_ref->{columns}};
                my %check_hash;
                
                for my $col (0..$number_of_columns_in_schema - 1){
                    my $schema_col_ref = $schema_ref->{columns}[$col];
                    my $col_name = $schema_col_ref->{name};
                    $check_hash{$col_name}++;
                    
                    if (exists $data_to_pass_ref->{$col_name}) {
                        my $data_col_ref = $data_to_pass_ref->{$col_name};
                        my $uniqueness_checker_ref = {};
                        my $structure_error = _is_structure_invalid(
                                                $data_col_ref,
                                                $schema_col_ref,
                                                $errors_ref,
                                                $navigation
                                                  . ($col_name)
                                                  . "/",
                                                $uniqueness_checker_ref,
                                                $anchor_ref,
                                                $opts_ref,
                                                \$data_to_pass_ref->{$col_name},
                                                               );
                        $number_of_errors_found++ if $structure_error;
                        
                        my $pause = 3;
                    } else {
                        push @{$errors_ref}, "[$navigation]"
                             . " Missing column $col_name";
                        $number_of_errors_found++;                        
                    }
                }
                for my $data_key (keys %{$data_ref}) {
                    if (! exists $check_hash{$data_key}) {
                        push @{$errors_ref}, "[$navigation]"
                             . " Key $data_key does not match any column";
                        $number_of_errors_found++;                        
                    }
                }
            
            } else {
                push @{$errors_ref}, "[$navigation] $schema_name should be scalar or $SEQUENCE_WORD";
                return $RESULT_STRUCTURE_IS_INVALID;
            }
        }
    } else {
        # Schema does not specify a map or a seq
        
        if ($schema_type ne 'any' && ref $data_ref) {
            my $ref_data_ref = ref $data_ref;
            my $type_text = $ref_data_ref eq 'HASH'  ? 'a $MAP_WORD'
                          : $ref_data_ref eq 'ARRAY' ? '$A_SEQUENCE_WORD'
                          : 'unknown';
            # Schema specifies scalar, but data is not scalar
            push @{$errors_ref}, "[$navigation] $schema_name '$data_ref' is $type_text, should be scalar";
            return $RESULT_STRUCTURE_IS_INVALID;
        }
    }
    return ($number_of_errors_found > 0);
}





# --------------------------------------------------------------------
# Update routines
#
# Update a scalar to standardised Perl-friendly format
# Can be called in two ways:
#   relaxed:    e.g. to strip out commas from numerics
#   Internalise:  e.g. to convert boolean N to 0
# Passed:
#   Call type: $RELAXED or $INTERNALISE
#   Data: scalar to be processed
# Returns:
#   Data, modified as necesssary
# --------------------------------------------------------------------
sub _update_int {
    my ($call_type, $data) = @_;
    my $error_text;
    if ($call_type == $RELAXED) {
        my $acceptable = _number_commas_acceptable($data);
        if ( defined $data && $acceptable ) {
            $data =~ s/ [,] //gx;
        }
    }
    return wantarray ? ($data, $error_text) : $data;
}
# --------------------------------------------------------------------
sub _update_float {
    my ($call_type, $data) = @_;
    my $error_text;
    if (defined $data && $call_type == $RELAXED) {
        $data =~ s/ [,] //gx;
    }
    return wantarray ? ($data, $error_text) : $data;
}
# --------------------------------------------------------------------
sub _update_num {
    my ($call_type, $data) = @_;
    my $error_text;
    if (defined $data && $call_type == $RELAXED) {
        $data =~ s/ [,] //gx;
    }
    return wantarray ? ($data, $error_text) : $data;
}
# --------------------------------------------------------------------
sub _update_bool {
    my ($call_type, $data) = @_;
    my $error_text;
    if ($call_type == $RELAXED) {
        if ($data eq '' || $data =~ $BOOLEAN_FALSE_REGEX) {
            $data = 0;  # Force boolean false to something false in Perl
        }
    }
    return wantarray ? ($data, $error_text) : $data;
}
# --------------------------------------------------------------------
sub _update_date {
    my ($call_type, $data, $option_text_ext, $option_text_int ) = @_;
    my $error_text;
    if ($call_type == $RELAXED) {
        # Pre-process non-YAML-standard dates
        # Parse date and decide if it is valid
        # If not, just return original field
        # If valid, update to yyyy-mm-dd format
        
        return _relaxed_dates($data, $option_text_ext);
    } else {
        # After
        # Convert yyyy-mm-dd to epoch seconds or Excel format
        my ($year, $month, $day);

        ($year, $month, $day) = ($data =~ /(....).(..).(..)/);
 
        my $epoch_seconds;
        if (defined $option_text_int && $option_text_int eq 'excel') {
            eval {$epoch_seconds = timegm(0, 0, 0, $day, $month - 1, $year - 1900);};
            my $err = $@;
            if ($@) {
                # timelocal barfed
                $error_text = "Date $data could not be converted to Excel";
                $data = 0;
            } else {
                $data = $epoch_seconds;
            }            
            $data = ($epoch_seconds / 86400) + 25569;
        } else {
            eval {$epoch_seconds = timelocal(0, 0, 0, $day, $month - 1, $year - 1900);};
            my $err = $@;
            if ($@) {
                # timelocal barfed
                $error_text = "Date $data could not be converted to epoch seconds";
                $data = 0;
            } else {
                $data = $epoch_seconds;
            }
        }
        return wantarray ? ($data, $error_text) : $data;
    }
}

# --------------------------------------------------------------------
sub _update_time {
    my ($call_type, $data, $option_text_ext, $option_text_int ) = @_;
    my $error_text;
    if ($call_type == $RELAXED) {
        # Pre-process non-YAML-standard times
        # Parse time and decide if it is valid
        # If not, just return original field
        # If valid, update to hh:mm:ss format
        
        return _relaxed_times($data, $option_text_ext);
    } else {
        # After
        # Convert hh:mm:ss to epoch seconds or Excel format
        my ($hours, $minutes, $seconds);

        ($hours, $minutes, $seconds) = ($data =~ /(..):(..):(..)/);
 
        my $epoch_seconds = $hours * 3600 + $minutes * 60 + $seconds;
        if (defined $option_text_int && $option_text_int eq 'excel') {
            $data = ($epoch_seconds / 86400);
        } else {
            $data = $epoch_seconds;
        }
        return wantarray ? ($data, $error_text) : $data;
    }
}
# --------------------------------------------------------------------
sub _update_timestamp {
    
    # Initial version
    # Assumes date occurs before time
    # Assumes time has no embedded spaces
    
    my ($call_type, $data, $option_text_ext, $option_text_int ) = @_;
    my $error_text;
    if ($call_type == $RELAXED) {
        # Pre-process non-YAML-standard times
        # Parse timestamp and decide if it is valid
        # If not, just return original field
        # If valid, update to yyyy-mm-dd hh:mm:ss format
        
        ##my ($date_part, $time_part) = split( / \s+ /x, $data, 2);
        my ($date_part, $time_part) = $data =~ /((?:\S+\s+)+)(\S+)/;
        $date_part =~ s/ \s+ $//x;
        my $relaxed_date = _update_date($call_type, $date_part,
                                        $option_text_ext, $option_text_int);
        my $relaxed_time = _update_time($call_type, $time_part,
                                        $option_text_ext, $option_text_int) || '';
        return $relaxed_date . ' ' . $relaxed_time;
    } else {
        # After
        # Convert yyyy-mm-dd hh:mm:ss to epoch seconds or Excel format
        my ($year, $month, $day, $hours, $minutes, $seconds);

        ($year, $month, $day, $hours, $minutes, $seconds)
            = ($data =~ /(....)-(..)-(..) (..):(..):(..)/);
 
        my $epoch_seconds_time = $hours * 3600 + $minutes * 60 + $seconds;
        if (defined $option_text_int && $option_text_int eq 'excel') {
            $epoch_seconds_time /= 86400;
        }
        
        my $epoch_seconds_date;
        if (defined $option_text_int && $option_text_int eq 'excel') {
            eval {$epoch_seconds_date = timegm(0, 0, 0, $day, $month - 1, $year - 1900);};
            my $err = $@;
            if ($@) {
                # timegm barfed
                $error_text = "Timestamp $data could not be converted to Excel";
                $epoch_seconds_date = 0;
            }            
            $data = ( ($epoch_seconds_date + $epoch_seconds_time) / 86400) + 25569;
        } else {
            eval {$epoch_seconds_date = timelocal(0, 0, 0, $day, $month - 1, $year - 1900);};
            my $err = $@;
            if ($@) {
                # timelocal barfed
                $error_text = "Timestamp $data could not be converted to epoch seconds";
                $data = 0;
            } else {
                $data = $epoch_seconds_date + $epoch_seconds_time;
            }
        }
        
        
        return wantarray ? ($data, $error_text) : $data;
    }
    
    
}
# --------------------------------------------------------------------
sub _do_nothing {}
# --------------------------------------------------------------------
sub _split_scalar {
    #
    # Passed: a scalar to split
    #       : options to control splitting 
    #            newlines:   boolean = split using only newlines
    #            csv_commas: boolean = split using commas
    # Returns: a reference to an array of fields within the scalar
    
    my ($scalar, $opt_ref) = @_;
    my $split_complete = 0;
    
    $scalar =~ s/ \s+ $ //x; # Trim trailing white space
    ##$scalar =~ s/ [ ]+ $ //x; # Trim trailing spaces
    $scalar =~ s/^ [\s]* \n //mgx; # Excise blank lines
    $scalar =~ s/ ^ [ ]* \# [^\n]* \n? //mgx; # Excise comment lines
    ## $scalar =~ s/ ^ [ ]* \# [^\n]* \n? //mgx; # Excise trailing comment
    
    my $opt_newlines   = $opt_ref->{newlines}   || 0;
    my $opt_csv_commas = $opt_ref->{csv_commas} || 0;
    my $opt_csv        = $opt_newlines || $opt_csv_commas;
    my $had_parentheses;
    
    ($scalar, $had_parentheses) = _strip_outer_parens($scalar)
        unless $opt_csv;
    
    my @list;
    if ($had_parentheses) {
        $list[0] = $scalar;
        return \@list;
    }
    @list = split(/ [ ]* \n [ ]* /x, $scalar, -1);
    if ($opt_newlines ) {
        return \@list;
    }    
    if (scalar @list == 1 && ! $opt_csv_commas) {
        # Only one line, try splitting on pipes
        my $first_char = substr($scalar,  0, 1);
        my $last_char  = substr($scalar, -1, 1);
        if ($first_char eq "|") {
            # The very first character is a pipe, drop it
            $scalar = substr($scalar, 1);
        }
        $scalar =~ s/   [ ]+ $ //x; # Trim trailing spaces
        if ($last_char eq "|") {
            # The very last character is a pipe, drop it
            $scalar = substr($scalar, 0, length($scalar) - 1);
        }
        @list = split(/ [ ]* [|] [ ]* /x, $scalar, -1);
    }
    
    if (scalar @list == 1) {
        # Only one line, try splitting on commas
        ## ??? If splitting on commas, don't allow commas within numbers

        ## ??? Split on commas that do not have digits adjacent both sides
        ## @list = split(/ (?<!\d) [,] | [,] (?!\d) /x, $scalar, -1);
        
        # If it fits within csv rules format, treat it as csv
        ##@list = split(/  [,]  /x, $scalar, -1);
        
        my $list_ref = _parse_csv($scalar);
        @list = @{$list_ref};
    }
    # Trim any leading and trailing spaces from the fields
    for my $field (@list) {
        my $first_char = substr($field,  0, 1);
        my $last_char  = substr($field, -1, 1);

        $field =~ s/ ^ [ ]+   //x if $first_char eq ' ';
        $field =~ s/   [ ]+ $ //x if $last_char  eq ' ';

        ($field) = _strip_outer_parens($field);
    }    
    return \@list;
    
    
}
# --------------------------------------------------------------------
sub _parse_csv_NOT_USED {
    
    # Passed: a string containing no newlines
    # Returns: a reference to an array containing the sub-fields of the
    #          string, split using Excel csv-format rules
    #               - sub-fields are delimited by commas outside of quoted strings
    #               - leading and trailing spaces are stripped off each sub-field
    #               - quoted sub-fields start and end with a double-quote
    #               - within a quoted sub-field, two adjacent double-quotes mean one double-quote
    #               - the outer quotes of a quoted sub-field are removed
    
    my ($line) = @_;
    my $col;
    $line .= "\n";
    my @cols = ( $line =~
                / [ ]*              # opt spaces
                  (                 # capture
                                    #   either
                         [^,"]*     #     zero or more not comma dq
                      |             #   or
                         "          #     dq
                         (?:        #     zero or more 
                            [^"]*   #         zero or more non-dq
                            ""      #         two dq
                         )*         #
                         [^"]*      #      zero or more non-dq
                         "          #      dq
                  )                 #
                  [ ]*              # opt spaces
                  [,\n]             # comma or newline
                  [ ]*              # opt spaces
                /gx);
    for $col (@cols) {
        if (substr($col, 0, 1) eq '"') {              # If quoted sub-field
            $col = substr($col, 1, length($col) - 2); #   Drop outer quotes
            $col =~ s/""/"/g;                         #   Combine adjacent quotes
        }
    }
    return \@cols;
}
# --------------------------------------------------------------------
sub _parse_csv {
    
    # Passed: a string containing no newlines
    # Returns: a reference to an array containing the sub-fields of the
    #          string, split using Excel csv-format rules
    #               - sub-fields are delimited by commas outside of quoted strings
    #               - leading and trailing spaces are stripped off each sub-field
    #               - quoted sub-fields start and end with a double-quote
    #               - within a quoted sub-field, two adjacent double-quotes mean one double-quote
    #               - the outer quotes of a quoted sub-field are removed
    
    my ($line) = @_;
    $line .= "\n";
    my @cols = ( $line =~
                / [ ]*              # opt spaces
                  (                 # capture
                                    #   either
                         [^,"]*?    #     lazy zero or more not comma dq
                      |             #   or
                         "          #     dq
                         (?:        #     zero or more 
                            [^"]*   #         zero or more non-dq
                            ""      #         two dq
                         )*         #
                         [^"]*      #      zero or more non-dq
                         "          #      dq
                  )                 #
                  [ ]*              # opt spaces
                  [,\n]             # comma or newline
                  [ ]*              # opt spaces
                /gx);
  
    map { s/^"|"$   # either start-of-string then dq
                    # or     dq then end-of-string
           //gx,    # Replace with null
         s/""       # two dqs
          /"/gx     # Replace with one dq
        } @cols;
    return \@cols;
}
# --------------------------------------------------------------------
sub _strip_outer_parens {
    
    # Passed a string
    # Returns the string with outer parentheses removed, provided that those
    # parentheses match each other, e.g.
    #       (content)
    # returns
    #        content
    # but
    #       (first) | (second)
    # and
    #       (first = (second)) | (third)
    # return unchanged, as the outer parentheses do not match each other even
    # though they are correctly matched
    #
    # Also returns a boolean: true if data had matching outer parentheses
    
    my ($text) = @_;
    my $original_text = $text;
    
    if ($text !~ / ^ [ ]* [(] /x ) {  # start-of-string, opt spaces, '('
        return ($original_text, 0);
    }
    if ($text !~ /   [)] [ ]* $ /x ) {  # ')',  opt spaces, end-of-string
        return ($original_text, 0);
    }
    $text =~ s/ \A [ ]* [(]             //x;    # Trim leading spaces and (
    $text =~ s/            [)] [ ]*  \z //x;    # Trim trailing ( and spaces
    
    my $nest_depth = 1;
    
    while ($text =~ / ( [()] )  /gx && $nest_depth > 0) {

        my $delim = $1;
        if (     $delim eq '(' ) {
            $nest_depth++;
        } elsif ($delim eq ')' ){
            $nest_depth--;
        }
    }
    return $nest_depth == 1 ? ($text, 1) : ($original_text, 0);
}

# --------------------------------------------------------------------
sub _min_max_error_count {
        
    # Passed:
    #   reference to schema hash
    #   key-name ('length', 'range' or 'size')
    #   value to check for min/max/min-ex/max-ex
    #   type (int, number, float, str, scalar, date, time, map)
    #   navigation string
    #   reference to errors array
    #   ref to schema updater routine (if required to convert data from relaxed
    #       input format to standard YAML format)
    # Returns:
    #   Number of errors found
    #    (and appends to errors array as a side-effect)
    
    my ($schema_ref, $key_name, $data_value, $schema_type,
        $navigation, $errors_ref, $schema_updater) = @_;
    
    my ($schema_min_check, $schema_max_check, $schema_min_ex_check, $schema_max_ex_check);

    my $errors_detected = 0;
    
    my $text_word = ($key_name eq 'range')                          ? 'value'    :
                    ($key_name eq 'size' && $schema_type eq 'seq' ) ? "size of $SEQUENCE_WORD" :
                    ($key_name eq 'size' && $schema_type eq 'map' ) ? 'number of keys' :
                     $key_name;

    if (defined $data_value && exists $schema_ref->{$key_name} ) {
        my $schema_check_ref = $schema_ref->{$key_name};
        if (ref $schema_check_ref eq 'HASH') {
            if ( exists $schema_check_ref->{'min'} )  {
                $schema_min_check = $schema_check_ref->{'min'};
            }
            if ( exists $schema_check_ref->{'min-ex'} )  {
                $schema_min_ex_check = $schema_check_ref->{'min-ex'};
            }
            if ( exists $schema_check_ref->{'max'} )  {
                $schema_max_check = $schema_check_ref->{'max'};
            }
            if ( exists $schema_check_ref->{'max-ex'} )  {
                $schema_max_ex_check = $schema_check_ref->{'max-ex'};
            }
            
        } elsif (ref $schema_check_ref eq 'ARRAY') {
            push @{$errors_ref}, "[$navigation] Schema error: $key_name must not be $A_SEQUENCE_WORD";
        } else {
            ## Obsolete ??? ##
            ## Following line may be hangover from when compact schemas were not
            ## pre-processed. It seems to assume that $schema_check_ref is a
            ## scalar rather than a reference, and that it contains the limits
            ## as text: <min> to <max>
            ## But - compact notation pre-processing supports "min <xx> max <yy>"
            ##       not "<xx> to <yy>" ????
            ($schema_min_check, $schema_max_check) = $schema_check_ref =~ /(\d+)\s+to\s+(\d+)/;
        }
        
        if (defined $schema_updater) {
            # relaxed min/max etc from schema
            ## Could be done when schema is validated
            ## But would make it difficult to display original schema values
            $schema_min_check    = $schema_updater->($RELAXED, $schema_min_check)    if $schema_min_check;
            $schema_max_check    = $schema_updater->($RELAXED, $schema_max_check)    if $schema_max_check;
            $schema_min_ex_check = $schema_updater->($RELAXED, $schema_min_ex_check) if $schema_min_ex_check;
            $schema_max_ex_check = $schema_updater->($RELAXED, $schema_max_ex_check) if $schema_max_ex_check;
            ## Should save original values from schema for error messages
        }
        
        my $numeric =    ($schema_type eq 'int'
                       || $schema_type eq 'float'
                       || $schema_type eq 'number'
                       || $schema_type eq 'num'
                       ## ?? || $schema_type eq 'seq'
                       || $schema_type eq 'length'
                       ||   $key_name  eq 'size'
                       );
        my $q = $numeric ? "" : "'";
        

        if (defined $schema_min_check) {
            if (   (   $numeric     && $data_value < $schema_min_check)
                || ( (not $numeric) && $data_value lt $schema_min_check) ) {
                push @{$errors_ref}, "[$navigation] $text_word is too small ($q$data_value$q is less than min $q$schema_min_check$q)";
                $errors_detected = 1;
            }
        }
        if (defined $schema_min_ex_check) {
            if (   (   $numeric     && $data_value <= $schema_min_ex_check)
                || ( (not $numeric) && $data_value le $schema_min_ex_check) ) {
                push @{$errors_ref}, "[$navigation] $text_word is too small ($q$data_value$q is not greater than $q$schema_min_ex_check$q)";
                $errors_detected = 1;
            }
        }
        if (defined $schema_max_check) {
            if (   (   $numeric && $data_value > $schema_max_check)
                || ( (not $numeric) && $data_value gt $schema_max_check) ) {
                push @{$errors_ref}, "[$navigation] $text_word is too large ($q$data_value$q is greater than max $q$schema_max_check$q)";
                $errors_detected = 1;
            }
        }
        if (defined $schema_max_ex_check) {
            if (   (   $numeric && $data_value >= $schema_max_ex_check)
                || ( (not $numeric) && $data_value ge $schema_max_ex_check) ) {
                push @{$errors_ref}, "[$navigation] $text_word is too large ($q$data_value$q is not less than $q$schema_max_ex_check$q)";
                $errors_detected = 1;
            }
        }
    }
    return ($errors_detected);
}
# --------------------------------------------------------------------
sub _not_in_hash {
    # Passed references to two hashes
    # Returns an array containing the keys that are present in the first
    # hash that are not present in the second, or a string with the keys
    # separated by a comma and a space

    my ($hash1_ref, $hash2_ref) = @_;    
    my @this_not_that = ( );
    foreach (keys %{$hash1_ref}) {
            push(@this_not_that, $_) unless exists $hash2_ref->{$_};
    }
    return wantarray ? @this_not_that : join (', ' , @this_not_that);
}
# --------------------------------------------------------------------
sub _compare_case_punc {
    # Compares two strings, possibly ignoring case and punctuation and
    # possibly allowing equivalents
    #
    # Passed:
    #   1) key (or key list) A
    #   2) key B
    #   3) case option: boolean, true if case-insensitive
    #   4) punctuation option: true if punctuation to be ignored
    #   5) equivalents option: true if pipe characters in key A are used to
    #      separate equivalents
    # Returns:
    #   - a string containing the first equivalent, if any of the equivalents match
    #   - a null string if none of the equivalents match
    
    my ($key_A, $key_B, $ignore_case, $ignore_punc, $check_equivalents) = @_;

    $key_A = '' unless defined $key_A;
    $key_B = '' unless defined $key_B;
    if ($check_equivalents) {
        $key_B = lc $key_B      if $ignore_case;
        $key_B =~ s/ [ _-] //gx if $ignore_punc;
        
        my @equivalents =  split( / \s* [=] \s*  /x, $key_A);
        my $original_equiv = $equivalents[0];
        for my $equiv (@equivalents) {
            if ($ignore_case) {
                $equiv = lc $equiv;
            }
            if ($ignore_punc) {
                $equiv =~ s/ [ _-] //gx;    # Strip out dash, underscore, space
            }
            return $original_equiv if $equiv eq $key_B;
        }
    } else {
        my $original_key_A = $key_A;
        if ($ignore_case) {
            $key_A = lc $key_A;
            $key_B = lc $key_B;
        }
        if ($ignore_punc) {
            $key_A =~ s/ [ _-] //gx;    # Strip out dash, underscore, space
            $key_B =~ s/ [ _-] //gx;    # Strip out dash, underscore, space
        }
        return $original_key_A if $key_A eq $key_B;
    }
    return '';
}
# --------------------------------------------------------------------

sub unload {
    # Data unloader - OO method
    
    my ($self, $data_ref, $opts_ref) = @_;
    my ($data_unloaded, $opts_errs) = unload_data($data_ref, $self->{schema}, $opts_ref);
    return wantarray ? ($data_unloaded, $opts_errs) : $data_unloaded;
}

# --------------------------------------------------------------------

sub unload_data {
    
# Passed:
#   - data structure
#   - schema structure
#   - options structure
#
# Builds an output structure by deep copying the supplied structure, converting
# from internalised format to strict format, and optionally to relaxed format

# It assumes that the data conforms to the schema

# Where no schema details are available, such as when data is supplied for
# a sub-schema of type 'any', standard formats are used

#### ASSUMES THAT DATA HAS BEEN INTERNALISED
####         DATES TO EPOCH SECONDS
####         BOOLEANS TO VALUES WHICH PERL TREATS AS TRUE OR FALSE
#### Should check options (supplied and/or in schema) before converting from
#### internal to standard format



    my ($data_ref, $schema_ref, $opts_ref) = @_;
    my $data_as_structure = undef;    
    my $output_errors;
    my ($updated_options_ref, $options_errors)
            = _check_options($opts_ref, _default_options_update() );

    if ( ! $options_errors) {
        $data_as_structure
            = _data_output_structure($schema_ref, $data_ref, $updated_options_ref);
    }
    my $output_format = $updated_options_ref->{unload_format} || 'YAML+';
    my $pause = 1;
    if ($output_format eq 'structure') {
        return wantarray ? ($data_as_structure, $options_errors) : $data_as_structure;
    } elsif ($output_format eq 'YAML' || $output_format eq 'YAML+') {
        my $data_as_YAML = _YAML_dump($data_as_structure);
        return wantarray ? ($data_as_YAML, $options_errors) : $data_as_YAML;
    } elsif ($output_format eq 'csv') {
        return wantarray ? ($data_as_structure, $options_errors) : $data_as_structure;
    } else {
        my $data_as_flow = _to_flow($data_as_structure, $output_format) . "\n";
        return wantarray ? ($data_as_flow, $options_errors) : $data_as_flow;
    }
}
#------------------------------------
sub _data_output_structure {

    my ($schema_ref, $data_ref, $opts_ref) = @_;

    # Walk the data and schema in parallel
    
    my $unload_format = $opts_ref->{'unload_format'} || 'structure';
    my $ref_data_ref = ref $data_ref;

    my $schema_type = '';

    if (defined $schema_ref
        && ref $schema_ref eq 'HASH'
        && exists $schema_ref->{type}) {
            $schema_type = $schema_ref->{type} || '';
    }

    if ( ! defined $data_ref ) {
        # data is undef
        return undef;
    } elsif ( ! $ref_data_ref ) {
        # data is not a reference
        my $scalar_data = $data_ref;

        if ($schema_type eq 'date') {
            # if date internalised, convert to standard
            return $scalar_data if ($scalar_data !~ / ^ -? \d+ \z /x);
                                                #   sos then opt - then one or more digits then eos
            my ($yy, $mm, $dd) = (localtime($scalar_data))[5, 4, 3];
            # if relaxation wanted, do it here
            my $date_option_int = $opts_ref->{dates}{internal} || '';
            my $date_option_ext = $opts_ref->{dates}{external} || '';
            # External: defaults to YAML standard yyyy-mm-dd
            #           supports ddmmyy, mmddyy, US,UK, Aus, Nz
            #               dmy ddmmyy ddmmyyyy dd-mm-yyyy dd/mm/yy dd/mm/yyyy
            #               ddth month yy etc.
            #               d = one or two digits, dd = two digits
            #               dth or ddth = one or two digit ordinal number
            #               m = one or two digits, mm = two digits,
            #                mon or Mon or mmm or Mmm = three letters,
            #                month or Month = full month name
            #                month, or Month, = full month name and comma
            #               yy = two digit year, yyyy = for-digt year
            #               allow any valid d/m/y sequence on input,
            #            convert to specified format on output
            # Internal
            if ($date_option_int eq 'excel') {
                if ($date_option_ext eq '') {
                    
                }
            }
            return ($yy + 1900 . '-'
                               . sprintf('%02d', $mm + 1) . '-'
                               . sprintf('%02d', $dd)
                               );
        } elsif ($schema_type eq 'bool') {
            # if boolean internalised, convert to standard
            return $scalar_data ? 'true' : 'false';
        } elsif ($schema_type eq 'time') {
            # if time internalised, convert to standard
            # Assuming seconds within day (sort of epoch seconds)
            # When we support unloading Excel time, we will have to convert fractional days
            
            my $time_option_int = $opts_ref->{dates}{internal} || '';
            my $time_option_ext = $opts_ref->{dates}{external} || '';
            
            if ($time_option_int eq 'excel') {
                $scalar_data *= 24 * 60 * 60;
            }
            my $secs  = $scalar_data % 60;
            my $mins  = int($scalar_data / 60);
            my $hours = int($mins / 60) % 24;
            my $mm    = $mins % 60;
            
            my $quote = $unload_format eq 'YAML_flow' ? '"' : '';
            my $time = sprintf('%02d:%02d:%02d', $hours, $mm, $secs);
            return $quote . $time . $quote;
        } elsif ($schema_type eq 'timestamp') {
            # if date internalised, convert to standard
            return $scalar_data if $scalar_data !~ / ^ \d+ $ /x;            
            my ($yy, $mon, $dd, $hour, $min, $ss) = (localtime($scalar_data))[5, 4, 3, 2, 1, 0];
            # if relaxation wanted, do it here

            my $date_option_int = $opts_ref->{dates}{internal};
            my $date_option_ext = $opts_ref->{dates}{external};

            my $stamp =   $yy + 1900 . '-'
                        . sprintf('%02d', $mon + 1) . '-'
                        . sprintf('%02d', $dd)      . ' '
                        . sprintf('%02d', $hour)    . ':'
                        . sprintf('%02d', $min)     . ':'
                        . sprintf('%02d', $ss) 
                        ;
            my $quote = $unload_format eq 'YAML_flow' ? '"' : '';                        
            return $quote . $stamp . $quote;
        } elsif ( ($schema_type eq 'int' || $schema_type eq 'number')
                  && $unload_format eq 'YAML+') {
            
            ## my $quote = '';
            while ($scalar_data =~ s/(?<![.]) (\d+) (\d{3})/$1,$2/x) {
                # A comma has been inserted by the substitution
                # But don't need to do anything
                
                ## $quote = $unload_format eq 'YAML_flow' ? '"' : '';
                ## Cannot be YAML_flow here
            }
            ## return $quote . $scalar_data . $quote;
            return $scalar_data;
        } else {
            # Plain scalar, presumably a string
            if ($unload_format eq 'csv') {
                # csv format data wanted
                if (   $scalar_data =~
                    /
                          [,"]      # Contains comma or double-quote
                      |   \A [ ]    # Or has leading space(s)
                      |   [ ] \z    # Or has trailing space(s)
                    /x) {
                    # String needs to be quoted
                    $scalar_data =~ s/"/""/g;
                    $scalar_data = '"' . $scalar_data . '"';
                } 
            }
            return $scalar_data;
        }

    } elsif ( $ref_data_ref eq 'ARRAY') {
        # Array
        my @out_array;   # start with an empty array
        my $has_table = 0;
        my $sub_schema;
        if (defined $schema_ref 
           && ref $schema_ref eq 'HASH'
           && exists $schema_ref->{sequence}
           && ref ($schema_ref->{sequence}) eq 'ARRAY') {
               
            $sub_schema = $schema_ref->{sequence}[0];
           
            # If it's really a table, the sub-schema will have type 'row'.
            # Only format a table as a table (rather than as an array of hashes)
            # if output format is YAML+, because it's not standard YAML
            
            ## To get block format data from tables converted to multi-line
            ## strings, force YAML.pm by setting
            ##       local $YAML::UseBlock = 1;
            ##       local $YAML::Indent = 4;  # is probably a good idea as well
           
            # First cut: convert to an array of scalars
            #            each scalar corresponds to one row of the table
            #            columns within scalar are delimited by pipe unless the
            #              data contains pipes
            #            first build array of array of scalars
            #               [table_row][column_number]
            #            and concurrently update array of max-width [column_number]
            
           
            if (ref $sub_schema eq 'HASH'
               && defined $sub_schema->{type}
               && $sub_schema->{type} eq 'row'
               && $unload_format =~ / YAML[+] | csv /xi ) {
                my @table_contents;
                my @max_column_width;
                my $pipe_seen  = 0;
                my $comma_seen = 0;
                
                my @column_names;
                for my $schema_column_ref (@{$sub_schema->{columns}}) {
                    my $col_name = $schema_column_ref->{'name'};
                    push @column_names, $col_name;
                    push @max_column_width, length($col_name);
                }
                if (_is_ref_to_array($data_ref)){
                    for my $row (@{$data_ref}) {
                        my $col_ndx = 0;
                        my @row_contents;
                        for my $schema_column_ref (@{$sub_schema->{columns}}) {
                            my $pause = 7;
                            my $col_name = $schema_column_ref->{'name'};
                            my $col_contents = _data_output_structure($schema_column_ref,
                                         $row->{$col_name},
                                         $opts_ref);
                            $col_contents = '' unless defined $col_contents;
                            $pipe_seen  = $pipe_seen  || $col_contents =~ /\|/x;
                            $comma_seen = $comma_seen || $col_contents =~ /\,/x;
                            my $column_width = length($col_contents);
                            if ($column_width >= ($max_column_width[$col_ndx] || 0)   ) {
                                $max_column_width[$col_ndx] = $column_width;
                            }
                            push @row_contents, $col_contents;
                            $col_ndx++;
                        }
                        push @table_contents, \@row_contents;
                    }
                    
                    my $col_sep = $unload_format =~ /csv/ ? ','
                                : $pipe_seen              ? ','
                                :                           '|';
                    my $number_of_columns = scalar @{$sub_schema->{columns}};
                    for my $row_ref (@table_contents) {
                        my $row_text = "";
                        $row_text = "| " if $col_sep eq '|';
                        for my $col_ndx (0 .. $number_of_columns - 1) {
                            my $cell_text = $row_ref->[$col_ndx];
                            $cell_text .= ' ' x ($max_column_width[$col_ndx] - length($cell_text) );
                            $row_text  .= ' ' if $col_sep eq '|';
                            $row_text  .= $cell_text . "$col_sep ";
                        }
                        chop $row_text; # Drop trailing space
                        chop $row_text; # Drop trailing separator
                        push @out_array, $row_text
                        
                    }
                    my $pause = 8;
                    if ($unload_format =~ /csv/) {
                        if ($unload_format eq 'csv_with_header') {

                            my $header_line = '';
                            my $cum_width = 0;
                            for my $col_ndx (0 .. scalar @column_names - 1) {
                                my $col_name = $column_names[$col_ndx];
                                $header_line .= $col_name;
                                $header_line .= ' ' x ($max_column_width[$col_ndx] - length($col_name) );
                                $header_line .= ', '; 
                            }
                            chop $header_line;  # Drop trailing space
                            chop $header_line;  # Drop trailing comma
                            unshift @out_array, $header_line;                            
                            #unshift @out_array, join(', ', @column_names);
                        }
                        return join( "\n", @out_array);  
                    } else {
                        return \@out_array;
                    }
                } else {
                    # Data is not an array, so don't treat it as a table
                }
               
            } else {
                
                # Not a table, drop through to normal array handling
                my $pause = 1;
            }
         }
        for my $array_index ( 0 .. (scalar @{$data_ref}) - 1 ) {            
            $out_array[$array_index]
                = _data_output_structure($sub_schema,
                                         $data_ref->[$array_index],
                                         $opts_ref);
        }
        return \@out_array;
        
    } elsif ( $ref_data_ref eq 'HASH'
             || _is_ref_to_hash($data_ref) ) {
        
    
        # Hash or table or a blessed hash (e.g. an object)
        
        # If it's a table, schema type will be 'row' and there should be a
        # 'columns:' key with an array of column entries
        
        # If it's a map, schema type will be 'map' and there should be a mapping: key
        # with allowable keys

        # We walk the keys in the data, find the corresponding key in the schema (which
        # may have alternatives) and recurse

        my @data_keys = keys %{$data_ref};
        my %out_hash;  # Start with an empty hash
        if ($schema_type eq 'row'
         || $schema_type eq 'map') {
            

            my @schema_keys_array;
            my %schema_keys_hash;
            my $sub_schema;
            my $wild_card;

            if (defined $schema_ref 
               && ref $schema_ref eq 'HASH') {
                
                if ($schema_type eq 'map'
                  && exists $schema_ref->{mapping}
                  && ref ($schema_ref->{mapping}) eq 'HASH'  ) {
                    @schema_keys_array = keys %{$schema_ref->{mapping}};

                    for my $schema_key (@schema_keys_array) {
                        if ($schema_key =~ / ^ < .* > $ /x) { 
                            # Wild card key
                            $wild_card = $schema_ref->{mapping}{$schema_key};
                        } else {
                            my @schema_key_options = split(/=/x, $schema_key);
                            for my $schema_key_option(@schema_key_options) {
                                $schema_keys_hash{$schema_key_option} 
                                    = $schema_ref->{mapping}{$schema_key};                                
                            }
                        }
                    }
                } elsif ($schema_type eq 'row'
                    && exists $schema_ref->{columns}
                    &&   ref ($schema_ref->{columns}) eq 'ARRAY' ) {
                    for my $column ( @{$schema_ref->{columns}} ) {  
                        $schema_keys_hash{$column->{name}} = $column;
                    }
                }
            }
            for my $key (@data_keys) {
                $sub_schema = $wild_card || $schema_keys_hash{$key};
                $out_hash{$key} = _data_output_structure( $sub_schema,
                                                         $data_ref->{$key},
                                                         $opts_ref);
            }
        } else {
            # Don't understand the schema type - might be 'any'
            for my $key (@data_keys) {
                $out_hash{$key} = _data_output_structure( undef,
                                                         $data_ref->{$key},
                                                         $opts_ref);
            }
        }
        return \%out_hash;
        

    } else {
        # Data is a reference, but not to a hash or array or something that acts
        # like a hash (e.g. a blessed hash)
        return "??? Reference to $ref_data_ref ???";
    }
}
#------------------------------------
sub _is_ref_to_hash {
    # Passed a reference
    # Returns true if the reference refers to a hash, even if it is bleesed
    my ($ref) = @_;
    
    eval {exists $ref->{"arbitrary key value"}};
    return not $@;
    
}

#------------------------------------
sub _is_ref_to_array {
    # Passed a reference
    # Returns true if the reference refers to an array
    my ($ref) = @_;
    
    eval {exists $ref->[0]};
    return not $@;
    
}
# --------------------------------------------------------------------
#------------------------------------
sub _to_flow {
    # Passed:
    #   1) a reference to a structure, or a scalar
    #   2) a string indicating Perl, JSON or YAML-flow output format
    #   3) a depth number
    # Returns a JSON, Perl or YAML (flow format) string representing the structure
    
    
    my ($data_ref, $lang, $depth) = @_;
    
    my $json = $lang =~ /JSON/xi;
    my $perl = $lang =~ /Perl/xi;
    
    $depth = $depth || 0;
    
    my $LEFT_BRACE    = '{';
    my $RIGHT_BRACE   = '}';
    my $LEFT_BRACKET  = '[';
    my $RIGHT_BRACKET = ']';
    my $KEY_SEPARATOR = $json ? ': '   :
                        $perl ? ' => ' :
                                ': '   ;
    my $COMMA_SPACE   = ', ';
    my $inset = 3;
    my $align_closers = 0;  # Align closing brackets and braces vertically
    
    my $ref_data_ref = ref $data_ref;
    if ( ! defined $data_ref ) {
        return $perl ? 'undef':
               $json ? 'null' :
                       'null' ;
                       
    } elsif ( ! $ref_data_ref) {
        # Not a reference
        return _string_escaped($data_ref, $perl, $json);
    } elsif ($ref_data_ref eq 'SCALAR') {
        return _string_escaped(${$data_ref}, $perl, $json);        
    } elsif ($ref_data_ref eq 'HASH') {
        my $prefix = $LEFT_BRACE;
        my $hash = '';
        for my $key (keys %{$data_ref}) {
            $hash .= "\n" . ' ' x ($depth * $inset) . $prefix
                   . _key_escaped($key, $perl, $json)
                   . $KEY_SEPARATOR
                   . _to_flow ($data_ref->{$key}, $lang, $depth + 1)
                   . $COMMA_SPACE
                   ;
            $prefix = ' ';
        }
        $hash =~ s/ , [ ] $ //x ; # Remove last comma and space
        $hash .= ("\n" . ' ' x ($depth * $inset)) x $align_closers . $RIGHT_BRACE; 
        return $hash;
    } elsif ($ref_data_ref eq 'ARRAY') {
        my $prefix = "\n" . ' ' x ($depth * $inset) . $LEFT_BRACKET;
        my $array =  '';
        for my $val (@{$data_ref}) {
            $array .= $prefix 
                    . _to_flow($val, $lang, $depth + 1)
                    . $COMMA_SPACE
                    ;
            $prefix = ' ';
        }
        $array =~ s/ , [ ] $ //x ; # remove last comma, space
        $array .= ("\n" . ' ' x ($depth * $inset)) x $align_closers . $RIGHT_BRACKET;
        return $array;
    }
}
#------------------------------------
sub _key_escaped {
    # Passed a scalar to be used as a hash key
    # Returns a string with any necessary quotes and escapes applied
    my ($string, $perl, $json) = @_;
    
    if ($perl && $string =~ / ^ \w+ $ /x) {
        return $string;
    } else {
        return _string_escaped($string, $perl, $json);
    }
}
#------------------------------------
sub _string_escaped {
    # Passed a scalar
    # Returns a quoted string with any necessary escapes applied
    
    my ($string, $perl, $json) = @_;
    my $Q;
    $string =~ s/ [\\] /\\\\/gx;    # One back-slash becomes two back-slashes
    if ($perl) {
        $string =~ s/ [']  /\\'/gx;     # Single-quote character become back-slash, single-quote
        $Q = "'";
    } elsif ($json) {
        $string =~ s/ ["]  /\\"/gx;     # Double-quote character become back-slash, double-quote
        $string =~ s/ \n   /\\n/gx;     # Newline becomes back-slash, letter n
        $string =~ s/ \t   /\\t/gx;     # tab becomes back-slash, letter t
        $string =~ s/ \f   /\\f/gx;    
        $string =~ s/ [\b] /\\b/gx;
        $string =~ s/ \r   /\\r/gx;
        $string =~ s{ [/] }{\\/}gx;     # One slash becomes back-slash, slash
        $Q = '"';
    } else {
        $Q = '';
    }
    if ($string =~ / ^ [-]? \d+ (?: [.] \d+ )? $ /x) {
        # A number acceptable to JSON or perl
        return $string;
    } else {
        return $Q . $string . $Q;
    }
}
#------------------------------------

sub _pre_process_schema {


    # Converts compact (or mixed compact/kwalify) schema to kwalify format, if
    # the schema type is not already strict Kwalify.
    # 
    #
    # Passed:
    #   - a reference to a YAML schema in kwalify and/or compact format
    #   - a reference to an array in which to store error information
    #   - a reference to a hash in which to store anchors
    #   - schema format (strict kwalify, compact-only or automatic (mixed)
    #   - navigation text
    #
    # Returns:
    #   A reference to the updated schema
    #
    # Side-Effects:
    #   Appends entries containing text description of errors to the error array
    # 
    # Usage:
    #   $schema_ref = _pre_process_schema($schema_ref, \@errors, \%anchors, $schema_format, $navig);
    #
    # Walks the schema, looking for anchors
    #
    # For each anchor that it finds, it creates an entry in the hash, containing
    # a reference to the appropriate point in the schema structure
    #


    my ($schema_ref, $errors_ref, $anchors_ref, $schema_format, $navigation) = @_;
    
    if (not defined $errors_ref) {
        $errors_ref = [];
    }
    if (not defined $anchors_ref) {
        $anchors_ref = {};
    }
    if (not defined $navigation) {
        $navigation = '/';
    }
    my $up_ref = $schema_ref;
    
    if (not defined $schema_format)  {
        $schema_format = $SCHEMA_FORMAT_AUTO;
    }
    my $strict       = ($schema_format == $SCHEMA_FORMAT_STRICT_KWALIFY);
    my $compact_only = ($schema_format == $SCHEMA_FORMAT_COMPACT_ONLY);
    my $auto         = ( ! $strict && ! $compact_only );
    my $ref_schema_ref = lc ref $schema_ref;
    my $kwalify = 0;    # True = already kwalify, False = compact
        

    # Not already strict kwalify - compact-only or auto

    if ($ref_schema_ref eq 'array') {
        # Passed an array as the schema
        # So it must be compact
        
        $up_ref = { type => 'seq', sequence => $schema_ref };
        
        if (scalar @{$schema_ref} > 1 ) {
            # Arrays as schemas are allowed an optional <control> entry, and
            # must have a single definition entry which defines the
            # allowable contents for every entry in the array being defined.
            
            ## Could allow multiple entries as alternatives - see notes about
            ## 'Alternations'.

            if (scalar @{$schema_ref} > 2 ) {
                push @{$errors_ref}, "[$navigation] Too many entries in schema $SEQUENCE_WORD ";
                return $schema_ref;
            }
            # Exactly two entries - examine the first to ensure it's <control>
            my $first_entry = shift(@{$schema_ref});
            
            if (ref $first_entry eq 'HASH'
                && defined $first_entry->{"<control>"} ) {
                # Cope with extra colon (like <control> in a hash), e.g.
                #           - <control>: whatever
                # instead of
                #           - <control> whatever
                $first_entry = "<control> " . $first_entry->{"<control>"};
            }
            if ($first_entry !~ / ^ <control> /x ) {
                push @{$errors_ref}, "[$navigation] Schema $SEQUENCE_WORD first entry not <control>";
                return $schema_ref;
            }

            my $control_text = substr($first_entry, length('<control>') );
            my $control_errs = _handle_control_line($control_text, $up_ref);
            push @{$errors_ref}, $control_errs if $control_errs;
        }
        $up_ref->{'sequence'}[0] =
              _pre_process_schema( $schema_ref->[0],
                                  $errors_ref,
                                  $anchors_ref,
                                  $schema_format,
                                  $navigation . "[0]/"
                                 );
    } elsif ( $ref_schema_ref eq 'hash' ) {
        # Passed a hash as the schema
        # Decide whether to treat as kwalify or compact

        my $explicit = $schema_ref->{kwalify};
        if (defined $explicit) {
            if      ($explicit =~ $BOOLEAN_TRUE_REGEX) {
                # Explicitly kwalify
                $kwalify = 1;
                $schema_format = $SCHEMA_FORMAT_STRICT_KWALIFY;
            } elsif ($explicit =~ $BOOLEAN_FALSE_REGEX) {
                # Explicitly not kwalify
                $kwalify = 0;
                $schema_format = $SCHEMA_FORMAT_AUTO;
            } else {
                # kwalify key does not have a valid boolean value
                # Arbitrarily treat it as compact
                $kwalify = 0;
            }
            delete $schema_ref->{kwalify};
        } else {
            # Not explicitly stated as kwalify or not
            # So look use specified format
            if ($schema_format == $SCHEMA_FORMAT_STRICT_KWALIFY) {
                $kwalify = 1;
            }
        }
        #if ( $auto ) {
        #    # Auto/mixed schema
        #    # Decide whether to treat as kwalify or compact
        #    my $non_kwalify_keys = _not_in_hash($schema_ref, \%SCHEMA_VALID_KEYS);
        #    my $key_count = scalar keys %{$schema_ref};
        #    if ($non_kwalify_keys) {
        #        # Not all keys are valid kwalify
        #        if ($non_kwalify_keys eq 'kwalify') {
        #            my $explicit = $schema_ref->{kwalify};
        #            if      ($explicit =~ $BOOLEAN_TRUE_REGEX) {
        #                # Explicitly kwalify
        #                $kwalify = 1;
        #                $schema_format = $SCHEMA_FORMAT_STRICT_KWALIFY;
        #            } elsif ($explicit =~ $BOOLEAN_FALSE_REGEX) {
        #                # Explicitly not kwalify
        #                $kwalify = 0;
        #                $schema_format = $SCHEMA_FORMAT_AUTO;
        #            } else {
        #                # kwalify key does not have a valid boolean value
        #                # Arbitrarily treat it as compact
        #                $kwalify = 0;
        #            }
        #            delete $schema_ref->{kwalify};
        #        } else {
        #            # Assume compact format
        #            # If it is really kwalify with mis-spellings, we are in trouble
        #            $kwalify = 0;
        #        }
        #    } else {
        #        ## All keys are valid in a kwalify-format schema
        #        ## But assume non-kwalify format anyway 2012-02-04
        #        $kwalify = 0;
        #    }
        #}
        if ($kwalify) {
            # It is auto/mixed, and we decided to treat hash as kwalify
            # So leave it for now
            # and drop through into the kwalify handler below
        } else {
            # It is compact-only,
            # or auto/mixed and we decided to treat hash as compact
            # or it has an explict kwalify: no entry
            $up_ref = { type => 'map', mapping => $schema_ref };
            foreach my $key (keys %{$schema_ref} ) {
                # convert each sub-schema
                if ($key eq 'kwalify') {
                    delete $schema_ref->{kwalify};
                } elsif ($key eq '<control>') {
                    my $control_text = $schema_ref->{$key};
                    my $control_errs = _handle_control_line($control_text, $up_ref);
                    push @{$errors_ref}, $control_errs if $control_errs;
                    delete $schema_ref->{'<control>'};
                } else {
                    my $hash_entry =
                        _pre_process_schema($schema_ref->{$key},
                                            $errors_ref,
                                            $anchors_ref,
                                            $schema_format,
                                            $navigation . "$key/"
                                           );
                    if (my ($key_text) = $key =~ / ^ ( .+ [|] .+ ) $ /x) {
                        # If key contains has embedded pipe(s), split name on
                        # pipe and create a hash entry for each part
                        
                         for my $k ( split(/ \s* [|] \s* /x, $key_text) ) {
                            $schema_ref->{$k} = $hash_entry;
                         }
                         delete $schema_ref->{$key};
                    } else {
                    
                        $schema_ref->{$key} = $hash_entry;
                    }
                }
            }
        }
    } elsif (not $ref_schema_ref) {
        # Scalar passed instead of schema reference
        # so try to turn it into a schema structure
        $up_ref = _schema_from_string($schema_ref, $navigation, $errors_ref );
        $kwalify = 0;
    }
    if (! $kwalify) {
    
        if ( ref $up_ref && exists $up_ref->{'define'} ) {
            my $anchor_name = $up_ref->{'define'};
            $anchors_ref->{$anchor_name} = $up_ref;
        }
        return $up_ref;  # ------------->>>>>>>>>>
    }

    # We have decided to treat schema as kwalify
    
    if ($ref_schema_ref eq 'hash') {
        
        my $schema_type = $schema_ref->{'type'} || '';
        
        if ( exists $schema_ref->{'define'} ) {
            my $anchor_name = $schema_ref->{'define'};
            $anchors_ref->{$anchor_name} = $schema_ref;
        }
        if ($schema_type eq 'map' || $schema_type eq 'mapping') {
            # sub-schema for a map
            my $mapping_ref = $schema_ref->{'mapping'} || '';
            my $mapping_key = 'mapping';
            if (not $mapping_ref) {
               $mapping_ref = $schema_ref->{'map'} || '';
               $mapping_key = 'map';
            }
            if (lc ref $mapping_ref eq 'hash') {
                foreach my $key (keys %{$mapping_ref} ) {
                    # process/convert each sub-schema
                    $mapping_ref->{$key} =
                            _pre_process_schema( $mapping_ref->{$key},
                                                $errors_ref,
                                                $anchors_ref,
                                                $schema_format,
                                                $navigation . "$key/"             
                                               );
               }
            } else {
                # sub-schema is type 'map' but has no mapping key
            }
        } elsif ($schema_type eq 'seq' || $schema_type eq 'sequence' ) {
            # sub-schema for a sequence
            my $sequence_ref = $schema_ref->{'sequence'} || '';
            my $sequence_text = 'sequence';
            if (not $sequence_ref) {
                $sequence_ref = $schema_ref->{'seq'} || '';
                $sequence_text = 'seq';
            }
            if (lc ref $sequence_ref eq 'array') {
                # sequence: key is an array as expected for a kwalify schema
                $sequence_ref->[0] =
                    _pre_process_schema( $sequence_ref->[0],
                                        $errors_ref,
                                        $anchors_ref,
                                        $schema_format,
                                        $navigation . "{$sequence_text}[0]/"             
                                      );
            } else {
                #### Error - sequence: entry not an array ???? ####
            }
        }
    } elsif ($ref_schema_ref eq 'array') {
        # Error - an array is not a valid kwalify schema
    } elsif (not $ref_schema_ref) {
        # scalar sub-schema
        # May be a valid kwalify sub-schema if null or undef
        return $schema_ref;
    } else {
    }
    return $schema_ref;
}
# --------------------------------------------------------------------
sub _handle_control_line {
    

# <control> handler
#
# Passed:
#   - the payload of <control> line from a compact schema that is being
#       pre-processed.
#   - a reference to the sub-schema being assembled
#   - a flag to indicate whether to stop when an angle-bracketted token is found
#
# Handles:
#   required    - creates required: yes
#   optional    - creates required: no (not really needed, as it is the default)
#   min n       - creates size: min: n, which controls the number of entries in
#                   the sequence or mapping. Checks whether 
#   max n       - creates size: max: n, which controls the number of entries in
#                   the sequence or mapping
#   use x       - creates use: x for the entire sequence or mapping
#   define x    - creates define: x for the entire sequence or mapping

# Uses _get_next_token to parse the supplied text

# Side-effects as appropriate for each option.

# Returns 
#    - an error string, or null if no errors
#    - any unprocessed text

    my ($control_text, $up_ref, $angle_term) =  @_;
    my ($token, $delim, $quote);
    my $error_result = '';
    
    my $prev_text = $control_text;
    ($token, $control_text, $delim, $quote) = _get_next_token($control_text);

    while ($token ne '') {
        my $lc_token = lc $token;

        if ($quote eq '<' && $angle_term) {
            # Angle-bracketted token, and it stops handler
            return wantarray ? ('', $prev_text) : '';        
        } elsif ($lc_token eq 'required' || $lc_token eq 'optional') {
            $up_ref->{required} = $lc_token eq 'required' ? 'yes' : 'no';
        } elsif ($lc_token eq 'min' || $lc_token eq 'max') {
            my $min_or_max = $lc_token;
            ($token, $control_text ) = _get_next_token($control_text);
            if ( $token =~ / ^ \d+ /x) {
                $up_ref->{size}{$min_or_max} = $token;
            } else {
                $error_result .= "No value after $min_or_max in <control>\n";
            }
        } elsif ($lc_token eq 'use' || $lc_token eq 'define') {
            my $use_or_define = $lc_token;
            ($token, $control_text ) = _get_next_token($control_text);
            if ($token ne '') {
                $up_ref->{$use_or_define} = $token;
            } else {
                $error_result .= "Name missing after '$use_or_define'\n";
            }
        } elsif ($lc_token eq 'default') {
            $up_ref->{default} = $control_text;
            $control_text = '';
        } else {
            $error_result .= "Unrecognised word: '$token' in <control>\n";
        }
        $prev_text = $control_text;
        ($token, $control_text, $delim, $quote) = _get_next_token($control_text);
    }
    return wantarray ? ($error_result, $control_text) : $error_result;
}
# --------------------------------------------------------------------

sub _get_meta_ref {
    # Gets a pre-digested version of the meta-schema

# A YAML string containing a schema for kwalify schemas

=format
my $meta_schema_str = <<'...';
name:      MAIN
type:      map
required:  yes
define:    main-rule
mapping:
    define: str
    use:    str
    name:
    desc:
    class:
    type: |
        seq=sequence=array, map=mapping=hash, str=string, int=integer,
        float, number=num, bool=boolean, text, date, time, timestamp,
        any, scalar, row, table
    required: bool
    enum:
         - type:     scalar
           unique:   yes
    pattern:
    assert:
    range:
       type:      map
       mapping:
            max:
            min:
            max-ex:
            min-ex:
    length:
        type:      map
        mapping:
            max:    int
            min:    int
            # max-ex: int ## Not needed for length?
            # min-ex: int ## Not needed for length?
    size:
        type:      map
        mapping:
            max:  int
            min:  int
    ident: bool
        # equivalent to 'primary-key' (undocumented)
    unique: bool
    default:
        type: any
        # Not fully implemented?
        # In kwalify, used only in action's template
        # Means something else now: the value to insert if a scalar, mapping or
        # sequence is omitted, and update is true
    sequence=seq=entries:
         #  [ meta-schema, describing the sequence: key                ]
         #  [ so it doesn't have a sequence following it at this level ]
            name:      SEQUENCE
            type:      seq
            sequence:
                # This is an ordinary schema sequence, so it has a single element
                - use: main-rule
    mapping=map=keys:
        name:      MAPPING
        type:      map
        mapping:
             <mapping-key>:
                 use: main-rule
    columns:
        type: seq
        sequence:
            # This allows non-scalars as row entries, but they may not work
            - use: main-rule
...
    return $meta_schema_str;
my $meta_schema_str_kwalify = <<'...';
---
define: main-rule
mapping:
  assert:
    type: scalar
  class:
    type: scalar
  columns:
    sequence:
      -
        use: main-rule
    type: seq
  default:
    type: any
  define:
    type: str
  desc:
    type: scalar
  enum:
    sequence:
      -
        type: scalar
        unique: 'yes'
    type: seq
  ident:
    type: bool
  length:
    mapping:
      max:
        type: int
      min:
        type: int
    type: map
  mapping=map:
    mapping:
      <mapping-key>:
        use: main-rule
    name: MAPPING
    type: map
  name:
    type: scalar
  pattern:
    type: scalar
  range:
    mapping:
      max:
        type: scalar
      max-ex:
        type: scalar
      min:
        type: scalar
      min-ex:
        type: scalar
    type: map
  required:
    type: bool
  sequence=seq:
    name: SEQUENCE
    sequence:
      -
        use: main-rule
    type: seq
  size:
    mapping:
      max:
        type: int
      min:
        type: int
    type: map
  type:
    enum:
      - seq=sequence
      - map=mapping
      - str=string
      - int=integer
      - float
      - number=num
      - bool=boolean
      - text
      - date
      - time
      - timestamp
      - any
      - scalar
      - row
      - table
    type: scalar
  unique:
    type: bool
  use:
    type: str
name: MAIN
required: 'yes'
type: map
...

=cut


my $meta_ref  = {
  'mapping' => {
    'assert' => {
      'type' => 'scalar'
    },
    'range' => {
      'mapping' => {
        'max-ex' => {
          'type' => 'scalar'
        },
        'min-ex' => {
          'type' => 'scalar'
        },
        'min' => {
          'type' => 'scalar'
        },
        'max' => {
          'type' => 'scalar'
        }
      },
      'type' => 'map'
    },
    'size' => {
      'mapping' => {
        'min' => {
          'type' => 'int'
        },
        'max' => {
          'type' => 'int'
        }
      },
      'type' => 'map'
    },
    'use' => {
      'type' => 'str'
    },
    'required' => {
      'type' => 'bool'
    },
    'desc' => {
      'type' => 'scalar'
    },
    'enum' => {
      'sequence' => [
        {
          'unique' => 'yes',
          'type' => 'scalar'
        }
      ],
      'type' => 'seq'
    },
    'sequence=seq' => {
      'sequence' => [
        {
          'use' => 'main-rule'
        }
      ],
      'name' => 'SEQUENCE',
      'type' => 'seq'
    },
    'unique' => {
      'type' => 'bool'
    },
    'name' => {
      'type' => 'scalar'
    },
    'default' => {
      'type' => 'any'
    },
    'define' => {
      'type' => 'str'
    },
    'ident' => {
      'type' => 'bool'
    },
    'mapping=map' => {
      'mapping' => {
        '<mapping-key>' => {
          'use' => 'main-rule'
        }
      },
      'name' => 'MAPPING',
      'type' => 'map'
    },
    'length' => {
      'mapping' => {
        'min' => {
          'type' => 'int'
        },
        'max' => {
          'type' => 'int'
        }
      },
      'type' => 'map'
    },
    'pattern' => {
      'type' => 'scalar'
    },
    'columns' => {
      'sequence' => [
        {
          'use' => 'main-rule'
        }
      ],
      'type' => 'seq'
    },
    'type' => {
      'enum' => [
        'seq=sequence',
        'map=mapping',
        'str=string',
        'int=integer',
        'float',
        'number=num',
        'bool=boolean',
        'text',
        'date',
        'time',
        'timestamp',
        'any',
        'scalar',
        'row',
        'table'
      ],
      'type' => 'scalar'
    },
    'class' => {
      'type' => 'scalar'
    }
  },
  'required' => 'yes',
  'name' => 'MAIN',
  'type' => 'map',
  'define' => 'main-rule'
};

    
    my $meta_ref_OLD = {
      'mapping' => {
        'assert' => '\\b/val/\\b',
        'range' => {
          'mapping' => {
            'max-ex' => undef,
            'min-ex' => undef,
            'min' => undef,
            'max' => undef
          },
          'type' => 'map'
        },
        ##'case' => {
        ##  'mapping' => {
        ##    'insensitive' => {
        ##      'type' => 'boolean'
        ##    },
        ##    'force' => {
        ##      'type' => 'upper, lower, title, no, false, off'
        ##    }
        ##  },
        ##  'type' => 'map'
        ##},
        'size' => {
          'mapping' => {
            'min' => 'int',
            'max' => 'int'
          },
          'type' => 'map'
        },
        'use' => 'str',
        'required' => 'bool',
        'desc' => undef,
        'enum' => [
          {
            'unique' => 'yes',
            'type' => 'scalar'
          }
        ],
        ##'punctuation' => {
        ##  'mapping' => {
        ##    'strip' => 'boolean',
        ##    'ignore' => 'boolean'
        ##  },
        ##  'type' => 'map'
        ##},
        'sequence=seq' => {
          'name' => 'SEQUENCE',
          'type' => 'seq',
          'sequence' => [
            {
              'use' => 'main-rule'
            }
          ]
        },
        'unique' => 'bool',
        'name' => undef,
        'default' => {
          'type' => 'any'
        },
        'define' => 'str',
        'ident' => 'bool',
        'mapping=map' => {
          'mapping' => {
            '<mapping-key>' => {
              'use' => 'main-rule'
            }
          },
          'name' => 'MAPPING',
          'type' => 'map'
        },
        'pattern' => undef,
        'length' => {
          'mapping' => {
            'min' => 'int',
            'max' => 'int'
          },
          'type' => 'map'
        },
        'columns' => {
          'sequence' => [
            {
              'use' => 'main-rule'
            }
          ],
          'type' => 'seq'
        },
        'type' => 'seq=sequence, map=mapping, str=string, int=integer,'
                . 'float, number=num, bool=boolean, text, date, time, timestamp,'
                . 'any, scalar, row, table',
        'class' => undef
      },
      'required' => 'yes',
      'name' => 'MAIN',
      'type' => 'map',
      'define' => 'main-rule'
    };
    return $meta_ref;
}
# --------------------------------------------------------------------
sub _truthiness {
    # Returns true if the string passed is acceptable as a boolean 'true'
    my ($arg) = @_;
    return 0 unless defined $arg;
    return $arg =~ $BOOLEAN_TRUE_REGEX;
    
}
# --------------------------------------------------------------------
sub _trim {
    my ($text) = @_;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}
# --------------------------------------------------------------------
sub _split_scalar_into_map {
#
# Passed:  A scalar to split
# Returns: A reference to a hash
#        : An error string, null if no errors
#
# The returned hash will have one key for each top-level key in the scalar
# with the data being the text from that key

    my ($scalar) = @_;
    
    my %result_hash = ();
    my $result_errors = '';
    
    my ($leading, $delim);
    #  Strip leading/trailng white space and commas    
    
    my $remaining = $scalar;
    $remaining =~ s/ ^ [\s,]+   //x;
    $remaining =~ s/   [\s,]+ $ //x;
    if ( substr($remaining, 0,  1) eq '('
        # Surrounded by parentheses - remove them
        && substr($remaining, -1, 1) eq ')') {
        $remaining = substr($remaining, 1, length($remaining) - 2 );
    }
    my $current_key = undef;
    my $loop_limiter = 100;
    my $after_delim;
    my $payload = '';
    while ($remaining ne '' && $loop_limiter-- > 0) {
        # find first or next top-level key, or nested stuff
        # find first ( or : or =>
        ($leading, $delim, $after_delim) = $remaining =~ / ^ (.*?) ( [:(] | [=] [>]? ) (.*) $ /x;
        #text before delim
        if (! defined $leading) {
            # No match - no delimiter in remaining text
            $loop_limiter = 0;
        } else {
            # We found a delimiter,  :  or  =>  or  (
            $remaining = $after_delim;
            if ($delim eq ':' || $delim eq '=>' || $delim eq '=') {
                # Found : or => or =
                # Try splitting on last comma that is not between digits
                my ($content, $new_key) = $leading =~ /  ( .* ) (?:  (?<! \d) , | , (?! \d) )( .* ) $ /x;
                ##my ($content, $new_key) = $leading =~ / ^ ( [^,]* ) [,] ( [^,]* ) $ /x;
                my $pause = 3;
                if (defined $content) {
                    # There was a comma
                    if ( ! defined $current_key) {
                        # We have content and a key, but no key in front
                        # e.g. "I, Claudius: the book"
                        return (undef, 'Malformed compact $MAP_WORD');
                    } else {
                        $payload .= $content;
                        $result_hash{$current_key} = _trim($payload);
                        $payload = '';
                        $current_key = _trim($new_key);
                    }
                } else {
                    # Try splitting on last embedded space
                    my $untrimmed = $leading;
                    ## $leading =~ s/ ^ \s+   //x;
                    $leading =~ s/   \s+ $ //x;
                    if (defined $current_key) {
                        ($content, $new_key) = $leading =~ / ^ ( .+ ) \s+ ( \S+ ) $ /x;
                    }
                    if (defined $content) {
                        # There was an embedded space
                        $payload .= $content;
                        if (defined $current_key) {
                            $result_hash{$current_key} = _trim($payload);
                            $payload = '';
                            $current_key = _trim($new_key);
                        } elsif ( length $payload) {
                            # We have content and a new key, but no key in front
                            #         I Claudius: the book
                            return (undef, 'Malformed compact $MAP_WORD');
                        }
                    } else {
                        # No embedded spaces or commas, so it is all key
                        # If we have a current key, this new key is nested content
                        # e.g. "options: case: upper"
                        #      is interpreted as "options: (case: upper)"
                        if (defined $current_key) {
                            $payload .= ($untrimmed . $delim);    
                        } else {
                            $new_key = $leading;
                            $payload = '';
                            $current_key = _trim($new_key);
                        }
                    }
                }
            } elsif ($delim eq '(') {
                # Found (
                # Keep storing stuff in payload until matching ) found
                $payload .= ($leading . $delim);
                
                # store leading text, and the left parenthesis
                my $nest_count = 1;
                #               increment nest count
                # until nest count = 0 or end of string reached
                while ($nest_count > 0 && length $remaining) {
                    # find next left or right parenthesis
                    ($leading, $delim, $after_delim) = $remaining =~ / ^ (.*?) ( [()] ) (.*) $ /x;
                    if (defined $leading) {
                        if ($delim eq '(' ) {
                            # found (
                            # store stuff and (
                            $payload .= ($leading . $delim);
                            $remaining = $after_delim;
                            $nest_count++;
                        } elsif ($delim eq ')' ) {
                            # found )
                            # store stuff and )
                            $payload .= ($leading . $delim);
                            $remaining = $after_delim;
                            $nest_count--;
                        } else {
                            return (undef, 'Internal error in _split_scalar_into_map');
                        }
                    } else {
                        # found end of string before matching )
                        # error - unbalanced parentheses
                        return (undef, 'Unbalanced parentheses');
                    }
                }
                # store stuff as data for current key
                # if no current key, error: scalar not interpretable as a map
                ## Is there code missing here ??
                my $pause = 4;
            } else {
                # Not expected delimiter - internal error
                return (undef, 'Internal error in _split_scalar_into_map');
            }
        }
        
        my $pause = 2;
    }
    $payload .= $remaining;
    if (defined $current_key) {
        # We have a key already
        $result_hash{$current_key} = _trim($payload);
        $remaining = '';
    } else {
        # No keys - not a compact map
        return (undef, 'No keys found');
    }
    return (\%result_hash, '');
}

# --------------------------------------------------------------------

sub _check_options {
    
# Passed
#   1) the options,  which may be in a data structure or as YAML text or file
#   2) the defaults, which may be in a data structure or as YAML text or file
# Returns
#   1) a reference to the options as a data structure (or undef if errors)
#   2) Error text re the options, or undef if no errors
#
# Checks options against a pre-loaded options schema
# Applies defaults from the defaults structure, which has the same structure as
# the options but only allows mappings
    
    my ($options, $defaults) = @_;
    $options = {} if ( ! defined $options
                      || (! ref $options
                          && $options =~ / ^ \s* $ /x)
                      );
    my ($errors, $opts_ref);
    if (ref $options || $options =~ /\n/) {
        ($errors, $opts_ref) = _accept_or_parse_arg($options);
        return (undef, "options: $errors") if $errors;
    } else {
        $opts_ref = $options;
    }
    
    
    my $defaults_ref;
    ($errors, $defaults_ref) = _accept_or_parse_arg($defaults);
    return (undef, "defaults: $errors") if $errors;
    
    my @error_array = ();                    # A empty array of error messages
    # Options to use for the options
    my $options_options_ref = {update => 1,
                               relaxed => 1,
                               internalise => 1,
                               keys         => {equivalents => 1,
                                                case => {insensitive => 1} },
                               enumerations => {equivalents => 1,
                                                case => {insensitive => 1} },
                               scalar => {map => 1, sequence => 1},
                               };  
    
    if (_is_structure_invalid(
            $opts_ref,           # We are validating these options
            $options_schema_ref, # Against this schema
            \@error_array,       # Errors go here
            'options/',          # Navigation prefix
             undef,              # Unique values hash
             undef,              # Anchors for schema lib
            $options_options_ref,# Options that apply to this validation attempt
            \$opts_ref,          # Updated result
                              ))  {
        return ( undef, join ("\n", @error_array) . "\n" );
    }
    
    # The options have validated successfully
    # Now apply the defaults supplied to this routine
    
    _apply_defaults($opts_ref, $defaults_ref);
    
    return ($opts_ref, undef);
    
}
# --------------------------------------------------------------------
sub _apply_defaults {
    # Passed:
    #   a reference to a baseline structure
    #   a reference to a defaults structure
    #
    # Applies any scalar defaults to hashes in the baseline structure
    
    my ($base_ref, $defaults_ref) = @_;
    if (ref $defaults_ref eq 'HASH') {
        # We have a hash
        my ($defaults_key, $defaults_val);
        while (($defaults_key, $defaults_val) = each %{$defaults_ref}) {
            if (ref $defaults_val eq 'HASH') {
                # Nested hash in the defaults
                if (ref $base_ref  eq 'HASH'
                    ## && exists $base_ref->{$defaults_key}
                    ) {
                    if (! exists $base_ref->{$defaults_key} ) {
                        $base_ref->{$defaults_key} = {};    # Create empty hash
                    }
                    _apply_defaults( $base_ref->{$defaults_key},
                                            $defaults_ref->{$defaults_key}
                                          );
                }
            } elsif (! ref $defaults_val) {
                # Scalar in defaults
                if (! exists $base_ref->{$defaults_key}) {
                    # Data value is missing from data hash so apply default
                    $base_ref->{$defaults_key} = $defaults_val;
                }
            }
        }
    }
}
# --------------------------------------------------------------------
sub _regex_errors {
#   Passed:
#       1) Data
#       2) Regex
#       3) Regex original text
#   Returns:
#       Error text if regex is not valid (better if done during pre-processing)
#       Null string if data matches regex
#       Error string if data does not match regex (some cleansing of the text may be done)

    my ($data, $regex, $regex_original) = @_;
    my $regex_result;
    eval { $regex_result = $data =~ $regex };
    if ( $@ ) {
        return "Schema error: invalid pattern: $@";
    }
    if ($regex_result) {
        return '';
    }
    return "'$data' does not match pattern $regex_original";
}


# --------------------------------------------------------------------
sub _options_schema
    {
            # Returns a structure containing a kwalify schema for the options hash
            # that is passed to these routines
            # When the OO interface is used, this schema is loaded into a structure and
            # stored in a validator object to avoid converting it every time a routine
            # is called. The procedural interface has to put up with the overhead.
            #
    my $options_schema_str_DOCUMENTATION_ONLY = << "...";
    {
        
        # 'update' determines whether any changes will be made to the data. This 
        # really only matters when the data being validated has already been loaded
        # into a structure, in which case it won't be changed unless update is
        # true.
        #
        # If data is passed as a YAML string (or YAML text in a file) then 'update'
        # is assumed to be true.
        #
        # 'relaxed' determines whether data is accepted as valid if its value is
        # not standard YAML (e.g. commas within numbers) but which is appropriate
        # for the type of field and unambiguous. 'relaxed' is assumed to be true
        # unless explicitly set to false.
        
        ## Note: There might well be defects resulting in the data actually being
        ## changed, e.g. sub-fields might get auto-vivified by being referenced, so
        ## they would come into existence although their content would be undef. If
        ## you *really* want to be sure that your data structure does not get
        ## modified, deep copy it and pass the cloned copy. Easy ways to deep copy a
        ## structure include Storable::dclone, or converting it to a YAML string
        ## and back.
        #
    
    
        ######################################################################
        # Allow US or UK/Aus/NZ format for dates before relaxation to yyyy-mm-dd
        # US allows [m]m/[d]d/[yy]yy or similar with - or space instead of /
        # UK/Aus/NZ allow [d]d/[m]m/[yy]yy or similar with - or space instead of /
        # All date formats accept:
        #       European (yyyy-mm-dd), and
        #       text month (dd mmm yy or mmm dd yy)
        # Change the default to suit your locale!

        

update:    boolean

relaxed=relax=relaxation: boolean

internalise: boolean

dates:
    internal:  default epoch values epoch, excel
      # Dates will be converted into this internal format 
    external:  default ddmmyy  values ddmmyy=NZ=Aus=UK mmddyy=US=USA


enumerations=enums:           
    case:
       insensitive=ignore: boolean
       force:      values upper, lower, title, no=false=off
    punctuation:
       ignore: boolean
       strip:  boolean
    equivalents=equivs: boolean
keys:
    case:
       insensitive=ignore: boolean
       force:       values upper, lower, title, no=false=off
    punctuation:
       ignore: boolean
       strip:  boolean
    equivalents=equivs: boolean
scalar:
    sequence=seq=array: boolean
    map=mapping=hash:   boolean
lib: any
unload_format: values structure, YAML, Perl, JSON, YAML_flow, YAML+, csv, csv_with_header
...

my $options_schema_kwalify = << "...";
---
mapping:
  dates:
    mapping:
      external:
        default: ddmmyy
        enum:
          - ddmmyy=NZ=Aus=UK
          - mmddyy=US=USA
        type: scalar
      internal:
        default: epoch
        enum:
          - epoch
          - excel
        type: scalar
    type: map
  enumerations=enums:
    mapping:
      case:
        mapping:
          force:
            enum:
              - upper
              - lower
              - title
              - no=false=off
            type: scalar
          insensitive=ignore:
            type: bool
        type: map
      equivalents=equivs:
        type: bool
      punctuation:
        mapping:
          ignore:
            type: bool
          strip:
            type: bool
        type: map
    type: map
  internalise=internalize:
    type: bool
  keys:
    mapping:
      case:
        mapping:
          force:
            enum:
              - upper
              - lower
              - title
              - no=false=off
            type: scalar
          insensitive=ignore:
            type: bool
        type: map
      equivalents=equivs:
        type: bool
      punctuation:
        mapping:
          ignore:
            type: bool
          strip:
            type: bool
        type: map
    type: map
  lib:
    type: any
  unload_format:
    enum:
      - structure
      - YAML
      - Perl
      - JSON
      - YAML_flow
      - YAML+
      - csv
      - csv_with_header
    type: scalar
  relaxed=relax=relaxation:
    type: bool
  scalar:
    mapping:
      map=mapping=hash:
        type: bool
      sequence=seq=array:
        type: bool
    type: map
  update:
    type: bool
  csv:
    type: bool
  csv_with_header:
    type: bool
type: map
...


    my ($options_schema, $err) = _YAML_load( $options_schema_kwalify );
    
    if ($err) {
         # YAML failed while getting options schema
        return ("Internal Error in options: $err");
    }

    ## return $options_schema->[0];
    return $options_schema;
}
    
# --------------------------------------------------------------------
sub _relaxed_times {

#   Expects: - an input field which is a time
#
#   Returns: - the input date converted to hh:mm:ss format, or
#              the input field unchanged if it does not match the external time format

#  Allows hh:mm 
#         hh:mm:ss 
#         h am  hh am  h:mm am  hh:mm am
#         h pm  hh pm  h:mm pm  hh:mm pm

    my ($raw) = @_;
    $raw = $raw || '';
    my ($hh, $mm, $ss, $am_pm, $sep);
    my $ok = 1;
    
    my $tim = $raw;
    if ( $raw =~ / [#] /x ) {
        ($tim) = $raw =~ / ( .*? ) \s* [#] /sx;
    }
    if (     $tim =~ / ^ (\d\d?)                      [ ]? ( [ap] [.]? m [.]? )   $ /xi ) {
        ($hh, $mm, $ss, $am_pm) = ($1, '00', '00', $2);
        $ok = 0 if $hh == 12;               # Disallow '12 am' and '12 pm'
    } elsif ($tim =~ / ^ (\d\d?) ([:h]) (\d\d)          [ ]? ( [ap] [.]? m [.]? )?  $ /xi ) {
        ($hh, $sep,$mm, $ss, $am_pm) = ($1, $2, $3, '00', $4 || '');
        $ok = 0 if $hh == 12 && $mm == 0;   # Disallow '12:00 am' and '12:00 pm'
        $ok = 0 if length($hh) == 1 && length $am_pm == 0 && $sep !~ /h/i; # Disallow 0:00, 9:59 etc.
    } elsif ($tim =~ / ^ (\d\d?) :    (\d\d) : (\d\d) [ ]? ( [ap] [.]? m [.]? )?  $ /xi ) {
        ($hh, $mm, $ss, $am_pm) = ($1, $2,    $3,  $4 || '');
        $ok = 0 if $hh == 12 && $mm == 0 && $ss == 0; # Disallow '12:00:00 am' and '12:00:00 pm'
        $ok = 0 if length($hh) == 1 && length $am_pm == 0; # Disallow 0:00, 9:59 etc.
    } elsif  ($tim =~ / ^ (?: 12 [ ]? )? noon $ /xi) {
        ($hh, $mm, $ss, $am_pm) = ('12', '00', '00', 'noon');
    } elsif  ($tim =~ / ^ (?: 12 [ ]? )? (?: midnight | mn ) $ /xi) {
        ($hh, $mm, $ss, $am_pm) = ('00', '00', '00', 'midnight');
    } else {
        $ok = 0;    # Did not match any of the supported formats
    }
    if ($ok && defined $hh && $am_pm =~ /[ap]/) {
        $ok = 0 if $hh =~ /^0/;
        $ok = 0 if $hh > 12;
    }
    $hh += 12 if $ok && defined $am_pm && $hh  < 12 && $am_pm =~ /p/xi;
    $hh -= 12 if $ok && defined $am_pm && $hh == 12 && $am_pm =~ /a/xi;

    $ok = 0 if $ok && defined $hh && $hh > 23;
    $ok = 0 if $ok && defined $mm && $mm > 59;
    $ok = 0 if $ok && defined $ss && $ss > 59;
    
   
    my $h2 = sprintf("%02d", $hh) if $ok;
    my $m2 = sprintf("%02d", $mm) if $ok;
    my $s2 = sprintf("%02d", $ss) if $ok;
    
    
    return $ok ? "$h2:$m2:$s2" : $tim;
}

# --------------------------------------------------------------------
sub _relaxed_dates {

#   Expects: - an input field which is a date
#            - an option specifying the external date format
#   Returns: - the input date converted to yyyy-mm-dd format, or
#              the input field unchanged if it does not match the external date format
    
    my ($in_date, $option_text) = @_;
    my %months = (jan => 1, feb => 2, mar => 3, apr => 4, may => 5, jun => 6,
                  jne => 6, jul => 7, jly => 7, aug => 8, sep => 9, oct => 10,
                  nov => 11, dec => 12,
                  january => 1, february => 2, march => 3, april => 4, may => 5,
                  june => 6, july => 7, august =>, 8, september => 9,
                  october => 10, november => 11, december => 12
                  );
    my $lc_date = lc($in_date);
    
    if ($lc_date =~ /\d\d\d\d-\d\d-\d\d/x) {
        # Already standard format
        return $in_date;
    } elsif ($lc_date eq 'today') {
        return _today_yyyy_mm_dd_offset(0);
    } elsif ($lc_date eq 'yesterday') {
        return _today_yyyy_mm_dd_offset(-1);
    } elsif ($lc_date eq 'tomorrow') {
        return _today_yyyy_mm_dd_offset(+1);
    } else {
        # See whether it matches external
        if ($option_text eq 'US') {
            
        }
        if ($option_text =~ / ddmmyy | mmddyy /x) {
            # UK or US style dates allowed
            # Expect dd mm [yy]yy
            # or     mm dd [yy]yy for US-style
            # Allow /, space or - to separate fields
            my @parts = split( /  [ -\/,]+  /x, $lc_date );
            if (scalar(@parts) != 3) {
                return $in_date;
            }
            my ($dd, $mm, $yy) = @parts;
            if ($mm =~ / ^ [a-z]+ $ /ix) {
                # Second field is entirely alphabetic
                # so assume that it is month
            } elsif ($dd =~ / ^ [a-z]+ $ /ix) {
                # First field is alphabetic
                # so assume that it is month
                $mm = $parts[0];
                $dd = $parts[1];
            } elsif ($option_text eq 'mmddyy') {
                # US-style date expected, do switch month and day
                ($mm, $dd, $yy) = @parts;
            }
            $dd =~ s/ 1st        $ /1/x;
            $dd =~ s/ 2nd        $ /2/x;
            $dd =~ s/ 3rd        $ /3/x;
            $dd =~ s/ ([4-9])th  $ /$1/x;
            $dd =~ s/ (1[0-9])th $ /$1/x;
            if ($dd !~ / ^ \d $ | ^ [012]\d $ | ^ 3[01] $ /x) {
                # Day is not good
                return $in_date;
            } else {
                # Day is OK
                if ($mm =~ / \d | 0\d | 1[012]  /x) {
                    # Month is OK already
                } else {
                    my $month = $months{lc $mm};
                    if (defined $month ) {
                        # Month is a recognised month name
                        $mm = $month;
                    } else {
                        # Month is not good
                        return $in_date;
                    }
                }
                if ($yy =~ / 19\d\d | 20\d\d /x ) {
                    # Year is OK
                } elsif ($yy =~ / \d\d /x) {
                    # Two-digit year
                    $yy += ($yy > 40) ? 1900 : 2000;
                    
                } else {
                    # Year is not good
                    return $in_date;
                }
            }
            my $m2 = sprintf("%02d", $mm);
            my $d2 = sprintf("%02d", $dd);
            return "$yy-$m2-$d2";
        }
        # Unknown/unimplemented external date code
        return $in_date;
    }
}
# --------------------------------------------------------------------
sub _today_yyyy_mm_dd_offset {
    # Returns today's date in standard yyyy-mm-dd format
    # adjusted by the number of days in offset
    
    my ($offset_days) = @_;
    
    my ($yyyy, $mm, $dd) = (localtime)[5, 4 ,3];
    $yyyy += 1900;
    $mm += 1;
    my $m2 = sprintf("%02d", $mm);
    my $d2 = sprintf("%02d", $dd);
    return "$yyyy-$m2-$d2";
}
# =================
# DEVELOPER'S NOTES
# =================
# Development version: has hash-level and array-level



# <control> information implemented - values allowed are:
#
#   - required     A hash must be present, and must have at least one key
#                  An array must be present, and must have at least one entry
#   - optional 
#   - min n
#   - max n
#   - use x
#   - define x
#   - default x, where x is a string that will be split using
#               _split_scalar_into_array or _split_scalar_into_map
#
# For a hash, add a key with the control information, e.g.
#
#   bill-to:
#       <control>: required  # Entire bill-to hash is required
#       name: required text  # Hash must contain this key
#       address: text        # This key is optional as it is not explicitly required
#
# For an array, make the first line a <control> line and the second line
# define the array contents, e.g.
#
#   customer-numbers:
#     - <control> required    # Hash entry 'customer-names' must be present
#                             #   and it must contain at least one array entry
#     - int                   # Each entry of the array is checked against this

# For a table, put any control information before the column definitions,
# either on the same line or as a multi-line block:
#
#   groups: <control> required min 5 <name> <code>
#
#   members: |
#       <control> required max 15
#       <membership_number> integer
#       <name>
#       <year_joined> integer min 1976 max 2012
#


#
#      ***********
#      *  TO DO  *
#      ***********
#----
# Guard against invalid regexes in patterns, consistently
#----
# Check schema_text() (might need YAML module fixes)
#----
# Allow trailing Perl-style comments within schema
# Option to discard trailing Perl-style comments within data
# Extra field types:
#   alphabetic (i.e only upper or lower case letters)
#   alpha-numeric (i.e only digits or upper or lower case letters)
#   single line of text (same as text, but no newlines or NELs)
#----
# A field type or constraint to limit the number of lines within a field. The
# commonest case would probably be to limit text fields to a single line (see
# previous)
#----
# (Done! is it documented?)
# Enumerated values for mapping keys, e.g.
#   key1|key2|key3:
# or just supplied in an enum list for kwalify schemas, e.g.
#   type: map
#   enum:
#       - key1
#       - key2
#       - key3
#   mapping:
#     =:
# The usual features for case and punctuation forcing should apply.
#----
#
# Process patterns at schema pre-processing time, rather than dynamically
# building a regex each time a field is validated.
#
# OPTION HANDLING
#
#   CURRENT STATUS:
#      
#       Options can be passed to calls to the methods and functions.
#       Options are allowed within a kwalify schema.
#       Options passed to new() are *not* saved for later use
#
#   They are allowed to be specified within the schema, but do not cascade - at
#   each level, any explicit options at that level over-ride the options passed
#   on the method or function call.
#
#   Options supplied when creating a validator object *should* be retained, and
#   used as the defaults for all calls to methods of that object - but at
#   present they are not. 
#
#   The defaults are permissive, in line wth YAML philosophy, so that
#   unambiguous data that people would accept should generally be accepted.
#
#   A strict setting might sometimes be more appropriate, for example if the
#   validator is being used to check data being passed between systems rather
#   than supplied by people.
#
#   The simplest option should therefore be permissive/strict. As the default is
#   permissive, the 'strict' option could also have its own calls so that most
#   users will not have to use options at all.
#
#   Schema extensions for options:
#       keywords within scalar definitions for compact schemas
#         may not be needed, as schema options probably very rarely necessary so
#         having to use kwalify-format schema not a big problem.


#   In kwalify-extended schemas:
#
#       If type is 'map':
#           If the only key is =: or <user_chosen_name>:
#               case:
#                   force: upper, capitals, lower, title, no=false=off
#               punctuation:
#                   strip:  boolean
#           Otherwise
#               case:
#                   insensitive: boolean
#               punctuation:
#                   ignore: boolean
#
#       If type is 'scalar', 'text', 'string' or omitted
#           case:
#               insensitive: boolean (if there is an enum: list)
#               force: upper, capitals, lower, title, no=false=off (if no enum: )
#           punctuation:
#               ignore: boolean (if there is an enum: list)
#               strip:  boolean (if no enum: )
#               
#
#   In compact schemas:
#       Overall options (for schema)
#          Extra YAML document, preceding the schema itself
#       (syntax for mapping keys?) key1 <options>:
#       (keywords for matching, so before enumeration list)
#           sensitive/exact case (strict)
#           insensitive/any case (permissive)
#           exact punctuation (strict)
#           ignore/any punctuation (permissive)
#       (keywords for forcing)
#           upper case
#           lower case
#           title case
#
#   Case and Punctuation Insensitivity for enumerated values
#       - determines whether a value in the enumerated data field is acceptable
#       - options are booleans
#               'insensitive:' for case
#               'ignore:'      for punctuation
#       - means that case and/or punctuation are ignored when checking
#       - will also update the data field if the 'update' option applies
#       - updates will change the data to the enumeration value that it matches
#   
#   Case and Punctuation Insensitivity for mapping keys
#       - determines whether a mapping key is acceptable
#       - options are boolean
#               'insensitive:' for case
#               'ignore:'      for punctuation
#       - will also update the mapping key if the 'update' option applies
#
#   Case and punctuation insensitivity is quite powerful: it provides
#   facilities that would be difficult and/or tedious to implement otherwise.
#
#   Case and punctuation forcing are much less important: they change the data,
#   but in ways that would only take a single line of Perl to achieve.
#
#   Keys
#       Case insensitivity
#           insensitive: boolean
#               true means:
#                 - ignore case when matching key
#                 - change case of supplied key to match schema if update is true               
#       Punctuation
#           ignore: boolean
#               true means:
#                 - ignore punctuation when matching key 
#                 -  change supplied key to match schema if update is true
#
#       Case forcing (not implemented)
#         - Would only apply if any key is allowed  ( =: or <name>: )
#         - Would force case to upper/lower/title
#         - Would flag error if more than one key supplied would be forced to
#               the same value
#         - Would only apply if update is true
#
#   Enumerations
#       Case insensitivity
#           insensitive: boolean
#               true means:
#                 - ignore case when matching data against enumerations
#                 - change case of data to match schema if update is true               
#       Punctuation
#           ignore: boolean
#               true means:
#                 - ignore punctuation when matching data against enumerations
#                 - change data to match schema if update is true
#
#   Data
#       Case Forcing
#       Punctuation Stripping


#   Case Checking
#       - determines whether text is acceptable
#       - never changes the data
#       - options are 'upper', 'capitals', 'lower', 'title'
#
#   Case Forcing
#       - never affects whether data is acceptable
#       - does not apply to fields with enumerated values
#       - does not apply to mapping keys
#       - options are 'upper', 'capitals', 'lower', 'title' or 'unforced'
#       - causes data field contents to be updated
#       - applies only if requested by an option
#       - applies only if 'update' option also applies
#
#   Punctuation Stripping
#       - never affects whether data is acceptable
#       - does not apply to fields with enumerated values
#       - does not apply to mapping keys ( except =: or <name>: )
#       - option is boolean 'strip:'
#       - 'strip: yes' causes data field contents to be updated
#       - applies only if requested by an option
#       - applies only if 'update' option also applies
#       - removes hyphens, underscores and spaces




# General
#
#   Test the code that accepts filenames and filehandles for data and schema,
#   it is currently only gently tested
#
#   Improve the way it uses other YAML libraries (e.g. YAML::XS and YAML.pm)
#   Check out their implementations of * and & (anchor and alias) to see if they
#   do what we need. They may be dangerous if the schema is recursive - we walk
#   the schema, without checking whether we are infinitely recursing.
#
#   Remove the dependency on YAML::Tiny (or other YAML modules), so that if the
#   data and schema are passed in Perl structures the YAML module is not
#   'required'. To achieve this, the meta-schema (and maybe some options stuff)
#   would have to be pre-converted.
#
#   Change default behaviour when null/undef supplied instead of map/seq
#       - currently allows undef/null instead of a sequence
#       - currently does not allow undef/null instead of a mapping
#
#   If the supplied min &/or max values are numeric, imply numeric relaxation and
#   comparison even if the type is not explicitly numeric.
#       Otherwise a field with definition:
#           quantity: max 500
#       would treat data such as '20 dozen' or '20x30' or '20,000' or '20000' as
#       valid. It is implicitly a text field, so the range values are treated as
#       text and string rather than numeric comparison is used. Accessing the
#       value for a numeric purpose would treat the first three examples as
#       having a value of 20.
#
#       This is largely a side-effect of having a default field type of 'scalar',
#       but removing that default would make compact schemas much noisier
#
#   Allow case-insensitive enumerations. Default could be to assume
#   case-insensitive unless enumerations have differently-cased variants of the
#   same sequence. -- Mostly done, needs option handling added
#
#   Relaxation, Internalisation and Conversion
#
#       Options (per-field granularity should be provided):
#           - No relaxation or conversion
#           - relaxed data before checking enumerations and ranges, but leave
#             data unchanged (e.g. 20 May 2011)
#           - relaxed data before checking enumerations and ranges, change
#             data to strict format (e.g. 2011-05-20)
#           - relaxed enumerations and ranges before checking, change
#             data to internal format (e.g epoch second)
#
#       For enumerations and ranges, the relaxation of the allowed values
#       could be done when the schema is loaded - but that would result in the
#       error text containing the normalised form, so the original value would
#       also need to be retained. If relaxation is deferred until checking,
#       efficiency is reduced, and the use of a hash for checking enumerations
#       is precluded.
#
#       For the data, it needs to be relaxed before checking of ranges,
#       enumerations, type-regexes, lengths and patterns. The best approach may
#       be to relax once, and pass the relaxed data into the checking
#       routines rather than them each normalising - but we have to ensure that
#       we do not modify the real source data in a supplied structure unless
#       explicitly requested by 'update'.
#
#       The updating of the original data to internal format is done only if
#       requested, and only if the data is accepted as valid.
#
#   If a schema provides a name for a sequence, use that name in error messages.
#
# Big-ticket items
#
#
#
#   Data conversions: all optional, on request only. Some are mutually exclusive.
#       E.g.

#       - Honour locale for numbers, e.g. swapping decimal point and comma
#       - Allow the case of text fields to be forced (upper, lower, title).
#         This could be enabled for individual fields, or for all fields of
#         specified types, e.g. text, string, scalar
#       - Allow currency (e.g. dollar) amounts, remove currency symbol (if
#         present) and commas, but only if currency symbol is the correct one
#         for the field type. E.g allow $4.95 if type is 'dollars'.
#
#       Should any conversion details be supplied within the schema?
#       Pragmaticaly, they will have to be in the schema if they can vary
#       between fields - but typically a blanket "Perl-friendly-conversions"
#       option is likely to be best and simplest.
#
#       Standard Perl-friendliness:
#           commas in numbers removed
#              length and range checks done after commas removed
#           booleans converted to null string if false, non-null if true
#           dates, times and timestamps converted to epoch seconds
#               range checks done after relaxation to yyyy-mm-dd   
#           dates and timestamps allow 
#                   yyyy-[m]m-[d]d
#                   dd mmm [yy]yy
#                   today/yesterday/tomorrow
#                   [d]d/[m]m/[yy]yy    (UK/Aus/NZ-style)
#                   [m]m/[d]d/[yy]yy    (US-style)
#           times and timestamps allow
#                   [h]h:mm [am|pm]  8:00 to  9:59 default to a.m.
#                                    1:00 to  7:59 default to p.m.
#                                   10:00 to 23:59 24-hour clock
#           timestamps allow date before or after time
#   Alternations
#       See below
#   
# Kwalify
#
#   assert
#       Allow a Perl snippet. Kwalify requires Ruby 'val', but Perl could use
#       $val and $_. Must return true if valid. In addition to assert,
#       non-kwalify options 'validate', 'relaxed' and 'internalise'.
#         - Validate must return an error string if invalid, otherwise a null string
#           or undef.
#         - relaxed is passed external data and must return it in strict format.
#           If it is unable to convert the data, it should return undef or a
#           null string: the error message will display the original data.
#           If no conversion is needed, it should return the data unchanged.
#         - Internalise is passed data in strict format, and converts it to a
#           convenient internal format.
#
#       Assertions would benefit from being able to be stored in a library and
#       invoked by name: this could be done by the library declaration adding
#       new keywords to the compact schema notation.
#
#       Security Alert: assert, validate, relaxed and internalise
#       all allow a schema writer to execute malicious code.
#
#
#   Implement 'required: yes' for all situations where it makes sense, e.g.
#     - Map: map must be present
#     - Map entry: an entry with the key must be present if the map is present
#     - Sequence: sequence must be present
#     - Sequence entry: Not relevant. Might be used to mean that the sequence
#                       itself is required
#   One issue is finding a syntactically attractive approach that fits
#   with the compact schema format, as we have to stay within YAML's limits.
#   Main issue is deciding exactly what 'required' means, and whether it would
#   be better to implement alternative and/or additional constraints such as
#   'compulsory' and 'not null / allow null'
#
#   'default' constraint and default values
#       The constraint (better called 'any other key') defines a scalar value to
#       be returned when a mapping in the data is accessed with any key for
#       which no entry exists. In Kwalify, it only applies to 'genclass' which
#       is not implemented here, and it does not affect validation. Not be
#       confused with the default mapping key ( =: )
#
#       There presumably could be a Perl equivalent (along the lines of a tied
#       hash), which returns the default value when accessed for a non-existent
#       key - the data structure would need to be converted to this.
#
#       Default values are implemented already for mapping keys.
#       They specify what is added to a mapping if the specified key is missing
#       and update is enabled.
#
#       Also see the notes on 'merging' below, which propose a different type
#       of default mechanism which could effectively provide a default value for
#       specific keys omitted.
#

## Default values for an array or hash in a compact schema can currently only be
## entered as a string, because the default value is part of the <control> entry
## which currently must be a string.

## If the entry is an array, the default value string will be split using
##     the _split_scalar() function.
## If the entry is a hash, the default value string will be split using the
##     _split_scalar_into_map() function.
## This does allow complex default values, but for a hash that have to be
## entered in a single line (due to _split_scalar_into_map() limitations).
## It would be more flexible to provide some mechanism to specify the default
## as a normal YAML structure. Possibilities include:
##      - a <default>: key parallel with the <control>: key in a hash
##      - an array entry such as - <default>:
##            followed by the default value structure
##      - sub-dividing <control>: between default: and other:
##          <control>:
##              other: max size 6
##              default:
##                  foibles: 56
##                  quirks: 123
#            
##
## A hash can be specified as optional, but with one or more keys specified as
## required. The semantics are that the required keys must be present unless the
## entire hash is omitted.
##
## The default values on the hash <control>: line would be better placed on the
## individual keys to which they apply.

#
#   Check defences against recursive schemas causing endless loops - probably
#   only an issue for pre-processing of schemas when using & and *
#   anchors/aliases, or validation of schemas against a meta-schema. YAML::Tiny
#   appears to do some checking, and doesn't implement & and *. YAML.pm can
#   result in loops exhausting memory if recursive schemas are specified using
#   & and * - but anchor and alias are OK so have to use those instead.
#
#   Implement enums as hashes, not arrays. This should improve performance, as
#   it replaces a serial search with a hash lookup. Maybe add an enum-map: key
#   to the schema, with the same elements as the corresponding enum: but as map
#   keys rather than sequence entries. Might be problematical for YAML::Tiny to
#   dump if any of the enum values require quoting to use as keys, but dumping
#   is for debug only. Can just use the enum sequence if there is no enum-map:
#   key. A non-starter when case-insensitive or punctuation-ignored enums are
#   used, which might be most of the time if it's the default.
#
# Non-Kwalify
#
#   Compact notation for pattern checking <variable>: mapping keys
#   Compact notation for required sequences and maps [limitation wrt kwalify]
#       sequences: extra sequence entry in schema, with only contents
#                   'required' and/or
#                    size limits.
#                  Allow options or [options] as prefix,
#                   or options: or [options]: nested map
#       maps: magic [options]: key in the map for auto or compact-only, with
#                              the only allowed contents:
#                       'required' and/or
#                        size limits and/or
#                        pattern for checking <variable>: mapping keys and/or
#                        keywords to control key case matching
#                                            key punctuation matching
#
#   
#   REVERSE CONVERSIONS:
#       Partially implemented as unload_data() and the unload method.
#       Output formats: YAML, JSON, PERL, csv, csv_with_header, YAML+ (with tables)
#
#       Passed a data structure with data in *internal* format and a schema,
#       produces the same data in *external* format.
#          Booleans becomes the text 'false' or 'true'
#          Numbers have commas added
#          Dates are converted from internal format (epoch/Excel) to yyyy-mm-dd
#           or to dd/mm/yyyyy or mm/dd/yyyy if external format is specified
#          Times are converted from internal format (epoch/Excel) to hh:mmAM/PM
#       Enumerations and mapping keys must exactly match, even if
#       case-insensitive or punctuation-ignored
#       Enumerated fields with equivalents are only valid if they exactly match
#       the first equivalent.
#       Mapping keys with equivalents are only valid if the key exactly
#       matches the first equivalent.
#       Optionally returns result as a Perl structure or as a YAML string (with
#        or without tables) or as JSON or as a Perl expresssion.
#       Row/column definitions should produce tabular output
#
#
#   ALTERNATIONS
#       At present, the schema notation does not allow the user to specify (e.g)
#       a sequence that can contain either a single string or a sequence of
#       strings -
#
#       race-results-1:
#           - Goldfinger (1st)
#           - Silver dollar (2nd)
#           - Bronze Beast (3rd)
#           - Also Ran (4th)
#       race-results-2:
#             # some entries are text, but the second is
#             # null and the third is a sequence
#           - Goldfinger (1st)
#           -
#               # nobody in 2nd place
#           -
#               # third place was a tie
#               - Silvery (3rd =)
#               - Bronzer (3rd =)
#           - Also Ran (4th)
#
#       One approach for this particular example would be to define results as a
#       sequence of sequences, and rely on the 'allow scalar when sequence expected'
#       option to produce the desired result.
#
#
#       Alternations could be data-value dependent, e.g. if a text field
#       contains a particular value, some other field becomes required.
#
#       Alternations make it harder to produce intelligible error messages apart
#       from a generic "data does not match schema" and navigation information
#       to the position of the alternation that had no valid branch.
#
#       If the choice is between a single scalar, a single mapping and/or a
#       single sequence, then the normal sorts of error messages could be created.
#       The validation could recognise that there is only one scalar and report
#       the usual error if it fails to validate.
#
#       One option may be to have an identifier tag on the value of a data field
#       and/or the presence of a particular mapping key, which would trigger the
#       validator to accept that alternative as the chosen one for an undecided
#       alternative.
#
#       Would there be a need for multiple alternatives concurrently open, i.e.
#       at more than one level?
#
#       Implement by trying each alternative in turn.
#       If one returns errors but is not triggered, its errors are discarded.
#       If one returns no errors, it is accepted and alternation stops.
#       If one returns a triggered indication, the alternation stops and
#       errors (if any) from that alternative are used.
#       If all alternatives have been attempted and none have succeeded or
#       triggered, then a generic "no alternative matched" error is created.
#       'compulsory:' entries are all checked, regardless of the alternation
#       results.
#
#       type: alt
#       alternatives:
#           - # First alternative (a plain scalar)
#               type: scalar trigger
#           - # second alternative (a sequence of scalars)
#               type: seq trigger 
#               sequence:
#                   - type: scalar          
#       compulsory:
#           # all data must match all compulsory entries
#           - # first compulsory
#
#       type: alt
#       alternatives:
#           -
#               type: map
#               mapping:
#                   
#
# MERGING
#   This could be quite different from Kwalify's merge.
#   It could accept old data as well as the new data and a schema. If the data
#   is valid, the new data is merged with the old, replacing existing data when
#   the same mapping key is present in existing and new maps. Not sure what the
#   behaviour should be for sequences: concatenate or replace? Maybe specify
#   which in the schema, or in invocation options.
#   Is this appropriately part of a validator, or should the architecture be
#   that you validate first and then do a merge? Probably has to be integrated,
#   as the validation for the new data (which is going to be merged) may differ
#   from validation of a complete structure: e.g. all required keys might not
#   need to be supplied in the new data.
#   So it is merge-and-then-validate: passed an existing structure, some new
#   data to merge into that structure and a schema (if it's not supplied by an
#   object). There is a case that the existing data should be deep cloned before
#   the merge, at least as an option. If new data is merged in and found to
#   be incompatible the old data would otherwise be lost - and the state of the
#   structure pre-merge may well be an important part of the error reporting in
#   this case.

# Sort out options for handling schemas
    #   The routine assumes 'auto' - it attempts to automatically determine
    #   whether the schema is in compact or kwalify notation.
    #
    #   Options should/could include:
    #       'kwalify' indicator that a schema is already in strict kwalify format
    #           i.e. do not allow any compact format entries, treat all entries
    #                as being in kwalify format
    #       'compact' indicator that a schema is entirely in compact format
    #           i.e. treat all entries as compact, even if they are also valid
    #                kwalify
    #       'auto' indicator that a schema may use both compact and kwalify formats
    #           i.e. treat entries as being in kwalify format if they appear to be
    #                kwalify, otherwise treat them as compact





# NOT TO DO - Kwalify bits not implemented, not intending to do
#
#   unique (on mappings) - not possible with current architecture
#           Maybe detect it if the YAML parser that is used to load YAML from a
#           string or file can be configured to report this
#
#   * (anchor) and & (alias). These may be implemented by the YAML parser, in
#     which case they should just work. The define: and use: extensions to
#     kwalify (which are now accessible from compact notation) work,
#     and provide what the * and & facility provides (and more, such as
#     libraries).
#
# ========================
# END OF DEVELOPER'S NOTES
# ========================

=format

==============================================================================

Copyright 2010, 2011, 2012, 2013 Derek Mead. All rights reserved 
 
This program is free software. It comes without any warranty, to the extent
permitted by applicable law. You can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

==============================================================================
=cut


# Package has to end with 1;
1;