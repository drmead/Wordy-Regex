#!/usr/bin/perl -w
use strict;
use warnings;
package RegExp::Tre2Wre;
require Exporter;
our (@ISA) = ("Exporter");
our (@EXPORT) = qw(tre_to_wre);

## use YAML::XS;   ## Not needed for this program - this is a convenience for debugging.
use IO::Handle;
STDERR->autoflush(1);

=format


Tre2Wre.pm - Convert a Terse Regular Expression to a Wordy Regular Expression

This is a development version of the module, with integrated tests

===================================================

TO DO:

An extra right parenthesis stops processing: remainder of terse regex is ignored



Error Handling:

    The original design was intended to be given a valid regex - the assumption
    is that whatever engine the regex was designed for will report any errors.
    This is probably not a safe assumption, e.g. if users are supplying terse
    regexes from non-Perl flavours: even when support is added for non-Perl
    regexes they may not specify the correct flavour. 
    
    Currently outputs error text as part of the generated wordy.
    Could also:
    - Keep track of line number and column position (in get_next_token?)
    - Report line/col with error message
    - Indicate position by graphic e.g.
        Unrecognised escape sequence at line 1 column 9:
           This is t\e input regex
                    ^^
        


Tokenise:

    Escaped sequence
        Vary considerably between flavours
    Regex end delimiter (e.g. /)

    [ character class starts
    
    ( left parenthesis (can change /x mode)
    ) right parenthesis (can revert /x mode)
    
    { start quantifier
    } end quantifier
    
    .   match all (except maybe newline)
    +   one or more
    +?  one or more, non-greedy
    *   zero or more (optional + one or more)
    *?  zero or more, non-greedy
    ?   optional
    ??  optional, non-greedy
    ^   start of line/string
    $   end of line/string (or start of interpolation in Perl)
    |   alternation separator
    #   start of comment if in /x mode
    newline
        end of comment if in /x mode
    whitespace
        ignored in /x mode
    
Character class tokeniser:
    Escaped sequence (slight different to outside)
    ] character class ends
    ^ meta if first
    - meta if not first (or 2nd after ^)  (or last?)
    literal single character

    [- | [ ^ \] . * { } ( ) \\ + ? \$ ]+

Note that tokenisers may be switchable between raw string input and various
types of quoted string, to allow text from a source file to be pasted in. For
example, \\\\ means a single backslash if supplied in a Java string.

 
 ab[12\\w]?  |  cd\dee* (?i: (?:  ss | [g-m]+ tt) uu (?: vv | [wx] )){5,}[34]
 either   
    'ab'
    optional 1 or 2 or word-char
 or
    'cd'
    digit
    e
    optionally one or more e  # ee* should be e+
    five or more case-insensitive # Stacked from same parens
        either 'ss'
        or
            one or more g to m
            'tt'
        'uu'
        'vv' w x  # Original was group-only, but no indent needed for simple alternatives
    3 or 4


  ab[12\\w]?  |  cd\dee* (?i: (?:  ss | [g-m]+ tt) uu){5,}[34]
    
name:   re2word-node
type:   seq
define: re2w-node-rule
sequence:
        # Each alternative is an array of parts
        -
            # Each part is an atom that can have its own quantifiers
            # or a nested parenthesised sub-expression.
            # mode_switch_a and mode_switch_b are only used for (?i) and (?-i)
            # mode_switch_a is created where the mode switch is found:
            # mode_switch_b is inserted at the start of each alternation where
            # the mode switch still applies.
            -
                type:   char_class, string, matcher, nested, mode_switch_a/b
                value:
                chars:
                    - string
                child: use re2w-node-rule
                quant: text     # quantifiers that apply to this part
                modes:
                

ab[12\\w]?  |  cd\dee* (?i: (?:  ss | [g-m]+ tt) uu){5,}[34]

# Array of alternatives
# Each alternative is an array of parts
# If we don't look ahead (including looking past any comments) then we have to
# make each atom a part in case it is followed by a quantifier
-
    # First top-level alternative
    -   type: string
        value: a
    -   type: string
        value: b        
    -   type: char_class
        chars:
            - 1
            - 2
            - \w
        quant: {0,1}
 -
    # Second top-level alternative
    -   type: string
        value: c
    -   type: string
        value: d
    -   type: string
        value: e
        quant:
            min: 0
            max: more
    -   type: nested    # actually a mode-modified span
        modes: i        # from the opening parenthesis of this mode-modified span
        child:
            -
                # First alternative (the only one at this level)
                -   type: nested    # Non-capturing
                    child:
                        -   # First alternative
                            -   type: string
                                value: s
                            -   type: string
                                value: s
                        -   # 2nd alternative
                            -   type: char_class
                                chars: g-m
                                    # Probably needs some more analysis
                                    # although embedded dash may be sufficient
                                quant: {1,}
                            -   type: string
                                value: t
                            -   type: string
                                value: t
                -   type: string
                    value: u
                -   type: string
                    value: u
        quant:
            min: 5
            max: 6
    -   type: char_class
        chars:
            - 3
            - 4
                                    
ab[12\\w]?  |  cd\dee* (?i: (?:  ss | [g-m]+ tt) uu){5,}[34]


^ (a+?) ( # whitespace and comments after left paren
           # multi-line comment
?: #   Colon must immediately follow question mark
X  #
)  #

    # The slippery slope: parentheses enclosing sequences
    # 
    #  'abc'    'def'    (p      digits      dots      q)    x    y    z
    #  'abc' or 'def', or p then digits then dots then q, or x or y or z
    
    
    #  'abc' or 'def' or (p then digits then q) or x or y or z



=cut

# token_sub_types, mostly for left parenthesis

my $TKST_CAPTURE_ANON    = 'capture_anon';
my $TKST_CAPTURE_NAMED   = 'capture_named';
my $TKST_GROUP_ONLY      = 'group_only';
my $TKST_MODE_SPAN       = 'mode_span';
my $TKST_LOOK_AHEAD      = 'followed by';
my $TKST_NEG_LOOK_AHEAD  = 'not followed by';
my $TKST_LOOK_BEHIND     = 'preceding';
my $TKST_NEG_LOOK_BEHIND = 'not preceding';
my $TKST_ATOMIC          = 'possessive';
my $TKST_NON_GREEDY      = 'minimal';
my $TKST_CONDITION       = 'condition';
my $TKST_BRANCH_RESET    = 'branch_reset';

my $MODE_X  = 1;
my $MODE_S  = 2;
my $MODE_M  = 4;
my $MODE_I  = 8;
my $MODE_P  = 16;
my $MODE_O  = 32;
my $MODE_G  = 64;
my $MODE_C  = 128;
my $MODE_A  = 256;
my $MODE_AA = 512;  # Must be double the flag value for single a
my $MODE_L  = 1024;
my $MODE_U  = 2048;
my $MODE_D  = 4096; # Unicode legacy mode: default/dodgy
my $MODE_NOT_I
            = 8192; # Dummy mode used to mean 'turn /i mode off'
my $MODE_N  = 16384;  # .NET capture-only-explicitly
my $MODE_ALL = ($MODE_N * 2 ) -1;


my $LEXICAL_MODES  = 2;
my $SPANNING_MODES = 1;
my $ALL_MODES      = 0;

# Force mode constants, used during lexical mode-change handling
# Other modes allowed (d, u, a, aa, l and p) can only be turned on, so they
# use their normal mode bits.
my $FORCE_MODE_NONE        = 0;
my $FORCE_CASE_INSENSITIVE = $MODE_I; 
my $FORCE_CASE_SENSITIVE   = $MODE_NOT_I;
                                      
my $flavour_text;           # Global - used in replacement
my $capture_count = 0;      # Global - used in replacement


    
    
my $fo_allow_single_hex_digit = 0;
my $fo_u_and_four_hex         = 0;
my $fo_U_and_eight_hex        = 0;
my $fo_escapes_in_repl        = 0;
my $fo_unknown_escapes_ok     = 0;
my $fo_escape_N_is_non_nl     = 0;
my $fo_escape_N_is_uni_name   = 0;


my %char_names = (
    # Name for some common non-printable characters, and backslash
    #
    # Backslash is represented by its name even though indented regexes don't
    # treat it as an escape character, because it causes too much trouble when
    # it is passed back in: it's OK in a text file, but not in a literal.
    #
    # No-break-space and soft-hyphen get names because their glyphs are
    # identical to their ordinary equivalents (space and hyphen) - and
    # no-break-space is also a whitespace character.
     "\t" => 'tab'  ,
     "\n" => 'newline', "\b" => 'backspace', "\a" => 'alarm',
     "\e" => 'escape' , "\f" => 'form-feed', "\r" => 'carriage-return',
     "\\" => 'backslash',
     "\xA0" => 'no-break-space',
     "\xAD" => 'soft-hyphen',
     "#"    => 'hash',
     ## Ordinary space could be included because it is a whitespace character,
     ## but if we convert all other whitespace to names (and we should) then we
     ## know that any whitespace within quotes is real spaces.
     ## " " => 'space',
     # Double-quote (officially QUOTATION MARK) is included because it is less
     # confusing than having naked double-quotes. It is also possible that solo
     # double-quotes will be deprecated or even forbidden
     '"'    => 'double-quote',
     # Apostrophe is included because it is less confusing than having solo
     # apostrophes, some sequences could be ambiguous, and solo apostrophes may
     # be deprecated or even be forbidden.
     "'"    => 'apostrophe',
     # Hyphen, so that it can't be confused with its use for ranges
     '-'  => 'hyphen',
        ## Various other named characters which arguably might be better named than
        ## appearing as naked characters - mostly because they are
        ## meta-characters in conventional regexes.
        ##  '.'  => 'dot',
        ##  '/'  => 'slash',
        ##  '*'  => 'asterisk',
        ##  '+'  => 'plus',
    );

my $generated_wre;
my $spaces_per_indent = 4;

my $regex_struct_ref;

my @test_regex;


# -------------------------------

    main() unless caller();

# -------------------------------
BEGIN { # Naked block for tokeniser
    my $re  = '';     
    my $line = 0;
    
    my %escapes = (a => "\a",   # Alarm
                   e => "\e",   # Escape (the character ESC, not backslash)
                   f => "\f",   # Form feed
                   n => "\n",   # Newline, whatever that is on this platform
                   r => "\r",   # Carriage return
                   t => "\t"    # Horizontal tab
                  );
    my %groups  = (d => 'digit',           D => 'non-digit',
                                           N => 'non-newline',
                                           R => 'generic-newline',
                   s => 'whitespace',      S => 'non-whitespace',
                   w => 'word-char',       W => 'non-word-char',
                                            # Extended grapheme cluster
                                           X => 'unicode-combo', 
                  );
    my %asserts = (                        A => 'start-of-string',
                   b => 'word-boundary',   B => 'non-word-boundary',
                                           G => 'end-of-previous-match',
                   z => 'end-of-string',   Z => 'almost-end-of-string',
                     );
    


    # -------------------------------
    sub init_tokeniser{
       ($re) = @_;
       pos($re)       = 0;
       $capture_count = 0;
       $line          = 0;
    }
    # -------------------------------
    sub escaped_common {
        # Handles the characters that follow a backslash, that are handled
        # the same inside or outside of a character class
        
        # Returns 1) type-name
        #         2) text
        #         3) the characters consumed
        
        ## Perl interpolation using $ or @ not implemented
        ## Should be optional even if a Perl regex is being processed, because
        ## the regex being fed into Tre2Wre might already have been interpolated
        ## rather than being raw source.
        my ($char, $octal_digits, $group_char);
        
        if ($re =~ / \G ( [aefnrt] ) /xgc) {
            # One of the simple escape characters
            $char = $1;
            return ( 'char', $escapes{$char}, $char);
        } elsif ( $re =~ / \G ( [wWdDsS] ) /xgc ) {
            # A group: word (or not), digit (or not), whitespace (or not)
            $group_char = $1;
            return ( 'group', $groups{$group_char}, $group_char );
        } elsif ( $re =~ / \G ( [0-7]{2,3} ) /xgc) {
            $octal_digits = $1;
            # two or three octal digits
            ## We assume that \10 is octal, but it would be back-reference 10
            ## if ten or more capture groups already seen
            return ( 'char', 'octal-' . $octal_digits, $octal_digits );
        } elsif ($re =~ / \G  x ( [0-9a-fA-F]{2} ) /xgc) {
            my $hex_digits = $1;
            # \x and two hex digits
            return ( 'char', 'hex-' . $hex_digits, $hex_digits );            
        } elsif ($fo_allow_single_hex_digit &&  $re =~ / \G  x ( [0-9a-fA-F] ) /xgc) {
            my $hex_digits = $1;
            # \x and one hex digit
            ## Single hex digit is deprecated in Perl
            return ( 'char', 'hex-0' . $hex_digits, $hex_digits );
        } elsif ( $re =~ / \G  x [{] ( [0-9a-fA-F]+ ) [}] /xgc) {
            my $hex_digits = $1;
            # \x and any number of hex digits, within braces
            return ( 'char', 'hex-' . $hex_digits, $hex_digits );
        } elsif ( $fo_u_and_four_hex && $re =~ / \G  u ( [0-9a-fA-F]{4} ) /xgc) {
            my $hex_digits = $1;
            # \u and four hex digits
            return ( 'char', 'hex-' . $hex_digits, $hex_digits );
        } elsif ( $fo_U_and_eight_hex && $re =~ / \G  U ( [0-9a-fA-F]{8} ) /xgc) {
            my $hex_digits = $1;
            # \u and four hex digits
            return ( 'char', 'hex-' . $hex_digits, $hex_digits );                       
        } elsif ( $re =~ / \G  c ( [a-zA-Z] ) /xgc) {
            my $raw_letter = $1;
            # \c and a letter
            my $control_letter = uc($raw_letter);
            return ( 'char', 'control-' . $control_letter, $raw_letter );
        ##} elsif ( $re =~ / \G  p ( [a-zA-Z] ) /xgc) {
        ##    # \p and a letter
        ##    my $control_letter = uc($1);
        ##    return ( 'group', 'up-' . $control_letter );
            
        } elsif ( $re =~ / \G (p) [{] ( [^}]+ ) [}] /ixgc) {
            # 'p' or 'P' and some stuff in curlies: it's a Unicode property
            
            my $p = $1;
            my $raw_property = $2;
            my $property = $raw_property;
            my $negated = $p eq 'P';
            if ( substr($property, 0, 1) eq '^') {
                # Perl and PCRE: allow caret to negate a Unicode property
                $negated = not $negated;    # Invert negation
                $property = substr($property, 1);
            }
            if (uc $property eq 'L&') {
                # L& is special-case to mean LULT
                $property = 'LUTL';
            }
            if ($negated) {
                # Upper-case p is negated 
                return ('matcher', "non-unicode-property-$property",
                        $p . '{' . $raw_property . '}'
                        );
            } else {
                return ('matcher', "unicode-property-$property",
                        $p . '{' . $raw_property . '}'
                        );
            }
        } elsif ( $re =~ / \G (p) ( [LMZSNPC] ) /ixgc) {
            # 'p' or 'P' and one appropriate letter: it's a Unicode property
            # Perl and PCRE: allow this short form
            my $p = $1;
            my $property = $2;
            if ($p eq 'P') {
                # Upper-case p means negated 
                return ('matcher', "non-unicode-property-$property",
                        $p . $property
                        );
            } else {
                return ('matcher', "unicode-property-$property",
                        $p . $property);
            }
           
        } elsif ( $re =~ / \G ( [\\] ) /xgc ) {
            # Any other character that is a meta-character within and outside char class
            # Literal backslash... are there any others?
            $char = $1;
            return ('char', $char, , $char);
        } else {
            # Not one of the escape sequences recognised by this routine
            return ( 'not_common', '', substr($re, pos($re), 1) );
        }
    }
    # -------------------------------
    sub escaped_outside_class {
        # Handles the character that follows a backslash, outside of a
        # character class 
        my ($esco_type, $esco_token) = escaped_common();
        if (not defined $esco_type) {
            my $esco_pause = 1;
        }
        return ($esco_type, $esco_token) unless $esco_type eq 'not_common';
        if ( $re =~ / \G ( [AbBGzZ] ) /xgc) {
            # Assertions \b \B \A \Z \z 
            # \b is a word boundary outside a character class
            my $assertion_char = $1;
            return ('matcher', $asserts{$assertion_char} );
        }
        if ( $re =~ / \G ( [0-9] ) /xgc) {
            # A single decimal digit - it's a back-reference
            # 
            my $back_ref_number = $1;
            return ('matcher', "backref-$back_ref_number" );
        }
        if ( $re =~ / \G g ( -? ) ( \d ) /xgc) {
            # 'g' and a (possibly negative) decimal digit - it's a back-ref
            ## More than one digit is legal - but we don't support it ###
            ## so back-references to the tenth or later captures will ###
            ## be wrongly handled. Similarly relative references      ###
            ## to captures ten or more previously.                    ###
            my $relative = $1 || '';
            my $back_ref_number = $2;
            if ($relative eq '-') {
                return ('matcher', "backref-relative-$back_ref_number" );
            } else {
                return ('matcher', "backref-$back_ref_number" );
            }
        }
        if ( $re =~ / \G g [{] ( [^}]+ ) [}] /xgc) {
            # 'g' and some stuff in curlies: it's a modern back-reference
            
            my $payload = $1;
            my $back_ref_number;
            if ($payload =~ / \A -? \d+ \z /x) {
                if (substr($payload, 0, 1) eq '-') {
                    $back_ref_number = substr($payload, 1);
                    return ('matcher', "backref-relative-$back_ref_number" );
                } else {
                    return ('matcher', "backref-$payload" );
                }
            } else {
                return ('matcher', "backref-$payload" );
            }
        }
        if ( $re =~ / \G k [<'{] ( [^>'}]+ ) [>'}] /xgc) {
            # 'k' and some stuff in angle-brackets or apostrophes or braces:
            #   it's a modern back-reference
            ## Should do more validation of the name, but best to extract it
            ## first and then complain if it's not valid
            # \k{name} is the .net version - name must not begin with a number, nor contain hyphens            
            my $payload = $1;
            my $back_ref_number;
            if ($payload =~ / \A -? \d+ \z /x) {
                if (substr($payload, 0, 1) eq '-') {
                    $back_ref_number = substr($payload, 1);
                    return ('matcher', "backref-relative-$back_ref_number" );
                } else {
                    return ('matcher', "backref-$payload" );
                }
            } else {
                return ('matcher', "backref-$payload" );
            }
        }
        
        if ( $re =~ / \G [R] /xgc ) {

            # \R = generic-newline
            my $group_char = 'R';
            return ( 'group', $groups{$group_char} );
        }
        
        if ( $re =~ / \G ( [X] ) /xgc ) {

            # \X = Extended grapheme cluster
            #  translates to 'unicode-combo' as the official name is too long
            my $group_char = 'X';
            return ( 'group', $groups{$group_char} );
        }
        
        if ( $fo_escape_N_is_uni_name && $re =~ / \G [N] \{ ( [\w ]+ ) \}  /xgc ) {

            # \N{name} in Perl but not PCRE means named unicode character
            # Perl actually handles this before it gets passed to the regex, as
            # it is just part of Perl's double-quoted string handling. But if we
            # are passed it we have to handle it.
            my $uni_name = $1;
            $uni_name = lc($uni_name);
            $uni_name =~ s/ [ ]{2,} / /gx;
            $uni_name =~ s/ [ ] /-/gx;
            return ( 'matcher', "un-$uni_name" );
        }
        if ( $fo_escape_N_is_non_nl && $re =~ / \G [N] /xgc ) {

           # \N in PCRE (and Perl after version n??) means any-char-except-nl (like dot, but unaffected by /s)
            my $group_char = 'N';
            return ( 'group', $groups{$group_char} );
        }
        
        
        
        $re =~ / \G ( . ) /xsgc;
        my $char = $1;
        # Any other character -
        #    Perl: treat letter as the literal character
        if ($char =~/ ^ [a-z] $ /ix && ! $fo_unknown_escapes_ok) {
            _error("Escaped letter \\$char is not recognised");
        }
        return ( 'char', $char );
        ##return ( 'unknown', '');
    }
    # -------------------------------
    sub escaped_within_class {
        # Handles the character that follows a backslash, inside a
        # character class
        my ($escw_type, $escw_token) = escaped_common();
        return ($escw_type, $escw_token) unless $escw_type eq 'not_common';
        if ( $re =~ / \G [b] /xgc) {
            # \b is a backspace within a char class
            return ('char', "\b");
        }
        $re =~ / \G ( . ) /xsgc;
        my $char = $1;
        # Any other character - treat as the literal character
        ## [FLAVOUR] Most flavours treat escaped letters that do not have defined
        #            escaped meanings as an error: this is sensible to allow for
        #            letters acquiring meaning with new versions.
        #            Perl just treats them as the letter.
        #            We don't have to detect all errors in terse regexes, so we
        #            can just alwys do it the Perl way.
        return ( 'escaped-char', $char );
        ##return ( 'unknown', '');
    }
    # -------------------------------
    sub get_next_token {
        
        # Initial proof of concept: Perl 5.8 mode assumed, undelimited
        # Passed:
        #   1) Free-spacing flag: true if currently in /x mode
        #   2) In character class: true if within character class
        #
        # The big gotcha is that we can't decide whether we are in /x mode until
        # we get to the end of the regex, so before using this we have to do
        # another parsing scan.
        #
        # Hard to cope with variable interpolation if the regex terminator
        # is something like } which is legal within a variable name.
        #
        # Perl is notoriously hard to parse, even if the regex terminator causes
        # no problems. A construct such as $a{3} is ambiguous: it might be the
        # interpolation of the scalar variable $a with a quantifier of 3, or the
        # interpolation of the element with key 3 of the hash %a. Similar
        # problems apply for $a[4567]: is it an array reference or a scalar
        # followed by a character class?
        
        my ($free_spacing, $in_class) = @_;
        my ($token_type, $token, $tk_comment, $tk_sub_type,
            $tk_arg_a, $tk_arg_b) 
               = ('', '', '', '', '', '');
        my ($char);
        
        if ($in_class) {
            $free_spacing = 0;  # Free-spacing never applies inside a character class
                     ### EXCEPT IN JAVA ???  ###
        }
        # Skip leading white space 
        if ($free_spacing) {
            $re =~ / \G \s+ /xgc ;  
        }
        # Grab a leading comment
        # Comments would usually have been attached to the token that they
        # follow, but if they start the regex we don't have anything to attach
        # them to.
        
        if ( $free_spacing && $re =~ / \G \s* ( [#] [^\n]* ) /xgc ) {
            ## Comments are terminated by newline, by the end of the string, or
            ## by a non-escaped regex terminator character.
            ## So we OUGHT to recognise
            ##   non-backslash
            ##   zero or more
            ##      \   # one backslash
            ##      \   # another backslash
            ##   the regex terminator character
            ## ...as terminating the comment
            $tk_comment = $1;
            $token_type = 'comment';
        } elsif ( $re =~ / \G ( [\w\d] ) /xgc ) {
            # Simple letter or digit
            $char = $1;
            $token_type = 'char';
            $token = $char;
        } elsif ( $re =~ / \G \z /xgc ) {
            # End of regular expression
            $token_type = 'end_of_regex';
        } elsif ( ! $in_class && $re =~ / \G [.]  /xgc ) {
            # A dot - match (almost) any character
            $token_type = 'group';
            $token      = 'almost_any';
        } elsif ( ! $in_class && $re =~ / \G \^  /xgc ) {
            # A caret - match start of string or start of line
            $token_type = 'group';
            $token      = 'start_of_something';
        } elsif ( ! $in_class && $re =~ / \G \$ (?! \w )  /xgc ) {
            # A dollar sign, not starting a variable name, which we assume
            # would start with a letter, digit or underscore
            $token_type = 'group';
            $token      = 'end_of_something';
        } elsif ( $in_class && $re =~ / \G [[] :
                ( \^? )
                (   alpha | alnum | ascii | cntrl | digit  | graph | lower |
                    print | punct | space | upper | xdigit | word  | blank   )
                                                  : []] /xgc ) {
            # POSIX character within character class
            $token_type = 'group';
            $token      = $1 eq '' ? "posix-$2" : "non-posix-$2";
            
        } elsif ( ! $in_class && $re =~ / \G [[]  /xgc ) {
            # Left bracket (not meta within char class)
            $token_type = 'left_bracket';
            $token      = '[';
        } elsif ( $in_class && $re =~ / \G []]  /xgc ) {
            # Right bracket (not meta outside char class)
            $token_type = 'right_bracket';
            $token      = ']';            
        } elsif ( ! $in_class && $re =~ / \G [|]  /xgc ) {
            $token_type = 'vbar';
            $token      = '|';
        } elsif (  $re =~ / \G [\\] /xgc ) {
            # A backslash, so we have an escape sequence
            my $escaped = $1;  #### WRONG! We didn't capture anything
            ##### Looks as though escaped_within_class initially only
            ##### handled one character after the \, so it was passed in.
            ##### But to handle \x{123} etc. the escaped_xxx routines now
            ##### do the parsing. Messy, but should be easy to tidy up.
            ($token_type, $token) = $in_class ? escaped_within_class($escaped)
                                              : escaped_outside_class($escaped);
                                              
        } elsif ( ! $in_class && $re =~ / \G
                (?:  [{] ( \d+ ) ( [,]? ) ( \d* ) [}]  # {m,n} or {m,} or {m}
                  |   ( [+?*] )                         # +  or  ?  or  *
                                        ) /xgc ) {
            # end-of-previous-match
            # either
            #    {
            #    capture as min digits
            #    capture as sep optional comma
            #    capture as max optional digits
            #    }
            # or capture as meta + ? *
            #
            # A valid quantifier in {m}  {m,}  {m,n}  +  ?  or  *  format
            my ($min, $comma, $max, $meta)   = ($1 || '', $2 || '', $3 || '', $4 || ''); 
            $token_type = 'quant';
            if ($meta) {
                # It's one of + ? *, rather than {m,n}
                $token = $meta;
                ($min, $max) =  $meta eq '+' ? (1, 'more')
                              : $meta eq '?' ? (0, 1)
                              : $meta eq '*' ? (0, 'more')
                              : ('oops', 'oops');
            } else {
                $token = "{$min$comma$max}";
                if ($comma) {
                    # There is a comma after the min
                    $max = 'more' if $max eq '';
                } else {
                    $max = $min;
                }
            }
            $tk_arg_a = $min;
            $tk_arg_b = $max;
            
            # Now look whether there is a ? or + after the quantifier
            if ($free_spacing) {
                # Deal with any comments, and swallow any spaces in front 
                while ( $re =~ / \G \s* [#] ( [^\n]* \n? )   /xgc) {
                    $tk_comment .= $1;
                }
                $re =~ / \G \s+ /xgc;
            }
            if ($re =~ / \G ( [+?] ) /xgc) {
                # Non-greedy, or possessive quantifier modifier
                my $mod = $1;
                $tk_sub_type = $mod eq '?' ? $TKST_NON_GREEDY : $TKST_ATOMIC;
            }
        } elsif ( ! $in_class && $re =~ / \G [(] \s* [?] ( [\-\^imnsxdualp]+ ) [)] /xgc ) {
            # A non-spanning mode-modifier  (?^imsxdualp-imsx)
            my $modes = $1;
            $token_type = 'mode_switch';
            $token = $modes;
            $tk_arg_a = $modes;
        } elsif ( ! $in_class && $re =~ / \G [(] [?] [#] ( [^)]* ) [)] /xgc ) {
            # Parenthesised comment  (?# ... ) with no escape
            my $comment_text = $1;
            $token_type = 'comment';
            $tk_comment = $comment_text;
        } elsif ( ! $in_class && $re =~ / \G [(] /xgc ) {            
            # A parenthesised sub-expression
            #   Un-named capture ( ... )
            #   Group-only (?: ... )
            #   Mode-modified span (?imsx-imsx: ... )
            #   Look-behind (?<= ... ) look-ahead (?= ... )
            #   -ve look-behind (?<! ... ) -ve look-ahead (?! ... )
            #   Named capture (?< name > ... ) or similar
            #   Atomic grouping (?> ... )
            #   Conditional (?( condition ) if | else )
            #   Branch reset (?| (...) | (...) ) 
            
            ## There can be white-space and multi-line comments between the
            ## left parenthesis and the ?, as well as after the ?:
            ## We parse it here, as the caller won't care that the
            ## comments were split - and it avoids having a messy "after (" mode
            
            # Skip any leading white-space and comment(s)
            # If the next character is not ? or *, it's a plain capture
            
            $token_type = 'paren_start';
            
            if ($free_spacing) {
                # First skip any leading whitespace
                $re =~ / \G \s+ /xgc;
                # Now deal with any comments, and swallow any spaces in front 
                while ( $re =~ / \G \s* [#] ( [^\n]* \n? )   /xgc) {
                    $tk_comment .= $1;
                }
            }
            
            if ( $re !~ / \G [?] /xgc ) {
                # There is no question mark, so it must be a plain capture
                ## at least until fancy * options implemented
                $tk_sub_type = $TKST_CAPTURE_ANON;
                $tk_arg_a = ++$capture_count;
            } else {
                # (?
                # The next markers must be adjacent, or at least we are assuming
                # that is the case
                
                if (      $re =~ / \G :            /xgc ) {
                    #   Group-only (?: ... )
                    $tk_sub_type = $TKST_GROUP_ONLY;
                } elsif ( $re =~ / \G ([\-\^imnsxdual]+ ) : /xgc ) {
                    #   Mode-modified span (?^imnsxdual-imnsx: ... )
                    my $mode = $1;
                    $tk_arg_a = $mode;
                    $tk_sub_type = $TKST_MODE_SPAN;
                } elsif ( $re =~ / \G =            /xgc ) {
                    #   Look-ahead (?= ... )
                    $tk_sub_type = $TKST_LOOK_AHEAD;
                } elsif ( $re =~ / \G !            /xgc ) {
                    # -ve look-ahead (?! ... )
                    $tk_sub_type = $TKST_NEG_LOOK_AHEAD;
                } elsif ( $re =~ / \G < =          /xgc ) {
                    # Look-behind (?<= ... )
                    $tk_sub_type = $TKST_LOOK_BEHIND;
                } elsif ( $re =~ / \G < !          /xgc ) {
                    #   -ve look-behind (?<! ... ) 
                    $tk_sub_type = $TKST_NEG_LOOK_BEHIND;
                } elsif ( $re =~ / \G
                                      < ( \w+ ) >
                                /xgc ) {
                    #   Perl Named capture (?<name> ... ) 
                    $tk_arg_a = $1;
                    $tk_sub_type = $TKST_CAPTURE_NAMED;
                    $capture_count++;
                } elsif ( $re =~ / \G
                                      < (      [a-z] [a-z0-9]*
                                         (?: - [a-z] [a-z0-9]* )
                                        ) >
                                /xgci ) {
                    #   .NET Named capture (?<name> ... )
                    #     allowing balanced capturing group names
                    $tk_arg_a = $1;
                    $tk_sub_type = $TKST_CAPTURE_NAMED;
                    $capture_count++;                    
                } elsif ( $re =~ / \G
                                      ' ( \w+ ) '
                                /xgc ) {
                    #   Named capture (?'name' ... ) 
                    $tk_arg_a = $1;
                    $tk_sub_type = $TKST_CAPTURE_NAMED;
                    $capture_count++;
                } elsif ( $re =~ / \G
                                      P< ( \w+ ) >
                                /xgc ) {
                    #   Named capture (?P<name> ... )  Python-style
                    $tk_arg_a = $1;
                    $tk_sub_type = $TKST_CAPTURE_NAMED;
                    $capture_count++;
                } elsif ( $re =~ / \G
                                      P= ( \w+ ) [)]
                                /xgc ) {
                    #   Named backref (?P=name)  Python-style
                    # Note that we have eaten the closing parenthesis
                    # because this is not treated as a group
                    $tk_arg_a = $1;
                    $token_type = 'matcher';
                    $token = "backref-$1";
                    
                } elsif ( $re =~ / \G >            /xgc ) {
                    #   Atomic grouping (?> ... )
                    $tk_sub_type = $TKST_ATOMIC;
                } elsif ( $re =~ / \G \(( [^)]+ )\)/xgc ) {
                    #   Conditional (?( condition ) if | else )
                    $tk_sub_type = $TKST_CONDITION;
                    $tk_arg_a = $1;
                } elsif ($re =~ / \G [|]           /xgc )  {
                    # Branch reset  (?|  (...) | (...) )
                    $tk_sub_type = $TKST_BRANCH_RESET;
                } else {
                    if ( $re =~ / ( .{0,20}? ) (?: [\#:)\n] | $ ) /xgc) {
                        # lazy 0 to 20 characters, followed by # : or newline or eos
                        _error("Unrecognised option $1 after (?");
                    } else {
                        _error("Unrecognised option after (?");
                    }
                }
            }
        } elsif ( ! $in_class && $re =~ / \G [)] /xgc ) {
            # Right parenthesis
            $token_type = 'paren_end';
            $token      = ')';
        } else {
            # Any other character - treat it as a literal character
            $re =~ / \G ( . ) /xgcs;
            $char = $1;
            $token_type = 'char';
            $token = $char;
            if ( ! defined $char) {
                $token_type = $token_type = 'end_of_regex'; # Defensive loop breaker
            }
        }
        
        if (! $in_class && $free_spacing && $token_type ne 'left_bracket') {
            # Handle comments that follow the current token
            while ( $re =~ / \G \s* ( [#] [^\n]* ) /xgc ) {
                $tk_comment .= $1;
            }
        }
        if ($token_type eq 'group' && ! defined $token) {
            my $pause = 1;
        }
        return ($token_type, $token, $tk_comment, $tk_sub_type, $tk_arg_a, $tk_arg_b);
    }
}

sub apply_modes {
=format
    Passed:
      - an existing modes bit vector (as an integer)
      - a mode flags string
      - an indicator which specifies which modes are allowed:
            $SPANNING_MODES
               allow those that can be used in embedded mode changers, i.e. both
               mode-modified spans and lexical mode changers
            $LEXICAL_MODES
               allow those that can be used independently: they change the mode
               until the end of the current sub-expression
            $ALL_MODES
               allow all modes
               
    Returns the vector, with bits cleared for any mode that follows a dash and
    set for any mode present that does not. Other mode bits are unchanged.
    Calls error if unrecognised mode flag supplied.

    Perl 5.10 modes:
        m  Multiline mode: ^ and $ match internal lines
        s  match as a Single line: . matches \n ( = dot means all)
        i  case-Insensitive
        x  eXtended legibility: free whitespace and comments
        p  Preserve a copy of the matched string: ${^PREMATCH}, ${^MATCH},
           ${^POSTMATCH} will be defined
        o  compile pattern Once
        g  Global: all occurrences You can use \G within regex for end-of-previous-match
        c  don't reset pos on failed matches when using /g
        a  restrict \d, \s, \w and [:posix:] to match ASCII only
        aa (two a's) also /i matches exclude ASCII/non-ASCII
        l  match according to current Locale
        u  match according to Unicode rules
        d  match according to native rules unless something indicates Unicode
                  (D for Default or Dodgy or Depends)
    
For earlier Perls, only imsx were allowed in mode-modified spans or lexical mode
changers. But we can allow any mode, anywhere - the main caveat is that earlier
Perls implicitly have /d, whereas later ones can assume /u.

From Perl 5.14 (and probably from 5.10), most modes can be specified within a
regex: the exceptions are c, g and o.
    (? adlupimsx-imsx)           Lexical mode changer
    (?^a lupimsx)                Lexical mode changer, starting from d-imsx
    (? adlu imsx-imsx :pattern)  Mode-modified span
    (?^a lu imsx      :pattern)  Mode-modified span, starting from d-imsx
    
=cut
    my ($previous_mode_bits, $mode_flags_text, $allowed_modes_code) = @_;
    my $hyphen_seen   = 0;
    my $positive_bits = 0;
    my $negative_bits = 0;
    
    $mode_flags_text =~ s/ aa /A/gx;    # Bodge aa
    my $lexical_modes_ref = {
        d => $MODE_D, u => $MODE_U, A => $MODE_AA, a => $MODE_A,
        l => $MODE_L, 
        x => $MODE_X, s => $MODE_S, m => $MODE_M,  i => $MODE_I,
        n => $MODE_N,
        };   
    my $spanning_modes_ref = {
        d => $MODE_D, u => $MODE_U, A => $MODE_AA, a => $MODE_A,
        l => $MODE_L, 
        x => $MODE_X, s => $MODE_S, m => $MODE_M,  i => $MODE_I,
        n => $MODE_N,
        };
    my $after_caret_modes_ref = {
                      u => $MODE_U, A => $MODE_AA, a => $MODE_A,
        l => $MODE_L, 
        x => $MODE_X, s => $MODE_S, m => $MODE_M,  i => $MODE_I,
    };
    my $all_modes_ref = {
        d => $MODE_D, u => $MODE_U, A => $MODE_AA, a => $MODE_A,
        l => $MODE_L,
        x => $MODE_X,  s  => $MODE_S,  m => $MODE_M,  i => $MODE_I,
        p => $MODE_P,  o  => $MODE_O,  g => $MODE_G,  c => $MODE_C,
        n => $MODE_N,
        };

    my $can_be_negated = $MODE_I | $MODE_M | $MODE_S | $MODE_X | $MODE_N;
    
    my $allowed_modes_ref =
            ($allowed_modes_code == $SPANNING_MODES) ? $spanning_modes_ref
          : ($allowed_modes_code == $LEXICAL_MODES)  ? $lexical_modes_ref 
          : ($allowed_modes_code == $ALL_MODES)      ? $all_modes_ref : {};
    my $check_bits = 0;


    if (substr($mode_flags_text, 0, 1) eq '^' ) {
        # First mode flag is ^
        #   - hyphen is not allowed
        #   - flags are assumed to be d-imsx unless explicitly over-ridden,
        #     so ^u would turn x off if it was already on
        #   -
        if ( not ($previous_mode_bits & $MODE_D ) ) {
            # Not already mode d, so force it on
            $positive_bits = $MODE_D;
        }
        $negative_bits = $MODE_I | $MODE_M | $MODE_S | $MODE_X | $MODE_N;
        for my $mode_char ( split ('', substr($mode_flags_text, 1) ) ) {
            my $mode_bit = $after_caret_modes_ref->{$mode_char};
            if (defined $mode_bit) {
                # Turn on the corresponding positive bit
                $positive_bits |= $mode_bit;
                # Turn off default d mode
                $positive_bits &= $MODE_ALL ^ $MODE_D;
                # Ensure the corresponding negative bit is off
                $negative_bits &= $MODE_ALL ^ $mode_bit;
            } else {
                _error("Unrecognised mode: $mode_char in $mode_flags_text");
            }
        }
    } else {
        for my $mode_char ( split ('', $mode_flags_text) ) {
    
            if ($mode_char eq '-') {
                $hyphen_seen = 1;
            } else {
                my $mode_bit = $allowed_modes_ref->{$mode_char};
                if (defined $mode_bit) {
                    if ($check_bits & $mode_bit) {
                        # We have already seen this bit
                        $mode_char =~ s/A/aa/;
                        _error("Mode: $mode_char used more than once")
                    } else {
                        $check_bits |= $mode_bit;
                        if ($hyphen_seen) {
                            if ($mode_bit & $can_be_negated) {
                                $negative_bits |= $mode_bit;
                            } else {
                                _error("Mode $mode_char is not allowed to be negated");
                            }
                        } else {
                            $positive_bits |= $mode_bit;
                        }
                    }
                } else {
                    _error("Unrecognised mode: $mode_char in $mode_flags_text");
                }
            }
        }
    }
    my $uni_bits = $MODE_D | $MODE_U | $MODE_AA | $MODE_A | $MODE_L;
    my $positive_uni_bits = $positive_bits & $uni_bits;
    if ($positive_uni_bits) {
        # We are explicitly turning on one of the unicode-mode bits (d/u/a/aa/l)
        # So we need to force the others off
        $negative_bits = $uni_bits ^ $positive_uni_bits;
    }
    
    my $result_bits = $previous_mode_bits | $positive_bits;
    
    my $negative_mask = $MODE_ALL ^ $negative_bits;
    $result_bits &= $negative_mask;
    return $result_bits;
}

sub set_flavour {
    # Sets global flavour-dependent flags
    
    ($flavour_text) = @_;
    
    $flavour_text = lc $flavour_text;
    
    
    $fo_allow_single_hex_digit = 0;
    $fo_u_and_four_hex         = 0;
    $fo_U_and_eight_hex        = 0;
    $fo_escapes_in_repl        = 0;
    $fo_unknown_escapes_ok     = 0;
    $fo_escape_N_is_non_nl     = 0;
    $fo_escape_N_is_uni_name   = 0;

    if ($flavour_text eq 'pcre') {
        $fo_allow_single_hex_digit = 1;
        $fo_u_and_four_hex         = 0;
        $fo_U_and_eight_hex        = 0;
        $fo_escapes_in_repl        = 1;
        $fo_unknown_escapes_ok     = 1;
        $fo_escape_N_is_non_nl     = 1;
        $fo_escape_N_is_uni_name   = 0;
    } elsif ($flavour_text eq 'perl') {
        $fo_allow_single_hex_digit = 1;
        $fo_u_and_four_hex         = 0;
        $fo_U_and_eight_hex        = 0;
        $fo_escapes_in_repl        = 1;
        $fo_unknown_escapes_ok     = 1;
        $fo_escape_N_is_non_nl     = 1;
        $fo_escape_N_is_uni_name   = 1;
    } elsif ($flavour_text eq 'javascript') {
        $fo_allow_single_hex_digit = 0;
        $fo_u_and_four_hex         = 1;
        $fo_U_and_eight_hex        = 0;
        $fo_escapes_in_repl        = 0;
        $fo_unknown_escapes_ok     = 0;
        $fo_escape_N_is_non_nl     = 0;
        $fo_escape_N_is_uni_name   = 0;
    } elsif ($flavour_text eq 'java') {
        $fo_allow_single_hex_digit = 0;
        $fo_u_and_four_hex         = 1;
        $fo_U_and_eight_hex        = 0;
        $fo_escapes_in_repl        = 1;
        $fo_unknown_escapes_ok     = 0;
        $fo_escape_N_is_non_nl     = 0;
        $fo_escape_N_is_uni_name   = 0;
    } elsif ($flavour_text eq '.net') {
        $fo_allow_single_hex_digit = 0;
        $fo_u_and_four_hex         = 1;
        $fo_U_and_eight_hex        = 0;
        $fo_escapes_in_repl        = 0;
        $fo_unknown_escapes_ok     = 0;
        $fo_escape_N_is_non_nl     = 0;
        $fo_escape_N_is_uni_name   = 0;
    } elsif ($flavour_text eq 'python') {
        $fo_allow_single_hex_digit = 0;
        $fo_u_and_four_hex         = 1;
        $fo_U_and_eight_hex        = 1;
        $fo_escapes_in_repl        = 0;
        $fo_unknown_escapes_ok     = 0;
        $fo_escape_N_is_non_nl     = 0;
        $fo_escape_N_is_uni_name   = 0;
    } else {
        # Unknown flavour text
        _error("Unrecognised flavour: $flavour_text");
    }
        
        
}
sub tre_to_wre {
    my ($old_regex, $mode_flags, $options, $replacement) = @_;
    $mode_flags = $mode_flags || '';
    my $default_modes_bits = 0;   # Default no modes on
    $generated_wre = '';
    my $updated_mode_bits = apply_modes($default_modes_bits,
                                        $mode_flags,
                                        $ALL_MODES
                                        );
    my $flavour = $options->{flavour} || $options->{flavor} || 'Perl';
    
    if ($flavour =~ /perl/ix) {
        set_flavour('perl');
    } elsif ($flavour =~ /javascript/ix) {
        set_flavour('javascript');
    } elsif ($flavour =~ /java/ix) {
        set_flavour('java');
    } elsif ($flavour =~ /net/ix) {
        set_flavour('.NET');
    } elsif ($flavour =~ /python/ix) {
        set_flavour('python');        
    } else {
        $generated_wre = "# Unknown flavour option: $flavour\n";
        set_flavour('perl');
    }
    
    $regex_struct_ref = {type=> 'root', child => []};
    my $root_ref = $regex_struct_ref->{child};    
    init_tokeniser($old_regex);
    analyse_regex($root_ref, $updated_mode_bits, 0);
    combine_strings($regex_struct_ref);
    analyse_alts($regex_struct_ref);
    generate_wre($regex_struct_ref, 0, $updated_mode_bits);
    
    my $wre_replace = '';
    if (defined $replacement) {
        $wre_replace = convert_replace($replacement, $capture_count);
    }
    return $generated_wre . $wre_replace;
}
# -------------------------------

{ # naked block for replace code
    my $current_string = '';
    my $current_string_contains_dq = 0;
    my $current_string_contains_sq = 0;
    my $converted_replacement = '';
    my $single_quote = "'";
    my $double_quote = '"';
    
sub convert_replace {
    my ($terse_replace, $number_of_captures) = @_;
    
    # Terse replacement is mostly literal text
    # In Perl it's a double-quoted string, so we handle interpolation -
    # but we can only interpolate regex-related variables
    # Named variables can be handled, but their use seems unlikely
    
    # $& means overall-match/entire-match in Perl/.Net
    #     Also pre-match and post-match
    # $$ means $ in .Net. Would interpolate to pid in Perl
    # $1, $2 etc. should expand to captured-n: backref-n would work, but it is
    #   not a back-reference so we shouldn't propagate that mistake
    # ${name} is a named capture in .Net 
    # $+{name} is a named capture in Perl
    # $0 is the overall match in Java
    
    # Perl provides the usual backslash escapes for double-quoted strings:
    #  non-groups, e.g.
    #          \\ \n \t \b \a \e \f \n \r
    #          \octal - complex, very flavour dependent
    #          \xnn
    #          \xn (single-digit, deprecated)
    #          \x{12345}
    #          \cx
    #      any other character after backslash is just a literal character
    #        (not really a good idea, but that's what Perl does)
    #  but not groups , e.g.
    #       \d \s \p{name} \X etc.
    
    # .Net does not allow character escapes
    
    # Only replace $1 etc. if there was a corresponding capture
    
    #  Literal characters tab, newline (and others?) need to be converted to
    #  their names. Space can be left as part of a quoted string
    #
    
    # The semantics of replace might allow us to put them on a single line,
    # with implied sequence rather than the alternation that applies in a regex.
    # But to avoid confusion, generate the various bits as a vertical list, or
    # maybe use 'then'
    #
    
    # replace-with
    #     'text in quotes including ", spaces, $ symbols and \ backslashes'
    #     "text including 'single' quotes is double-quoted"
    #     'text with both " and '
    #     "' is split into multiple quoted strings '"' "'"
    #     # No naked characters: use one-character quoted strings
    #     'a'
    #     tab           # Perl \t, all flavours literal tab
    #     newline       # Perl \n,  all flavours literal newline
    #     hex-34        # Perl \xnn, \x{nnn} etc.
    #     overall-match
    #     captured-1 # etc., if corresponding captures exist
    #     captured-name
    #     pre-match
    #     post-match
        
    # Do our own tokenising, as we have to handle $$, $1 etc.
    # but use the escape-sequence routines to avoid duplication
    
    $current_string = '';
    $current_string_contains_dq = 0;
    $current_string_contains_sq = 0;
    $converted_replacement = "replace-with";
    $single_quote = "'";
    $double_quote = '"';
    
    init_tokeniser($terse_replace);
    
    my $repl_token_re;
    my $end_of_repl = 0;

    if ( $fo_escapes_in_repl )  {
        $repl_token_re = qr/ \G ( .*? ) ( [\\\$"'\t\n\f\r\a\e] | \z ) /x;
                            # end-of-previous-match
                            # capture opt minimal chs
                            # capture  \ $ dq sq tab nl form-feed carriage-return alarm escape eos
    } else {
        # Flavours that don't have escaped characters in the replacement text
        $repl_token_re = qr/ \G ( .*? ) (   [\$"'\t\n\f\r\a\e] | \z ) /x;
                            # end-of-previous-match
                            # capture opt minimal chs
                            # capture   $ dq sq tab nl form-feed carriage-return alarm escape eos
    }
    my $max_chunks = 10;
    while ($max_chunks-- > 0 && not $end_of_repl) {
        
        my $chunk_found = $terse_replace =~ /$repl_token_re/gc;
        my ($chunk, $delim) = ($1, $2);
        $current_string .= $chunk;
        if (length $delim == 0) {
            # Last chunk
            $end_of_repl = 1;
        } elsif ($delim eq $single_quote) {
            if ($current_string_contains_dq == 0) {
                # No double-quotes previously, so just keep appending
                $current_string_contains_sq = 1;
                # append chunk and delim to current_string
                $current_string .= $delim;
            } else {
                # Already have double-quote pending, so flush
                output_current_string();
                $current_string = $delim;
            }
        } elsif ($delim eq $double_quote) {
            if ($current_string_contains_sq == 0) {
                $current_string_contains_dq = 1;
                $current_string .= $delim;
            } else {
                output_current_string();
                $current_string = $delim;
            }
        } elsif ($delim eq '$') {
            my $found_a_char = $terse_replace =~ / \G ( . | \z ) /gcmx;
            my $char = $1;
            if ($char eq '') {
                # end_of_replace
                $current_string .= '$';
                $end_of_repl = 1;
            } elsif ($char eq '$') {
                $current_string .= '$';
            } elsif ($char eq '0') {
                output_keyword('overall-match');                    
            } elsif ($char =~ / [1-9] /x
                     && $number_of_captures >= $char) {
                output_keyword('captured-' . $char);
            } elsif ($char eq '&') {
                output_keyword('overall-match');
            } else {
                $current_string .= '$' . $char;
            }
        } elsif ($delim eq '\\' && $flavour_text eq 'perl') {
            init_tokeniser(substr($terse_replace, pos($terse_replace)));
            
            my ($escape_code, $escape_text, $chars) = escaped_common();
            pos($terse_replace) += length $chars; # Adjust our position
            if ($escape_code eq 'group') {
                _error("Escape sequence not allowed in replace: \\$chars");
            } elsif ($escape_code eq 'char') {
                if (length $escape_text == 1) {
                    output_keyword($char_names{$escape_text});
                } else {
                    output_keyword($escape_text);
                }
            } elsif ($escape_code eq 'not_common') {
                # unrecognised escape 
                if ($chars =~ / ^ [a-z] $ /ix) {
                    # \ and a letter that we don't recognise
                    _error("\\$chars not allowed in replace");
                } elsif ($chars =~ / ^ [1-9] $ /ix) {
                    # \ and a digit: Perl deprecated backref
                    #   (they should use $ and a digit instead)
                    output_keyword('captured-' . $chars);
                } else {
                    # \ and something else, probably punctuation
                    # Just treat it as unescaped
                    ## Is this flavour-specific?
                    $current_string .= $chars;
                }
            } else {
                _error("\\$chars not allowed in replace");
            }
        } else {
            output_keyword($char_names{$delim});
        }
    }
    output_current_string();
    return $converted_replacement;
}

sub output_current_string {
    if (length $current_string > 0) {
        my $string;
        if ($current_string_contains_sq) {
            $string = $double_quote . $current_string . $double_quote;
        } else {
            $string = $single_quote . $current_string . $single_quote;
        }
        $converted_replacement .= "\n    $string";
    }
    init_replace_chunk();
}
sub output_keyword {
    my ($text) = @_;
    output_current_string();
    $converted_replacement .= "\n    $text";
}

sub init_replace_chunk {
    $current_string = '';
    $current_string_contains_sq = 0;
    $current_string_contains_dq = 0;
}

} # end of naked block for replace

    # Tokenise and assemble into chunks
    # Plain literal text goes into a quoted strings
    # Keep track of whether we have seen sq or dq,
    #   terminate current quoted string assembly if we have one already and find
    #   the other
    # Variable interpolation
    # Some characters never included in strings
    #   literal tab or newline
    #   Perl escape sequences
    #
    # Get a (possibly null) chunk, terminated by
    #       $  because that's interpolation or $$
    #       \  only for Perl, so we can handle escape sequences
    #       "  so we can create the right sort of quoted string
    #       '  so we can create the right sort of quoted string
    #       tab, newline, form-feed etc. (so we can replace these
    #             literal characters with their names)
    #       end of string
    
=for
    while not end of replace
        (chunk, delim) = get_chunk
        if end of replace
            output_current_string()
        elsif delim eq sq
            if current_string__contain_dq == 0
                current_string_contains_sq = 1
                append chunk and delim to current_string
            else
                output_current_string()
        elsif delim eq dq
            if current_string__contain_sq == 0
                current_string_contains_dq = 1
                append chunk and delim to current_string
            else
                output_current_string()
        elsif delim eq '$'
            get one char
            if end_of_replace
                append '$' to current_string
                output_current_string()
            elsif char eq '$'
                append '$' to current_string
            elsif char is digit 1 thru 9
                output_current_string()
                output_keyword('captured-' . char)
            elsif char eq '&'
                output_current_string()
                output_keyword('overall-match')
        elsif delim eq '\' and flavour eq 'perl'
            (escape_code, escape_text) = escaped_common()
            if escape_code eq 'group'
                error "Escape sequence not allowed in replace: escape_text)
            elsif escape_code = 'char'
                if length escape_text == 1
                    output_current_string()
                    output_keyword(char_names{escape_text})
                else
                    output_current_string()
                    output_keyword(escape_text)
            else
                error "escape_text not allowed in replace"
            
        else
            output_current_string()
            output_keyword(char_names{delim})

sub output_current_string
    if current_string is not null
        if current_string_contains_sq
            string = dq . current_string . dq
        else
            string = sq . current_string . sq
        replace .= newline . '    ' . string
    init_replace_chunk()

sub output_keyword(text)
    output_current_string
    replace .= newline . '    ' . text
    

sub init_replace_chunk
    current_string = ''
    current_string_contains_sq = 0
    current_string_contains_dq = 0



JAVA

    Java literal strings use \ as an escape character.
    
    So to pass the two characters "\n" as a regex or replacement string, the
    backslash has to be doubled, i.e. "\\n". Otherwise the backslash acts as
    an escape in the literal string. If it's something legal like \f than the
    escaped meaning of the character is used (e.g. form feed). If it's a
    punctuation character, then it means that character literally. A backslash
    followed by a letter than is not one of the specified set is an error, but
    we don't have to enforce that.

    To convert to the convention used by other flavours, replace any occurence
    of two consecutive backslashes with a single backslash.
    So  \\\\  becomes  \\
        \\\n  becomes  \\n
    

from: http://docs.oracle.com/javase/7/docs/api/java/util/regex/Matcher.html#appendReplacement%28java.lang.StringBuffer,%20java.lang.String%29

    The replacement string may contain references to sub-sequences captured
    during the previous match: Each occurrence of ${name} or $g will be replaced
    by the result of evaluating the corresponding group(name) or group(g)
    respectively. For $g, the first number after the $ is always treated as part
    of the group reference. Subsequent numbers are incorporated into g if they
    would form a legal group reference. Only the numerals '0' through '9' are
    considered as potential components of the group reference. If the second
    group matched the string "foo", for example, then passing the replacement
    string "$2bar" would cause "foobar" to be appended to the string buffer. A
    dollar sign ($) may be included as a literal in the replacement string by
    preceding it with a backslash (\$).

    Note that backslashes (\) and dollar signs ($) in the replacement string may
    cause the results to be different than if it were being treated as a literal
    replacement string. Dollar signs may be treated as references to captured
    subsequences as described above, and backslashes are used to escape literal
    characters in the replacement string. 


=cut
    


# -------------------------------
sub add_to_generated {
    my ($line, $indent) = @_;
    $generated_wre .= ' ' x ($indent * $spaces_per_indent) . $line . "\n";
}
# -------------------------------
sub named_single_character {
    # Passed a string representing a single character
    # Returns a string representation of that character usable outside of
    # a quoted literal - so a space is represented by 'space'
    my ($char) = @_;
    if ($char eq ' ') {
        return 'space';
    } else {
        return named_character($char);
    }
}
sub named_character {
    # Passed a character, as parsed by escaped_common.
    # Returns the preferred representation of that character, which can be a
    # name, the character itself, its control-character equivalent or its hex
    # or octal value.
    ## Which is the best representation for control characters is probably
    ## application specific. It might be hex, it might be the control-letter
    ## notation or it might be the relatively rarely-used control character
    ## names (such as SUB and ENQ). The best option is to use the closest
    ## representation to the original regex, unless that is a non-printable
    ## character. So \cX would produce control-X, \x123 would produce hex-123
    ## and \34 would produce octal-34.
    
    my ($char) = @_;
    
    if (length $char > 1) {
        # User supplied a special format (control, hex, octal) - use it
        return $char;   
    }
    my $name = $char_names{$char} || '';
    return $name if $name;
    
    # It was supplied as a single literal character, and it's not one of the
    # common characters that have names.
    # If it's a printable character in the Latin or Latin-1 extended range, then
    # return the literal character as that is what the original regex author
    # wrote - it may be an unusual character but that's what they entered.
    
    return $char if $char =~ / [\x20-\x7E \xA1-\xAC \xAE-\xFF] /x;

    # Otherwise return the hexified version
    my $hex = sprintf('%02x', ord($char));
    return 'hex-' . uc($hex);
}
# -------------------------------
sub number_words {
    # Passed a number and a prefix
    # Returns the word equivalent
    #
    # If the number is too large to get a word and the prefix is not null,
    # the retuned equivalent is prepended with the prefix and a single space
    
    my ($number, $prefix) = @_;
    my @number_word = ('zero', 'one', 'two', 'three', 'four', 'five', 'six',
                       'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve');
    if ($number < 0 || $number > 12) {
        if ($prefix) {
            return $prefix . ' ' . $number;
        } else {
            return $number;
        }
    } else {
        return $number_word[$number];
    }
}
# -------------------------------
sub quants {
    # Passed an entry
    # Returns null string if no quantifiers
    # Otherwise returns quantifier and modifier string, plus one space
    
    my ($entry_ref) = @_;

    # {0,1} ?  optional
    # {0,N}    optionally one to N
    # {0,}  *  optionally one or more
    # {1,}  +  one or more
    # {M,}     M or more
    # {M,N}    M to N

    my $text = '';    
    if (exists $entry_ref->{quant}) {
        my $min = $entry_ref->{quant}{min};
        my $max = $entry_ref->{quant}{max};
        my $mod = $entry_ref->{quant}{mod} || '';
        if (! defined $min) {
            my $pause = 1;
        } elsif ($min eq '') {
            my $pause = 2;
        }
        if ($min eq '' || $min == 0) {
            my $GENERATE_ZERO_QUANT = 1;
            if ($GENERATE_ZERO_QUANT) {
                if ($max eq 'more') {
                    $text = 'zero or more ';
                } elsif ($max == 1) {
                    $text =  'optional ';                
                } else {
                    $text = 'zero to ' . number_words($max) . ' ';
                }
            } else {
                if ($max eq 'more') {
                    $text = 'optionally one or more ';
                } elsif ($max == 2) {
                    $text = 'optionally one or two ';
                } elsif ($max == 1) {
                    $text =  'optional ';                
                } else {
                    $text = 'optionally one to ' . number_words($max) . ' ';
                }
            }
        } else {
            $text = number_words($min, 'qty') . ' ';
            if ($max eq 'more') {
                $text .= 'or more ';
            } elsif ($max == $min + 1) {
                $text .= 'or ' . number_words($max) . ' ';
            } elsif ($max != $min) {
                $text .= 'to ' . number_words($max) . ' ';
            }
        }
        $text .= $mod;
        ##$text .= 'minimal '    if ($mod eq '?');
        ##$text .= 'possessive ' if ($mod eq '+');
        return $text . ' ';
    } else {
        return '';
    }
}

# -------------------------------
# -------------------------------
{ # naked block for generate_wre and friends

    my $line = '';
    my $comment = '';
# -------------------------------    
sub emit_line {
    my ($indent) = @_;
    
    if ($line =~ / \A '  ( [ ]{2,} ) ' \s* \z /x) {
        # start-of-string
        # apostrophe
        # capture two or more spaces
        # apostrophe
        # optional whitespace
        # end-of-string
        # ...so it's a literal with just multiple spaces
        my $multiple_spaces = $1;
        $line = number_words(length $multiple_spaces, 'qty') . ' spaces';
    }
    
    $line =~ s/ \s+ $//x;
    add_to_generated($line, $indent) if $line ne '';
    $line = '';
    if ($comment) {
        add_to_generated('#' . $comment, $indent);
        $comment = '';
    }
}
# -------------------------------
sub generate_captures {

    # Passed a 'nested' entry
    # Returns capture text and a space, or null if no capture
    #
    # Captures are handled separately because combined capture and quantifiers
    # need additional indentation. (\d){3,5} is not the same as (\d{3,5}).
    #   (\d){3,5}
    #       three to five
    #           capture digit
    #   (\d{3,5})
    #       capture three to five digit
    
    my ($entry_ref) = @_;
    my $sub_type = $entry_ref->{sub_type} || '';
    my $sp = ' ';   # Single space
    if ($sub_type eq $TKST_CAPTURE_ANON) {
        return 'capture ';
    } elsif ($sub_type eq $TKST_CAPTURE_NAMED) {
        return 'capture as ' . $entry_ref->{options} . $sp;
    }
}
# -------------------------------
sub generate_non_captures {

    # Passed a 'nested' entry
    # Creates stuff specific to the type of parentheses 
    
    my ($entry_ref) = @_;
    my $sub_type = $entry_ref->{sub_type} || '';
    my $sp = ' ';   # Single space
    if ($sub_type eq $TKST_MODE_SPAN) {
        # Translate mode info into words.
        # i, d, u, a and l modes generate stuff in the wre.
        # i mode can be turned on or off: d, u, a and l can only be turned on.
        # x s and m modes are handled when parsing
        
        my $modes = $entry_ref->{options};
        my $mode_bits = apply_modes(0, $modes, $SPANNING_MODES);
        my $mode_text = '';
        if ($modes =~ / .* [-] .* [i] /x) {
            # Turning i-mode off
            $mode_text .= 'case-sensitive ';
        } else {
            $mode_text .= _mode_text($mode_bits);
        #} elsif ($modes =~ /  [^-]* [i] /x) {
        #    return 'case-insensitive ';
        }
        return $mode_text . $sp;
    } elsif ($sub_type eq $TKST_CONDITION) {
        _error("Unimplemented: condition within regex");
        return "error ";
    } elsif (   $sub_type eq $TKST_LOOK_AHEAD
             || $sub_type eq $TKST_NEG_LOOK_AHEAD
             || $sub_type eq $TKST_LOOK_BEHIND
             || $sub_type eq $TKST_NEG_LOOK_BEHIND
             || $sub_type eq $TKST_ATOMIC
             || $sub_type eq $TKST_BRANCH_RESET
             ) {
        # look-ahead, look-behind , atomic, etc.
         return $sub_type . $sp;
    } elsif ($sub_type eq $TKST_CAPTURE_ANON
             || $sub_type eq $TKST_CAPTURE_NAMED) {
        # Anonymous or named capture needs no action here
        return '';
    } elsif ($sub_type eq $TKST_GROUP_ONLY) {
        # No action
        return '';
    } elsif ($sub_type) {
        _error("Internal error sub_type: $sub_type, in generate_non-captures()");
        return "error ";
    }

}
# -------------------------------
sub generate_stuff_from_entry {

    # Passed one entry
    # Appends generated stuff to line
    
    # Entry may have a quantifier/modifier as well as its main content
    
    my ($entry_ref) = @_;
    
    # combo       quoted string
    # string      naked char
    # char_class  characters, space delimited
    # group       text name of group
    # matcher     text name
    # comment     append to comment

    # mode-switch-a: nothing generated here??
    # mode-switch-b: nothing generated ??
    # nested - shouldn't get here
    
    my $entry_type = $entry_ref->{type};
    
    $line .= quants($entry_ref);
    
    my $value = $entry_ref->{value};
    $value = '' unless defined $value;
    my $sp = ' ';           # A single space
    if ($entry_type eq 'string') {
        $line .= named_single_character($value) . $sp;
    } elsif ($entry_type eq 'combo') {
        my $DQ    = '"';    # Double quote
        my $SQ = "'";    # Single quote
        if ($value =~ / ['] [ ] /x) {
            # Has single-quote followed by space
            if ($value =~ / ["] [ ] /x) {
                # Has double-quote followed by space
                _error("Unimplemented: mixed double and single quotes: $value");
                $line .= "<$value> ";
            } else {
                $line .= $DQ . $value . $DQ . $sp;
            }
        } else {
            $line .= $SQ . $value . $SQ . $sp;
        }
    } elsif ($entry_type eq 'char_class') {
        if ($entry_ref->{negated}) {
            my $char_count = scalar @{$entry_ref->{chars}};
            if ($char_count > 0) {
                $line .= 'not ';
            } else {
                $line .= 'character ';
            }
        }
        for my $char ( @{$entry_ref->{chars}} ) {
            $line .= named_single_character($char) . $sp;
        }
    } elsif ($entry_type eq 'group') {
        $line .= $value . $sp;
    } elsif ($entry_type eq 'matcher') {
        $line .= $value . $sp;
    } elsif ($entry_type eq 'comment') {
        $comment .= $entry_ref->{comment} . $sp;
    } elsif ($entry_type eq 'mode_switch_a') {
        # No action
    } elsif ($entry_type eq 'mode_switch_b') {
        # No action
    } else {
        _error("Internal error: generate_stuff type: $entry_type");
    }
}

=format
        Combine_alts means that we only emit a single line, even though
        there may be multiple alternatives. This can happen because
        indented regexes have alternations on a single line.
        Alternations in conventional regexes are explicit using '|',
        although character classes are also a type of alternation.
        Conversely, even a single alternative may not be emittable on a
        single line, as it may have multiple entries.
       
        All_on_one_line only matters if combine_alts is false. It means
        that there is only a single entry for the current alt, so it can
        be put on one line. That line will start with 'either' or 'or',
        if there is more than one alternative.
       
        If we are emitting 'either' or 'or' then any things that apply to
        all the alternatives (such as a quantifier, or a capture or a
        mode) have to go onto a line from which the eithers/ors are
        indented: 'either' and 'or' must be the first thing on their
        lines.
        
        create capture/quant/mode etc. text in line
        if combine_alts
            for each alt
                for each entry
                    generate stuff from entry, append stuff to line
            emit line (it's all-alts plus everything else)
        else
            if line not null (all-alts) and need either/or's
                emit line (it's the all-alts line) # Because either/or need their own lines
                indent++    # Move everything over
            for each alt
                analyse this alt to determine whether all on one line
                line = either/or if need either/or's       
                if this alt NOT all on one line
                    emit line if not null
                for each entry
                    if nested
                        recursive call
                    else
                        generate stuff from entry,  append stuff to line
                        if this alt NOT all on one line
                            offset = 0
                            offset = 1 if need either/or's
                            emit line at indent + offset if any stuff
                emit line if this alt all on one line
=cut    
# -------------------------------
    sub generate_wre {
        
        # Generates an indented regular expression
        my ($hash_ref, $indent_level, $modes) = @_;
        
        # The only mode acted on here (currently) is /i (case-insensitive)
        # Modes /x, /m, /n and /s are used when parsing the terse regex
        
        # Unicode modes ( /d /u /a /aa /l ) may also be need support here. For
        # example, \w in the terse regex input will generate 'word-ch' in the
        # wordy, but word-ch may change meaning depending on the Unicode mode.

        my $modes_text = _mode_text(($modes || 0) & ( $MODE_I | $MODE_D  | $MODE_U
                                                    | $MODE_A | $MODE_AA | $MODE_L));
        if ($modes_text) {
            $line .= $modes_text;
            emit_line($indent_level++);
        }
        my $child_ref = $hash_ref->{child};
        if ( ! defined $child_ref ) {
            # There is no child entry
            _error("Internal error - no child entry");
        }
            
        my $combine_alts = $hash_ref->{analysis}{combine_alts};
        my $number_of_alternatives = scalar @{$child_ref};
    
        # Create capture/quant/mode etc. text in line

        my $captures     = generate_captures($hash_ref);        
        my $non_captures = generate_non_captures($hash_ref);        
        my $quants       = quants($hash_ref);
        # current_indent is local to this possibly recursive call
        # So it will automatically revert to the previous level
        # when we exit 
        my $current_indent; 
        
        if ($captures && $quants) {
            # Capturing parentheses, followed by a quantifier
            # So we have to put the quantifier first on a separate line and then
            # indent everything from it
            $line = $quants;
            emit_line($indent_level++);
            $current_indent = $indent_level++;
            $line = $captures . $non_captures;
        } else {
            # At most one line needed
            $line = $captures . $quants . $non_captures;
            $current_indent = $indent_level;
            # Indent if there is anything to indent from
            $indent_level++ unless $line eq '';
        }
        if ($combine_alts) {
            # All the alternatives will combine into a single one
            for my $alt_ref( @{$child_ref} ) {
                # For each alternative
                for my $entry_ref ( @{$alt_ref} ){
                    # For each entry, append the stuff to a single line
                    my $type = $entry_ref->{type};
                    generate_stuff_from_entry($entry_ref) unless $type eq 'removed';
                }
            }
            emit_line($current_indent);
            return; # --------->>>>
        }
            
        if ($line ne '' && $number_of_alternatives > 1) {
            # We need either/ors to start their own lines,
            # as we have something enclosing the either/ors
            emit_line($current_indent);
            $indent_level++;        # Move everything over
            $current_indent = $indent_level;
        }
        ALTERNATIVE:
        for my $alt_index (0 .. ($number_of_alternatives - 1) ) {
            # For each alternative
          
            my $alt_ref = $child_ref->[$alt_index];
            next ALTERNATIVE unless defined $alt_ref;
            my $number_of_entries = scalar @{$alt_ref};
            # We need to know whether there will be multiple lines
            # If there is only one non-removed entry and it is not type
            # nested, we can put everything on one line
            # So we count the number of non-removed entries for this alternative
            #
            # We also check for mode_switches
            my $number_of_simple_entries  = 0;
            my $number_of_complex_entries = 0;
            my $number_of_switch_mode_a   = 0;
            my $number_non_mode_switch    = 0;
            my $mode_switch_a_is_first    = 0;
            my $mode_switch_a_is_last     = 0;
            my $number_of_switch_mode_b   = 0;
            my $all_on_one_line           = 0;
            my $leading_mode_switch_a_text = '';
            my $mode_switch_b_text         = '';
            
            for my $entry_ref ( @{$alt_ref} ){
                # For each entry within this alternative
                if ( $entry_ref->{type} eq 'mode_switch_a' ) {
                    $number_of_switch_mode_a++;
                    $mode_switch_a_is_last = 1; # Gets turned off if not really last
                    if ($number_non_mode_switch == 0) {
                        $mode_switch_a_is_first = 1;
                        $leading_mode_switch_a_text = _mode_text($entry_ref->{value});
                    }
                } else {
                    # Not mode_switch_a
                    $mode_switch_a_is_last = 0;
                    if ( $entry_ref->{type} eq 'mode_switch_b' ) {
                        $number_of_switch_mode_b++;
                        $mode_switch_b_text = _mode_text($entry_ref->{value});
                    } else {
                        # Not mode_switch_a or mode_switch_b
                        $number_non_mode_switch++;
                        if      ( $entry_ref->{type} eq 'nested'        ) {
                            $number_of_complex_entries++;
                        } elsif ( $entry_ref->{type} eq 'removed'       ) {
                            # Ignore removed entries
        
                        } else {
                            # Anything else, as long as it doesn't have quantifiers
                            exists $entry_ref->{quant} ? $number_of_complex_entries++ 
                                                       : $number_of_simple_entries++;
                        }
                    }
                }
            }
            if (   $number_of_simple_entries  == 1
                && $number_of_complex_entries == 0
                &&  (   $number_of_switch_mode_a  == 0
                     || $mode_switch_a_is_first
                     || $mode_switch_a_is_last
                    )
               ) {
                $all_on_one_line = 1;
            }
            
            ############### alt > 1 TRUE ### all_on_one_line TRUE ########
            ############### and therefore there cannot be any mode_switch_a's
            if ($number_of_alternatives > 1 && $all_on_one_line) {
                $line = ($alt_index == 0) ? 'either ' : 'or ';
                $line .= $mode_switch_a_is_first ? $leading_mode_switch_a_text
                                                 : $mode_switch_b_text;
                for my $entry_ref ( @{$alt_ref} ){
                    # For each entry within this alternative
                    generate_stuff_from_entry($entry_ref) if $entry_ref->{type} ne 'removed';
                }
                emit_line($current_indent);
            ################ alt > 1 FALSE ### all_on_one_line TRUE ########
            ################ and therefore there cannot be any mode_switch_a's ????
            } elsif ($number_of_alternatives <= 1 && $all_on_one_line) {
                $line .= $mode_switch_a_is_first ? $leading_mode_switch_a_text
                                                 : $mode_switch_b_text;
                for my $entry_ref ( @{$alt_ref} ){
                    # For each entry within this (the only) alternative
                    generate_stuff_from_entry($entry_ref) if $entry_ref->{type} ne 'removed';
                }
                emit_line($current_indent);
            ############### alt > 1 TRUE ### all_on_one_line FALSE ########
            } elsif ($number_of_alternatives > 1 && ! $all_on_one_line) {
                # This alternative needs a line of its own to introduce it,
                # because there are multiple items below it
                $line = ($alt_index == 0) ? 'either ' : 'or ';
                $line .= $mode_switch_b_text unless $mode_switch_a_is_first;
                emit_line($current_indent);
                $indent_level++;    # Move the entries over from either/or
                $current_indent = $indent_level;
                my $mode_indent = 0;
                my $mode_switch_a_seen_count = 0;
                for my $entry_ref ( @{$alt_ref} ){
                    # For each entry within this alternative
                    if ($entry_ref->{type} eq 'nested' ) {
                        ## generate_wre($entry_ref, $indent_level);
                        generate_wre($entry_ref, $current_indent);
                    } elsif ( $entry_ref->{type} eq 'mode_switch_a') {
                        $mode_switch_a_seen_count++;
                        if ( $mode_switch_a_is_last
                            && ($mode_switch_a_seen_count == $number_of_switch_mode_a)
                            ) {
                            # Trailing mode-switch-a
                            # Do nothing
                        } else {
                            # mode switch within an entry, and it isn't the last
                            # element within this alternative
                            if ($mode_indent) {
                                # Already indented from a mode_switch_b from the
                                # preceding alternative or an earlier mode_switch_a
                                # within the same alternative.
                                # So outdent from that one first
                                $current_indent--;
                            }
                            $line = _mode_text($entry_ref->{value});
                            emit_line($current_indent++);
                            $mode_indent = 1;
                        }
                    } elsif ( $entry_ref->{type} ne 'removed' ) {
                        generate_stuff_from_entry($entry_ref);
                        emit_line($current_indent);
                    }
                }
                $indent_level--;    # Move back to either/or level
            ############### alt > 1 FALSE ### all_on_one_line FALSE ########
            ## There cannot be any mode_switch_b's because there is only one
            ## alternative
            } elsif ($number_of_alternatives <= 1 && ! $all_on_one_line) {
                my $mode_indent = 0;
                if ($line ne '') {
                   # We have a partial line already built, emit it
                   emit_line($current_indent);
                   $current_indent = $indent_level; 
                }
                for my $entry_ref ( @{$alt_ref} ){
                    # For each entry within this (the only) alternative
                    if ($entry_ref->{type} eq 'nested' ) {
                        ## generate_wre($entry_ref, $indent_level);
                        generate_wre($entry_ref, $current_indent);
                    } elsif ( $entry_ref->{type} eq 'removed' ) {
                        # Ignore removed entries
                    } elsif ( $entry_ref->{type} eq 'mode_switch_a' ) {
                        # mode switch within an entry
                        if ($mode_indent) {
                            # Already indented from a mode_switch_b
                            # So outdent from that one first
                            $current_indent--;
                        }
                        $line = _mode_text($entry_ref->{value});
                        emit_line($current_indent++);
                        $mode_indent = 1;                        
                    } else {
                        # Anything else
                        generate_stuff_from_entry($entry_ref);
                        emit_line($current_indent);
                        ## $current_indent = $indent_level;   ### ???????
                    }
                }
            }
            $current_indent = $indent_level;
        }
    }
} # End naked block for generate_wre and friends

    

    
    # Slippery slope: parentheses in wordies
    #  (?: abc | def | p \d+ q | [xyz] )
    #  'abc' 'def' (p digits q) x y z
    #  'abc' or 'def' or (p then digits then q) or x or y or z
    #
    # time=hh:mm
    #  No parentheses needed
    # 'time=' then  as hh  two digits  then : then  as mm  two digits
    # 'time=' then (as hh  two digits) then : then (as mm  two digits)
    # 'time=' then  as hh (two digits) then : then  as mm (two digits)
    # 'time='
    # as hh two digits
    # :
    # as mm two digits
    
    # time=hh:mm
    #  Parentheses needed, otherwise hhmm only captures the first two characters
    # as hhmm (two digits then : then two digits)

    

# -------------------------------
sub _error {
    my ($text) = @_;
    print STDERR "Error: $text\n";
    $generated_wre .= 'Error: ' . $text . "\n";
}

# -------------------------------
sub _mode_text {
    # Passed a mode text value 
    # Returns the text to go into the wre
    my ($mode_bits) = @_;
    my $mode_text = '';
    $mode_text .= 'case-sensitive '   if $mode_bits & $MODE_NOT_I;
    $mode_text .= 'case-insensitive ' if $mode_bits & $MODE_I;
    $mode_text .= 'legacy-unicode '   if $mode_bits & $MODE_D;
    $mode_text .= 'full-unicode '     if $mode_bits & $MODE_U;
    $mode_text .= 'ascii '            if $mode_bits & $MODE_A;
    $mode_text .= 'ascii-all '        if $mode_bits & $MODE_AA;
    $mode_text .= 'locale-specific '  if $mode_bits & $MODE_L;
    return $mode_text;
    
}
# -------------------------------
sub is_combinable_string {
    # Passed a reference to an entry
    # Returns true if the entry is for something that can be combined with
    # other strings to form a quoted string
    
    # There are multiple categories:
    #   - simple characters (e.g. a 5 7) which can always be combined
    #   - groups ( e.g. digits ) which cannot be represented in quoted strings
    #   - characters that do have names, but which are always allowed in
    #      within quoted strings (e.g. plus equal asterisk slash + = * /)
    #   - strings that have combinations that do not work in a wre, e.g. the
    #     string:
    #          q '  "
    #     that has single and double quotes, both immediately followed by spaces
    #     has to become:
    #         "q ' " then double-quote
    #     or
    #         q then space then apostrophe then space then double-quote
    #     or
    #         "q ' "
    #         "
    #   - quote characters that could be combined into quoted literal, but are
    #      best generated using names, e.g.
    #         ''    #   better as: two apostrophes
    #               # rather than: "''"
    #         '"'   #   better as: apostrophe then double-quote then apostrophe
    #               # rather than: "'"'"
    my ($entry_ref) = @_;
    
    if ( $entry_ref->{type} eq 'string') {
        my $value = $entry_ref->{value};
        $value = '' unless defined $value;
        if ( length($value) == 1 ) {
            if (exists $entry_ref->{quant} ) {
                return 0;
            } else {
                if (length(named_character($value)) == 1) {
                    return 1;
                }
            }
        }
    }
    return 0;
}
# -------------------------------
sub quote_status {
    my ($text) = @_;
    # returns 1 if single-quote(s), 2 if double_quote(s), 3 if both, 0 if neither
    my $status = ($text =~ /'/) ? 1 : 0;
    $status   += ($text =~ /"/) ? 2 : 0;
    return $status;
}
# -------------------------------
sub combine_strings {

    #   Passed: a reference to a hash
    #   Walks the tree, combining any adjacent strings where this possible.
    #   Adjacent entries within an alternation represent a sequence. Strings can
    #   be combined when they can be added to form one quoted string.
    #   So a series of entries:
    #       - a
    #       - b
    #       - digit
    #       - c
    #       - d
    #     would change to:
    #       - 'ab'
    #       - b removed
    #       - digit (not combinable)
    #       - 'cd'
    #       - d removed
    #     and the generated indented regex fragment would be:
    #       'ab'
    #       digit
    #       'cd'
    #   Unwanted entries are marked as 'removed', although they aren't actually
    #   removed.
    #   Any entry that has combined strings is changed to type 'combo'
    
    # To Do:
    #   ?? Recognise situations where it's better to put a character into a
    #   ?? string literal, rather than used the character's name, e.g.
    #   ??   ab-cd is better as
    #       'ab-cd'
    #   than
    #       'ab'
    #       hyphen
    #       'cd'
    #
    #   Recognise consecutive named characters, e.g.
    #   """
    #   is better as
    #       three double-quotes
    #   or even
    #       '"""'
    #   than
    #       double-quote
    #       double-quote
    #       double-quote
    #
    #   Handle simple or mixed quotes where possible, e.g.
    #       "Mrs O'Grady"
    #   should generate
    #       '"Mrs O'Grady"'
    #   not
    #       double-quote
    #       'Mrs O'
    #       apostrophe
    #       'Grady'
    #       double-quote
    
    
    my ($hash_ref) = @_;
    my $child_ref = $hash_ref->{child};
    if ( defined $child_ref ) {
        # There is a child entry
        # For each alternative
        ALTERNATIVE:
        for my $alt_ref ( @{$child_ref} ) {
            if ( ! defined $alt_ref) {
                next ALTERNATIVE;
            }
            my $number_of_entries = scalar @{$alt_ref};
            my $a = 0;
            my $b = 1;
            
            while ($b < $number_of_entries) {
                # if (entry[a] is a quotable string entry[a] ) {
                my $a_is_combinable = is_combinable_string($alt_ref->[$a]);
                if ( $a_is_combinable ) {
                    my $a_value = $alt_ref->[$a]{value};
                    my $a_quote_status = quote_status($a_value);
                    while (($b < $number_of_entries)
                           && is_combinable_string($alt_ref->[$b])
                           && (($a_quote_status + quote_status($alt_ref->[$b]{value}) != 3 )
                            )
                          ) {
                        $alt_ref->[$a]{type} = 'combo';
                        $alt_ref->[$b]{type} = 'removed';
                        my $b_value = $alt_ref->[$b]{value};
                        $alt_ref->[$a]{value} .= $b_value;
                        $a_quote_status |= quote_status($b_value);
                        $b++;
                    }
                    $a = $b;
                    $b++;
                } 
                $a++;
                $b = $a + 1;
            }
            # Do a complete separate pass to handle any nested entries
            for my $entry_ref (@{$alt_ref}) {
                # For each entry
                if ($entry_ref->{type} eq 'nested') {
                    combine_strings($entry_ref);
                }                
            }
        }
    } else {
        my $no_child = 1;
    }
}
# -------------------------------
sub analyse_alts {
    
    # Analyse alternations, to decide whether they can be combined.
    #
    # This is cosmetic rather than functional: if we mark things as not being
    # possible to combine then more lines than necessary will be generated but
    # the generated indented regex will still be correct.
    # But if we mark things as combinable when they are not, the generated
    # indented regex will be wrong.
    #
    # Passed a hash-ref.
    #
    # If the hash has a child entry, analyse each of its alternatives.
    # Adds or updates the 'analysis' entry of the hash passed.
    #
    # It calls itself for any entries of type 'nested', so it will walk the
    # entire tree.
    
    # Identify alternatives which are eligible to combine with others.
    # An alternative qualifies only if it comprises:
    #       A single string, or
    #       A single non-negated character class, or
    #       A group
    #   in each case with no quantifiers.
    # So if the alternation is:
    #       (?: cat | dog | [p-t\t\d] | \w )
    # then each of the alternations qualifies. The generated line will be:
    #       'cat' 'dog' p-t tab digit word-ch

    my ($hash_ref) = @_;
    my $child_ref = $hash_ref->{child};
    if ( defined $child_ref ) {
        # There is a child entry
        
        my $number_of_alternatives = scalar @{$child_ref};
        my $number_of_qualifying_alts = 0;
        ALTERNATIVE:
        for my $alt_ref ( @{$child_ref} ) {
            # For each alternative, we must have exactly one qualifying entry 
            # and no disqualifying entries for the entire alternative to qualify
            if ( ! defined $alt_ref) {
                next ALTERNATIVE;
            }
            my $entry_qualifiers = 0;
            my $entry_disqualifiers = 0;
            my $number_of_entries = scalar @{$alt_ref};
            
            for my $entry_ref ( @{$alt_ref} ){
                # For each entry within this alternative
                if ($entry_ref->{type} eq 'nested' ) {
                    # Nested stuff - no possibility of qualifying
                    analyse_alts($entry_ref);
                    $entry_disqualifiers++;
                } elsif ( exists $entry_ref->{quant} ) {
                    # An entry must have no quantifiers to qualify
                    $entry_disqualifiers++;
                } elsif (   $entry_ref->{type} eq 'combo'
                         || $entry_ref->{type} eq 'string'
                         || $entry_ref->{type} eq 'group'
                         ) {
                    $entry_qualifiers++;
                } elsif ( $entry_ref->{type} eq 'char_class' ) {
                    # Character class in original regex
                    if ( $entry_ref->{negated} ) {
                        # Negated character class does not qualify
                        ## Some negated character classes might work,
                        ## but are probably rare enough to ignore in alternations
                        $entry_disqualifiers++;
                    } else {
                        $entry_qualifiers++;
                    }
                } elsif (   $entry_ref->{type} eq 'removed' ) {
                    # Ignore removed entries
                } else {
                    # Anything else
                    $entry_disqualifiers++;
                }
            }
            if ($entry_qualifiers == 1 && $entry_disqualifiers == 0) {
                $number_of_qualifying_alts++;
            }            
        }
        # Remember whether all the alternatives qualified.
        # Even if there is only one, it may not be eligible for 'combine_alt'
        # status because it may have more than one qualifying entry and/or at
        # least one disqualifying entry.
        $hash_ref->{analysis}{combine_alts}
            = ($number_of_qualifying_alts == $number_of_alternatives);
        
    }
}
# -------------------------------
sub analyse_regex {
    my ($tree_ref, $mode_bits, $depth) = @_;
    $depth++;
    my $alt_ndx  = 0;
    my $part_ndx = 0;
    my $x_mode   = $mode_bits & $MODE_X;
    my $IN_CLASS = 1;
    my $OUTSIDE_CLASS = 0;
    
    my $force_mode = 0; # Set when lexical mode change applies, e.g. from
                        # (?idualp) or (?-i) until the end of the current
                        # sub-expression or until there is another lexical mode
                        # change. Not passed through to nested elements
    
    my ($token_type, $token, $tk_comment, $tk_sub_type,
        $tk_arg_a, $tk_arg_b);
    
    $token_type = 'just_starting';
    
    while ($token_type ne 'end_of_regex') {
        ($token_type, $token, $tk_comment, $tk_sub_type, $tk_arg_a, $tk_arg_b)
                   = get_next_token($x_mode, $OUTSIDE_CLASS);
                
        if ($token_type eq 'char') {
            $tree_ref->[$alt_ndx][$part_ndx] = {type    => 'string',
                                                value   => $token,
                                                comment => $tk_comment,
                                               };
            $part_ndx++;
        } elsif ($token_type eq 'group') {

            if ($token eq 'almost_any') {
                if ($mode_bits & $MODE_S) {
                    # Meaning changes with s-mode
                    $token = 'character'
                } else {
                    $token = 'non-newline';
                }
            } elsif ($token eq 'start_of_something') {
                if ($mode_bits & $MODE_M) {
                    # Meaning changes with m-mode
                    $token = 'start-of-line';
                } else {
                    $token = 'start-of-string';
                }
            } elsif ($token eq 'end_of_something') {
                if ($mode_bits & $MODE_M) {
                    # Meaning changes with m-mode
                    # to 'after last char in string or before any newline'
                    $token = 'end-of-line';
                } else {
                    # Otherwise it means
                    # 'after last char in string or before a string-ending newline'
                    # so it's sort of end-of-string but not quite.
                    # 'eosx' is what we use for legacy $
                    $token = 'eosx';
                }                
            }
            $tree_ref->[$alt_ndx][$part_ndx] = {type  => 'group',
                                                value => $token,
                                                comment => $tk_comment,
                                               };
            $part_ndx++;            
        } elsif ($token_type eq 'left_bracket') {
            $tree_ref->[$alt_ndx][$part_ndx] = {type  => 'char_class',
                                                chars => [ ],
                                                comment => $tk_comment,
                                               };
            ($token_type, $token) = get_next_token($x_mode, $IN_CLASS);
            
            if ($token eq '^' && $token_type ne 'escaped-char') {
                $tree_ref->[$alt_ndx][$part_ndx]{negated} = 1;
                ($token_type, $token) = get_next_token($x_mode, $IN_CLASS);
            }
            my $char_count = 1;
            CHAR:
            until ($token_type eq 'right_bracket'
                     && ($char_count > 1 || $flavour_text eq 'javascript')
                   || $token_type eq 'end_of_regex') {
                if (   $token eq '-'
                    && $token_type ne 'escaped-char'
                    && $char_count > 1) {
                    # A hyphen that might be introducing a range, but not if
                    # it is the first or last character in the class
                    ($token_type, $token) = get_next_token($x_mode, $IN_CLASS);
                    if ($token_type eq 'right_bracket') {
                        # Hyphen was last character in class, add it to list
                        push @{$tree_ref->[$alt_ndx][$part_ndx]{chars}}, '-';
                        last CHAR;
                    } else {
                        my $range_start = @{$tree_ref->[$alt_ndx][$part_ndx]{chars}}[-1];
                        my $range_end = $token;
                        my $range_text = $range_start . ' to ' . $token;
                        if (    $range_start lt $range_end
                             && (  ($range_start =~ / ^ [a-z] $ /x
                                 && $range_end   =~ / ^ [a-z] $ /x)
                                || ($range_start =~ / ^ [A-Z] $ /x
                                 && $range_end   =~ / ^ [A-Z] $ /x)
                                || ($range_start =~ / ^ [0-9] $ /x
                                 && $range_end   =~ / ^ [0-9] $ /x)
                                )
                             ){
                            $range_text = $range_start . '-' . $range_end;    
                        }

                        @{$tree_ref->[$alt_ndx][$part_ndx]{chars}}[-1] = $range_text;
                    }
                } else {
                    push @{$tree_ref->[$alt_ndx][$part_ndx]{chars}}, $token;
                }
                $char_count++;
                ($token_type, $token) = get_next_token($x_mode, $IN_CLASS);
            }
            if ($token_type eq 'end_of_regex') {
                _error ("Unterminated character class - missing ']'");
            }
            $part_ndx++;
        } elsif ($token_type eq 'vbar') {
            # Vertical bar: another alternative starting
            $alt_ndx++;
            $part_ndx = 0;
            
            if ($force_mode != $FORCE_MODE_NONE) {
                # A (?idual) or (?-i) in an earlier alternative is still in effect,
                # so create a synthetic mode_switch element to trigger indent
                $tree_ref->[$alt_ndx][$part_ndx] = {type    => 'mode_switch_b',
                                                    value   => $force_mode,
                                                    comment => $tk_comment,
                                                   };
                $part_ndx++;
            }
            
        } elsif ($token_type eq 'paren_start') {
            # Left parenthesis, possibly plus some other goodies
            if ($tk_sub_type eq $TKST_CAPTURE_ANON
                && $mode_bits & $MODE_N) {
                $tk_sub_type = $TKST_GROUP_ONLY;                
            }
            $tree_ref->[$alt_ndx][$part_ndx] = {type     => 'nested',
                                                sub_type => $tk_sub_type,
                                                options  => $tk_arg_a,
                                                child    => [ ],
                                                comment => $tk_comment,
                                               };
            my $nested_mode_bits = $mode_bits;
            if ($tk_sub_type eq $TKST_MODE_SPAN) {
                $nested_mode_bits = apply_modes($mode_bits,
                                                $tk_arg_a,
                                                $SPANNING_MODES
                                                );
            }
            my $reached_end = analyse_regex($tree_ref->[$alt_ndx][$part_ndx]{child},
                                            $nested_mode_bits,
                                            $depth);
            if ($reached_end) {
                _error("Unbalanced parentheses");
                return 1;  #---->>
            }
            $part_ndx++;
        } elsif ($token_type eq 'paren_end') {
            # Right parenthesis, other goodies such as quantifiers and their
            # modifiers may follow, but not yet parsed
            if ($depth == 1) {
                _error("Unbalanced parentheses");
            }
            return 0;  #---->>
        } elsif ($token_type eq 'quant') {
            # Quantifier - applies to previous part
            if ($part_ndx == 0) {
                _error("quantifier $token has nothing to quantify");
            } elsif (exists $tree_ref->[$alt_ndx][$part_ndx - 1]{quant}) {
                my $previous_quant = $tree_ref->[$alt_ndx][$part_ndx - 1]{quant}{token};
                _error("quantifier: $token follows another quantifier: $previous_quant");
            } else {
                $tree_ref->[$alt_ndx][$part_ndx - 1]{quant}
                    = {min   => $tk_arg_a,
                       max   => $tk_arg_b,
                       mod   => $tk_sub_type,
                       token => $token
                       };
            }
          
        } elsif ($token_type eq 'group') {
            $tree_ref->[$alt_ndx][$part_ndx] = {type  => 'group',
                                                value => $token,
                                                comment => $tk_comment,
                                               };
            $part_ndx++;
        } elsif ($token_type eq 'mode_switch') {
            # Change of mode, but not a mode modifying span
            # Mode changes until end of sub-expression
            
            # For s and m, just set or clear $mode_bits
            # For x, set or clear $mode_bits and also ensure $x_mode is correct
            # so that parsing is done correctly.
            
            # For i and d/u/a/l, it's messier. We set or clear the mode bits
            # here, and set the value to do the rest later
            
            
            my $new_mode_bits = apply_modes(0,          $tk_arg_a, $LEXICAL_MODES);
            $mode_bits        = apply_modes($mode_bits, $tk_arg_a, $LEXICAL_MODES);
            $x_mode           = $mode_bits & $MODE_X;
            
            if ($tk_arg_a =~ /[idualp]/) {
                if ($tk_arg_a =~ /i/) {
                    # Turning i-mode on or off.
                    my $i_mode = $new_mode_bits & $MODE_I;
                    # There are two i-mode bits in $force_mode,
                    #   one for (?i) and one for (?-i)
                    # Turn both bits off
                    $force_mode &= ~ ($FORCE_CASE_INSENSITIVE | $FORCE_CASE_SENSITIVE);
                    # Now turn on the one that we want
                    $force_mode |= ($i_mode ? $FORCE_CASE_INSENSITIVE
                                            : $FORCE_CASE_SENSITIVE);
                }
                if ($tk_arg_a =~ /[dual]/) {
                    # One of the Unicode modes has been specified
                    # Turn off all the mutually-exclusive Unicode mode bits
                    my $uni_mask = ($MODE_D | $MODE_U | $MODE_A | $MODE_AA | $MODE_L);
                    $force_mode &= ~ $uni_mask;
                    # Now turn on the relevant one
                    $force_mode |= ($new_mode_bits & $uni_mask);
                }
                if ($tk_arg_a =~ /[p]/) {
                    # /p mode
                    ## Should set a global flag
                }
                $tree_ref->[$alt_ndx][$part_ndx] = {type    => 'mode_switch_a',
                                                    value   => $force_mode,
                                                    comment => $tk_comment,
                                                   };
                $part_ndx++;                  
            }
        } elsif ($token_type eq 'end_of_regex') {
            ## Should we check for incorrect nesting?
            return 1;   #---->>
        } elsif ($token_type eq 'matcher') {
            $tree_ref->[$alt_ndx][$part_ndx] = {type  => 'matcher',
                                                value => $token,
                                                comment => $tk_comment,
                                               };
            $part_ndx++;            
        } elsif ($token_type eq 'comment') {
            # Don't do anything with comments at present
        } else {
            _error('Unhandled token type: ' . $token_type);
        }
    }
}



sub main {



    # Reads terse regexes from a file or stdin .
    # Use control-D to terminate input
    # Use /n.../n to separate terse regexes
    # Use Perl / regex /imsx notation for modes
    
    my $stdin = $ARGV[0];
    if ($stdin eq '-') {
        print "Use Control-D to finish\nUse ... to separate regexes\n\n";
    }
    
    
    my $terse = '';
    
    while (<>) {
        if ( m{ \A [.][.][.] \s* \Z }x ) {
            # End of a terse
            _handle_terse($terse);
            print "Enter next regex terminated with ...\nor control-D to finish\n";
            $terse = '';
        } else {
            $terse .= $_;
        }
    }
    if ($terse =~ m{ \S }x) {
        _handle_terse($terse);
    }
}
#-------------------------------------------------
sub _handle_terse {
    my ($terse_in) = @_;
    chomp $terse_in;
    my $modes = '';
    my $replace = undef;
    my $terse;
    if ($terse_in eq 'builtin') {
        _builtin_tests();
    } else {
        if (substr($terse_in, 0, 1) eq '/') {
            # Perl-style regex in /regex/modes format
            #  (except that we don't handle escaped / characters)
            # or maybe replace in /regex/replace/modes format
            if ($terse_in =~ m{
                (?sx: \/                      #     /
                (?<regex>.                    #     as regex one or more minimal character
                +?)(?<midsep>                 #     as midsep
                (?<!\\                        #         not preceding \
                )(?: \\\\                     #         zero or more '\\'
                )*\/                          #         /
                )(?<repl>(?:.+                #     as repl opt chs
                )?)\/                         #     /
                (?<modes>(?:.+                #     as modes opt chs
                )?) )
                               }x  ) {
                # Replacement in /regex/repl/modes format
                # midsep is used to avoid variable-length look-behind
                $terse   = $+{regex} . $+{midsep};
                chop $terse;
                $replace = $+{repl};
                $modes   = $+{modes};
            } else {
                ($terse, $modes) =  $terse_in =~ m{ \A  \/ (.*) \/ ( [ismxdual-]* ) \z }x;
            }
        } elsif (substr($terse_in, 0, 1) eq '~') {
            # Perl-style regex in ~regex~modes format
            ($terse, $modes) =  $terse_in =~ m{ \A  ~ (.*)  ~ ( [ismxdual-]* ) \z }x;
        } else {
            $terse = $terse_in;
        }
        my $wre = tre_to_wre($terse, $modes, undef, $replace);
        print "\nterse:\n$terse\n\nwordy:\n$wre\n";
    }
}
#-------------------------------------------------
sub _builtin_tests {
        
    load_tests();

    for my $regex_ref (@test_regex) {
        test_gen (@{$regex_ref});
    }
    my $done_gen = 1;
    
}

=format
TO DO:


        
    Protection and Case-forcing:
        These are mostly used with interpolation, but we might be given a regex
        that has been interpolated already.
        \Q ... \E treats most characters is non-meta
        \U and \L force case until \E
        \u and \l force the case of the next character.
            \u forces titlecase, not upper-case, for Perl versions from ??

\N{name} Named Unicode character. There are tens of thousands of them. In Perl
             it's not the regex engine that handles this: it's done earlier and
             the actual character is passed to the engine. But for our purposes
             we have to handle it: possibly only 'require' the names module when
             this construct is seen.
\N{U+hex}   Unicode by code point
\N          non-newline (experimental from Perl 5.12). As it is still experimental
            then it's not appropriate to generate this, but we should accept it
            in conventional regex input. Syntax looks messy to distinguish from
            named/numbered Unicode. Need to check whether it is used in other
            flavours.

            PCRE: The escape sequence \N behaves like a dot, except that it is not
            affected by the PCRE_DOTALL option.  In other words, it matches any
            character except one that signifies the end of a line. Perl also uses
            \N to match characters by name; PCRE does not support this.

\px, \Px    Unicode property, where x is single letter
\p{name}
\P{name}    Unicode property, name longer than one character. Thousands of them
            Unicode properties is one area where flavours differ substantially.
            
    Capture Number Checking.
        Warn if a round-tripped regex will have its capture numbers disturbed.

    

MODES
  On the regex itself (e.g. after ending / when m/.../ notation used)
    m  Multiline mode: ^ and $ match internal lines
    s  match as a Single line: . matches \n
    i  case-Insensitive
    x  eXtended legibility: free whitespace and comments
    p  Preserve a copy of the matched string: ${^PREMATCH}, ${^MATCH},
       ${^POSTMATCH} will be defined.
    o  compile pattern Once
    g  Global - all occurrences. You can use \G within regex for end-of-previous-match
    c  don't reset pos on failed matches when using /g
    a  restrict \d, \s, \w and [:posix:] to match ASCII only
    aa (two a's) also /i matches exclude ASCII/non-ASCII
    l  match according to current locale
    u  match according to Unicode rules
    d  match according to native rules unless something indicates Unicode (This
         might be what Perl did by default prior to version 5.10)


\K          see Regexp::Keep. Probably can be handled in the same way as
            zero-width assertions: give it a keyword and generate /K when we
            see it in an wre when we are generating conventional regex.

\h, \H      Horizontal whitespace, or not
\v, \V      Vertical whitespace, or not

\C          One byte
\X          Unicode extended grapheme cluster (base + any modifying characters)


# \X extended grapheme cluster: Perl & PCRE




Named Patterns (perl 5.10+)
    Define sub-regex with (?(DEFINE) (?<name>pattern)... ) where the < and >
    around the name must be present. This is a special case of (?(cond)...)
    
    Use the sub-pattern (earlier or later!) using (?&name)
    Example:
        /^ (?&osg) [ ]* ( (?&int)(?&dec)? | (?&dec) )
            (?: [eE](?&osg)(?&int) )?
        $
        (?(DEFINE)
            (?<osg>[-+]?)         # optional sign
            (?<int>\d++)          # integer
            (?<dec>\.(?&int))     # decimal fraction
        )/x

    IRE's will need their own keywords for this: maybe 'define as name' and
    'use name'. It would be possible for 'define' to add the defined name as a
    keyword, so that just the bare name invokes it - it is shorter, and avoids
    the cognitive clash with the Perl 'use'.
    
    The semantics could be largely macro-like: paste in the defined text at the
    point of use.
    
    Does it imply the need for an extra pass? Probably not in this module, as
    long as we can assume that any name used will eventally be defined (and we
    can report an error if not).

    Lexical Mode Spans
        Modes such as (?x)  or (?-i): implemented, but assuming Perl syntax
        In Perl, they "only affect the regexp inside the group the embedded modifier
        is contained in" according to perlretut.
        Check for exact effect in other flavours.
            Perl: rest of sub-expression (?xsmi) (?-xsmi)
            Java: rest of sub-expression (?xsmidu) (?-xsmidu)
                    d = treat \n as the only line terminator
                    u = case-insensitive match for Unicode characters
            .NET: rest of sub-expression (?xsmin) (?-xsmin)
                    n = plain parentheses do not capture
            Python: entire regexp (?iLmsux), so no negation needed
    

Interpolation:
        The crudest approach is to only handle the regex after interpolation has
        been done. But if the interpolation is dynamic, this isn't a useful
        option: the user wants to know the indented regex that will provide the
        same functionality as the original.
        
        A simple approach is to just add the same interpolation into the
        generated regex. This may work for most cases, provided that either:
            - a single character is being interpolated , or
            - we can determine whether the characters are being interpolated
              into a character class. If so, they are alternatives: if not they
              are a simple sequence, or alternative sequences separated by pipes.
              
        Anything that interpolates meta-characters is doubtful - about the only
        one that might be able to be made to work consistently is alternation,
        and even that might require an additional layer of group-only
        parentheses to be generated.

        If the conventional regex is going to be obtained by calling a function
        that has the wre embedded, then that function could be passed the
        value(s) to be interpolated. The function can manage the handling of
        meta-characters if necessary: plain protection (\Q \E) will work for
        single characters and sinple sequences but won't work if a sequence has
        pipes to show alternation.
        
        If the original regex has \Q and \E around the interpolated variable, that
        implies the interpolated value is not trying to use meta-characters (not
        even pipe). If it doesn't have \Q and \E, almost anything may possibly
        be attempted - but it may not work with the conventional regex generated
        from the ire. One possiblity is for the function to check its arguments
        for meta-characters at run time.
        
        Original conventional regex is:
            if ($data =~ /my cat $verb dogs/) ...
        The interpolation is not inside a character class, nor does it have /Q
        and /E. So we know it's a plain sequence, and we can guess that it
        probably won't have embedded pipes. So the generated ire function might
        be:
            sub cat_verb_dogs {
                my ($verb_value) = @_;
                my $ire = "
                    'my cat $verb_value dogs'
                    ";
                my $regex = convert_ire_to_regex($ire);
                return $regex;
            }
            sub cat_verb_dogs_mark_2 {
                my ($verb_value) = @_;
                my $ire = "
                    'my cat $verb_value dogs'
                ";
                return convert_ire_to_regex($ire);
            }
        ...and the invocation changes to:
            my $re = cat_verb_dogs($verb);
            if ($data =~ /$re/) ...
        
        
        
            if ($data =~ /my cat (?:$verb )dogs/) ...
            
            sub cat_verb_dogs {
                my ($verb_value) = @_;
                my $ire = "
                    'my cat'
                    insert_seq verb
                    ' '
                    'dogs'
                ";
                return convert_ire_to_regex($ire, $verb_value);
            }

        ...and the invocation changes to:
            my $re = cat_verb_dogs($verb);
            if ($data =~ /$re/) ...
            
    Look at Perl 5.12 overloading of qr//
         qr is used for the RHS of =~ and when an object is interpolated into a
         regexp. Not sure if this will allow much simplification - but it might
         allow for a tidier oo version.
            
    
    
    
Mode-Modified Spans and Regex Literals
--------------------------------------

My experiments with ActiveState Perl 5.8.4 on Windows show that m-mode does not
apply when applied to a qr// regex literal, even though the stringified version
of the regex shows it enclosed between (?msx-i: and ).

This contradicts what MRE2 states, which is that modes from qr-regexes are very
sticky. It looks like a Perl 5.8 defect to me, as even if the qr-regex contains
a mode-modified span turning m-mode on, when that regex is used m-mode is off
unless turned on locally. It works correctly in ActiveState Perl 5.10 on Windows.

    my $re4 = qr/a$/msx;
    
    my $match4a = "a\n" =~ $re4;
    my $match4b = "a\nbb\n" =~ $re4; # Should match, but doesn't
    
    my $match4e = "a\n" =~ /$re4/;
    my $match4f = "a\nbb\n" =~ /$re4/; # Should match, but doesn't
    
    my $match4g = "a\n" =~ /$re4/msx;
    my $match4h = "a\nbb\n" =~ /$re4/msx;
    
    my $re5 = qr/(?m:a$)/msx;
    my $match5a = "a\n" =~ $re5;
    my $match5b = "a\nbb\n" =~ $re5; # Should match, but doesn't
    
    my $match5e = "a\n" =~ /$re5/;
    my $match5f = "a\nbb\n" =~ /$re5/; # Should match, but doesn't
    
    my $match5g = "a\n" =~ /$re5/msx;
    my $match5h = "a\nbb\n" =~ /$re5/msx;
    
    my $re6 = '(?m:a$)';
    my $match6a = "a\n" =~ $re6;
    my $match6b = "a\nbb\n" =~ $re6;
    
    my $match6e = "a\n" =~ /$re6/;
    my $match6f = "a\nbb\n" =~ /$re6/;
    
    my $match6g = "a\n" =~ /$re6/msx;
    my $match6h = "a\nbb\n" =~ /$re6/msx;
    
    This appears to have been fixed in Perl 5.10. It doesn't affect regexes
    interpolated from a string, but there may be serious performance issues
    when targetting Perl 5.8 if we are forced to use strings rather than
    qr-regexes.

Mode Modifiers (as opposed to mode-modified spans)
--------------------------------------------------

qr/ abc ( qw (?i) d ) f  /x;
'abc'
capture
    'qw'
    case_insensitive
        d
f
--------------
qr/ abc ( qw (?i) d (?-i) e ) f  /x;
'abc'
capture
    'qw'
    case_insensitive
        d
    e
f
--------------
qr/ abc ( qw (?i) d (?-i) e ) f  /ix;
case_insensitive
    'abc'
    capture
    'qwd'
    case-sensitive
        e
    f
--------------
qr/ abc ( q (?s) .w (?i) (?-s) d (?-i) e ) f  /x;

We only have to handle i, m, s and x, I hope.

m and s affect what . $ and ^ mean within the scope of the mode modifier, so we
can keep track of those and put the appropriate things into the tree.

x affects the parsing, but not the meaning of the regex.

(?x) is allowed as a lexical mode changer, unlike (?x: ... )
which is a mode-modified span. It does seem to work in Perl, but not in Komodo's
Rx Toolkit.


Names For String and Line Endings
---------------------------------
[[[ These notes are about the design of the wordy notation - they are in this module
    because they mostly affect terse regular expressions that are being translated
    into wordies. ]]]
 
 Currently implemented in Wre.pm:
 
    Short   Full                    Terse regex equivalent
    sos     start-of-string         \A
    sol     start-of-line           ^ provided /m mode is on
    
    eosx    almost-end-of-string    \Z ($ provided /m mode is off)
    eos     end-of-string           \z (absolute end of string)
    eol     end-of-line             $ provided /m mode is on
    
    Tre2Wre.pm has to cope with whatever is supplied in the terse regex, and allow
    for whether /m mode is on. It generates the full versions of the words.
    
    Wre.pm follows the recommendations in 'Perl Best Practices' and generates
        \A      for sos/start-of-string
        \z      for eos/end-of-string
        ^       with /m mode on, for sol/start-of-line
        $       with /m mode on, for eol/end-of-line
        \Z      for eosx/almost-end-of-string
            

One possibility is to special-case regexes that start with ^ and end with $ (and
don't have any alternations active at that stage) as they are quite common, and
have a 'match-entire-string' command. But that would still need to differentiate
itself from a similar regex that started with ^ but ended with \z - which might
need a modifier so that you say 'match-entire-string-legacy'.

If 'legacy' only affects eos/eol, then a more descriptive name for it should be
possible. The design philosophy is that someone who knows only the sequence and
alternation rules should correctly understand the meaning of the wordy.




[from http://search.cpan.org/~dom/perl-5.14.3/pod/perlretut.pod]
Starting with Perl 5.10, it is possible to define named subpatterns in a section
of the pattern so that they can be called up by name anywhere in the pattern.
This syntactic pattern for this definition group is
(?(DEFINE)(?<name>pattern)...). An insertion of a named pattern is written as
(?&name).

The example below illustrates this feature using the pattern for floating point
numbers that was presented earlier on. The three subpatterns that are used more
than once are the optional sign, the digit sequence for an integer and the
decimal fraction. The DEFINE group at the end of the pattern contains their
definition. Notice that the decimal fraction pattern is the first place where we
can reuse the integer pattern.

   /^ (?&osg)\ * ( (?&int)(?&dec)? | (?&dec) )
      (?: [eE](?&osg)(?&int) )?
    $
    (?(DEFINE)
      (?<osg>[-+]?)         # optional sign
      (?<int>\d++)          # integer
      (?<dec>\.(?&int))     # decimal fraction
    )/x

==============================================================================

=head1 AUTHOR

Derek Mead

=head1 COPYRIGHT

Copyright (c) 2011, 2012, 2013 Derek Mead

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut

# In-line test generation.
# These are not self-checking tests: they generate output that can be manually
# verified, and that can then be added to a self-checking automated test.
# These will get moved out to separate .t (or .tgen) files eventually,
# but held here during initial development
#
# The reason for generating the tests this way is that a minor tweak to this
# module may result in changes to many of the generated wres. This approach
# does not avoid the need to check each result, but does provide a way of
# regenerating the tests en masse after they have been checked. One major
# problem is that these tests do not specify test data, matches or captures - so
# if they have been added manually to the tests there is a risk that they will
# be lost. A better approach might be to have the test rig create the updated
# test itself, retaining any data, match and capture information but updating
# the generated wordy.
#
# Probably keep the ability to test the module by running it as a program,
# to provide an easy way of doing ad hoc tests, even when the main tests
# have all moved into .t files

sub load_tests {
    push @test_regex, ['[\d[:^ascii:]]', '-x', ""   ];
    push @test_regex, ['[\d[:ascii:]]', '-x', ""   ];

    push @test_regex, [
        '(?x-ism:(?-xism:(?:(?i)(?:[+-]?)(?:(?=[.]?[0123456789])
         (?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[
         E])(?:(?:[+-]?)(?:[0123456789]+))|))|(?-xism:[[:upper:]][
         [:alnum:]_]*))(?:\s*(?-xism:[-+*/%])\s*(?-xism:(?:(?i)(?:[
         +-]?)(?:(?=[.]?[0123456789])(?:[0123456789]*)(?:(?:[.])
         (?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[+-]?)(?:[0123456789
         ]+))|))|(?-xism:[[:upper:]][[:alnum:]_]*)))*)
                               ', '-x', "" ];
    push @test_regex, ['h?{2}', '-x', ""   ];
    push @test_regex, ['h+{2}', '-x', ""   ];
    push @test_regex, ['h*{2}', '-x', ""   ];
    push @test_regex, ['   (?i) cd | ef  ', 'x', ""   ];
    push @test_regex, ['   (?i: cd | ef )', 'x', ""   ];
    push @test_regex, ['(?:(?i: cd | ef))', 'x', ""   ];
    push @test_regex, ['(?:(?i: cd | ef)g)', 'x', ""   ];
    push @test_regex, ['    a (?i) b | (?-i) c (\d) w       d', 'x', "Leading mode-switch end"   ];
    push @test_regex, ['    a (?i) b | (?-i) c (\d) w  (?i) d', 'x', "Leading mode-switch end"   ];
    push @test_regex, ['    a (?i) b | c (\d (?-i) Q)  w  (?i) d', 'x', "Nested lexical mode-switches"   ];
    push @test_regex, ['    a (?i) b | c (\d (?-i) Q+) w  (?i) d', 'x', "Nested lexical mode-switches"   ];
    push @test_regex, ['    a (?i) b | c (\d (?-i) Q++)w  (?i) d', 'x', "Nested lexical mode-switches"   ];
    push @test_regex, ['    a (?i) b | c (\d) (?-i) w  (?i) d', 'x', ""   ];
    push @test_regex, ['(?: a (?i) b | c (?-i) | p ) d', 'x', "trailing mode-switch"   ];
    push @test_regex, ['(?: a (?i) b | c ) d', 'x', ""   ];
    push @test_regex, ['(?: a (?i) b | c (?-i) w) d', 'x', ""   ];
    push @test_regex, ['    a (?i) b | c (?-i) w  d', 'x', ""   ];
    push @test_regex, ['    a (?i) b | c (?-i) w  (?i) d', 'x', ""   ];
    push @test_regex, ['\W{4} (?: a (?i) b | c ) d', 'x', ""   ];
    push @test_regex, ['ab (?i) cd | ef', 'x', ""   ];
    push @test_regex, ['   (?i) cd | ef [gh]', 'x', ""   ];
    push @test_regex, ['ab (?i) cd (?-i) ef', 'x', ""   ];
    push @test_regex, ['ab (?i) (cd) q (?-i) ef', 'x', ""   ];
    push @test_regex, ['ab (?i) (cd) (?-is: p . r) q (?-i) ef', 'x', ""   ];
 
    push @test_regex, ['(\d){4}h', '-x', "four\n    capture digit\nh"   ];
    push @test_regex, ['(\d{4})h', '-x', "capture four digit\nh"   ];
    push @test_regex, ['\d+', '-x', 'one or more digits'   ];
    push @test_regex, ["[\x14\cG ]", '-x', 'literal x14, ctl-G, space'   ];
    push @test_regex, ['[\x14\cG ]', '-x', ' x14, ctl-G, space char class'   ];
    push @test_regex, ["[\cA\cB\cC\cD\cE\cF\cG\cH\cI\cJ]", '-x', 'literal ctl-a thru ctl-j'   ];
    push @test_regex, ['[\cA\cB\cC\cD\cE\cF\cG\cH\cI\cJ]', '-x', 'ctl-a thru ctl-j'   ];    
    push @test_regex, ["[\cK\cL\cM\cN\cO\cP\cQ\cR\cS\cT\cU\cV]", '-x', 'literal ctl-K thru ctl-V'   ];
    push @test_regex, ['[\cK\cL\cM\cN\cO\cP\cQ\cR\cS\cT\cU\cV]', '-x', 'ctl-K thru ctl-V'   ];
    push @test_regex, ["[\cW\cX\cY\cZ]", '-x', 'ctl-W thru ctl-Z'   ];
    push @test_regex, ['[\cW\cX\cY\cZ]', '-x', 'literal ctl-W thru ctl-Z'   ];
    push @test_regex, ["[\\cA\\cB\\cC\\cD\\cE\\cF\\cG\\cH\\cI\\cJ]", '-x', 'ctl-a thru ctl-j'   ];
    push @test_regex, ["[\\cK\\cL\\cM\\cN\\cO\\cP\\cQ\\cR\\cS\\cT\\cU\\cV]", '-x', 'ctl-K thru ctl-V'   ];
    push @test_regex, ["[\\cW\\cX\\cY\\cZ]", '-x', 'ctl-W thru ctl-Z'   ];
    push @test_regex, ["\n?  \a", '-x', 'Embedded newline and alarm character'];
    push @test_regex, ["   \t\t  \n?\a\x12", '-x', 'Embedded tabs, newline, hex-12'];
    
    
    push @test_regex, ['[\d\s]+'];
    push @test_regex, [q<21>, '-x'];

    push @test_regex, ['\G \? ( .* ) '];
    push @test_regex, ['\( ( (?: [a-zA-Z] | [ivx]{1,3} | \d\d? ) ) \) \s+(.*)'];
    push @test_regex, ['name="p_flow_id" value="([^"]*)"', '-x'];
    push @test_regex, ['p_flow_id" value="(.*?)"', '-x'];
    push @test_regex, [' \R \D [\R] '];
    push @test_regex, [' \b [\b] \B [\B] '];
    push @test_regex, ['([012]?\d):([0-5]\d)(?::([0-5]\d))?(?i:\s(am|pm))?'];
    
    push @test_regex, [q/<A[^>]+?HREF\s*=\s*["']?([^'" >]+?)['"]?\s*>/, '-x'];
    push @test_regex, [q/<A[^>]+?HREF\s*=\s*(["']?)([^'" >]+?)\1?\s*>/, '-x'];
    
    push @test_regex, [q/^0?(\d*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)/ ];
    push @test_regex, ['[a-g]{1,2}+' ];
    push @test_regex, ['[a-g]*+'     ];
    push @test_regex, ['[a-g]++'     ];
    push @test_regex, ['[a-g]?+'     ];
    
    push @test_regex, ['[a-g]*?'   ];
    push @test_regex, ['[a-g]+?'   ];
    push @test_regex, ['[a-g]??'   ];
    
    
    push @test_regex, [q<20>, '-x'];
    
    push @test_regex, [q<0>, '-x'];
    push @test_regex, [q<^(?:21|19)>, '-x'];
    push @test_regex, [q<^(?:20|19)>, '-x'];
    push @test_regex, [q<^(?:19|20)>, '-x'];
    push @test_regex, [q<^(?:0)>, '-x'];
    push @test_regex, [q<^0>, '-x'];
    push @test_regex, [q<^(?:19|20)\d{2}-\d{2}-\d{2}(?:$|[ ]+\#)>, '-x'];
    ###                   hex-00 ???   # or '#' as literal ???
    push @test_regex, [q<^[012]?\d:[0-5]\d(?:[0-5]\d)?(?:\s(?:AM|am|PM|pm))?(?:$|[ ]+\#)>, '-x'];
    push @test_regex, [q<\G(?:(?:[+-]?)(?:[0123456789]+))>, 'gc-x'];
    push @test_regex, [q<(?:(?:[+-]?)(?:[0123456789]+))>, '-x'];
    push @test_regex, [q<(?:(?:[-+]?)(?:[0123456789]+))>, '-x'];
    push @test_regex, [q<(?i:J[.]?\s+A[.]?\s+Perl-Hacker)>, '-x'];
    push @test_regex, [q<http://(?:(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|(?:(?:[a-z]|[A-Z])|[0-9])(?:(?:(?:[a-z]|[A-Z])|[0-9])|-)*(?:(?:[a-z]|[A-Z])|[0-9]))\.)*(?:(?:[a-z]|[A-Z])|(?:[a-z]|[A-Z])(?:(?:(?:[a-z]|[A-Z])|[0-9])|-)*(?:(?:[a-z]|[A-Z])|[0-9]))\.?|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(?::[0-9]*)?(?:/(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*(?:;(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*)*(?:/(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*(?:;(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*)*)*(?:\\?(?:[;/?:@&=+$,]|(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f]))*)?)?>, '-x'];
    push @test_regex, [q<http://(?::?[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.[a-zA-Z]*(?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.?|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(?::[0-9]*)?(?:/(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*(?:;(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*)*(?:/(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*(?:;(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*)*)*(?:\\?(?:(?:[;/?:@&=+$,a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f]))*)?)?>, '-x'];
    

    push @test_regex, ['(.)\g1', '-x'];
    push @test_regex, ['(.)\1', '-x'];
    push @test_regex, ['(.)\g{-1}', '-x'];
    
    push @test_regex, ['\b', '-x'];
    push @test_regex, ['\B', '-x'];
    
    push @test_regex, ['[a-g]'   ];
    push @test_regex, ['[a-g]*'   ];
    push @test_regex, ['[a-g]+'   ];
    push @test_regex, ['[a-g]?'   ];
    
    
    push @test_regex, ['[a-zA-Z0-9\x02-\x10]'   ];
    push @test_regex, ['[a-q ]', '-x'];
    push @test_regex, ['[\ca-\cq ]', '-x'];
    push @test_regex, ['[a\-g]*'   ];
    push @test_regex, ['[pa-gk]*'    ];
    push @test_regex, ['[\\x20 ]\?'   ];
    push @test_regex, ['[\\x34\\cG ]\?'   ];
    
    push @test_regex, ['[abc]\?'   ];
    push @test_regex, ['[abc]\?*'  ];
    push @test_regex, ['[]]?'      ];
    push @test_regex, ['[\\]]?'    ];
    push @test_regex, [']?'        ];
    push @test_regex, ['\\]?'      ];
    push @test_regex, ['[]X]?'     ];
    push @test_regex, ['[[]?'      ];
    push @test_regex, ['[a-g]+'    ];
    push @test_regex, ['X++Y', '-x'];
    push @test_regex, ['X?+Y', '-x'];
    push @test_regex, ['X*+Y', '-x'];
    push @test_regex, ['X{3,4}+', '-x'];
    push @test_regex, ['X{3,4}?', '-x'];
    push @test_regex, ['X{3,4}', '-x'];
    push @test_regex, ['\p{Ll}', '-x'];
    push @test_regex, ['<tr[^<]*><td>([^<]*)<\/td><td[^<]*>([^<]*)<\/td><td>[^<]*<\/td><td>([^<]*)<\/td><td>([^<]*)<\/td><td[^<]*>([^<]*)<\/td><\/tr>', '-x'];
    push @test_regex, ['[\D\S\W]+', '-x', 'nonsensical regex: multiple negated'];  
    push @test_regex, ['[\D\S\W]', '-x', 'nonsensical regex: multiple negated'];
    push @test_regex, ["[^ ]", '-x'];

    push @test_regex, ['\\\\w?  \\\\d'];
    
    push @test_regex, ['\n?\x12', '-x'];
    push @test_regex, ['(cat) (mouse)', '-x'];
    push @test_regex, ['cat & mouse', '-x'];
    push @test_regex, ['\w?  \d{3}'];
    push @test_regex, ['\w?  \d{4,}'];
    push @test_regex, ['\w?  \d{5,6}'];
    push @test_regex, ['\w?  \d'];
    push @test_regex, ['\\w?  \d'];
    push @test_regex, ['\w?  \\d'];
    push @test_regex, ['\\w?  \\d'];
    push @test_regex, ['\w?  \d'];
    push @test_regex, ['\\w?  \d'];
    push @test_regex, ['\w?  \\d'];
    push @test_regex, ['\\n?  \\a'];
    push @test_regex, ['\n?  \a'];
    push @test_regex, ['\\n?  \a'];
    push @test_regex, ['\n?  \\a'];
    push @test_regex, ['^cat.dog$', 'ms'];
    push @test_regex, ["t''\"dog", ''];
    push @test_regex, ['cat""""dog'];
    push @test_regex, ["cat''''dog"];
    push @test_regex, ['cat["\']dog'];
    push @test_regex, ['cat.dog'];
    push @test_regex, ['cat.dog', 's'];
    push @test_regex, ['cat.dog', 's'];
    push @test_regex, ['^cat.dog$', 's'];
    push @test_regex, ['^cat.dog$', ''];
    push @test_regex, ['^cat.dog$', 's'];
    push @test_regex, ['^cat.dog$', 'm'];
    push @test_regex, ['^cat.dog$', 'ms'];
    push @test_regex, ['([^ ]+) +([^ ]+) +([^"]+)" +(\d+) +([^ ]+) +(\d+) +"([^"]+)" +"[^"]+"(?: +(.*))?', '-x'];
    push @test_regex, ['               cd      (?i: (?:  ss                     ) uu (?: vv | [wx] )){5,}[34]'];
    push @test_regex, ['ab[12\\w]?  |  cd\dee* (?i: (?:  ss | (?<gmt> [g-m]+ tt)) uu (?: vv | [wx] )){5,}[34]'];
    push @test_regex, ['ab[12\\w]?  |  cd\dee* (?i:                               uu (?: vv | [wx] )){5,}[34]'];
    push @test_regex, ['ab[12\\w]?  |  cd\dee* (?i:                               uu (?: vv | [wx] )){5,}[34]'];
    push @test_regex, ['(?: aa\d | bb\w ) cc (?: dd\D | ee | ff\d ) (?: gg | hh | ii )'];
    push @test_regex, ['(?: aa \d | bb \w ) cc (?: dd \D | ee | ff \d ) (?: gg | hh | ii )'];
    push @test_regex, ['^(?:([^,]+),)?((?:\d+\.){3}\d+)[^\[]+\[([^\]]+)\][^"]+"([^ ]+) +([^ ]+) +([^"]+)" +(\d+) +([^ ]+) +(\d+) +"([^"]+)" +"[^"]+"(?: +(.*))?', '-x'];
    
    
    my $rjl_1 = '^--\sappl\s+=\s+(\S*)                                       # application
            \s+host\s+\=\s(\S*)                                         # host
            \s+user\s+\=\s+(\S*)\/                                      # user
            \s+pid\s+\=\s+(\d+)                                         # pid
            \s+elapsed\s+\=\s+(\d+\.\d+)\s+seconds                      # elapsed
            \s+rows\s+\=\s+(\d+)                                        # rows
            \s+tran\s+\=\s+(\d+)                                        # tran
            \s+server\s+=\s+(\S+)                                       # server
            \s+database\s+\=\s+(\S*)                                    # database
            \s+client\s+\=\s+(\d+\.\d+\.\d+\.\d+)\/\d+                  # client IP
            \s+(\w+)                                                    # operation type (CONNECT TRAN etc)
            \s+\w\w\w\s+\w\w\w\s+\d+\s+(\d+\:\d+\:\d+\.\d+)             # start time
            \s+\d+\s+\-\s+\w\w\w\s+(\w\w\w)                             # end month
            \s+(\d+)                                                    # end day of month
            \s+(\d+\:\d+\:\d+\.\d+)                                     # end time
            \s+(\d+)                                                    # end year
            \s+.*send\s+\=\s+(\d+\.\d+)\s+sec                           # send time
            \s+receive\s+\=\s+(\d+\.\d+)\s+sec                          # receive time
            \s+send_packets\s+\=\s+(\d+)                                # send packets
            \s+receive_packets\s+\=\s+(\d+)                             # receive packets
            \s+bytes_received\s+\=\s+(-*\d+)                            # bytes received (sometimes negative!)
            \s+errors\s+\=\s+(\d+)                                      # errors
            \s+((sid)\s+=\s+(\d+)|                                      # sid (Oracle only) or
                (\S+))                                                  # sql type (prepared-sql, cursor, etc)
                ';
=format
# Manual conversion of regexp above to ire.
# 
# Space in string means whitespaces
# Mostly functionally equivalent, but have added named captures which removes
#   the need for end-of-line comments
space-means-wss
    sos then '--' then ws
    'appl = '              then as application opt non-wss
    ' host =' then ws      then as host        opt non-wss
    ' user = '             then as user        opt non-wss
    '/ pid = '             then as pid         digits
    ' elapsed = '          then as elapsed
                                               digits then . then digits
    ' seconds rows = '     then as rows        digits
    ' tran = '             then as tran        digits 
    ' server = '           then as server      non-wss 
    ' database = '         then as database    opt non-wss
    ' client = '           then as client_IP 
                                               digits then . then digits . then digits  then . then digits 
    / then digits then wss
    then                        as operation   word-chars 
    wss then three word-chars then wss then three word-chars then wss then digits then wss
    then                        as start-time                            
                                               digits then : then digits then : digits then . then digits 
    wss then digits then wss then hyphen then wss then three word-chars then wss
    then                        as end-month   three word-chars   then wss
    then                        as end-day     digits             then wss
    then                        as end-time
                                               digits then : then digits then : digits then . digits
    wss                    then as end-year    digits             then wss then opt non-newlines
    'send  = '             then as send-time
                                             digits then . then digits 
    ' sec receive = '      then as receive
                                             digits then . then digits 
    ' sec send_packets = ' then as send-pkts digits 
    ' receive_packets = '  then as rcv_pkts  digits
    ' bytes_received = '   then as bytes-rcv 
                                             opt hyphens then digits
    ' errors = '           then as errors    digits               then wss
    either 
                                as sid-text  'sid' 
                                ' = '
                                as sid-num   digits 
    or 
                                as sql-type  non-wss 
=cut

    my $rjl_2 = '
            # Terse regexp version with additional punctuation
            # For this example with consistent layout and very little nesting,
            #  it is debatable whether the wre version has a significant advantage
            #  apart from the named captures
            ^ --
            \s  appl     \s+ = \s+ (\S*)                                 # application
            \s+ host     \s+ = \s  (\S*)                                 # host
            \s+ user     \s+ = \s+ (\S*) [/]                             # user
            \s+ pid      \s+ = \s+ (\d+)                                 # pid
            \s+ elapsed  \s+ = \s+ (\d+\.\d+) \s+ seconds                # elapsed
            \s+ rows     \s+ = \s+ (\d+)                                 # rows
            \s+ tran     \s+ = \s+ (\d+)                                 # tran
            \s+ server   \s+ = \s+ (\S+)                                 # server
            \s+ database \s+ = \s+ (\S*)                                 # database
            \s+ client   \s+ = \s+ (\d+ [.] \d+ [.] \d+ [.] \d+) [/] \d+ # client IP
            \s+ (\w+)                                                    # operation type (CONNECT TRAN etc)
            \s+ \w\w\w  \s+ \w\w\w \s+ \d+ \s+ (\d+ : \d+ : \d+ [.] \d+) # start time
            \s+ \d+ \s+ - \s+ \w\w\w \s+ (\w\w\w)                        # end month
            \s+ (\d+)                                                    # end day of month
            \s+ (\d+ : \d+ : \d+ [.] \d+)                                # end time
            \s+ (\d+)                                                    # end year
            \s+ .* send         \s+ = \s+ (\d+ [.] \d+) \s+ sec          # send time
            \s+ receive         \s+ = \s+ (\d+ [.] \d+) \s+ sec          # receive time
            \s+ send_packets    \s+ = \s+ (\d+)                          # send packets
            \s+ receive_packets \s+ = \s+ (\d+)                          # receive packets
            \s+ bytes_received  \s+ = \s+ ([-]* \d+)                     # bytes received (sometimes negative!)
            \s+ errors          \s+ = \s+ (\d+)                          # errors
            \s+ ((sid) \s+ = \s+ (\d+) |                                 # sid (Oracle only) or
                 (\S+))                                                  # sql type (prepared-sql, cursor, etc)
                ';
    my $rjl_3 = '
            # Terse regexp version with additional punctuation, and native named captures
            ^ --
            \s  appl     \s+ = \s+ (?<application> \S*                         ) 
            \s+ host     \s+ = \s  (?<host>        \S*                         )
            \s+ user     \s+ = \s+ (?<user>        \S*                         ) [/] 
            \s+ pid      \s+ = \s+ (?<pid>         \d+                         ) 
            \s+ elapsed  \s+ = \s+ (?<elapsed>     \d+ [.] \d+                 ) \s+ seconds 
            \s+ rows     \s+ = \s+ (?<rows>        \d+                         )
            \s+ tran     \s+ = \s+ (?<tran>        \d+                         )
            \s+ server   \s+ = \s+ (?<server>      \S+                         )
            \s+ database \s+ = \s+ (?<database>    \S*                         ) 
            \s+ client   \s+ = \s+ (?<client_IP>   \d+ [.] \d+ [.] \d+ [.] \d+ ) [/] \d+ 
            \s+                    (?<operation>   \w+                         )
            \s+ \w\w\w  \s+ \w\w\w \s+ \d+ \s+
                                   (?<start_time>  \d+ : \d+ : \d+ [.] \d+     )
            \s+ \d+ \s+ [-] \s+ \w\w\w \s+
                                   (?<end_month>   \w\w\w                      )
            \s+                    (?<end_day>     \d+                         )
            \s+                    (?<end_time>    \d+ : \d+ : \d+ [.] \d+     )
            \s+                    (?<end_year>    \d+                         )
            \s+ .* send             \s+ = \s+ (?<send_time>  \d+ [.] \d+         ) \s+ sec
            \s+ receive             \s+ = \s+ (?<recv_time>  \d+ [.] \d+         ) \s+ sec
            \s+ send_packets        \s+ = \s+ (?<send_pkts>  \d+                 )
            \s+ receive_packets     \s+ = \s+ (?<recv_pkts>  \d+                 )
            \s+ bytes_received      \s+ = \s+ (?<recv_bytes> [-]* \d+            )
            \s+ errors              \s+ = \s+ (?<errors>     \d+                 )
            \s+ (?:(?<sid_text>sid) \s+ = \s+ (?<sid_num>    \d+ )    # sid (Oracle only)
                                     |        (?<sql_type>   \S+ ) )                                                  # sql type (prepared-sql, cursor, etc)
                ';
    
    push @test_regex, [$rjl_1, 'x'];
    push @test_regex, [$rjl_2, 'x'];
    push @test_regex, [$rjl_3, 'x'];

    return;  ### ------------->>>>>>>>>>
    
    # Not executed


}

{ my $test_number;            
    sub test_gen {
        my ($terse_regex, $mode_flags, $notes) = @_;
        
        $test_number = 1 if ! defined $test_number;
        if ( ! defined $mode_flags) {
            $mode_flags = 'x';      # Default to /x mode for tests
        }
        my $x_mode_on = $mode_flags =~ / ^ [^-]* x /x;

        my $wre = tre_to_wre($terse_regex, $mode_flags);
        
        print     "        - name: Test $test_number\n";
        $terse_regex =~ s/\n/\n              /g;
        $terse_regex =~  s/^/\n              /g;        
        print     "          terse-in: |$terse_regex\n";
        print     "          terse-options: $mode_flags\n";
        if ($notes) {
            $notes =~   s/\n/\n              /g;
            $notes =~    s/^/\n              /g;
            print "          notes: |$notes\n";
        }

        $wre =~         s/\n/\n              /g;
        $wre =~          s/^/\n              /g;
        print     "          wordy-out: |$wre\n";
        $test_number++;
    }
}


1;  # Module must end like this
