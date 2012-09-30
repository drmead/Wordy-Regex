#!/usr/bin/perl -w
use strict;
use warnings;
package RegExp::Tre2Wre;
require Exporter;
our (@ISA) = ("Exporter");
our (@EXPORT) = qw(tre_to_wre);

use YAML::XS;   ## Not needed for this program - this is a convenience for debugging.


=format


Tre2Wre.pm - Convert a Terse Regular Expression to a Wordy Regular Expression



Tokenise:

    Escaped sequence
        Vary considerably between languages
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
example, \\\\ means a single backslash if supplied in a Javascript string.

 
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
            # or a nested parenthesised sub-expression
            -
                type:   char_class, string, matcher, nested
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
my $MODE_D  = 4096;
my $MODE_ALL = ($MODE_D * 2 ) -1;

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
            ## appearing in an indented regex as naked characters - mostly because they
            ## are meta-characters in conventional regexes.
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
    
    my $capture_count = 0;
    
    my %escapes = (a => "\a",   # Alarm
                   e => "\e",   # Escape (the character ESC, not backslash)
                   f => "\f",   # Form feed
                   n => "\n",   # Newline, whatever that is on this platform
                   r => "\r",   # Carriage return
                   t => "\t"    # Horizontal tab
                  );
    my %groups  = (d => 'digit',           D => 'non-digit',
                                           R => 'generic-newline',
                   s => 'whitespace',      S => 'non-whitespace',
                   w => 'word-char',       W => 'non-word-char',
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
       pos($re) = 0;
       $capture_count = 0;
    }
    # -------------------------------
    sub escaped_common {
        # Handles the characters that follow a backslash, that are handled
        # the same inside or outside of a character class
        
        ## Perl interpolation using $ or @ not implemented
        ## Should be optional even if a Perl regex is being processed, because
        ## the regex being fed into Tre2Wre might already have been interpolated
        ## rather than being raw source.
        my ($char, $octal_digits, $group_char);
        if ($re =~ / \G ( [aefnrt] ) /xgc) {
            # One of the simple escape characters
            $char = $1;
            return ( 'char', $escapes{$char} );
        } elsif ( $re =~ / \G ( [wWdDsS] ) /xgc ) {
            # A group: word (or not), digit (or not), whitespace (or not)
            $group_char = $1;
            return ( 'group', $groups{$group_char} );
        } elsif ( $re =~ / \G ( [0-7]{2,3} ) /xgc) {
            $octal_digits = $1;
            # two or three octal digits
            ## We assume that \10 is octal, but it would be back-reference 10
            ## if more than 10 capture groups already seen
            return ( 'char', 'octal' . $octal_digits );
        } elsif ( $re =~ / \G  x ( [0-9a-fA-F]{1,2} ) /xgc) {
            my $hex_digits = $1;
            # \x and one or two hex digits
            ## Single hex digit is deprecated in Perl
            $hex_digits = '0' . $hex_digits if length($hex_digits) == 1;
            return ( 'char', 'hex-' . $hex_digits );
        } elsif ( $re =~ / \G  x [{] ( [0-9a-fA-F]+ ) [}] /xgc) {
            my $hex_digits = $1;
            # \x and any number of hex digits, within braces
            return ( 'char', 'hex-' . $hex_digits );
        } elsif ( $re =~ / \G  c ( [a-zA-Z] ) /xgc) {
            # \c and a letter
            my $control_letter = uc($1);
            return ( 'char', 'control-' . $control_letter );
        } elsif ( $re =~ / \G ( [\\] ) /xgc ) {
            # Any other that is a meta-character within and outside char class
            # Literal backslash... any others?
            $char = $1;
            return ('char', $char);
        } else {
            # Not one of the escape sequences recognised by this routine
            return ( 'not_common', '');
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
        
        # \k{name}, \k<name> or \k'name' name must not begin with a number, nor contain hyphens
        
        if ( $re =~ / \G ( [R] ) /xgc ) {

            # generic-newline
            my $group_char = 'R';
            return ( 'group', $groups{$group_char} );
        }
        $re =~ / \G ( . ) /xsgc;
        my $char = $1;
        # Any other character - treat as the literal character
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
        
        my ($free_spacing, $in_class) = @_;
        my ($token_type, $token, $tk_comment, $tk_sub_type,
            $tk_arg_a, $tk_arg_b) 
               = ('', '', '', '', '', '');
        my ($char);
        
        # Skip leading white space 
        if ($free_spacing && ! $in_class) {
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
            my $escaped = $1;
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
        } elsif ( ! $in_class && $re =~ / \G [(] [?] ( [-imsx]+ ) [)] /xgc ) {
            # A non-spanning mode-modifier  (?imsx-imsx)
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
                } elsif ( $re =~ / \G ([-imsx]+ ) : /xgc ) {
                    #   Mode-modified span (?imsx-imsx: ... )
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
                } elsif ( $re =~ / \G < ( \w+ ) >  /xgc ) {
                    #   Named capture (?< name > ... ) ### or variants
                    $tk_arg_a = $1;
                    $tk_sub_type = $TKST_CAPTURE_NAMED;
                    $capture_count++;
                } elsif ( $re =~ / \G >            /xgc ) {
                    #   Atomic grouping (?> ... )
                    $tk_sub_type = $TKST_ATOMIC;
                } elsif ( $re =~ / \G \(( [^)]+ )\)/xgc ) {
                    #   Conditional (?( condition ) if | else )
                    $tk_sub_type = $TKST_CONDITION;
                    $tk_arg_a = $1;
                } else {
                    _error("Unrecognised option after (?");
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
      - an indicator which is false if all modes allowed, true to only allow
        those that can be used in embedded mode-changers.
    Returns the vector, with bits cleared for any mode that follows a dash and
    set for any mode present that does not. Other mode bits are unchanged.
    Calls error if unrecognised mode flag supplied.

    Perl 5.10 modes:
        m  Multiline mode - ^ and $ match internal lines
        s  match as a Single line - . matches \n
        i  case-Insensitive
        x  eXtended legibility - free whitespace and comments
        p  Preserve a copy of the matched string - ${^PREMATCH}, ${^MATCH},
           ${^POSTMATCH} will be defined
        o  compile pattern Once
        g  Global - all occurrences You can use \G within regex for end-of-previous-match
        c  don't reset pos on failed matches when using /g
        a  restrict \d, \s, \w and [:posix:] to match ASCII only
        aa (two a's) also /i matches exclude ASCII/non-ASCII
        l  match according to current locale
        u  match according to Unicode rules
        d  match according to native rules unless something indicates Unicode
    
    Assuming that doubled letter implies single letter mode:
        a   turns a on, but doesn't turn aa on
        -a  turns both a and aa off        
        aa  turns a on as well as aa
        -aa turns aa off, but does not turn a off [## NEED TO VERIFY THIS]

    
    
=cut
    my ($previous_mode_bits, $mode_flags_text, $embedded_only) = @_;
    my $hyphen_seen   = 0;
    my $positive_bits = 0;
   
    my $embedded_modes_ref = {
        x => $MODE_X, s => $MODE_S, m => $MODE_M, i => $MODE_I,
        };
    my $overall_modes_ref = {
        x => $MODE_X, s  => $MODE_S,  m => $MODE_M,  i => $MODE_I,
        p => $MODE_P, o  => $MODE_O,  g => $MODE_G,  c => $MODE_C,
        a => $MODE_A, aa => $MODE_AA, l => $MODE_L,  d => $MODE_D,
        };
    my $can_be_doubled = $MODE_A;

    my $allowed_modes_ref = $embedded_only ? $embedded_modes_ref
                                           : $overall_modes_ref;
    my $check_bits = 0;
    for my $mode_char (split ('',$mode_flags_text)) {
        if ($mode_char eq '-') {
            $hyphen_seen = 1;
            $positive_bits = $check_bits;
            $check_bits = 0;
        } else {
            my $mode_bit = $allowed_modes_ref->{$mode_char};
            if (defined $mode_bit) {
                if ($check_bits & $mode_bit) {
                    # We have already seen this bit
                    if ($mode_bit & $can_be_doubled) {
                        $check_bits |= ($mode_bit << 2);
                        $check_bits ^= $mode_bit if $hyphen_seen; # aa doesn't turn a off
                    } else {
                        _error("Mode: $mode_char used more than once")
                    }
                } else {
                    $check_bits |= $mode_bit;
                }
            } else {
                _error("Unrecognised mode: $mode_char in $mode_flags_text");
            }
        }
    }
    if ( ! $hyphen_seen) {
        return ($previous_mode_bits | $check_bits);
    }        
    my $negative_mask = $MODE_ALL ^ $check_bits;
    return ($previous_mode_bits & $negative_mask);
}

sub tre_to_wre {
    my ($old_regex, $mode_flags) = @_;
    $mode_flags = $mode_flags || '';
    my $default_modes_bits = 0;   # Default no modes on
    my $updated_mode_bits = apply_modes($default_modes_bits, $mode_flags, 0);
    $generated_wre = '';
    $regex_struct_ref = {type=> 'root', child => []};
    my $root_ref = $regex_struct_ref->{child};    
    init_tokeniser($old_regex);
    analyse_regex($root_ref, $updated_mode_bits);
    combine_strings($regex_struct_ref);
    analyse_alts($regex_struct_ref);
    generate_reword($regex_struct_ref, 0);
    return $generated_wre;
}

sub main {
    load_tests();
    for my $regex_ref (@test_regex) {
        test_gen (@{$regex_ref});
    }
    my $done_gen = 1;
}

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
    # Passed a number
    # Returns the word equivalent
    my ($number) = @_;
    my @number_word = ('zero', 'one', 'two', 'three', 'four', 'five', 'six',
                       'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve');
    if ($number < 0 || $number > 12) {
        return $number;
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
        if ($min == 0) {
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
            $text = number_words($min) . ' ';
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
{ # naked block for generate_reword and friends

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
        $line = number_words(length $multiple_spaces) . ' spaces';
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
        # Translate mode info into words
        my $modes = $entry_ref->{options};
        if ($modes =~ / .* [-] .* [i] /x) {
            return 'case-sensitive ';
        } elsif ($modes =~ /  [^-]* [i] /x) {
            return 'case-insensitive ';
        }
    } elsif ($sub_type eq $TKST_CONDITION) {
        _error("Unimplemented: condition within regex")
    } elsif (   $sub_type eq $TKST_LOOK_AHEAD
             || $sub_type eq $TKST_NEG_LOOK_AHEAD
             || $sub_type eq $TKST_LOOK_BEHIND
             || $sub_type eq $TKST_NEG_LOOK_BEHIND
             || $sub_type eq $TKST_ATOMIC
             ) {
        # look-ahead, look-behind , atomic
         return $sub_type . $sp;
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

    # mode-switch nothing generated - should not be passed here
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
            
            $line .= 'not ';
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
    sub generate_reword {
        
        # Generates an indented regular expression
        my ($hash_ref, $indent_level, $modes_ref) = @_;

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
        # when we exit - so any additional indent to cope with a
        # non-spanning mode modifier will 
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
        for my $alt_index (0 .. ($number_of_alternatives - 1) ) {
            # For each alternative
            my $alt_ref = $child_ref->[$alt_index];
            my $number_of_entries = scalar @{$alt_ref};
            # We need to know whether there will be multiple lines
            # If there is only one non-removed entry and it is not type
            # nested, we can put everything on one line
            # So we count the number of non-removed entries for this alternative
            my $number_of_simple_entries = 0;
            my $number_of_complex_entries = 0;
            my $all_on_one_line = 0;
            for my $entry_ref ( @{$alt_ref} ){
                # For each entry within this alternative
                if      ( $entry_ref->{type} eq 'nested'  ) {
                    $number_of_complex_entries++;
                } elsif ( $entry_ref->{type} eq 'removed' ) {
                    # Ignore removed entries                    
                } else {
                    # Anything else, as long as it doesn't have quantifiers
                    exists $entry_ref->{quant} ? $number_of_complex_entries++ 
                                               : $number_of_simple_entries++;
                }
            }
            if (   $number_of_simple_entries  == 1
                && $number_of_complex_entries == 0) {
                $all_on_one_line = 1;
            }
            ############### alt > 1 TRUE ### all_on_one_line TRUE ########
            if ($number_of_alternatives > 1 && $all_on_one_line) {
                $line = ($alt_index == 0) ? 'either ' : 'or ';
                for my $entry_ref ( @{$alt_ref} ){
                    # For each entry within this alternative
                    generate_stuff_from_entry($entry_ref) if $entry_ref->{type} ne 'removed';
                }
                emit_line($current_indent);
            ################ alt > 1 FALSE ### all_on_one_line TRUE ########
            } elsif ($number_of_alternatives <= 1 && $all_on_one_line) {
                for my $entry_ref ( @{$alt_ref} ){
                    # For each entry within this alternative
                    generate_stuff_from_entry($entry_ref) if $entry_ref->{type} ne 'removed';
                }
                emit_line($current_indent);
            ############### alt > 1 TRUE ### all_on_one_line FALSE ########
            } elsif ($number_of_alternatives > 1 && ! $all_on_one_line) {
                $line = ($alt_index == 0) ? 'either ' : 'or ';
                # This either/or needs a line of its own
                emit_line($current_indent);
                $indent_level++;    # Move the entries over from either/or
                $current_indent = $indent_level;

                for my $entry_ref ( @{$alt_ref} ){
                    # For each entry within this alternative
                    if ($entry_ref->{type} eq 'nested' ) {
                        generate_reword($entry_ref, $indent_level);
                    } elsif ( $entry_ref->{type} ne 'removed' ) {
                        generate_stuff_from_entry($entry_ref);
                        emit_line($current_indent);
                    }
                }
                $indent_level--;    # Move back to either/or level
            ############### alt > 1 FALSE ### all_on_one_line FALSE ########
            } elsif ($number_of_alternatives <= 1 && ! $all_on_one_line) {
                if ($line ne '') {
                   # We have a partial line already built, emit it
                   emit_line($current_indent);
                   $current_indent = $indent_level; 
                }
                for my $entry_ref ( @{$alt_ref} ){
                    # For each entry within this alternative
                    if ($entry_ref->{type} eq 'nested' ) {
                        generate_reword($entry_ref, $indent_level);
                    } elsif ( $entry_ref->{type} eq 'removed' ) {
                        # Ignore removed entries                    
                    } else {
                        # Anything else
                        generate_stuff_from_entry($entry_ref);
                        emit_line($current_indent);
                        $current_indent = $indent_level;                        
                    }
                }
            }
            $current_indent = $indent_level;
        }
    }
} # End naked block for generate_reword and friends

    
# Mode-modifiers within Alternations
# ----------------------------------
#
# Just adding an extra level of indent won't work, as the outdent
# to get back for the 'or' will terminate the mode incorrectly.
#
#    (?: a (?:i) b | c ) d
#
#   either
#       a
#       case-insensitive
#           b
#   or  # oops! case-sensitivity should stay off here
#       c
#   d
#
#  Output should be:
#   either
#       a
#       case-insensitive
#           b
#   or
#       case-insensitive
#           c
#   d

# One option is a real hack: a mode-switch that is not indentation
# limited, but is explicitly turned on and off. This might be tolerable
# if non-spanning mode modifiers are rarely used, and even more rarely
# within an alternation.
#
# This mode-switch would not be intended to be written as part of new indented
# regexes: the risk is that if they are commonly seen by people analysing old
# regexes they will just deploy the generated indented regex complete with hack
# and/or be led into bad habits when writing new indented regexes.
#
# I think the problem only applies to a single level of either/or's, and only if
# the mode-modifier is not the first thing in the first alternative.
#
# A short-term option would be to detect the situation and have the analyser
# flag the situation as 'unimplemented'.
#
# A tidier solution would be to generate the mode-changing indent as needed
# immediately for the mode switch, and also create the same indent for
# subsequent alternatives
    
    
    
    #  (?: abc | def | p \d+ q | [xyz] )
    #  'abc' 'def' (p digits q) x y z
    #  'abc' or 'def' or (p then digits then q) or x or y or z

    
   
    #  (?: abc | def | p [\d.]+ q | [xyz] )
    
    
    # The slippery slope: parentheses enclosing sequences
    # 
    #  'abc'    'def'    (p      digits      dots      q)    x    y    z
    #  'abc' or 'def', or p then digits then dots then q, or x or y or z
    
    
    #  'abc' or 'def' or (p then digits then q) or x or y or z
    

# -------------------------------
sub _error {
    my ($text) = @_;
    print "Error: $text\n";
}
# -------------------------------
sub is_combinable_string {
    # Passed a reference to an entry
    # Returns true if the entry is for something that can be combined with
    # other strings to form a quoted string
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
    
    my ($hash_ref) = @_;
    my $child_ref = $hash_ref->{child};
    if ( defined $child_ref ) {
        # There is a child entry
        # For each alternative
        for my $alt_ref ( @{$child_ref} ) {
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
    #       'cat'  or  'dog'  or  p thru t  or  tab  or  digit  # verbose
    #       'cat', 'dog', p thru t, tab or digit                # medium
    #       'cat' 'dog' p-t tab digit                           # terse

    my ($hash_ref) = @_;
    my $child_ref = $hash_ref->{child};
    if ( defined $child_ref ) {
        # There is a child entry
        
        my $number_of_alternatives = scalar @{$child_ref};
        my $number_of_qualifying_alts = 0;
        
        for my $alt_ref ( @{$child_ref} ) {
            # For each alternative, we must have exactly one qualifying entry 
            # and no disqualifying entries for the entire alternative to qualify
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
    my ($tree_ref, $mode_bits) = @_;
    my $alt_ndx  = 0;
    my $part_ndx = 0;
    my $x_mode   = $mode_bits & $MODE_X;
    my $IN_CLASS = 1;
    my $OUTSIDE_CLASS = 0;
    my ($token_type, $token, $tk_comment, $tk_sub_type,
        $tk_arg_a, $tk_arg_b);
    
    $token_type = 'just_starting';
    
    while ($token_type ne 'end_of_regex') {
        ($token_type, $token, $tk_comment, $tk_sub_type, $tk_arg_a, $tk_arg_b)
                   = get_next_token($x_mode, $OUTSIDE_CLASS);
                
        if ($token_type eq 'char') {
            $tree_ref->[$alt_ndx][$part_ndx] = {type  => 'string',
                                                value => $token,
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
                    # Oherwise it means
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
            until ($token_type eq 'right_bracket' && $char_count > 1
                   || $token_type eq 'end_of_regex') {
                if (   $token eq '-'
                    && $token_type ne 'escaped-char'
                    && $char_count > 1) {
                    # A hyphen that might be introducing a range, but not if
                    # it is the first or last character in the range
                    ($token_type, $token) = get_next_token($x_mode, $IN_CLASS);
                    if ($token_type eq 'right_bracket') {
                        # Hyphen was last character in class, add it to list
                        push @{$tree_ref->[$alt_ndx][$part_ndx]{chars}}, '-';
                        last CHAR;
                    } else {
                        my $range_start = @{$tree_ref->[$alt_ndx][$part_ndx]{chars}}[-1];
                        my $range_end = $token;
                        my $range_text = 'range ' . $range_start . ' to ' . $token;
                        if (    $range_start lt $range_end
                             && (  ($range_start =~ / ^ [a-z] $ /x
                                 && $range_start =~ / ^ [a-z] $ /x)
                                || ($range_start =~ / ^ [A-Z] $ /x
                                 && $range_start =~ / ^ [A-Z] $ /x)
                                || ($range_start =~ / ^ [0-9] $ /x
                                 && $range_start =~ / ^ [0-9] $ /x)
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
        } elsif ($token_type eq 'paren_start') {
            # Left parenthesis, possibly plus some other goodies
            $tree_ref->[$alt_ndx][$part_ndx] = {type     => 'nested',
                                                sub_type => $tk_sub_type,
                                                options  => $tk_arg_a,
                                                child    => [ ],
                                                comment => $tk_comment,
                                               };
            my $nested_mode_bits = $mode_bits;
            if ($tk_sub_type eq $TKST_MODE_SPAN) {
                $nested_mode_bits = apply_modes($mode_bits, $tk_arg_a, 1);
            }
            my $reached_end = analyse_regex($tree_ref->[$alt_ndx][$part_ndx]{child},
                                            $nested_mode_bits);
            _error("Unbalanced parentheses: $token") if $reached_end;
            $part_ndx++;
        } elsif ($token_type eq 'paren_end') {
            # Right parenthesis, other goodies such as quantifiers and their
            # modifiers may follow, but not yet parsed
            return 0;
        } elsif ($token_type eq 'quant') {
            # Quantifier - applies to previous part
            if ($part_ndx == 0) {
                _error("quantifier $token has nothing to quantify");
            } else {
                $tree_ref->[$alt_ndx][$part_ndx - 1]{quant}
                    = {min => $tk_arg_a, max => $tk_arg_b, mod => $tk_sub_type};
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
            _error('Unimplemented: mode change');
        } elsif ($token_type eq 'end_of_regex') {
            ## Should we check for incorrect nesting?
            return 1;
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
=format
TO DO:

    Back-references:
        \1  \2 etc. to refer to the 1st, 2nd... capture group
        Perl 5.10 allows
            \g{name} where 'name' is the name of a capture group.
                If more than one capture group has that name, use the leftmost.
            \g{-1}  \g{-2} etc. to refer to the previous, 2nd previous capture group

    Protection and Case-forcing:
        These are mostly used with interpolation, but we might be given a regex
        that has been interpolated already.
        \Q ... \E treats most characters is non-meta
        \U and \L force case until \E
        \u and \l force the case of the next character.
            \u forces titlecase, not upper-case, for Perl versions from ??

\N{name}    named Unicode
\N{U+hex}   Unicode by code point


\px, \Px    Unicode property, where x is single letter
\p{name}
\P{name}    Unicode property, name longer than one character. Thousands of them

    Capture Number Checking.
        Warn if a round-tripped regex will have its capture numbers disturbed.

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
        that has the ire embedded, then that function could be passed the
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
            see it in an ire when we are generating conventional regex.
            
/k          Can't find any more details. khaidoan.wikidot.com/perl-basics
            seems to think it exists as a mode.

\h, \H      Horizontal whitespace, or not
\v, \V      Vertical whitespace, or not

\C          One byte
\X          Unicode extended grapheme cluster (base + any modifying characters)
\N          non-newline (experimental from Perl 5.12). If it is still experimental
            then it's not appropriate to generate this, but we should accept it
            in conventional regex input

\R          matches a generic linebreak, that is, vertical whitespace, plus the
            multi-character sequence "\x0D\x0A".


[[:name:]]  Posix character classes

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

For i, always create a nested level when see a i-mode modifier, and end it when
the outer sub-expression ends or when we find another i-mode modifier. This may
create some unecessary output if the original regex has some unecessary mode
modifiers.
--------------
qr/ abc ( qw (?i) d (?-i) e ) f  /ix;
case-insensitive    
    'abc'
    capture
        'qw'
        case-sensitive
            d
        case-insensitive
            e
    f

Names For String and Line Endings
---------------------------------

The standard meaning of $ is:
    'end of string, or before a string-ending newline'.
Even that is abbreviated, as a common interpretation of 'end of string' might be:
    'the last character in the string':
so the full version is:
    'after the last character in the string or before a string-ending newline'.
But $ can actually match in two places in the same string (even without /m) if
the string ends with a newline: both before and after the string-ending newline.
So should we be saying:
    'after the last character in the string *and* before a string-ending newline'?

That's quite difficult to turn into a pithy keyword, or even a pithy phrase,
especially as we want to be clear that it matches the zero-width place before a
terminal newline rather than matching the newline itself.

One option is to have long, medium, short and abbreviated versions:
 - the long version spells out the meaning in full. This isn't an option that
   people would be expected to write, but it would be acceptable as input - it
   is useful as a documentation/full explanation option
 - the medium version says 'end of string or almost'
 - the short version says 'eos-or-btnl' 
 - the abbreviated version is 'eosx', where the 'x' is intended to distinguish
   it from plain eos meaning end-of-string, and to imply 'extended'
 
Or we could redefine 'end of string' to mean 'end of string or almost', and
use 'absolute end of string' for \z. This helps with indented regexes that have
been converted from old-style regexes, but at the cost of forcing new
hand-written ones to use a clumsier form, and risk that they will be written as
'end of string' when they should have been 'absolute end of string'.

Or use (say) 'string-end' or 'string-end-nl' for 'end of string or almost', so
'end of string' can retain its face value.
 
Or have a 'legacy eos' mode setting, which changes 'end of string' to mean eosx:
if you then want non-legacy end of string you have to say 'absolute end of
string'.

$ is used in a high proportion of regexes, but rarely occurs many times in the
same regex. In an indented regex it will usually end up on a line of its own:
a verbose name for it won't make the regex occupy more lines, although it might
extend the width.
 
In /m mode, $ means 'end of string, or before any newline'. That can turn into
'end of line', with the understanding that the end of the string counts as
ending a line.

One possibility is to special-case regexes that start with ^ and end with $ (and
don't have any alternations active at that stage) as they are quite common, and
have a 'match entire string' command. But that would still need to differentiate
itself from a similar regex that ended with \z - so it might need a modifier so
that you say 'match entire string legacy'.

If 'legacy' only affects eos/eol, then a more descriptive name for it should be
possible. Given the design philosophy of making ire's readable by someone who
knows only the sequence/alternation rules.


The intention for hand-written indented regexes is that they will use plain
'end of line' or 'end of string', unless they really want a fancier version.

==============================================================================

=head1 AUTHOR

Derek Mead

=head1 COPYRIGHT

Copyright (c) 2011, 2012 Derek Mead

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut

# In-line tests. These will get moved out to separate .t files eventually,
# but held here during initial testing.
#
# Probably keep the ability to test the module by running it as a program,
# to provide an easy way of doing ad hoc tests, even when the main tests
# have all moved into .t files

sub load_tests {

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
    
    push @test_regex, [q/<A[^>]+?HREF\s*=\s*["']?([^'" >]+?)['"]?\s*>/, '-x'];
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
    # Needs 'then' to be implemented
    # Needs redundant 'then' at start of line to be ignored
    #   (but it is used only for cosmetic reasons)
    # Mostly functionally equivalent, but have added named captures which removes
    #   the need for end-of-line comments
    
    sos then '--' then ws-ch 
    'appl = '              then as application opt non-wss
    ' host =' then ws-ch   then as host        opt non-wss
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
    wss                 then as end-year    digits             then wss then opt non-newlines
    'send  = '             then as send-time
                                             digits then . then digits 
    ' sec receive = '
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
    push @test_regex, ["[\x14\cG ]", '-x', 'literal x14, ctl-G'   ];
    push @test_regex, ["[\cA\cB\cC\cD\cE\cF\cG\cH\cI\cJ]", '-x', 'ctl-a thru ctl-j'   ];
    push @test_regex, ["[\cK\cL\cM\cN\cO\cP\cQ\cR\cS\cT\cU\cV]", '-x', 'ctl-K thru ctl-V'   ];
    push @test_regex, ["[\cW\cX\cY\cZ]", '-x', 'ctl-W thru ctl-Z'   ];
    push @test_regex, ["[\\cA\\cB\\cC\\cD\\cE\\cF\\cG\\cH\\cI\\cJ]", '-x', 'ctl-a thru ctl-j'   ];
    push @test_regex, ["[\\cK\\cL\\cM\\cN\\cO\\cP\\cQ\\cR\\cS\\cT\\cU\\cV]", '-x', 'ctl-K thru ctl-V'   ];
    push @test_regex, ["[\\cW\\cX\\cY\\cZ]", '-x', 'ctl-W thru ctl-Z'   ];
    push @test_regex, ["\n?  \a", '-x', 'Embedded newline and alarm character'];
    push @test_regex, ["   \t\t  \n?\a\x12", '-x', 'Embedded tabs, newline, hex-12'];
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
        print     "          terse: |$terse_regex\n";
        print     "          terse-options: $mode_flags\n";
        if ($notes) {
            $notes =~   s/\n/\n              /g;
            $notes =~    s/^/\n              /g;
            print "          notes: |$notes\n";
        }

        $wre =~         s/\n/\n              /g;
        $wre =~          s/^/\n              /g;
        print     "          wordy: |$wre\n";
        $test_number++;
    }
}


1;  # Module must end like this
