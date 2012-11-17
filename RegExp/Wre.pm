#!/usr/bin/perl -w
    use 5.8.0;
    use strict;
    use warnings;
    package RegExp::Wre;
    require Exporter;
    our (@ISA) = ("Exporter");
    our (@EXPORT_OK) = qw(wre wret flag_value _wre_to_tre);
    use overload
       'qr'       =>  \&_regex,
       '""'       =>  \&_string,
       'bool'     =>  \&_bool,
    #   '0+'       =>  \&_num,
       'nomethod' =>  \&_other,
       ;
    use Carp;

our $VERSION = '2012.10.08';


=format

NAME:
    Wre

SYNOPSIS:

    Procedural interface:
        
    wre()
        
        # Decide if the contents of $data matches your wordy regexp
        if ($data =~ wre '<your wordy regexp>')  { ... }
        
        # Decide if the contents of $_ matches your wordy regexp
        if (wre '<your wordy regexp>')  { ... }
        
        # Assign a regexp to a scalar, then use it later
        my $wre_1 = wre '<your wordy regexp>';
        if ($data =~ /$wre_1/)  { ... }
        
        # Use a regex with global mode (/g)
        my $wre_2 = wre '<your wordy regexp>';
        while ($data =~ /$wre_2/g) {
            print "$1\n";
        }
        
        # Use a regexp in a substitution
        my $wre_3 = wre '<your wordy regexp>';
        $data =~ s/$wre_3/<replacement text>/g;
            
    wret()        
            
        wret() is only needed when you want to avoid using an intermediate
        variable, which would otherwise be needed for:
        
            - global matches (where you need to use the /g mode flag)
            - substitutions (s///).
            
        # Use the regex in-line with global mode
        while ($data =~ /${wret '<your wordy regexp>'}/g) {
            print "$1\n";
        }
        
        # Use the regex in a substitution
        $data =~ s/${wret '<your wordy regexp>'}/<replacement text>/g;
        
        
    OO interface:
    
        # Create a wordy regexp object
        my $wre = RegExp::Wre->new('<your wordy regexp');
        
        # Decide if the contents of $data matches your wordy regexp
        if ($data =~ $wre) { ... }
        
        # Decide if the contents of $_ matches your wordy regexp
        if ($wre)  { ... }
        
        # Use the regex with global mode (/g)
        while ($data =~ /$wre/g) {
            print "$1\n";
        }        
        
        # Use the regexp in a substitution
        $data =~ s/$wre/<replacement text>/g;
        
    Wordy Regexp Notation:
    
        A wordy regular expression is a string
    
    Wordy Regexp Notation Examples:
    
        'cat'       # Simple sequence of characters, the three letter c, a and t
        
        a f p       # Simple alternative. One character: either a, f or p
        
        2 * $ =     # Simple alternative. One character: either 2, *, $ or =
        
        c 'dog' e   # Alternatives: just c, all three letters d, o, g, or just e
        
        two digits  # Exactly two digits. Note that the quantity is a word
        
        one or more letters
        zero or more digits
        one to five digits
        
        five digits letters # Five characters, each can be a digit or a letter
        
        
        
        
DESCRIPTION:        
        
    Procedural Interface
        
        The intention is that wre() can be used as a drop-in replacement for a
        conventional regular expression used for simple matching and capturing.

        wre() is the main procedural interface routine. You pass it a wordy
        regular expression, and it returns an object that can be used where you
        would otherwise use a conventional (terse) regular expression.

        wret() is an alternative routine that is only needed in the situation
        where:
            (1) you want to put your wordy regexp directly in-line, rather than
                assign the regexp to an intermediate variable, and
            (2) you need to match using the global mode (/g), or do a substitution 

    OO interface:
    
        The oo interface is intended for situations where:
            
            Error Trapping is Important
            
              Both the procedural interface and the oo interface can only detect
              errors in a wordy regular expression at run time.
              
              However, using the oo interface allows the programmer to create
              wordy regexp objects at program initiation, so any errors in wordy
              regexps are detected at the start of the run.
              
              If the wordy regexp changes dynamically using interpolation, then
              it can't be checked until immediately before use; but the same
              problem affects conventional regexps that use interpolation.
              
              The oo interface also provides cleaner access to error information.
              The procedural interface is restricted to returning an error string
              via croak(), whereas the oo interface can persist more detail in
              the Wre object.
              
            Efficiency is Crucial
            
              There is an efficiency advantage for the oo interface. Using the
              procedural interface requires the wordy regexp text to be checked
              against the cache of previously-converted regexeps every time: for
              the oo interface this only needs to be done once when the object
              is created. However, the cache check is just a simple hash access,
              so it is typically very fast.
        





INSTALLATION
METHODS
PROJECT DEVELOPMENT
AUTHOR
COPYRIGHT
LICENCE
DISCLAIMER OF WARRANTY 




    WRE: Wordy Regular Expression Notation
    --------------------------------------
    
Takes a string containing an indented textual representation of a regular
expression and produces an equivalent standard regular expression.
    
The wre notation:

    - Uses words instead of giving special meaning to punctuation characters
    - Does not require escaping of any character
    - Uses indentation for grouping, to indicate the extent of captures,
       quantifiers and alternations
    - Has no metacharacters (well, hardly any that you'd notice)
    - Allows trailing comments on any line
    - Allows keywords for punctuation and other characters
    
   
Matchers are single characters, quoted strings, or keywords such as 'digit'
Matchers on one line (separated by spaces) are alternatives
Matchers on consecutive lines are matched in sequence

Modifiers are words that specify capturing, optional, mode or quantity
Modifiers apply to their own line, or to any lines indented from them

Capturing is requested by 'capture' or 'capture as <name>'
Optional items have the word 'optional'
Quantifiers are words or phrases such as 'three' or 'one or more' or 'two to four'

Alternatives can be specified using either/or, with each 'or' vertically below the 'either'.
++++ 
On a given line: capture, optional, quantifier, and any matchers can only be in that order.
A line that has any matchers must not have any lines indented from it.
If you want to use digits as a quantifier rather than the word, prefix it with 'quantity'
Groups: letter, digit, word-character
Named characters: optional except for:
        hash (meaning the # character which starts a comment)
        single and double quotes
        newline, tab and other non-graphic characters
Negated characters, groups and other matchers (such as word-boundary): not and non-
Other matchers, such as start-of-string/end-of-string/eosx/start-of-line/end-of-line
Spaces and whitespace
hex, octal and control characters: e.g. hex-0A, octal-12, control-G
Ranges:  0-9  a-g  q to z (Caution: a - z is three naked characters, not a range)
Plurals
'character' or 'ch' matches any character, including newline. Use 'non-newline' if required.
Either/or/or: must be first word on a line, must be at same indentation level
Lists of character and group names
Other modifiers:  lazy (must have quantifier), case-insensitive, possessive, ... 
Followed by, not followed by, preceding, not preceding
Rules for matching single and double quotes - revisit?
    otherwise adding a comment may alter a wre: e.g.
            a b c ' 
            a b c '   # Allow some letters or '
    In the second line above, that's part of a quoted string, not a comment
    Disallow naked quotes? It's simple to explain.
    Would need short synonyms such as SQ or DQ as alternatives to apostrophe,
     double-quote, and the ugly quoted-quotes '"' and "'" 
Unicode options
Numeral vs. digit
then
space-means-whitespace/whitespaces/space options
back-references
condition

=cut

my $GENERATE_FREE_SPACE_MODE;
my $EMBED_ORIGINAL_REGEX;
my $WRAP_WITH_DELIMITERS;
my $USE_APPENDED_MODES;

## my $HACK = 0;

my $xsp;
my $embed_source_regex;

# Option: causes a single space to be generated as [ ] even if /x mode is off
# It's a readability preference, and might have some slight performance penalty.
# Currently it's a constant as there is no mechanism to change it
# BUG: Setting it to false?? results in [\s+] instead of [\s]+ in space-means-wss
# mode

my $put_solo_space_into_class = 0;

# Characters to put into a character class even when solo.
# It's a readability preference: we have to generate (e.g.) either [*] or \* 
# I find the bracketted option clearer than the escaped option, so that a
# backslash introduces a group (such as \d) or a special character (such as \t)
# rather than escaping a regex meta-character.
my $prefer_class_to_escape = 1;
my %char_class_even_when_solo;
my $DEBUG = 0;
my $comment_starter = '#';      # Standard for Perl
my $regex_starter   = '/';      # Globals used by character encoder and regex 
my $regex_finisher  = '/';      # generator

my $REQUIRE_S_MODE = 1;
my $REQUIRE_M_MODE = 2;
my $REQUIRE_X_MODE = 4;
my $REQUIRE_P_MODE = 8;
    
my $MAGIC_MARKER = '#MAGIC^MARKER#';

my %target = ( does_capture_name  => 1,
               capture_name_start => '?<',
               capture_name_end   => '>',
               early_perl_names   => 0,    # Emulate Perl 5.10 for earlier Perls
             );

my @capture_name;



my $LT_GROUP    = 'group';      # Group name, e.g. LETTERS or DIGIT or DIGITS
my $LT_CHAR     = 'char';       # One character, whether specified as a 
                                # naked character or the name of a character
my $LT_CONTROL  = 'control';    # One character, specified as control-<letter>
my $LT_HEX      = 'hex';        # One character, specified as hex-<digits>
my $LT_OCTAL    = 'octal';      # One character, specified as octal-<digits>
my $LT_SEQUENCE = 'seq';        # A quoted string with more than one character
                                #  - so it's a sequence of characters
my $LT_RANGE    = 'range';      # A range *token* such as 4-7 or b-j. The parser
                                # itself has to detect multi-token ranges such as:
                                #    b thru j 
                                #    4 to 7
                                #  (with the word 'to', or 'thru' or 'through':
                                #   hyphen cannot be used)
                                # which are split by the tokeniser
my $LT_ASSERTION  = 'matcher';  # The name of a zero-width matcher, such as end-of-line
my $LT_BACKREF    = 'backref';  # A back-reference

my %LIT_TYPE_SINGLE_CHAR =
         ($LT_CHAR => 1, $LT_CONTROL => 1, $LT_HEX => 1,$LT_OCTAL => 1);

my $TT_COMMENT     = 'comment';
my $TT_LITERAL     = 'literal'; # Solo character, or quoted sequence, or named character
my $TT_ASSERTION   = 'assertion';
my $TT_NUMBER      = 'number';  # Number, but not a digit. e.g. seven or 42
my $TT_RANGE       = 'range';   # letter-letter or digit-digit
my $TT_MODE        = 'mode';    # A mode-changing keyword
my $TT_WORD        = 'word';    # A word-like sequence, excluding numbers
my $TT_WORD_HYPHEN = 'word_hyphen';
                                # A word-like sequence, except with a trailing
                                # hyphen or underscore, as in left- or right-
my $TT_ERROR       = 'error';   # Syntax error detected by get_next_token
my $TT_NO_MORE     = 'no_more'; # End of regex line  - no more tokens
                                # (not to be confused with the token EOL)

{ # naked block for tokeniser
    my $line = '';
    my $token_pos = 0;
    
    my $line_has;                   # Bit mask
    my $LINE_HAS_CAPTURE      = 1;   # Line has 'capture'
    my $LINE_HAS_MODE         = 2;   # Line has explicit mode(s)
    my $LINE_HAS_QUANTIFIER   = 4;   # Line has explicit quantifier
    my $LINE_HAS_OPTIONAL     = 8;   # Line has explicit 'optional'
    my $LINE_HAS_BEEN_NEGATED = 16;  # Line has 'not' or a synonym
    my $LINE_HAS_LITERAL      = 32;  # Line has at least one literal
    
    my $LINE_HAS_SEQUENCE_LITERAL
                              = 64;  # Line has at least one quoted literal that has
                                     # more than one character
    my $LINE_HAS_ANYTHING     = 128; # Line has 'character' or an equivalent
    my $LINE_HAS_ASSERTION    = 256; # Line has at least one assertion
    
    my $capture_count = 0;
    
    # Beware that these are effectively singleton global variables, but they are
    # used by routines that recurse for each level of indentation. So their
    # values (whether accessed directly or by an accessor routine) are only
    # useful between when gnt() was called and the next level of recursion.
    
    my $token = '';
    my $token_raw;
    my $token_flags;
    my $prev_token = '';
    my $prev_prev_token = '';
    my $delimiter = '';
    
    my $token_type;
    my $token_start_pos;
    my $word_is_plural;             # True if word found in plural list, e.g. HASHES or LETTERS
    my $word_is_negated;
    my $literal_is_a_digit;
    my $literal_is_a_letter;
    
    my $token_lc;
    

    my $literal_type;               #    text: values are 'char' 'group'
                                    #                 'seq' 'control' 'hex' 'octal'
                                    #                 'matcher' (e.g. assertion)
                                    #                 'backref'
                                    #                 'range' (range token, such as 0-8)
    
    
    my $literal_char_case;          # Set if char class letter
    my $LLC_CAPITAL    = 'upper';   # Upper case letter
    my $LLC_SMALL      = 'lower';   # Lower case letter
    
    my %digits = (zero => 0,
                  one  => 1, two   => 2, three => 3, four => 4, five => 5,
                  six  => 6, seven => 7, eight => 8, nine => 9);
    
    my %numbers = (ten      => 10, eleven   => 11, twelve  => 12, thirteen  => 13,
                   fourteen => 14, fifteen  => 15, sixteen => 16, seventeen => 17,
                   eighteen => 18, nineteen => 19);
    
    my %multiples_of_ten = (twenty => 20, thirty  => 30, forty  => 40, fifty  => 50,
                            sixty  => 60, seventy => 70, eighty => 80, ninety => 90);
    
    # Normalised, anglicised, lower-cased keywords
    # Converts synonyms to standard form
    my %synonyms = (cased              => 'case_sensitive'       ,
                    ch                 => 'character'            ,
                    chs                => 'characters'           ,
                    char               => 'character'            ,
                    chars              => 'characters'           ,
                    ci                 => 'case_insensitive'     ,
                    cs                 => 'case_sensitive'       ,
                    eosx               => 'almost_end_of_string' ,
                    eos                => 'end_of_string'        ,
                    eol                => 'end_of_line'          ,
                    eopm               => 'end_of_previous_match',
                    get                => 'capture'              ,
                    gnl                => 'generic_newline'      ,
                    gnls               => 'generic_newlines'     ,
                    look_behind        => 'preceding'            ,
                    lookbehind         => 'preceding'            ,
                    look_ahead         => 'followed_by'          ,
                    lookahead          => 'followed_by'          ,
                    lower_case_letter  => 'lc_letter'            ,
                    lowercase_letter   => 'lc_letter'            ,
                    negative_lookahead => 'not_followed_by'      ,
                    negative_lookbehind=> 'not_preceding'        ,
                    non_case_sensitive => 'case_insensitive'     ,
                    opt                => 'optional'             ,
                    optionally         => 'optional'             ,
                    qty                => 'quantity'             ,
                    sos                => 'start_of_string'      ,
                    sol                => 'start_of_line'        ,
                    thru               => 'to'                   ,
                    through            => 'to'                   ,
                    uncased            => 'case_insensitive'     ,
                    uni                => 'full_unicode'         ,
                    uppercase_letter   => 'uc_letter'            ,
                    upper_case_letter  => 'uc_letter'            ,
                    word_char          => 'word_ch'              ,
                    ws                 => 'whitespace'           ,
                    );
    
    normalise_hash_contents(\%synonyms);
    
    
    my %kw;
    
    my @keyword_array = qw{ to
                            or more
                            character letter digit whitespace
                            case_insensitive case_sensitive
                            either or
                            capture as  capture_as
                            not
                            minimal  possessive
                            followed_by  followed by  preceding
                            not_followed_by           not_preceding
                            optional
                            quantity
                            then
                            };
    
    for my $k (@keyword_array) {
        # For English, load keyword hash translating words to themselves
        ## For French, for example, $kw{small} would need to contain 'petite', and
        ## $synonyms{petit} would need to contain 'petite'. There would need to be
        ## extra table loaders to manage this.
        ## The names of the standard keywords would be translated, but not the names
        ## of Unicode characters that are defined in all caps in the Unicode
        ## standards.
        $kw{$k} = $k;
    }
    # Add hyphenated variants for synonyms with underscores
    #if (0) {
    #for my $syns (keys %synonyms) {
    #    my $hyphenated = $syns;
    #    $hyphenated =~ s/ [_] //gx;
    #    if ($hyphenated ne $syns) {
    #        # A new variant on the synonym, with hyphens replacing underscores    
    #        $synonyms{$hyphenated} = $synonyms{$syns};
    #    }
    #}
    #}
    
    normalise_hash_contents(\%kw);
    
    my %is_plural_of = (letters     => 'letter',
                        lcletters   => 'lcletter',
                        ucletters   => 'ucletter',
                        digits      => 'digit',
                        characters  => 'character',
                        whitespaces => 'whitespace',
                        ## Should whitespace always be plural?
                        ## Decision: No
                        ##   - It makes 'non-whitespace' confusing
                        ##   - It is irregular
                        ##   - Means that also need 'whitespace-character' to be
                        ##       able to get a single whitepace (or say 'one whitespace')
                        wss         => 'whitespace',
                        wordchs     => 'wordch',
                        wordchars   => 'wordch',
                        genericnewlines
                                    => 'genericnewline',
                                    
                        );
    
    my %group_words = (letter     => 'noun',
                       lc_letter  => 'noun',
                       uc_letter  => 'noun',
                       digit      => 'noun',
                       whitespace => 'adj',
                       word_ch    => 'noun',
                       character  => 'noun',
                       generic_newline => 'noun',
                       );
    normalise_hash_keys(\%group_words);
    
    my %mode_words = (
                      case_sensitive   => 'i-', # /-i
                      case_insensitive => 'i+', # /i
                      preserve         => 'p+', # /p
                      legacy_unicode   => 'Ud', # /d
                      full_unicode     => 'Uu', # /u
                      ascii            => 'Ua', # /a
                      locale_specific  => 'Ul', # /l
                      space_means_ws   => 'S1', # space within string means whitespace mode
                      space_means_wss  => 'S+', # space within string means whitespaces mode
                      space_means_space=> 'S-', # space within string means space mode
                      );
    normalise_hash_keys(\%mode_words);
    
    my %zero_width_matchers = (
                    start_of_string => ['\\A'],
                    end_of_string   => ['\\z'],
                    almost_end_of_string
                                    => ['\\Z'],
                    start_of_line   => ['^', 'm'],   # Needs m-mode
                    end_of_line     => ['$', 'm'],   # Needs m-mode
                    word_boundary   => ['\\b', 'b'], # Can be negated
                    end_of_previous_match
                                    => ['\\G'],
                               );
    
    normalise_hash_keys(\%zero_width_matchers);
    
    my $NON_WORD    = 'non';
    my $NON_LENGTH  = length($NON_WORD);
    
    ## my %groups      = (digit => 'digit', letter => 'letter');
    
    my %char_names = (
        alarm   => "\a",
        ampersand       => '&',
        apostrophe      =>  "'",
        asterisk        => '*',
        at              => '@',
        at_sign         => '@',
        back_slash      => "\\", 
        backslash       => "\\", 
        backspace       => "\b",
        backtick        => '`',
        caret           => '^',
        carriage_return => "\r",
        close_brace     => '}',
        close_bracket   => ']',
        close_parenthesis=> ')',
        colon           => ':' ,
        comma           => ',',
        dash            => '-', 
        dot             => '.' ,
        dollar          => '$',
        dollar_sign     => '$',
        double_quote    =>  '"',
        dq              =>  '"',
        equal_sign      => '=',
        equals          => '=' ,
        equals_sign     => '=',
        escape          => "\e",    # the character x1B, not to be confused with backslash
        exclamation     => '!',
        exclamation_mark=> '!',
        form_feed       => "\f",
        forward_slash   => '/',
        hash            => '#',
        hat             => '^',
        hyphen          => '-',
        line_feed       => '\x0A',
        left_brace      => '{',
        left_bracket    => '[',
        left_parenthesis=> '(',
        minus           => '-' , 
        newline         => '\n', 
        no_break_space  => '\xA0',
        open_brace      => '{',
        open_bracket    => '[',
        open_parenthesis=> '(',        
        percent         => '%',
        percent_sign    => '%',
        period          => '.',
        pipe            => '|',
        plus            => '+',
        question_mark   => '?',
        right_brace     => '}',
        right_bracket   => ']',
        right_parenthesis=>')',
        semi_colon      => ';', 
        single_quote    => "'",
        slash           => '/', 
        soft_hyphen     => '\xAD',
        solidus         => '/',
        space           => ' ',
        sq              => "'",
        star            => '*', 
        tab             => '\t',
        tilde           => '~',
        underscore      => '_',
         );
    normalise_hash_keys(\%char_names);
    
    #while (my ($char_key, $char_value) = each %char_names ) {
    #    if ($char_key =~ / [-_] /x) {
    #        delete $char_names{$char_key};
    #        $char_key =~ s/ [-_] //gx;
    #        $char_names{$char_key} = $char_value;
    #    }
    #}
    
    
    my %irregular_plural = (
                            # singular  =>  irregular_plural, or null if no plural
                            equals => '',
                            leftparenthesis  => 'leftparentheses',
                            openparenthesis  => 'openparentheses',
                            rightparenthesis => 'rightparentheses',
                            closeparenthesis => 'closeparentheses',
                            );
    
    ## Wrong for some words, e.g. lath -> lathes. Would have to examine more than
    ## one trailing letter. May not matter if all of the character names are OK
    my %pluralisers = (h => 'es', s => 'es'); 
    
    
    
    
    # Initialise plurals hash
    while (my ($singular, $ch) = each %char_names ) {
        # Derive the plural by using standard English rules, but with
        # an exception list
        ## print "singular: $singular ch: $ch\n";
        if (exists $irregular_plural{$singular}) {
            # Irregular plural value is null string if there is no plural
            $is_plural_of{$irregular_plural{$singular}} = $singular if $irregular_plural{$singular};
        } else {
            my $last_ch =  substr($singular, -1, 1);
            my $plural = $singular . ($pluralisers{$last_ch} || 's');
            $is_plural_of{$plural} = $singular;
        }
    }


{
    # State data for wre, done this way for compatibility with Perl versions
    # that don't implement 'state'.
    ## Should this be in a begin block?
    
    my %memo_of_qrs;
    my $memo_count          = 0;    # Number of items added to memo_of_qrs
    my $memo_accesses_count = 0;    # Number of times memo accessed
    my $memo_hit_count      = 0;    # Number of successful memo accesses
    my $memo_size           = 0;    # Total bytes in memo, keys + content
    my $memo_max_chars      = 10_000_000;   # Arbitrary limit    
    
    sub token_type {
        # Accessor for token_type
        return $token_type;
    }
    sub wre_to_terse {
        
        #   wre_to_terse()
        #
        # Passed an indented regular expression (ire) and possibly some options.
        # Returns the equivalent terse regular expression, or failure
        # diagnostics.
        #
        # 
    }
    sub wre {
        
        #    wre()  - Simple interface to Wordy Regular Expressions
        #
        #  
        #
        # Passed:
        #   1) A wordy regular expression
        #   2) Optionally, a terse regex (as documentation or fallback)
        #   3) Optionally, control and option information
        #
        # Returns:
        #   1) - In a string or regex context:
        #          An object that evaluates to a terse regex
        #      - In a boolean context
        #          The result of matching $_ against a terse regex
        #
        # The regex returned (or used) by wre is normally the
        # terse equivalent of the indented regular expression.
        #
        # Modes of Use:
        #
        #   wre only:
        #       wre() is passed only an wordy regexp and
        #                returns a terse one.
        #   documented:
        #       wre() is passed both an wordy regexp and a terse one.
        #             Returns a terse regexp generated from the wordy regexp
        #                
        #   fallback/test:
        #       wre() is passed both an wordy regexp and a terse one.
        #       returns the terse regexp that was passed as the second parameter
        #
        # wre() is intended to be used in Perl programs where a terse
        # regexp would otherwise be used.
        #
        # The reasoning for passing both a wre and a terse regexp to wre() is
        # that it allows maximum flexibility.
        #
        # There can be three regexps that relate to a single regexp in Perl
        # code, although some of them may not normally be visible.
        #
        #  If the original program was written using terse regexps:
        #
        #       (a) The original terse regexp as written by the programmer
        #
        #       (b) The equivalent wordy regexp, expanded from (a) by an
        #            automated script conversion utility
        #
        #       (c) The terse regexp generated from (b)
        #            This is not normally visible, but it could be shown for
        #            debug purposes, and to give users the ability to check that
        #            the wordy regexp is functionally equivalent to the original.
        #
        #            It could also be used to avoid the generation step that
        #            would otherwise be needed. However, the performance gain
        #            may be modest as generated regexps will usually be cached,
        #            and showing all three regexps could be confusing.
        #
        #  If the original program was written using wordy regexps:
        #       (d) The original wordy regexp as written by the programmer
        #       (e) The terse regexp generated from (d)
        #
        #       An automated conversion process could identify terse
        #       regexps and replace them with calls to wre() passing
        #       both the generated wre and the original terse regexp.
        #
        #       - When the program is executed, a global switch can control
        #         whether the generated wres or the original regexps are used.
        #         Possible scenarios include:
        #           - Treat the generated wre as documentation only, and continue
        #             to use the original terse regexp for code execution.
        #             This minimises the risk of functional changes caused by
        #             incorrect conversion.
        #
        #           - Use the generated wre for code execution, but leave the
        #             original regexp visible as documentation, e.g. for
        #             maintainers who do not understand wordy regexps.
        #
        #             However, code with a mixture of 'live' wre regexps
        #             and 'live' terse regexps needs to be avoided.
        #             If a maintainer changed the original regexp but did not
        #             regenerate the corresponding wre, the change would become
        #             effective only when the global switch was set to use the
        #             original regexp: it would regress when that switch was changed.
        #
        #           - Use of the global switch to simplify testing of a program
        #             that has had the auto-conversion process applied. The
        #             program can be run against the same test both with the
        #             flag set to 'use the wordy' and with it set to 'use
        #             terse', and the test results compared.
        #
        #
        # To enable automated detection of manual changes, the conversion
        # utility can output digests of both the generated and original regexps.
        # These can be used to detect whether either (or both) of the supplied
        # regexps have been manually edited, in which case they may not be
        # functionally equivalent.
        #
        # Auto-detection of changes could be done by a check utility, and/or
        # dynamically at code execution.
        #
        # The memoing capability that improves performance by avoiding
        # regeneration of regexps could also cache the digests, so they could be
        # found using the same hash lookup.
        #
        # There would be nothing stopping a maintainer from changing code to use
        # some terse regexps, although this would make for more confusing
        # code. 
        
        # Implementation Approaches.
        #
        #   New Code
        #       New code is simplest if written and tested using only wres. The
        #       main concession would be to include documentation links for
        #       maintainers.
        #
        #
        #   Existing Code, Cautious Approach
        #       Stage 1: Auto-convert, but keep and execute the original regexps
        #           This is a very low risk step, but can help the maintainer by:
        #             - making the meaning of existing regexps clear
        #             - providing examples of wordy regexps
        #       Stage 2: Switch to executing the wordy regexps
        #           This allows testing, with easy fallback.
        #       Stage 3: Re-convert, dropping the original regexp
        #           This simplifies and shortens the code.
        #
        #   Existing Code, Big Bang Approach
        #       Auto-convert, without retaining the original regexp.
        #       Test and deploy the new version.
        #
        # Because wres are longer than terse regexps, good programming style may
        # result in the result from wre() being saved in a variable which is
        # then used in a match expression, rather than having the wre() call in
        # the match.
        #
 
        ## Does wre() need options?
        ## There are regex features such as /g and /c that cannot be baked into
        ## a qr-style regex literal. For example:
        ##      $text =~ m/[def]/gc
        ## cannot be replaced by a wre such as:
        ##      $text =~ wre 'd e f';
        ## as there is no way for options in the wre() call to apply the /gc.
        ## So the approach is to provide wret() that returns a reference to the
        ## terse version that can be interpolated into the regex without needing
        ## an intermediate variable:
        ##      $text =~ /${wret 'd e f'}/gc
        ##
        ## Note: Other modes (/i, /s, /m etc.) will be ignored because the
        ##       values of those mode flags get baked into the regex that is
        ##       being interpolated.
        
        
        
        ## Note that wre() returns an object, even though it is not a method.
        ## This allows a non-oo interface to take advantage of Perl's ability to
        ## overload the use of a call to wre in a boolean context, so we can
        ## recognise and handle the case where wre() is being implicitly used to
        ## match $_.
        
        ## Should we check the arguments passed, e.g. to detect being
        ## called as a method, or being passed superfluous parameters?
        ## Defering until the interface is more settled, e.g. have to
        ## decide whether there is an optional 'options' argument.
        ##
        ## Philosophically, it's better to have everything specified in the wre,
        ## rather than having some things that can or must be specified as
        ## options. The counter-argument might be situations where a global
        ## default (maybe unicode setting?) is being over-ridden - but I
        ## can't think of a convincng use case.
                
        my ($wre, $arg2, $arg3) = @_;
        my $number_of_args = scalar @_;
        my $terse = '';
        my $option_ref = { };
        
        if ($number_of_args < 1) {
            croak "RegExp::Wre wre(): No arguments passed";
        } elsif ($number_of_args > 3) {
            croak "RegExp::Wre wre(): Too many arguments passed ($number_of_args)";
        } elsif ($number_of_args == 2) {
            # Two args: wordy + tre, or wordy + options
            if (ref $arg2 eq 'HASH') {
                # wordy + options
                $option_ref = $arg2;        
            } else {
                $option_ref = $arg2;
            }
        } else {
            # Must be 3 args
            $terse = $arg2;
            $option_ref = $arg3;
        }

        
      
        my $self = { };
        
        $self->{wre} = $wre;      # Stash the wre in the new object
        
        # Check whether we have seen this wre before, and can avoid the
        # processing involved in generating the wre into a legecy regex
        #
        # The size of the memo is tracked, and memoisation is halted when
        # the maximum total size is exceeded: this is to avoid runaway memory
        # usage in situations such as a wre with constantly changing
        # interpolated content being used within an high-usage loop.
        #
        ## A more sophisticated option would be to also monitor the proportion
        ## of hits, and stop memoisation if this is very low even if the limit
        ## on memo size has not been reached. The memo_stats() and
        ## set_memo_limit_chars() routines enable this to be done externally,
        ## but implementation within this package would be simpler and have
        ## lower overheads.
        
        my $qr = $memo_of_qrs{$wre};
        $memo_accesses_count++;
        
        if (defined $qr) {
            # Do nothing: we can use the memoised qr we just found
            $memo_hit_count++;
            my $pause = 7;
        } else {
            # Convert the wre to a qr regex literal
            my $terse = _wre_to_tre($wre, $option_ref);
            
            eval {$qr = qr/$terse/x};
            
            if ($@) {
                croak "RegExp::Wre wre(): Invalid regex generated: $@";
            }
            
            if ($memo_size < $memo_max_chars) {
                $memo_of_qrs{$wre} = $qr;   # Memoise the qr regex
                $memo_count++;
                $memo_size += length($wre) + length($qr);
            }
        }
        
        $self->{'terse'} = $qr; # Stash the qr regex literal
        
        ## If we discovered errors, report them and/or stash them.
        ## An invalid wre should not normally be ignored. The default
        ## behaviour should make it hard to accidentally use the regexp
        ## created from an invalid wre, e.g. by returning an invalid
        ## regexp that will not compile, or will crash if used in a match.
        
        
        bless ($self, 'RegExp::Wre');
        return $self;       
        
    }
    
    sub memo_stats {
        # Returns a reference to a hash containing memo statistics
        return { count    => $memo_count,
                 accesses => $memo_accesses_count,
                 hits     => $memo_hit_count,
                 chars    => $memo_size };
    }
    
    sub set_memo_limit_chars {
        # Sets the maximum number of characters to be held in the qr memo
        # If the new $memo_size has already been exceeded, this will stop
        #    memoisation immediately, but the existing memo will be retained.
        # If the new $memo_size has not yet been exceeded, memoisation will
        #   continue until the new limit is reached.
        ($memo_max_chars) = @_;
    }
}

sub wret {
    my ($wre, $options_ref) = @_;
    my $wre_obj = wre($wre, $options_ref);
    return $wre_obj->{'terse'};
}

sub new {
    my ($class, $wre, $options_ref) = @_;
    
    my $self = { };
    
    ## say ('in wre');    

    my $terse = _wre_to_tre($wre, $options_ref);
    $self->{'terse'} = $terse;
    $self->{'ire'} = $wre;
    
    bless ($self, $class);
    return $self;       
    
}

sub _regex {
    my ($self, $other, $swap) = @_;
    my $terse = $self->{terse};
    #say ("in regex: returning $terse");
    ## my $pause = 1;
    return $terse;
}

sub _bool {
    # Object used in a boolean context, such as:
    #   if ( wre q/a b c/) { ... }
    # which implies matching the regex against $_
    
    my ($self, $other, $swap) = @_;
    ## say "in bool. \$_ = $_";
    ## my $str = $self->{terse} . '';
    ## say "terse: $str";
    ## my $pause = 2;
    return ($_ =~ $self->{terse});
}

sub _num {
    my ($self, $other, $swap) = @_;
    ## say 'in num';
    ## my $pause = 3;
    return $self->{terse};
}

sub _other{
    my ($self, $other, $swap) = @_;
    ## say 'in other';
    ## my $pause = 4;
    return 'overload error in ' . __PACKAGE__;
}
my $string_count = 0;
sub _string {
    my ($self, $other, $swap) = @_;
    ## say "in string " . ++$string_count;
    return $self->{terse};
}

sub flag_value {
    # Passed: A string containing the name of a variable (with no sigil)
    # Returns: The value of that variable in the caller's context
    #
    # This allows a user to set their desired value for
    # a flag that affects all calls to wre, by:
    #   our $flag = 'xxx';
    # without it being affected by any other package's value for their variable
    # of the same name
    
    my ($var_name) = @_;
    
    my $caller_name = caller();
    my $stmt = '$' . $caller_name . '::' . $var_name;
    
    my $eval_result = eval $stmt;
    return $eval_result;
    
}

    sub reset_line_flags {
        $line_has = 0;
    }

    sub give_line_to_tokeniser {
        ($line) = @_;
        ## $line = _trim_trailing($line);
        pos($line) = 0;
        $token_pos = 0;
        $line_has  = 0;     # Bit mask of what has been seen on this line

    }
    sub gnt {
        # get next token
        # Looks up barewords and sets $token_word to a standardised form, so
        # 'ThRouGH' as a bareword would be standardised to 'to', as case is
        # ignored and 'through' is a synonym of 'to'.
        # Returns
        #   
        ($prev_prev_token, $prev_token) = ($prev_token, $token);
       
        $token_start_pos = pos($line);
        $token_raw = undef;
        
        $word_is_plural  = 0;
        $word_is_negated = 0;
        
        my ($quote);
        
        $line =~ / \G \s+ /xgc; # Skip any leading whitespace
        ## my $pl = pos($line);print     "pos line: $pl\n";
        if ( $line =~ / \G \z /xgc) {
            # End of line
            $token_type = $TT_NO_MORE;
        } elsif ($line =~ / \G \Q$comment_starter\E ( .* ) /xgc) {
            $token = $1;
            $token_type = $TT_COMMENT;
        } elsif ($line =~ / \G ( ['"]            )      # single or double quote
                               ( .+?             ) \1   # any chars, then same quote
                               ( \s | $ )               # space or eol
                               /xgc) {
            # There is a valid quoted literal
            $quote = $1; $token = $2; $delimiter = $3;
            $token_type = $TT_LITERAL;
            $literal_type = (length $token == 1) ? $LT_CHAR : $LT_SEQUENCE;
            $token_raw  = $quote . $token . $quote; # Reconstruct raw literal
        } elsif ($line =~ / \G ( ['"]   \S*      )      # single or double quote + opt space
                               ( \s | $ )               # space or eol
                               /xgc) {
            # Single or double quote, but didn't get picked as starting a valid
            # literal by previous match
            $token_type = $TT_ERROR;
            $token = $1; $delimiter = $2;
        } elsif ($line =~ / \G ( . ) ( \s | $ ) /xgc){
            # Single character, followed by whitespace or eol
            # So it's a valid naked character
            $token = $1; $delimiter = $2;
            $token_type = $TT_LITERAL;
            $literal_type = $LT_CHAR;
        } elsif ( $line =~ / \G ( [a-z] - [a-z] | [A-Z] - [A-Z] | \d - \d )
                                ( \s | $ ) /xgc) {
            # range of digits or letters, e.g. a-z or D-H or 2-8
            # Allows invalid ranges such as B-A, 9-0, b-a
            $token = $1; $delimiter = $2;
            $token_type = $TT_LITERAL;
            $literal_type = $LT_RANGE;
        } elsif ($line =~ / \G ( \d+             )
                               ( \s | $ ) /xgc) {
            # A number, but single digits previously handled
            $token = $1; $delimiter = $2;
            $token_type = $TT_NUMBER;
        } elsif ($line =~
            / \G  hex (?: adecimal )? [-_] ([a-f0-9]+)
                  ( \s | $ )/xgci) {
            # hex-<hex-digits>
            my $hex_digits = $1; $delimiter = $2;
            $token_type = $TT_LITERAL;
            $literal_type = $LT_HEX;
            $token = '\\x{' . lc($hex_digits) . '}' ;
        } elsif ($line =~
            / \G oct (?: al )? [-_] ( [0-7]{1,3} )
                                     ( \s | $ ) /xgci) {
            # octal-<1-to-3-octal-digits>
            my $octal_digits = $1; $delimiter = $2;
            $token_type = $TT_LITERAL;
            $literal_type = $LT_OCTAL;
            # Add leading zero(s) to avoid ambiguity
            # with back-references
            $octal_digits = substr("00$octal_digits", -3);
            $token = '\\' . lc($octal_digits);
        } elsif ($line =~
            / \G ( (?: back [_-]? ref (?: erence )? | captured )
                    [-_] ( \d+ ))
                    (?: \s | $ ) /xgci) {
            # backref-<number>
            # or captured-<number>
            $token_raw = $1;
            my $backref_number = $2;
            $token_type = $TT_LITERAL;
            $literal_type = $LT_BACKREF;
            $token = $backref_number;
        } elsif ($line =~
            / \G ( (?: back [_-]? ref (?: erence )? [-_] rel (?: ative )? 
                       | captured [-_] previous )
                   [-_] ( \d+ )
                 ) (?: \s | $ ) /xgci) {
            # backref-relative-<number>
            # or captured-previous-<number>
            $token_raw = $1;
            my $backref_number = $2;
            $token_type = $TT_LITERAL;
            $literal_type = $LT_BACKREF;
            $token = '-' . $backref_number;
            #} elsif ($line =~
            #    / \G ( back [_-]? ref (?: erence )? [-_] rel (?: ative )? [-_]
            #           ( \d+ )
            #         ) (?: \s | [,] \s | $ ) /xgci) {
            #    # backref-relative-<number>
            #    $token_raw = $1;
            #    my $backref_number = $2;
            #    $token_type = $TT_LITERAL;
            #    $literal_type = $LT_BACKREF;
            #    $token = '-' . $backref_number;
        } elsif ($line =~
            / \G ( back [_-]? ref (?: erence )? [-_] 
                   ( [a-z] [a-z0-9\-_]* )
                 ) (?: \s | $ ) /xgci) {
            # backref-<name>
            $token_raw = $1;
            my $backref_name = $2;
            $token_type = $TT_LITERAL;
            $literal_type = $LT_BACKREF;
            $token = $backref_name;
            
        } elsif ($line =~ / \G ( [a-z] [-_a-z0-9]*? [a-z0-9] )
                               ( \s | $       ) /xgci) {
            # 'word' - something starting and ending with a letter, containing
            # only letters, hyphens and underscores
            $token = $1; $delimiter = $2;
            $token_raw = $token;
            $token_type = $TT_WORD;
            $token_lc = lc $token;
            if (defined $digits{$token_lc}) {
                # The word is the name of a digit
                $token_type = $TT_NUMBER;
                $token = $digits{$token_lc};
            } elsif (defined $numbers{$token_lc} ) {
                # The word is the name of a number
                $token_type = $TT_NUMBER;
                $token = $numbers{$token_lc};
            } elsif (defined $multiples_of_ten{$token_lc} ) {
                # The word is the name of a multiple of ten
                $token_type = $TT_NUMBER;
                $token = $multiples_of_ten{$token_lc};                
            } else {
                my ($first_word, $second_word) = $token_lc =~ / ^ ( [^-_]+ ) [-_] ( [^-_]+ ) $ /x;
                if (
                       defined $first_word
                    && defined $second_word
                    && defined $multiples_of_ten{$first_word}
                    && defined $digits{$second_word}
                    ) {
                    # word-number such as 'forty-two'
                    $token_type = $TT_NUMBER;
                    $token      = $multiples_of_ten{$first_word}
                                  + $digits{$second_word};
                } else {
                    # The word is not a number that we recognise
                    # Convert hyphens to underscores
                    # Convert synonyms
                    # Convert negated word to the positive (but remember it was negated)
                    # Convert to singular (but remember it was a plural)

                    my $word_converted = $token_lc;
                    $word_converted =~ s/[-_]//xg;

                    if (   substr($token_lc, 0, $NON_LENGTH) eq $NON_WORD
                        && substr($token_lc, $NON_LENGTH, 1) =~ / [-_] /x ) {
                        # Word starts with 'non-' or local equivalent
                        $word_converted = substr($word_converted, $NON_LENGTH);
                        $word_is_negated = 1;
                    }
                    my $synonym = $synonyms{$word_converted};
                    $word_converted = $synonym if $synonym;
                    my $singular = $is_plural_of{$word_converted};
                    if ($singular) {
                        $word_converted = $singular;
                        $word_is_plural = 1;
                    }

                    my $ch = $char_names{$word_converted};
                    
                    if (defined $ch) {
                        # It's the name of a character (or its negation)
                        $token_type   = $TT_LITERAL;
                        $literal_type = $LT_CHAR;
                        $token        = $ch;
                    } elsif (defined $group_words{$word_converted}) {
                        # It's the name of a group (or its negation)
                        $token_type   = $TT_LITERAL;
                        $literal_type = $LT_GROUP;
                        $token        = $word_converted;
                    } elsif (defined $zero_width_matchers{$word_converted}) {
                        my ($code, $flags) = @{$zero_width_matchers{$word_converted}};
                        $token_type   = $TT_ASSERTION;
                        $token        = $code;
                        $token_flags  = $flags;
                    } elsif (defined $mode_words{$word_converted}) {
                        my $flags = $mode_words{$word_converted};
                        $token_type   = $TT_MODE;
                        $token_flags  = $flags;
                    } elsif (  my ($control_letter) = $word_converted
                           =~ / \A (?: control | ctrl | cntrl | ctl )
                                # hyphens & underscores deleted  [-_]
                                ( [a-zA-Z] )
                                \z /x) {
                        # control-<letter>
                        # or non-control-<letter>
                        $token_type = $TT_LITERAL;
                        $literal_type = $LT_CONTROL;
                        $token = '\\c' . uc($control_letter);
                    } else {
                        # token is the normalised word itself
                        $token = $word_converted;
                    }
                }
            }
        } else {
            # Don't understand token - syntax error
            # Bump along in case we get called again, and to extract the token
            # that will be used in the error message.
            $token_type = $TT_ERROR;
            $line =~ / \G (.+?) ( \s | $ ) /xgc;
            $token = $1; $delimiter = $2;
        }
        if ($token_type eq $TT_LITERAL) {
            
            $literal_is_a_letter = ($token =~ / ^ [a-z] $ /xi);
        }
        if ( ! defined $token_raw) {
            # If we have messed with the original token, we should have already
            # saved it in $token_raw, otherwise copy it to the raw version
            $token_raw = $token;
        }
        $token_pos = pos($line);
    }
    
    sub token_pos {
        return $token_pos;
    }
    
    sub token_start_pos {
        return $token_start_pos;
    }
    
    sub token_is_kw {
        my ($keyword) = @_;
        return (   $token_type eq $TT_WORD
                && $token      eq $kw{$keyword} );
    }
    
    sub parse_chunk {
        
        # Parse a single chunk from the input line.
        # A chunk consists of:
        #   - a single keyword or phrase (such as 'optional' or 'but as few as possible')
        #   - a quantifier phrase (e.g. 'two', 'two of', 'zero or more',
        #                               'one or two', 'quantity 1 or more')
        #   - a single literal or a range (e.g. 'x' or 'TAB' or '1-7' or 'A thru F')
        # Passed:
        #   (1) A reference to the structure for the complete line
        #   (2) The chunk number within the line
        # Returns:
        #   negative when the keyword 'then' is found
        #   zero when it finds no more chunks available from this line
        #   True otherwise: 1 if no errors that might be literals, > 1 otherwise
        # Side Effects:
        #   Adds the details of the chunk to the structure referenced by $pl_ref
        #
        # Assumes gnt() previously called, leaving the first token available
        # Calls gnt() to work its way through a single chunk
        # Exits after finding the first token of the next chunk
        
        my ($pl_ref, $chunk_number) = @_;

        my $ambiguity_seen = 0;
        
        if (! defined $token_type) {
            my $pause = 1;
        }
        if      ($token_type eq $TT_NO_MORE) {
            # gnt() reported end of line
            return 0;
        } elsif ($token_type eq $TT_WORD && $token eq $kw{then} ) {
            # gnt() found the keyword 'then'
           
            return -1;
            
        } elsif ($token_type eq $TT_NUMBER
                 || $token_type eq $TT_WORD && $token eq $kw{quantity} ) {
            # A number specified as a word (e.g. one, or twenty-seven), or the
            # keyword 'quantity' which introduces a number
            my $qty_error_seen = 0;
            
            if ($token_type eq $TT_WORD && $token eq $kw{quantity}){
                # Keyword 'quantity', so expect quantifier next
                gnt();  # Get first token of quantifier
                if ($token_type eq $TT_NUMBER) {
                    # OK
                } elsif (   ($token_type eq $TT_LITERAL)
                         && ($literal_type eq $LT_CHAR || $literal_type eq $LT_SEQUENCE)
                         && ($token =~ / ^ \d+ $ /x)
                        ) {
                    # OK
                } else {
                    _error("Expected a quantifier after 'quantity', found: $token_raw");
                    $qty_error_seen = 1;
                }
            }
            if (defined $pl_ref->{min} ) {
                _error("Have already seen seen a quantifier on this line");
                $qty_error_seen = 1;
                gnt();
            } elsif ($token == 0 && $pl_ref->{optional} ) {
                _observation("Zero quantifier, but line was already optional");
            }
            if (! $qty_error_seen) {
                $line_has |= $LINE_HAS_QUANTIFIER;
                $pl_ref->{min} = $token;
                $pl_ref->{max} = $token;
                gnt();
                if ($token_type eq $TT_WORD) {
                    if ($token eq $kw{or} ) {
                        gnt();
                        if ($token_type eq $TT_WORD) {
                            if ($token_type eq $TT_WORD
                                && $token eq $kw{more} ) {
                                # Number or more
                                $pl_ref->{max} = 'more';
                                gnt();
                            } else {
                                _error("Expected 'more' or a number after 'or'");
                            }
                        } elsif ($token_type = $TT_NUMBER) {
                            if ( $token != $prev_prev_token + 1 ) {
                                _error("Numbers must be consecutive");
                                gnt();
                            } else {
                                # Number or Number
                                $pl_ref->{max} = $token;
                                gnt();
                            }
                        } else {
                            _error ("Expected a number or 'more' after 'or' in quantifier");
                        }
                    } elsif ($token eq $kw{to} ) {
                        gnt();
                        if ($token_type = $TT_NUMBER) {
                            if ($token < $prev_prev_token) {
                                _error("'to' number must not be smaller");
                                gnt();
                            } else {
                                # Number to Number
                                $pl_ref->{max} = $token;
                                gnt();
                            }
                        }
                    } else {
                        # Word after number is not 'or' or 'to', so assume
                        # that it is the start of the next chunk
                        if ( $pl_ref->{min} == 0) {
                            _error ("Quantifier 'zero' not followed by 'to' or 'or'");
                        }
                    }
                } else {
                    # Number followed by non-word
                    # Assume end of chunk
                }
            }
        } elsif ($token_type eq $TT_COMMENT) {
            debug ("# $token");
            $pl_ref->{comment} = $token;
            gnt();
        } elsif ($token_type eq $TT_ERROR) {
            _error("Don't understand: $token_raw");
            $ambiguity_seen = 1;
            gnt();
        } elsif ($token_type eq $TT_LITERAL) {
            $line_has |= $LINE_HAS_LITERAL;
            $line_has |= $LINE_HAS_SEQUENCE_LITERAL if $literal_type eq $LT_SEQUENCE;
   
            if ($line_has & $LINE_HAS_BEEN_NEGATED
                && $word_is_negated) {
                _error("Negated literal $token_raw not allowed when entire line negated");
            }
            if ($word_is_plural
                && ($line_has & $LINE_HAS_QUANTIFIER)
                && $pl_ref->{max} eq '1') {
                _error("Plural not allowed when max quantity is one: $token_raw");
            }

            my $pending_entry = {value   => $token,
                                 type    => $literal_type,
                                 plural  => $word_is_plural
                                            ### &&  ! defined $pl_ref->{min},
                                            &&  ! ($line_has & $LINE_HAS_QUANTIFIER),
                                            # Treat plural as singular if we have seen
                                            # an explicit numeric quantifier on this line
                                 negated => $word_is_negated,
                                 raw     => $token_raw,
                                };
            my $pending_is_single = $LIT_TYPE_SINGLE_CHAR{$literal_type};
            
            gnt();

            if ($token_type eq $TT_WORD
                && $token eq $kw{to}
                && $pending_is_single) {
                gnt();
                if (   $token_type eq $TT_LITERAL
                    && $LIT_TYPE_SINGLE_CHAR{$literal_type}) {
                    $pending_entry->{value} .= "-$token";
                    $pending_entry->{type}  =  $LT_RANGE;
                    push @{$pl_ref->{literal}}, $pending_entry;
                    gnt();
                } else {
                    _error("Expected single character after 'to', found: $token_raw");
                }
            } else {
                push @{$pl_ref->{literal}}, $pending_entry;
            }
        } elsif ($token_type eq $TT_ASSERTION) {
            $line_has |= $LINE_HAS_ASSERTION;
            if ( ($line_has & $LINE_HAS_BEEN_NEGATED)
                || $word_is_negated) {
                # Check whether this assertion can be part of a negated line
                # Also check $word_is_negated for individually negated assertions
                # e.g. non-word-boundary
                if ($line_has & $LINE_HAS_BEEN_NEGATED
                    && $word_is_negated) {
                    _error("Negated assertion $token_raw not allowed when entire line negated");
                } else {
                    if ($token_flags eq 'b') {
                        # word-boundary, or possibly some other negatable zero-width
                        $token = uc($token);
                    } else {
                        _error("Unimplemented: negated assertion: $token_raw");
                    }
                }
            }
            push @{$pl_ref->{literal}}, {value   => $token,
                                         type    => $LT_ASSERTION,
                                         flags   => $token_flags,
                                        };
            gnt();
        } elsif ($token_type eq $TT_MODE) {

            my $mode = substr($token_flags, 0, 1);

            if ( $line_has & $LINE_HAS_BEEN_NEGATED) {
                # Disallow overall-negated mode - the only one that makes any
                # sense is 'not case-sensitive', and its simpler to just have
                # to say 'case-insensitive'.
                _error("Negated mode is not allowed: $token_raw");
            }
            if ( $word_is_negated ) {
                if ($token_flags eq 'i-') {
                    # Allow 'non-case-sensitive' and 'non-cased'
                    $token_flags = 'i+';    # Flip the mode
                } else {
                    _error("Negated mode is not allowed: $token_raw");
                }
            }
            if ($line_has & $LINE_HAS_LITERAL) {
                _error("Mode is not allowed after a literal: $token_raw");
            }
            ## Need more checking here: overlapping d/u/a/l modes,
            ## case-sensitive + case-insensitive
            push @{$pl_ref->{modes}}, $token_flags;
            gnt();
        } elsif ($token_type eq $TT_WORD) {
            # It's a word, rather than a literal, number or range

            if ($token eq $kw{optional} ) {
                if ( defined $pl_ref->{min} && $pl_ref->{min} == 0) {
                    _observation("Optional, but already had zero quantifier on this line");
                }
                $line_has |= $LINE_HAS_OPTIONAL;
                $pl_ref->{optional} = 1;
                gnt();
            } elsif ($token eq $kw{minimal} || $token eq $kw{possessive} ) {
                if ($line_has & $LINE_HAS_QUANTIFIER ) {
                    $pl_ref->{greed} = $token eq $kw{minimal} ? 'minimal'
                                                              : 'possessive';
                } else {
                    _error("Only allowed after a quantifier: $token_raw");
                }
                gnt();
            } elsif (   $token eq $kw{followedby}
                     || $token eq $kw{followed}
                     || $token eq $kw{preceding}
                     || $token eq $kw{notfollowedby}
                     || $token eq $kw{notpreceding}
                     ) {
                if ($line_has & $LINE_HAS_QUANTIFIER ) {
                    _error("Not allowed after a quantifier: $token_raw");
                    
                } else {
                    $pl_ref->{look_direction} = 
                     (   $token eq $kw{followedby}
                      || $token eq $kw{followed}
                      || $token eq $kw{notfollowedby})
                                                    ? 'ahead'
                                                    : 'behind';
                    
                    if ($line_has & $LINE_HAS_BEEN_NEGATED) {
                        if (   $token eq $kw{notfollowedby}
                            || $token eq $kw{notpreceding}) {
                            # Double negative: 'not' and negative lookaround
                            _error("Double-negated lookaround: $token_raw");
                        } else {
                            # Line has 'not' but assertion is not negated
                            # Turn 'line negated' off so that it applies to the
                            # lookaround but not anything following
                            $line_has ^= $LINE_HAS_BEEN_NEGATED;
                            delete $pl_ref->{overall_negation};
                            $pl_ref->{look_match} =  'negative';
                        }
                    } else {
                        $pl_ref->{look_match} = ( $token eq $kw{notfollowedby}
                                               || $token eq $kw{notpreceding})
                                          ? 'negative'
                                          : 'positive';
                    }
                }

                if ($token eq $kw{followed}) {
                    gnt();
                    if ($token_type ne $TT_WORD || $token ne $kw{by}) {
                        _error("Expected 'by' after 'followed', found: $token_raw");
                    } else {
                        gnt();
                    }
                } else {
                    gnt();
                }
                
            } elsif ($token eq $kw{either} ) {
                if ($chunk_number != 1) {
                    _error("'either' must be the first thing on a line");
                } else {
                    $pl_ref->{either_start} = 1;
                }
                gnt();
            } elsif ($token eq $kw{or} ) {
                if ($chunk_number == 1) {
                    $pl_ref->{leading_or} = 1;
                } else {
                    if ($line_has & $LINE_HAS_LITERAL) {
                        # 'or' is a noise-word after a literal
                    } else {
                        _error("'or' is not allowed here");
                    }
                }
                gnt();
            } elsif (   $token eq $kw{capture}
                     || $token eq $kw{as}
                     || $token eq $kw{captureas} ) {
                $line_has |= $LINE_HAS_CAPTURE;
                $pl_ref->{capture_number} = ++$capture_count;
                if ($token eq $kw{capture}) {
                    gnt();
                }
                if ($token_type eq $TT_WORD
                    && ( $token eq $kw{as} || $token eq $kw{captureas} )
                   ) {
                    # [capture] as  or  capture_as, so get and check capture name
                    gnt();
                    #if ($token_type eq $TT_NUMBER) {
                    #    if ($token == $capture_count) {
                    #        $pl_ref->{capture} = $token_raw;
                    #    } else {
                    #        _error("capture as: number supplied does not match position");
                    #    }
                    #    gnt();
                    #} elsif ($token_type eq $TT_LITERAL) {
                    #    ## Literal might be a single digit ??
                    #    $pl_ref->{capture} = $token;
                    #    gnt();
                    #} elsif ($token_type eq $TT_WORD) {
                    #    # Word after 'as' - don't care even if it is a keyword
                    #    $pl_ref->{capture} = $token_raw;
                    #    gnt();
                    #}
                    if ($token_type eq $TT_NO_MORE) {
                        _error("capture as: name is missing");
                    } else {
                        $pl_ref->{capture} = $token_raw;
                        gnt();
                    }
                } else {
                    # Capture not followed by 'as'
                    $pl_ref->{capture} = '';
                    # No gnt() needed here - we are leaving the token to be
                    # processed as the start of the next chunk
                }
            } elsif ($token eq $kw{not} ) {
                if ($line_has & $LINE_HAS_LITERAL) {
                    _error("'not' must precede any literals on the same line");
                } elsif ($line_has & $LINE_HAS_BEEN_NEGATED) {
                    _error("More than one 'not'");
                } else {
                    $line_has |= $LINE_HAS_BEEN_NEGATED;
                    $pl_ref->{overall_negation} = 1;
                }
                gnt();
            } else {
                _error("Unrecognised word: $token_raw");
                $ambiguity_seen = 1;
                gnt();
            }
        }
        return 1 + $ambiguity_seen;
    } # end sub parse_chunk

} # end naked block for tokeniser

{
    my $generated_output;  # Global, used by _output() to accumulate output
    sub _output {
        my ($text) = @_;
        $generated_output .= $text;
    
    }
    sub clear_generated_output {
        $generated_output = '';
    }
    
    sub generated_output {
        return $generated_output;
    }
}

## These very crude error etc. handling routines are leftover from before this
## was a module. It needs refactoring:
##   - error (and other) text stored in the Wre object. 
##   - croak on error detected during non-oo call. Wrap call in eval if you
##     really need to handle errors
##   - default to croak() on error, as that implies the regex isn't really safe
##     to use, so it shouldn't just be left to execute whatever the erroneous
##     regex produces
##   - option to prevent croaking on error, e.g. when being called by a utility
##     that accepts a wordy as input and displays the result

sub _observation {
    my ($text) = @_;
    _output("Note: $text\n");
}
sub _warning {
    my ($text) = @_;
    _output("Warning: $text\n");    
}
sub _error {
    my ($text) = @_;
    _output("Error: $text\n");    
}
sub _trim {
    my ($text) = @_;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}

my $rule_mask;
sub detab{
    # Initialises a decision table
    # This is a very crude implementation of a rule-mask technique
    $rule_mask = "1" x 100;     # Arbitrary limit of 100 rules
}
sub a (&$) {
    my ($act, $mask) = @_;

    my $action_mask = $mask;
    $action_mask =~ tr/-Xx /011/d;

    my $result_mask =  "$action_mask" & "$rule_mask";
    $result_mask =~ tr/0//d;
    if ($result_mask) {
        $act->();
    }
}
sub c (&$) {
    # Decision table: condition

    # If relevant, apply condition mask
    #
    # It may be that the execution cost of deciding whether a condition is
    # relevant is higher than the cost of evaluating the condition: relevance
    # testing is done because:
    #   - some conditions may be untestable in some situations
    #   - conditions can be expensive to evaluate

    
    my ($cond, $mask) = @_;

    my $true_mask = $mask;
    $true_mask =~ tr/-YNTFyntf /110101010/d;
    my $false_mask = $mask;
    $false_mask =~ tr/-YNTFyntf /101010101/d;
    my $relevance_mask = $mask;
    $relevance_mask =~ tr/-YNTFyntf /011111111/d;
    if ("$relevance_mask" & "$rule_mask") {
        # Condition is relevant
        $rule_mask &= $cond->() ? "$true_mask" : "$false_mask";
        ## print "Rule mask now: $rule_mask\n";
    }
}

sub _letter_class {
    # Returns:
    #      1) The representation to use for a 'letters' type group
    #      2) True if representation needs character class
    # Passed:
    #   1) The normalised literal (letter, lc_letter, uc_letter)
    #   2) Perl 5.14 style Unicode status, or undef:
    #       u:     Must use Unicode
    #       a:     Must not use Unicode, assume ASCII
    #       d:     Use default/'depends' setting
    #       l:     Use locale
    #       undef: No preference - use whatever works, preferably the fastest
    #   3) Negation: True if negated form is wanted
    #
    #
    ## The list of unicode status values might be extended to include specific
    ## non-Unicode choices, e.g. 7-bit ASCII vs. 8-bit ASCII
    #
    ## The 'd' setting will differ from what \w will treat as word characters,
    ## as \w is word and this is explicitly letter
    my ($literal, $unicode, $negated) = @_;
    my ($uni, $non_uni) = ($literal eq 'letter'   ) ? ('Letter', 'A-Za-z')
                        : ($literal eq 'lcletter') ? ('Ll', 'a-z')
                        : ($literal eq 'ucletter') ? ('Lu', 'A-Z')
                        :                             ('err 3', 'err 3');
    $unicode = $unicode || 'a';
    if (defined $unicode) {
        if ($negated) {
            if ($unicode eq 'u') {
                return ("\\P{$uni}", 0);
            } else {
                return ("^$non_uni", 1);
            }
        } else {
            if ($unicode eq 'u') {
                return ("\\p{$uni}", 0);
            } else {
                return ("$non_uni", 1);
            }
        }
    } else {
        ## Won't happen while we default unicode to 'a'
        return (($negated ? '^' : '') . "$non_uni", 1);
    }
}

{ #Naked block for regex generator



sub _generate_regex {
# Passed:
#   1) Reference to root node of regex structure
#   2) Ref to options structure
#   3) Ref to ancestral information
#
# Returns:
#   1) Regex string
#   2) Required modes bit-map
#
#   The required-modes bit-map is the logical-or of the overall modes required
#   by this node and all its children. It is used when the entire generated
#   regex needs to have /s, /m and/or /p modes set because a lower level:
#       - uses dot to mean 'any character', or
#       - uses ^ or $ to mean start/end of line
#       - invokes the 'preserve' option 
#   These modes could be handled using mode-modifying spans, or by always having
#   at least /s and /m applied at the top level: the approach taken means they
#   are always at the top level and only present if the regex actually needs
#   them.
#
#   Other modes (such as case-insensitive, or ascii/unicode) are not handled by
#   this mechanism, because they need to be switched on and off as necessary.
#
# Ancestral information is used to pass information about the modes turned on or
# off at higher levels down to lower levels - the reverse of the 'required modes'
# bit-map which passes information upwards. Ancestral information is the net
# effect of all the ancestors information, so when processing the third line
# (A B digit) of:
#   ascii cased
#       two or three 
#           A B digit
#       zero or more uncased
#           D E F
# then ancestral information would be: ascii and cased.
# But for the fifth line (D E F), the cased would be overidden by the uncased,
# so its ancestral information would be uncased (but still ascii).
#
# Note that case-sensitivity is binary (it defaults to true at the top-level).
# Unicode/ascii can have five values to allow for Perl's options of /d /u /l /a
# and /aa.
#
# Modes passed via ancestral information are:
#   - case sensitivity
#   - ascii/unicode
#   - quoted space means whitespace
#
# OPTIONS
# -------
# Lots of options possible:
#   partial or full match
#       partial match (with sos/sol allowed)
#       full string match implied (opt warn if sos/sol present)
#   
#   target language + version
#   target engine
#       e.g. RE2
#            PCRE (implied for PHP?)
#   language-specific options
#       Perl:
#           emulate %+ for named captures
#           capture into named variables
#       JavaScript
#           generate string  '\\d\\\\\'   or regex  /\d\\/
#              depending on whether you want all your toothpicks falling the same way :-)
#   generate free-text (/x) regex
#   embed original comments
#   embed original regex as comments
#
# These options are global: they apply to the entire regex and generally only
# make any sense applied to the entire regex. The exception are the options to
# embed original comments or the original regex, and the free-text options - but
# there doesn't seem to be much reason to apply those to apply part of a regex,
# and switching them on and off would produce an extra confusing regex.
#
# They are also likely to be preferences that do not change, so they might best
# be handled by a config file that overrides the default settings, with the
# ability to also specify them on the invocation line. Priority would be
# highest from invocation-line, then config file, then lowest from system default

 
    my ($node_ref, $opts_ref, $ancestral_ref) = @_;

    my $re = '';
    my $re_class = '';  # C = capturing, G group-only, P = other parentheses
                        # A = Atomic, N = not atomic and not fully parenthesised
    
    my $RE_CLASS_CAPTURING   = 'C';
    my $RE_CLASS_GROUP       = 'G';
    my $RE_CLASS_OTHER_PAREN = 'P';
    my $RE_CLASS_ATOM        = 'A';
    my $RE_CLASS_NEITHER     = 'N';
    
    my ($has_capture, $has_optional, $has_mode, $has_quant, $group_type);
    my $mode_string;
    my $quant_text;
    my $capture_group_name = '';

    my $required_modes = 0;     # Bit-map of modes that will bubble up to top
    my $mode_string_on = '';    # Text for modes to turn on at this level
    my $mode_string_off = '';   # Text for modes to turn off at this level
    
    my $combined_ref = {};  # Start with an empty hash
    # Copy ancestral information

    $combined_ref->{case_insensitive} = $ancestral_ref->{case_insensitive};
    $combined_ref->{unicode}          = $ancestral_ref->{unicode}      || '';
    $combined_ref->{space_means}      = $ancestral_ref->{space_means}  || '';
    # Walk the modes entries (if any) in this node.
    # Compare requested mode with previous mode: if it differs, add an entry to
    # the mode string and set $has_mode to true
    
    for my $mode_flags ( @{$node_ref->{modes}} ){
        my ($mode_letter, $mode_action) = split('', $mode_flags);
        if ($mode_letter eq 'i') {
            # Case insensitivity
            if ($combined_ref->{case_insensitive}) {
                # Already case-insensitive
                if ($mode_action eq '-') {
                    $mode_string_off = 'i';
                    $combined_ref->{case_insensitive} = 0;  # Turn it off
                }
            } else {
                # Not case-insensitive
                if ($mode_action eq '+') {
                    $mode_string_on  = 'i';
                    $combined_ref->{case_insensitive} = 1;  # Turn it on
                }
            }
        } elsif ($mode_letter eq 'p') {
            $required_modes |= $REQUIRE_P_MODE;
        } elsif ($mode_letter eq 'U') {
            # Unicode modes can only be turned on
            if ($combined_ref->{unicode} ne $mode_action) {
                $mode_string_on = $mode_action;
                $combined_ref->{unicode} = $mode_action;
            }
        } elsif ($mode_letter eq 'S') {
            # space-means-?  ws/wss/space  1/+/-
            $combined_ref->{space_means} = $mode_action;
        } else {
            _error ("Internal error: mode_letter = $mode_letter");
        }
    }
    $has_mode = $mode_string_on || $mode_string_off;
    $mode_string = $mode_string_on
                 . ($mode_string_off ? "-$mode_string_off" : '');
    
    $has_capture = defined $node_ref->{capture};
    if ($has_capture) {
        $capture_group_name = $node_ref->{capture} || '';
        ##if ($target{does_capture_name}) {
        ##    $capture_group_name = $target{capture_name_start}
        ##                        . $capture_group_name
        ##                        . $target{capture_name_end};
        ##} else {
        ##    $capture_group_name = '';
        ##}
    }
    
    ## $has_capture, $has_optional, $has_mode, $has_quant, $group_type
    
    $has_optional = $node_ref->{optional};
    my $was_optional = 0;
    $has_quant    = defined $node_ref->{min};
    
    #  Coalesce optional with minimum if possible
    my ($quant_min, $quant_max);
    $quant_text = '';
    if ($has_quant) {
        $quant_min = $node_ref->{min};
        $quant_max = $node_ref->{max};
        if ($has_optional && $quant_min < 2) {
            $has_optional = 0;
            $was_optional = 1;
            $quant_min    = 0;
        }
    } else {
        # No quant.
        # Turn 'optional' to a quant, so that we can
        # handle optional/non-greedy
        if ($has_optional) {
            $has_optional = 0;
            $has_quant    = 1;
            ($quant_min, $quant_max) = (0,1);
        }
    }
    if ($has_quant) {
        # Work out {m,n} notation
        $quant_text = '{'
                      . $quant_min
                      . ','
                      . ($quant_max eq 'more' ? '' : $quant_max)
                      . '}'
                      ;
        
        #  {0,1}     ?
        #  {0,more}  *
        #  {1,more}  +
        if ($quant_min == 0) {
            if ($quant_max eq 'more') {
                $quant_text = '*';
            } elsif ($quant_max == 1) {
                $quant_text = '?';
            }
        } elsif ($quant_min == 1) {
            if ($quant_max eq 'more') {
                $quant_text = '+';
            } elsif ($quant_max == 1) {
                # min 1, max 1: no text needed
                $quant_text = '';
            }
        } elsif ($quant_min eq $quant_max) {
            $quant_text = "{$quant_min}";
        }
        #  Add ? for minimal, + for possessive
        if (defined $node_ref->{greed}) {
            $quant_text .= ($node_ref->{greed} eq 'minimal') ? '?'
                                                             : '+';
        }
    }
    my $child_count = 0;
    if (defined $node_ref->{'z_children'}) {
        $child_count = scalar @{$node_ref->{'z_children'}};
    }
    
    my $literal_count = 0;
    
    if (defined $node_ref->{literal}) {
        $literal_count = scalar @{$node_ref->{literal}};
    }
    
    if ($literal_count > 0) {
        # node has literals (and/or matchers)
        ##   a+  [ab]+  [^ab]+  \d+  \D+  [\d\s]+ [^\d\s]+
        ##  (?: A | cat )+  (?: a \b | [a\b] )+
        my @chars = ('', '');
        my @single_char = ('', '');
        my @leading_dash = ('', '');

        my @char_control = (0, 0);   # 0 = no chars,
                                # 1 = do not need to use character class
                                #     e.g. single non-negated character
                                #     or single possibly negated group (\D)
                                # >1 = must use character class
                                #      e.g. multiple characters   a b c
                                #           or negated character  non-tab [^\t]
                                #           or overall negation   not a b c [^abc]
                                #           or range              [a-g]
                                #           or backspace character [\b]
                                #           or some groups such as letter [A-Za-z] \p{L} \p{Letter}
                                #                            or lc-letter [a-z]    \p{Ll} \p{LowercaseLetter}
                                #                            or uc-letter [A-Z]    \p{Lu} \p{UppercaseLetter}
                                
        my $SINGULAR = 0;
        my $PLURAL   = 1;
        my $sing_or_plural = $SINGULAR;

        my $strings = '';
        my $string_count = 0;
        my $matcher_count = 0;
        my $overall_negated = $node_ref->{overall_negation} || 0;

 
                                            
        for my $lit_ref (@{$node_ref->{literal}}) {
            # for each literal/assertion
            my $lit_val     = $lit_ref->{value};
            my $lit_type    = $lit_ref->{type};
            my $lit_negated = $lit_ref->{negated};
            $sing_or_plural = $lit_ref->{plural} ? $PLURAL : $SINGULAR;

            my $encoding_for_space_non_class
                 = $combined_ref->{space_means} eq '+' ? '\\s+'  :
                   $combined_ref->{space_means} eq '1' ? '[\\s]' : 
                                                 $xsp  ? '[ ]'   : ' ';
            my $encoding_for_space_class
                 = $combined_ref->{space_means} eq '+' ? '\\s'   :
                   $combined_ref->{space_means} eq '1' ? '\\s'   :  ' ';
                   
            if ($LIT_TYPE_SINGLE_CHAR{$lit_type}) {
                 # Literal is a single char, or maybe a plural such as 'spaces'
                 # If it is a space, its meaning depends on whether it was
                 # specified as a quoted string (' ' or " ") or as the keyword
                 # 'space'. A quoted space is affected by space-means-x.
                 
                 if ($lit_ref->{raw} =~ /^ ['"] [ ] ['"] /x) {
                    # Literal was a single space, within quotes
                    if ($combined_ref->{space_means} eq '+') {
                        # space-means-wss here, so ' ' is a plural
                        $sing_or_plural = $PLURAL;
                        $encoding_for_space_non_class = '\\s';
                        $encoding_for_space_class = '\\s';
                    }
                 } else {
                    # Literal was not a quoted space
                    # Disable space-means-x stuff
                    $encoding_for_space_non_class = $xsp  ? '[ ]'   : ' ';
                    $encoding_for_space_class     = ' ';
                 }
                 
                $char_control[$sing_or_plural]++;
                
                if ($lit_type eq $LT_CHAR) {
                    # Not a pre-encoded character such as one specified by its
                    # hex value, or a control character
                
                    $single_char[$sing_or_plural] = _char_non_class_encode($lit_val, $encoding_for_space_non_class);
                    
                    if ($lit_val eq '-') {
                        $leading_dash[$sing_or_plural] = '-';
                    } else {
                        $chars[$sing_or_plural] .= _char_class_encode($lit_val, $encoding_for_space_class);
                    }
                } else {
                    $single_char[$sing_or_plural] = $lit_val;
                    $chars[$sing_or_plural] .= $lit_val;
                }
                if ($lit_negated || $overall_negated) {
                    $char_control[$sing_or_plural] = 2;
                }
                if ($lit_negated) {
                    ## This looks a bit hackish...
                    ## ...it forces character classes to be all negated,
                    ##    which is probably OK if multiple-negative are not
                    ##    allowed - but that error may not be being reported
                    $overall_negated = 1;   
                }
                if ($char_class_even_when_solo{$lit_val}) {
                    $char_control[$sing_or_plural] = 2; # Force character class
                }
            } elsif ($lit_type eq $LT_SEQUENCE) {
                # Literal is a string, but more than a single character
                # Encode any of the characters that needs it
                # The meaning of an embedded space depends on space-means-x
                $string_count++;
                my @string_chars = split('', $lit_val);
                #my @encoded = map { _char_non_class_encode($_) } @string_chars;
                my $encoded_val = '';
                for my $sch (@string_chars) {
                    $encoded_val .= _char_non_class_encode($sch, $encoding_for_space_non_class);
                }
                if ($strings) {
                    # Not first string
                    $strings .= $xsp . '|' . $xsp . $encoded_val;
                } else {
                    # First string
                    $strings = $xsp . $encoded_val;
                }
            } elsif ($lit_type eq $LT_RANGE) {
                $char_control[$sing_or_plural] = 99;
                $chars[$sing_or_plural] .= $lit_val;
                                                                                                  
            } elsif ($lit_type eq $LT_GROUP)  {
                if ($lit_val eq 'digit') {
                    $single_char[$sing_or_plural] = ($lit_negated || $overall_negated) ? "\\D" : "\\d";
                    $chars[$sing_or_plural] .= "\\d";
                    $char_control[$sing_or_plural]++;
                } elsif ($lit_val =~ /letter/) {
                    # We need to check whether we have Unicode defaulting,
                    # explicitly enabled or explicitly disabled to determine
                    # what we generate here.
                    #   default - whatever is easiest/fastest for this target??
                    #   explicitly Unicode             : e.g. \p{Letter}
                    #   explicitly not Unicode = ASCII : e.g. [A-Za-z]
                    
                    # Sometimes _letter_class() will return a string (such as
                    # \p{Letter} ) that will work inside or outside a character
                    # class: other times it will return a range (such as A-Z)
                    # that has to be within a character class
                    my ($force_class, $chars_format);
                    ($single_char[$sing_or_plural], $force_class) =
                                            _letter_class($lit_val,
                                                          $combined_ref->{unicode},
                                                          $lit_negated || $overall_negated);
                                            
                    ($chars_format, $force_class) =
                                       _letter_class($lit_val,
                                                     $combined_ref->{unicode},
                                                     0);
                    $chars[$sing_or_plural] .= $chars_format;                                
                    if ($force_class) {
                        $char_control[$sing_or_plural] = 99;
                    } else {
                        $char_control[$sing_or_plural]++;
                    }
                    if ($lit_negated) {
                        ## This looks a bit hackish...
                        ## ...it forces character classes to be all negated,
                        ##    which is probably OK if multiple-negative are not
                        ##    allowed - but that error may not be being reported
                        $overall_negated = 1;   
                    }
                } elsif ($lit_val eq 'wordch') {
                    $single_char[$sing_or_plural] = ($lit_negated || $overall_negated) ? "\\W" : "\\w";
                    $chars[$sing_or_plural] .= "\\w";
                    $char_control[$sing_or_plural]++;                                     
                } elsif ($lit_val eq 'character') {
                    $char_control[$sing_or_plural] = 1;
                    $single_char[$sing_or_plural]  = '.';
                    $chars[$sing_or_plural]        = '<internal error 2>';
                    ## $strings = $xsp . '.';  # any character, assuming /s mode
                    $required_modes |= $REQUIRE_S_MODE;
                } elsif (   $lit_val eq 'whitespace') {
                    $single_char[$sing_or_plural] = ($lit_negated || $overall_negated) ? "\\S" : "\\s";
                    $chars[$sing_or_plural] .= "\\s";
                    $char_control[$sing_or_plural]++;
                } elsif (   $lit_val eq 'genericnewline') {
                    if ($lit_negated || $overall_negated) {
                        _error("generic_newline is not allowed to be negated");
                    }
                    ##$single_char[$sing_or_plural] = "\\R";
                    ##$chars[$sing_or_plural] .= "\\R";
                    ##$char_control[$sing_or_plural]++;
                    # Generic newline is treated as a string as it is not
                    # allowed to go into a class
                    $string_count++;
                    $strings .= ($strings ? ($xsp . '|' . $xsp) : '')
                             . "\\R"
                             . ($lit_ref->{plural} ? '+' : '');
                } else {
                    _error("Unimplemented group: $lit_val");
                    ########## group, but unknown
                }
                
            } elsif ($lit_type eq $LT_ASSERTION)  {
                # Matcher: Zero-width assertion
                # It counts as a string for some purposes
                $string_count++;
                my $flags = $lit_ref->{flags} || '';
                $required_modes |= $REQUIRE_M_MODE if $flags eq 'm';
                ## $strings .= ($strings ? ($xsp . '|') : '') . $xsp . $lit_val;
                $strings .= ($strings ? ($xsp . '|' . $xsp) : '') . $lit_val;
            } elsif ($lit_type eq $LT_BACKREF)  {
                # Back-reference
                # It counts as a string for some purposes
                $string_count++;
                my $back_ref = '\\g{' . $lit_val . '}';
                $strings .= ($strings ? ($xsp . '|' . $xsp) : '') . $back_ref;
                
            } else {
                # Don't know what kind of literal this is
                _error("Unimplemented literal type: $lit_type");
            }
        }
        
        # If chars only or a single string then no parentheses needed
        
        my $parens_needed = 0;
        
        my @chars_present = (length($chars[$SINGULAR] . $leading_dash[$SINGULAR]) > 0,
                             length($chars[$PLURAL]   . $leading_dash[$PLURAL])   > 0
                            );
        if ( ($chars_present[$SINGULAR] + $chars_present[$PLURAL] + $string_count) > 1 ) {
            # More than one of singular chars/plural chars/strings
            $parens_needed = 1;
            $re = $xsp . '(?:';
            $re_class = $RE_CLASS_GROUP;
        }
        if ($strings) {

            $re .= $strings;
            if ($chars_present[$SINGULAR] || $chars_present[$PLURAL]) {
                $re .= $xsp . '|' . $xsp;
            }
        }
        if ($chars_present[$SINGULAR] || $chars_present[$PLURAL]) {
            # Either or both singular and pluralised characters
            
            for my $s_p ($SINGULAR, $PLURAL) {
                if ($chars_present[$s_p]) {
                    if ($char_control[$s_p] == 1) {
                        $re .= $single_char[$s_p] . ($s_p ? '+' : '');
                    } else {
                        my $char_class = '[';
                        $char_class .= '^' if $overall_negated;
                        $char_class .= $leading_dash[$s_p] . $chars[$s_p] . ']';
                        $re .= $char_class . ($s_p ? '+' : '');
                    }
                    if ($s_p == $SINGULAR && $chars_present[$PLURAL] ) {
                        $re .= $xsp . '|' . $xsp;
                    }
                }
            }
        }
        $re .= $xsp . ')' if $parens_needed;
    }

    if ($embed_source_regex) {
        $re .= $MAGIC_MARKER . '(' . 2 . ')' . ($node_ref->{a_raw_line} || '') . "\n";
    }
    # Node might have children - append their sub-regexes
    if ($child_count) {
        my $assembled = '';
        for my $child_ref (@{$node_ref->{'z_children'}} ) {
            # for each child
            my ($re_part, $x) = _generate_regex($child_ref, undef, $combined_ref);
            $required_modes |= $x;
            $assembled .= $re_part;
            debug ("assembled: $assembled");
        }
        $re .= $assembled;
    }

    # Decide content group code.
    #
    # We need to know whether the partial regex is fully-parenthesised, i.e.
    # whether there is a leading '(' and a trailing ')' that matches. We assume
    # that if there is more than one immediate child then the partial regex
    # will not be fully parenthesised.
    # C = Capturing parentheses
    # G = Group-only parentheses [ ## assuming Perl syntax for this]
    # P = Other parentheses (e.g. mode)
    # If it isn't parenthesised, we distnguish:
    # A = Atomic (a single character, or a single character class)
    # N = Not atomic (and not fully parenthesised)
    #
    # Note that some mis-classifications (such as N when it's really A) may be
    # acceptable, in that they may produce correct although sub-optimal regexes.

    ## Would be better to pass this back from the recursive calls but not set up
    ## to do this yet. The current method requires parsing of the generated
    ## regex, and this gets very messy to do accurately for multiple targets.

    my ($leading_left_paren, $trailing_right_paren,
        $leading_group_only, $leading_non_capture);
    
    if ($child_count > 1) {
        $group_type = 'N';
    } else {
        # Only one child, so possibly atomic or fully-parenthesised
        if ($xsp) {
            $leading_left_paren   = $re =~ / \A \s* [(]        /x;
            $leading_group_only   = $re =~ / \A \s* [(][?][:]  /x;
            $leading_non_capture  = $re =~ / \A \s* [(][?]     /x;
                        
            $trailing_right_paren = $re =~ /        [)] \s*
                                    (?: \Q$MAGIC_MARKER\E [^\n]* \n )?
                                                            \z /x;
        } else {
            $leading_left_paren   = $re =~ / \A     [(]        /x;
            $trailing_right_paren = $re =~ /        [)]     \z /x;
            $leading_group_only   = $re =~ / \A     [(][?][:]  /x;
            $leading_non_capture  = $re =~ / \A     [(][?]     /x;
        }
        if ($leading_left_paren && $trailing_right_paren) {
            # Has leading ( and trailing ) so possibly fully parenthesised
            # What we need to know is whether any embedded non-escaped ) matches
            # with the initial (.
            
            my $wk_re = $re;    # Copy partial regex as we are going to do
                                # destructive testing

            $wk_re =~ s/ \\ \\      //gx;   # Get rid of any escaped backslashes
            $wk_re =~ s/ \\ [()]    //gx;   # Get rid of any escaped ( or )
            $wk_re =~ s/   [^()]    //gx;   # Get rid of anything except ( or )
            $wk_re =~ s/ \A [(]     //x;       # Remove first (
            $wk_re =~ s/     [)] \z //x;    # Remove last )
            $wk_re =~ s/ \[ [^\]]+ \]    //gx; # Remove any character classes
                         
            while ($wk_re =~ //x) {
                $wk_re =~ s/ [(] [)] //gx;  # Remove paired ()
            }
            if ($wk_re eq '') {
                # Every embedded ) matched with an embedded (
                # so the partial regex is fully parenthesised
                if ($leading_non_capture) {
                    $group_type = $leading_group_only ? 'G' : 'P';
                } else {
                    # Leading capture
                    $group_type = 'C';
                }
            } else {
                # Not fully parenthesised
                $group_type = 'N';
            }
        } else {
            # Examine the regex to decide if it is atomic
  
            # Atomic is a single (possibly escaped) character
            # or a single character class
            # or a character group (such as \d or \w)
            # We can assume that the partial regex is a fully-formed regex
            
            ## What about \xnn or \nnn or \cX ??
            
            my $partial_regex = $re;
            $partial_regex =~ s/ \A \s+    //x if ($xsp);
            $partial_regex =~ s/    \s+ \z //x if ($xsp);    
            if ($xsp && $embed_source_regex) {
                $partial_regex =~ s/ \Q$MAGIC_MARKER\E
                                     [^\n]+ 
                                     \z       //gx;
            }
            if (  length $partial_regex == 1
                || length $partial_regex == 2
                   && substr($partial_regex, 0, 1) eq '\\'
                ) {
                # A single character - atomic
                $group_type = 'A';
            } elsif ($partial_regex =~ / \A \[ [^\]]+ \] \z /x) {
                # One character class - atomic
                $group_type = 'A';
            } elsif ($partial_regex =~ / \A \\ x
                                       (?: [0-9a-f]+ | [{] [0-9a-f]+ [}] )
                                       \z
                                       /x) {
                # Hex character class - atomic
                $group_type = 'A';                
            } else {
                $group_type = 'N';
            }
        }
    }
    
    # Action routines - usually invoked from decision table. Although some of
    # these are short enough to have been done directly within the decision
    # table, they are split out here for extensibility
    my $group_to_capture = sub {
        # Convert group-only parentheses that completely enclose
        # the partial regex to a capture group.
        # Assumes that the partial regex is fully-enclosed by a non-capturing
        # group: a non-fully capturing re such as (?: a )(?: b) would get
        # converted to ( a)(?: b) which captures the wrong stuff.
        
        # Change (?: to (
        
        $capture_name[$node_ref->{capture_number}] = $capture_group_name;
        if ($target{does_capture_name} && $capture_group_name ne '') {
            $re =~ s/ \A \s* [(] [?] [:] / (
                                            $target{capture_name_start}
                                            $capture_group_name
                                            $target{capture_name_end}
                                            /x; 
            ## $capture_group_name = $target{capture_name_start}
            ##                 . $capture_group_name
            ##                  . $target{capture_name_end};
        } else {
            $re =~ s/ \A \s* [(] [?] [:] / (  /x;
            # For targets that don't directly support named capture groups, we
            # need to be able to correlate capture names with capture numbers:
            # we have to count 'captures' to get this: Note that won't work for
            # targets that don't support non-capturing parentheses.
            #
            # For Perl prior to 5.10, we use Perl embedded code to do the named
            # capture into the %+ hash that Perl 5.10 uses.
            ## For Perl 5.8, the $^N syntax could be used instead of keeping
            ## track of the capture number 
            if ($target{early_perl_names}) {
                $re .= '(?{$+{'
                      . $capture_group_name
                      . '} = $'
                      . $node_ref->{capture_number}
                      . '}';
            }
        }
    };
    my $surround_with_capture = sub {
        # Surround the partial regex with a capture group.
        
        ## Should share some code with group_to_capture
        
        $capture_name[$node_ref->{capture_number}] = $capture_group_name;
        if ($target{does_capture_name} && $capture_group_name ne '') {
            $re = '(' . $target{capture_name_start}
                      . $capture_group_name
                      . $target{capture_name_end}
                      . $re
                      . ')'
                      ;
                                            
           ## $capture_group_name = $target{capture_name_start}
           ##                     . $capture_group_name
           ##                     . $target{capture_name_end};
        } else {
            # It's an unnamed capture, or target doesn't directly support named captures
            # So we do a plain capture
            $re = '(' . $re . ')';
            # For targets that don't directly support named capture groups, we
            # need to be able to correlate capture names with capture numbers:
            # we have to count 'captures' to get this: Note that won't work for
            # targets that don't support non-capturing parentheses, or number
            # captures differently from Perl
            #
            # For Perl prior to 5.10, we use Perl embedded code to do the named
            # capture into the %+ hash that Perl 5.10 uses.
            if ($target{early_perl_names} && $capture_group_name ne '') {
                ## e.g. (?{$+{punc} = $1})
                $re .= '(?{$+{'
                      . $capture_group_name
                      . '} = $'
                      . $node_ref->{capture_number}
                      . '})';
            }
        }
    };
    my $group_to_mode = sub {
        # Convert a group-only fully-parenthesised partial regex to one that has
        # mode(s)
        if ($re =~ / \s* [(][?]: /x) {
            $re =~ s/[(][?]:/(?$mode_string:/;
        } else {
            _error("Internal error: missing left parenthesis");
        }
    };
    my $surround_with_mode = sub {
        # Surrounds the partial regex with a mode-modifying span
        $re = "(?$mode_string:" . $re . ")";
    };
    my $surround_with_group = sub {
        # Adds group-only parentheses around the partial regex
        $re = '(?:' . $re . ')';
    };

    my $append_quant_if_any = sub {
        # Appends any quamtifiers, laziness or atomicity to the partial regex
        # The quantifiers may have had 'optional' coalesced, e.g. if they were
        # {1,3} but there was also an 'optional', we use {0,3}
        $re .= $quant_text;
    };

    my $append_qmark_if_opt = sub {
        # Appends a question mark if the line has 'optional', and that
        # has not been coalesced with a quantifier
        $re .= '?' if $has_optional;
    };
    
    
    # This decision table specifies the rules for handling regex generation
    # intended to produce regexes with minimal extra levels of parentheses, so
    # as to be similar to the hand-coded equivalent.
    #
    # This is a very Perl-centric initial version. Given the complexity, it is
    # likely that the best approach for different target regex engines will be
    # to create a separate decision table for each: the problem is hard enough
    # for even a single target, unless the targets are very closely related 
    # (e.g. PCRE and Perl).
    #
    # Assumes the hierarchy capture->optional->quantifiers, so that e.g.:
    #    two or three capture digit    possibly expecting (\d){2,3}
    # would treated as if it were:
    #    capture two or three digit    actually producing (\d{2,3})
    # The hierarchy *should* have been enforced by the parser
    #                                               1 1 1 1 1 1 1 1 1 1 2
    #                             1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0
    detab();
    c {$has_capture           } ' Y Y Y Y Y Y N N N N N N N N N N N N N N ';
    c {$has_optional          } ' - - - - - - N N N N N Y Y Y Y Y Y Y Y Y ';
    c {$has_mode              } ' N N Y Y N N N N N Y Y N N N N Y Y Y Y Y ';
    c {$has_quant             } ' N N - - Y Y N Y Y - - N N Y Y Y Y Y N N ';
    c {$group_type eq 'G'     } ' N Y N Y - - - - - Y N - - - - - Y N N Y ';
    c {$group_type eq 'N'     } ' - - - - N Y - N Y - - N Y N Y Y - N - - ';
    
    a {&$group_to_capture     } ' - X - - - - - - - - - - - - - - - - - - ';
    a {&$group_to_mode        } ' - - - X - - - - - X - - - - - - X - - X ';
    a {&$surround_with_mode   } ' - - X - - - - - - - X - - - - X - X X - ';
    a {&$surround_with_group  } ' - - - - - X - - X - - - X - X - - - - - ';
    a {&$append_quant_if_any  } ' - - X X X X - X X X X - - X X X X X - - ';
    a {&$surround_with_capture} ' X - X X X X - - - - - - - - - - - - - - ';
    a {&$surround_with_group  } ' - - - - - - - - - - - - - X X X X X - - ';
    a {&$append_qmark_if_opt  } ' X X X X X X - - - - - X X X X X X X X X '; 
    
    if (defined $node_ref->{look_direction}) {
        # This node has a look-ahead or look-behind assertion
        my $look_start = $node_ref->{look_direction} eq 'ahead' ? '(' : '(<';
        $look_start   .= $node_ref->{look_match} eq 'positive'  ? '=' : '!';
        $re = $look_start . $re . ')';
    }
    
    
    if ($node_ref->{either_start} ) {
        # Start of alternation
        $re = "(?:" . $xsp . $re;
    }
    if ($node_ref->{leading_or} ) {
        # Another alternative
        $re =  $xsp . "|" . $xsp . $re;
    }
    if ($node_ref->{either_end} ) {
        # End of alternation
        $re .= $xsp . ')';
    }
    debug ("returning re: $re");
    my $child_structure_ref = {};
    return ("$re", $required_modes);
}

=format

group_to_capture
group_to_mode
surround_with_group
surround_with_mode
append_quant_if_any
surround_with_capture
surround_with_group
append_qmark_if_opt
                                          1 1 1 1 1 1 1 1 1 1 2
                        1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0
Capture                 Y Y Y Y Y Y N N N N N N N N N N N N N N
Optional                - - - - - - N N N N N Y Y Y Y Y Y Y Y Y
Modes                   N N Y Y N N N N N Y Y N N N N Y Y Y Y Y
Quantifiers             N N - - Y Y N Y Y - - N N Y Y Y Y Y N N
Grouping Code G         N Y N Y - - - - - Y N - - - - - Y N N Y
Grouping Code N         - - - - N Y - N Y - - N Y N Y Y - N - -

Change (?: to (         - X - - - - - - - - - - - - - - - - - -
Change (?: to (mode     - - - X - - - - - X - - - - - - X - - X
Surround with (?: )     - - - - - X - - X - - - X - X - - - - -
Surround with (mode )   - - X - - - - - - - X - - - - X - X X -
Append quant if any     - - X X X X - X X X X - - X X X X X - -
Surround with ( )       X - X X X X - - - - - - - - - - - - - -
Surround with (?: )     - - - - - - - - - - - - - X X X X X - -
Append ? if optional    X X X X X X - - - - - X X X X X X X X X

=cut
#---------------------------------------

} # End naked block for regex generator


sub _char_class_encode {
    # Returns the character class entry for a single character
    
    my ($ch, $space_option) = @_;
    my $encoded_ch = _char_encode($ch);
    
    if (length $encoded_ch > 1) {
        # _char_encode has already escaped the character
        return $encoded_ch;
    }
    # Decide if we need to encode because it will be within a character class
    if (   $encoded_ch eq $regex_starter
        || $encoded_ch eq $regex_finisher) {
        # Using this character to delimit regex
        ## It might not be strictly necessary to escape the starting delimiter
        ## if it differs from the finishing delimiter
        return "\\$encoded_ch";
    }
    if ($encoded_ch eq ' ') {
        $encoded_ch = $space_option;
    } elsif ( $encoded_ch =~ / [ \[ \] \\ \$ \@ \^ ] /x) {
        # regex above has spaces only for readability        
        # One of the meta-characters that need escaping, even inside a
        # character class
        return "\\$encoded_ch";
    }
    return $encoded_ch;
}
#---------------------------------------
sub _char_non_class_encode {
    # Returns the representation for a single character outside a character class
    
    my ($ch, $space_option) = @_;
    my $encoded_ch = _char_encode($ch);
    my $BACKSLASH_B_MUTATES = 1;    # True for Perl: backspace within character
                                    #   class, word boundary outside
    if ($ch eq "\b" && $BACKSLASH_B_MUTATES) {
        # It is a backspace, and \b is not backspace outside char classes
        return "\\x" . sprintf('%02x', ord($ch));
    }
    if (length $encoded_ch > 1) {
        # _char_encode has already escaped the character
        return $encoded_ch;
    }
    # Decide if we need to encode it outside a character class
    if (   $encoded_ch eq $regex_starter
        || $encoded_ch eq $regex_finisher) {
        # Using this character to delimit regex
        ## It might not be strictly necessary to escape the starting delimiter
        ## if it differs from the finishing delimiter
        return "\\$encoded_ch";
    }
    if ( $encoded_ch ne ' ' && $encoded_ch =~ / [ \[ \] \\ \$ \@ \^ .+*?#|(){} ] /x) {
        # regex above has spaces only for readability
        # One of the meta-characters that need escaping outside a character class
        return "\\$encoded_ch";
    }
    if ($encoded_ch eq ' ' && defined $space_option) {
        return $space_option;
    }
    return $encoded_ch;
}
#---------------------------------------
sub _char_class_to_non_class {
    # Converts a one-character class to the equivalent outside of a class
    # In most cases, no change
    # Some characters that are meta outside but not in, so they get escaped
    # \b (backspace) 
}
#---------------------------------------
sub _char_encode {
    # Returns the char equivalent to a single character
    # e.g. unchanged for printable ASCII characters (including space) \x20 to \x7E
    #      \n for newline
    #      \t for tab
    #      \e for escape
    #      \b for backspace ### only within character classes ###
    #      \r for carriage return
    #      \f for form feed
    #      \a for bell/alarm
    #      \cA to \cZ for other ASCII control characters \x01 to \x1A 
    #      \xnn for other ASCII control characters, \x00, \x1B to \x1F, \x7F
    #      \xnn for other ASCII control characters  \x80 to \xA0, \xAD
    #      unchanged for characters \xA1 to \xFF except for \xAD (option Latin-1 Supplement?)
    #           A0 (non-breaking space) and AD (soft hyphen) are shown in hex as
    #           their glyphs are identical to ordinary space and hyphen
    #      \x{nnnn} for any other character
    
    my ($ch) = @_;
    my %basic = ("\a" => "\\a",
                 "\b" => "\\b",
                 "\e" => "\\e",
                 "\f" => "\\f",
                 "\n" => "\\n",
                 "\r" => "\\r",
                 "\t" => "\\t",
                 );
    ## return '\x0a' if $ch eq '\x0A';  # Hack for line-feed
    return $ch unless length $ch == 1;
    return $basic{$ch} if $basic{$ch};
    my $ord = ord($ch);
    my $hex = sprintf('%2x', $ord);
    if ($ord >= ord("\cA") && $ord <= ord("\cZ") ) {
        my $ctrl_letter = chr( $ord + ord("A") - 1 );   # \cA is \x01, etc.
        return "\\c$ctrl_letter";
    }
    return $ch if $ch =~ / [\x20-\x7E \xA1-\xAC \xAE-\xFF] /x;
    return "\\x" . (length($hex) == 2 ? "$hex" : '{' . sprintf('%4x', $ord) . '}');
    
}

#---------------------------------------
sub _split_regex {
    # Passed a regex with embedded original text, each starting with a magic
    # original marker and ending at the next newline. If the original text has
    # comments, they follow the magic original marker and the original text, and
    # are indicated by a magic comment marker.
    #
    # The magic original marker is a sequence that would not be generated as
    # part of a regex, that indicates the start of the original text and the
    # indent level.
    #
    # The magic comment marker is a sequence that would not be generated as
    # part of a regex, that indicates the start of a comment and the indent
    # level.
    #
    # Returns a functionally-equivalent regex with additional spaces:
    #   - at the start of each line
    #   - between the end of the non-comment text and the comment
    #
    # It may also add additional newlines, where the non-comment text extends
    # past the point chosen as the vertical dividing line between the actual
    # regex and the comments.
    #
    # If the original text and comment fit within the output line width, the
    # comment will be appended to the same line.
    #
    # If the comment would start or extend beyond the output line width, it will
    # be placed on a separate line.
    #
    # The result should be a regex with the actual regex indented, then a
    # vertical line of comment markers and then the original regex with its
    # original indentation.
    #
    # Method
    # ------
    # Ideally, it would pre-analyse the input and decide on the best position
    # for the division between the generated and the original regex. For now,
    # we just have a constant that is a reasonable compromise.
    #
    # 
    my ($regex_text) = @_;
    my $div_pos = 30;
    my $target_width = 80;
    my @lines = split(/ \n /x, $regex_text);
    my $out_text = '';
    my $indent_level = 0;
    
    my $no_terminal_newline = (substr($regex_text, -1, 1) ne "\n");
    
    for my $in_line (@lines) {
        my ($gened, $param, $rest, $orig);
        my $orig_comment = '';
        my $out_line = '';    
        if (($gened, $param, $rest) = $in_line =~ /
            (.*)              # capture zero or more any-char
            \Q$MAGIC_MARKER\E # '#MAGIC^MARKER#'
            [(]               # (
            ( [^)]+ )         # capture one or more not )
            [)]               # )
            (.*)              # capture zero or more any-char
                                               /x ){
            # The line has original regex appended
            my $gened_indented = (' ' x $indent_level) . $gened;
            my $gened_len = length($gened_indented);
            $out_line .= $gened_indented;
            
            ($orig, $orig_comment) = $rest =~ /
                          (.*)                  # capture zero or more any-char
                          (?:                   # optional 
                              magic-comment     #     'magic-comment'
                              (.*)              #     capture zero or more any-char
                          )? 
                                              /x;
                                                                                                # optional

            if ($gened_len >= $div_pos) {
                # gened already extends past divider
                $out_text .= $out_line . "\n";
                $out_line = '';
                $gened_len = 0;
            }
            $out_line .= ' ' x ($div_pos - $gened_len);
            $out_line .= '# ';
            if (length($rest) < ($target_width - $div_pos)
                || length($orig_comment || '') == 0) {
                # Can fit orig & comment on same line, or no comment present
                $out_line .= $rest;
            } else {
                # original & comment is wider than we want
                $out_line .= $orig;
                $out_text .= $out_line . "\n";
                $out_line = (' ' x $target_width) . '## ' . $orig_comment;
            }
            
        
        } else {
            # No original regex - just gened
            $out_line .= ' ' x $indent_level;
            $out_line .= $in_line;
        }
        $out_text .= $out_line . "\n";
    }
    chomp $out_text if $no_terminal_newline;
    if ($xsp) {
        $out_text =~ s/ ^ \Q$xsp\E //x;# Hack a leading space off
    }
    return $out_text;
}

#---------------------------------------
sub _report_error_position {
        my ($line, $pos, $msg) = @_;
                    _output("$line");
                    _output(' ' x $pos);
                    _output("^\n");
                    _output(' ' x $pos);
                    _output("|\n");
                    _output("$msg\n");

}

#---------------------------------------
sub leading_spaces {
    
    # Count leading spaces.
    # Tabs are treated as inserting between one and four spaces, taking the
    # number of spaces to a multiple of four.
    #
    my ($line_to_check) = @_;
    $line_to_check = $line_to_check || '';
    my ($leading_whitespace) = ($line_to_check =~ m/ ^ ( [ \t]* )/x );
    
    if ($leading_whitespace =~ / ^ [ ]* $ /x) {
        # Just spaces, so it's easy
        return  length($leading_whitespace);
    }
    # We must have some tabs, possibly mixed with spaces
    if ($leading_whitespace =~ / ^ [\t]+ $ /x) {
        # Just tabs, so it's easy
        return  length($leading_whitespace) * 4;
    }
    # Mixed tabs and spaces. Generally considered not good practice, but we do
    # our best to handle it...
    
    my $space_count = 0;
    while ($leading_whitespace =~ / (.) /gx ) {
        my $ws = $1;
        if ($ws eq ' ') {
            $space_count++;
        } else {
            # Must be a tab
            $space_count = ($space_count - ($space_count % 4) ) + 4;
        }
    }
    return $space_count;
    
}

#---------------------------------------

sub _wre_to_tre {
    # Intent:
    #   Internal routine providing wordy to terse regex conversion, for use
    #   by public functions or methods.
    # Passed:
    #   - a string containing a complete wordy regular expression
    #   - any options that don't form part of the input regex
    # Returns:
    #   - a string containing the equivalent conventional regular expression
    #   - a code indicating whether there were any errors, warnings or observations
    #   - if no errors or warnings: a null string
    #     Otherwise, a string (typically multi-line) containing the input wre
    #     with each line prepended with its line numbers and a colon,
    #     interspersed with any error or warning lines prepended with error: or
    #     warning:
    #   
    # Options:
    #   Passed in as a reference to a hash
    #   Implemented:
    #       free_space     (boolean)
    #       embed_original (boolean)
    #       wrap_output    (boolean)
    #       regex_delimiters (one character, or a matched pair)
    #   Candidate stuff:
    #   - Source details:
    #       Text format: 
    #           Pure text
    #           Perl source text, double-quoted (interpolation, escapes)
    #           Perl source text, single-quoted (escapes for \ and ')
    #       Regex options:
    #           Any options not supplied embedded in the wre itself.
    #           e.g. match_part/match_all
    #   - Target environment
    #       - language
    #       - language version
    #       - target format
    #     
    #   - Indented Regex version
    #       - Perl-style dotted version number
    #       - Means that the syntax and semantics of the specified version apply
    #   - Preferences (over-riding default preferences)
    #       e.g.
    #       - do not generate output regex in x-mode
    #       - do not pass comments through to generated regex
    #       - report named captures as errors if not natively supported, even if
    #         there is a workaround in the target environment to support them
    #       - do not embed the original indented regex as comments in the
    #         generated regex
    
    
    my ($ire_string, $arg_options_ref) = @_;

    my $options_ref = defined $arg_options_ref ? $arg_options_ref : {};
    
    my $free_space       = $options_ref->{'free_space'};
    my $embed_original   = $options_ref->{'embed_original'};
    my $wrap_output      = $options_ref->{'wrap_output'};
    my $regex_delimiters = $options_ref->{'regex_delimiters'};
    
    $GENERATE_FREE_SPACE_MODE = defined $free_space     ? $free_space     : 1;
    $EMBED_ORIGINAL_REGEX     = defined $embed_original ? $embed_original : 1;
    $WRAP_WITH_DELIMITERS     = defined $wrap_output    ? $wrap_output    : 1;
    
    if (defined $regex_delimiters) {
        if (     length $regex_delimiters == 1) {
            $regex_starter  = $regex_delimiters;
            $regex_finisher = $regex_delimiters;
        } elsif (length $regex_delimiters == 2
                 && $regex_delimiters =~ / [{] [}] | [(] [)] | < > | [[] []]  /x
                 ) {
            ($regex_starter, $regex_finisher) = split(//, $regex_delimiters);
            
        } else {
            _error("Invalid regex delimiters: $regex_delimiters");
        }
    }
    
    $xsp = $GENERATE_FREE_SPACE_MODE ? ' ' : '';   # Space for use within regex when in /x mode
    $embed_source_regex = $EMBED_ORIGINAL_REGEX
                      && $GENERATE_FREE_SPACE_MODE; # Only possible if /x mode

    my %char_class_even_when_solo = (' ' => $xsp ? 1 : $put_solo_space_into_class,
                                 '(' => $prefer_class_to_escape,
                                 ')' => $prefer_class_to_escape,
                                 '|' => $prefer_class_to_escape,
                                 '.' => $prefer_class_to_escape,
                                 '+' => $prefer_class_to_escape,
                                 '?' => $prefer_class_to_escape,
                                 '*' => $prefer_class_to_escape,
                                 '^' => $prefer_class_to_escape,
                                 );
    load_ire_lines($ire_string);
    clear_generated_output();
    
    my $root_node = {desc             => 'root',
                     lazy             => 0,
                     case_insensitive => 0,
                     optional         => 0,
                     z_children       => [] };

    my ($ml_line, $ml_indent, $ml_comment_lines) = read_line();
    if (defined $ml_line) {
        my ($returned_line, $returned_indent, $returned_comment_lines) =
             process_line($ml_line, $ml_indent, $ml_comment_lines, $root_node);
    }    
      
    ### NEEDS A BETTER WAY OF DETECTING THIS CONDITION ###
    ### Maybe a return value from process_line?        ###
    #if (defined $ml_line) {
    #    # Bad indentation - something less indented than first line
    #    print "Initial indentation error\n";
    #}
    
    
    my ($regex, $overall_modes) = _generate_regex($root_node);

    if ($overall_modes || $wrap_output) {
        my $mode_text = '';
        
        $mode_text .= 'p' if  $overall_modes & $REQUIRE_P_MODE;
        $mode_text .= 's' if  $overall_modes & $REQUIRE_S_MODE;
        $mode_text .= 'm' if  $overall_modes & $REQUIRE_M_MODE;
        $mode_text .= 'x' if ($overall_modes & $REQUIRE_X_MODE) || $xsp;
        
        if ($wrap_output) {
            $regex = $regex_starter . $regex . $regex_finisher . $mode_text;
        } else {
            $regex = '(?' . $mode_text . ':' . $xsp . $regex . $xsp . ')';
        }
    }
    
    my $reformatted = _split_regex($regex);
    _output( "$reformatted");

    return generated_output();
        
    
    
}

#---------------------------------------
sub main_line {
    # Reads a wre from a file, generates and prints a conventional regex

   
    my $wre = slurp_stdin();
    print (_wre_to_tre($wre, {free_space => 1}) );
    print "\n------------------------\n";
    print (_wre_to_tre($wre, {free_space => 0}) );
    print "\n------------------------\n";
    my $pause = 'end of program';
}
#---------------------------------------
sub process_line {
    
    my ($pl_line, $pl_indent, $pl_comment_lines, $parent_ref) = @_;
    my $starting_indent = $pl_indent;
    
    my $or_required = 0;
    my $or_allowed  = 0;
    my $has_or;
    my $has_either;
    
    my $expecting_children = 0;
    my $elder_sibling_ref = undef;  # The child before me
    my $chunker_found_then = 0;

    my $start_pos = 0;
    
    LINE_OR_THEN:
    while ($pl_indent >= 0 &&
               $pl_indent >= $starting_indent) {
    ## do {
        # Process the current line, and any line at the same level.
        # Nested lines (children) are handled by recursive calls.
        # Each iteration of this do loop handles a complete line, except that
        # the keyword 'then' causes a pseudo line end.
        
        # Either/or is handled partly at this level, as it does not follow the
        # standard indented block structure: the end of an either/or sequence is
        # marked by a non-or line equally indented, or any line less indented.
        
        # Parse the current line
        # Add new_child to parent
        my $child_ref = {}; # New child is empty hash
        push @{$parent_ref->{z_children}}, $child_ref;
        ##$child_ref->{a_raw_line} = ' ' x $pl_indent . $pl_line;
            

            
        if (not $chunker_found_then) {
            give_line_to_tokeniser($pl_line);
            gnt();  # get first token of current line
            ## Base either/or on the first token. If this isn't sufficient (e.g. for
            ## languages where the first token isn't definitive), then change this
            ## to special-case the first parse_chunk.
            $has_or     = token_is_kw('or'    );
            $has_either = token_is_kw('either');
        }

        
        my $chunk_number = 0;
        my $chunk_result;
        my $chunk_error_count = 0;

        
        # Parse all the chunks in a complete line, except stop at 'then'

        while ( $chunk_number++ < 2000 && (($chunk_result = parse_chunk($child_ref, $chunk_number)) > 0 ) ) {
            $chunk_error_count++ if $chunk_result > 1;
        }
        if ($chunk_number >= 2000) {
            _output("Internal Error: runaway chunker: $pl_line\n");
            return ($pl_line, -1, '');
        }
        my $end_pos = token_pos();
        
        $child_ref->{a_raw_line} = 
            ' ' x ($pl_indent + $start_pos) . substr($pl_line, $start_pos, $end_pos - $start_pos);
        
        if ($chunk_result < 0) {
            # 'then' found, so end of sub-line
            $chunker_found_then = 1;
            $start_pos = token_pos();
            reset_line_flags();
            
            ## Checks here:
            ##  Allow 'then' as first word on line: $chunk_number == 1 && $start_pos == 0
            ##  Otherwise
            ##     error if 'then' was last token on line: $token_type eq $TT_NO_MORE or $TT_COMMENT
            ##     error if no matchers in partial line preceding 'then'
            
            if ($chunk_number == 1 && token_start_pos() == 0) {
                # 'then' at start of complete line is OK
                gnt();  # Skip the 'then' so the next token is available as expected
            } else {
                gnt();  # Skip the 'then' so the next token is available as expected
                if (token_type() eq $TT_NO_MORE || token_type() eq $TT_COMMENT) {
                    # 'then' was last non-comment token on line
                    _error("'then' should not end a line");
                } elsif (defined $child_ref->{literal}) {
                    # OK, previous sub-line had some matcher(s)
                } else {
                    _error("No matcher found before 'then'");
                }
            }
            
            next LINE_OR_THEN;  # ----------->>>>>>>>>>>>
        } else {
            $chunker_found_then = 0;
        }

        if (  $or_required && ! $has_or) {
            _output("Error - missing or: $pl_line\n");
            
        }
        if (! $or_allowed   &&   $has_or) {
            _output("Error - unexpected or: $pl_line\n");
        }
        
        if ($or_required || $or_allowed) {
            if ( ! $has_or ) {
                # The end of an either
                if (defined $elder_sibling_ref ) {
                    $elder_sibling_ref->{either_end} = 1;
                }
            }
        }
        # Require children if no literals, otherwise forbid them
        
        # If we had an error (such as an unrecognised word)
        # and there no valid literals before or after the error
        # then we don't know whether or not to allow indentation.
        #
        # If an unrecognised word was supposed to be a literal
        # (e.g. spaxes) then it would not have anything indented: if
        # it was supposed to be 'capture' and it had no literals then it
        # would have lines indented.
        #
        # The main issue is spurious 'Expected indented lines...' errors.
        
        $expecting_children = ( not defined $child_ref->{literal});
        # Require next line at this level to be 'or' if this one is 'either'
        $or_required        = $has_either;
        # Allow next line at this level to be 'or' if this one is 'either' or 'or'
        $or_allowed         = $has_either || $has_or;

        ($pl_line, $pl_indent, $pl_comment_lines) = read_line();
        $start_pos = 0;
        
        if ($expecting_children) {
            # Did not see any literals on previous line
            if ($pl_indent > $starting_indent) {
                ($pl_line, $pl_indent, $pl_comment_lines) = process_line($pl_line, $pl_indent, $pl_comment_lines, $child_ref);
            } else {
                if ($chunk_error_count == 0) {
                    _error("Expected indented lines, but there are none");
                }
            }
        } else {
            # Not expecting children (saw literal(s))
            if ($pl_indent > $starting_indent) {
                _error("Indented line is not allowed here");
            } else {
                # No children
            }
        }
        # Back to same level, or maybe back out further

        if ($pl_indent == $starting_indent && defined $pl_line) {
            ## _output("same level: $pl_line\n");

        } elsif ($pl_indent < $starting_indent) {
            # Outdent here, check if we just had an 'either'
            if ($or_required) {
                _output("Error: missing 'or' at end of block: $pl_line\n");
            }
            if ($or_required || $or_allowed) {
                # Outdent here, check if we just had an 'either' or an 'or'
                ### $elder_sibling_ref->{either_end} = 1; ### ??? ###
                $child_ref->{either_end} = 1;
            }
        }
        $elder_sibling_ref = $child_ref;
    }   
    return ($pl_line, $pl_indent, $pl_comment_lines);
}
#---------------------------------------
sub slurp_stdin {
    
    local $/;
    undef $/;
    my $stdin_contents = <>;
    return $stdin_contents;
}
#---------------------------------------
sub slurp_file {
    # Passed filename, returns entire contents and error text
    # If called in scalar context, returns file contents, or undef if error
    
    my ($filename) = @_;
    my ($fh, $file_contents, $error_text);
    if (open($fh, '<', $filename)) {
        local $/;
        undef $/;
        $file_contents = <$fh>;
    } else {
        $error_text = "Could not open $filename for reading: $!\n";
    }
    return wantarray ? ($file_contents, $error_text) : $file_contents;
}
#---------------------------------------
#---------------------------------------
{
    # Variables for use by read_line, load_ire_lines
    my @ire_lines;
    
    sub load_ire_lines {
        # Passed a string contining a wre
        # Splits it into lines and stores them in the shared array
        # Re-initialiises other read_line variables as necessary
        
        my ($ire_lines_string) = @_;
        @ire_lines = split( /\n/, $ire_lines_string);
    }
    sub read_line {
        my $rl_line = shift @ire_lines;
        my $rl_indent = 0;
        my $rl_comment_lines = '';
        
        if ( ! defined $rl_line) {
            return ($rl_line, -1, '');
        }
        while (defined $rl_line && $rl_line =~ m/ ^ \s* (?: [#\n] | \z )  /x) {
            # Skip whitespace-only and comment-only lines
            $rl_comment_lines .= $rl_line;
            $rl_line = shift @ire_lines;
        }
        if (defined $rl_line) {
            chomp $rl_line;
            $rl_indent = leading_spaces($rl_line);  # Count leading spaces or
                                                    #  equivalent of tabs
            $rl_line =~ s/ ^ [ \t]+ //x;     # Discard leading spaces and tabs
        } else {
            $rl_indent = -1;
        }
        return ($rl_line, $rl_indent, $rl_comment_lines);
    }
}

sub normalise_hash_keys {
    my ($hash_ref) = @_;
    
    while (my ($char_key, $char_value) = each %{$hash_ref} ) {
        if ($char_key =~ / [-_] /x) {
            delete $hash_ref->{$char_key};
            $char_key =~ s/ [-_] //gx;
            $hash_ref->{$char_key} = $char_value;
        }
    }
}

sub normalise_hash_contents {
    my ($hash_ref) = @_;
    
    while (my ($char_key, $char_value) = each %{$hash_ref} ) {
        if ($char_key =~ / [-_] /x) {
            delete $hash_ref->{$char_key};
            $char_key =~ s/ [-_] //gx;
            $hash_ref->{$char_key} = $char_value;
        }
        if ($char_value =~ / [-_] /x) {
            $char_value =~ s/ [-_] //gx;
            $hash_ref->{$char_key} = $char_value;
        }
    }
}

#---------------------------------------
#



main_line() unless caller();

#---------------------------------------
#---------------------------------------


sub debug {
    my ($text) = @_;
    _output("$text\n") if $DEBUG > 0;
}

sub say {
    my ($a) = @_;
    print "$a\n";
}

=format

To Do:

    Serious Bugs
        
        - Ordering capture->optional->numeric quantifiers.
          If not in this order, no error is reported but the regex generated is
          unlikely to be what the user wanted. E.g.
            three optional x  # Expecting zero to three occurences of x
                              #  but is treated as if it was:
            optional three x  # zero or exactly three occurences of x
        
        - Group 'character' mixed with other groups generates incorrect regex.
          One reasonable fix is to disallow the mixture: 'any character' with
          almost anything else doesn't make much sense, except maybe for 'end of
          string'. If disallowed, would have to use either/or if such a mixture
          is needed.
          
        - Group 'character' mixed with string literal generates incorrect regex.
          The string literals are ignored. This has a different cause than the
          defect above: but could also be 'fixed' by disallowing the mixture.
          
    Required for quality control
    
        Improvements to automated test harness:
            - checking of error handling
            - exact error text vs. some error text vs. no error reported
            - lots more tests in wordy-to-terse direction
            
            for wordy-to-terse:
                wordy-in / terse-expected
            for terse-to-wordy:
                terse-in / wordy-expected
            
            
    
    Required for Usefulness
    
        Improved module interface, supporting utilities that allow
        wres to be passed in via a file, embedded in source, or directly from
        a user e.g. using a web browser.
        
        Improved error reporting, particularly in highlighting the location of
        the error within the wre.

            calls to _error():        
                parse_chunk  26
                _generate_regex 
                    internal 5
                    non-internal 1  "generic_newline is not allowed to be negated"
                    
                _wre_to_tre
                     Invalid parameters passed to call 1
                     
                process_line 4
                
            So it's mostly parse_chunk and process_line that need work, and maybe
            detect the one non-internal error earlier.
                
    Required to support standard regex features

        Ranges:
            'range a to g', 'range a through g' and 'range a thru g'.
            Ranges that are currently unsupported, i.e. not same-case, not
            numeric etc., are required to support legacy regexes. Explicit
            keyword 'range' to allow these?, e.g.
                range control-b to control-x
                range ' ' to '/'
            'a - g' is ambiguous without the preceding 'range' keyword, as it
            could be intended to be the range a-g rather than the three
            characters 'a', hyphen and 'g'. Probably best not to support it:
            could create an observation if it is seen, or have a rule that
            unquoted solo hyphens are not allowed between a pair of naked
            letters or a pair of naked digits.
        
        Interpolation:

            Simple interpolation can be done using ordinary string interpolation
            into the indented regex, e.g. of single characters or strings.
            
            Interpolating a numeric quantifier needs to use the 'quantity'
            keyword, to ensure that a single digit is not interpreted as a solo
            character.
               E.g.     quantity 1 to 3 commas
                        quantity 2 spaces
                        qty 6 or more digits

            We could implement recognition of $name constructs, where the sigil
            is seen by this module (e.g. it is passed via a file, a
            single-quoted string, or is escaped in a double-quoted string). The
            syntax would be recognised (it's unambiguous) and the $name would be
            passed though to the generated regex. The value being interpolated
            would need to be either a sequence of characters (if the
            interpolation is found within quotes) or one or more solo
            characters.
            
                'cat' 'dog' '$other_animal'  # literal string
                
                a b $other_letters y z       # character class
                
            Would need to ensure that interpolated characters did not get
            treated as meta-characters.
            
            This works for the situation where a generated conventional regex is
            embedded into the converted code: it doesn't work where the wre is
            converted dynamically, unless the interpolated variables are passed
            as extra parameters to the dynamic conversion routine (as the module
            cannot determine the value of $name in the caller's context).

            
            Memoisation would need to include the current value of the
            interpolated variable. So the wre with the $name would not be itself
            be memoised, but the entire wre with the interpolated value(s) would
            be. Simple handling of interpolation would risk the memo size limits
            being reached by ineffective memoisation of one regexp that would
            then prevent further additions to the memo: specail handling of wres
            that have interpolated variables might reduce this risk. One very
            crude approach would be 'do not memo' options that prevent memoing
            of either a specific wre with interpolation, or of all such wres.
            
        Multiple Matches ( /g )
        Iterative Matching ( /g  /gc  and  \G )
        
            If the generated regex is just used in a Perl script, that script
            can use /g in a list context (to get multiple matches) or /g or /gc
            in a scalar context (to get iterative matching). The keyword
            'end_of_previous_match' (or eopm) can be used to get \G.
            
            The wret() routine returns a reference to the terse regex, which can
            be interpolated into a regex that has /g or /gc flags.
            
                while ($data =~ /${wret "capture a b c"}/g) {
                    print "# next abc letter: $1\n"
                }

            This can be useful when a terse regex is being replaced by a wordy,
            as it allows the replacement to be done without requiring an
            intermediate variable. For manual replacement, adding a variable
            that contains the regex has simpler syntax. It doesn't require the
            wordy to be within slashes and curlies as well as quotes.
                        
                my $abc_regex = wre "capture a b c";
                while ($data =~ /$abc_regex/g) {
                    print "# next abc letter: $1\n"
                }
                
            ...but for automated replacement, adding an intermediate variable
            can be problematic, e.g. after an elsif. Even just deciding on a
            sensible name can be difficult to automate.
            
        Properties
        Unicode mode handling (check whether complete)
        Ordering of string/char class items - maybe do multiple classes if
            solo characters separated by strings or assertions, to preserve the
            exact sequencing semantics. Alternatively enforce some sequence,
            e.g. assertions, then quoted sequences, then solo characters.
        Conditions: needed for completeness, but rare enough to defer
        Named patterns/macros - Perl 5.10+, but probably rarely used
        

        
    Not Strictly Required, but High Priority
    
        Multiple modifiers on one line: report error if capture, optional,
            quantifier are not in that order
        Error reporting of disallowed combinations, e.g.
            negative/positive
            negative + negative
            not, followed by an assertion (or auto lookahead/behind??)
            mixing 'any' with other groups or characters
            negative + singular + plural
        ' ' means whitespace
            A space character within a quoted literal would be treated as
            specifying that one or more whitespace characters are allowed there.
        ' '  means whitespace-character
            A space character within a quoted literal would be treated as
            specifying that one whitespace character is allowed there.
            
        Prettier output
             Getting trailing quantifiers on their own lines would be a good start
             

                
        White space:
            Tie down definition, check implementation
            Implement 'whitespace-character' to allow single whitespace character
     
        Change definition of 'digit', add keyword 'numeral'
            'Digit' is always a plain ASCII arabic numeral, that will be treated
               as a digit by Perl
            'Numeral' is the same as 'digit' when using ASCII.
            'Numeral' is any character that has the Unicode property 'Number'
               when using Unicode. The Unicode::UCD::num() function can convert
               a series of numerals to the equivalent number
        Alternatives to 'not', e.g. 'anything except'
        Leading tabs: handle (e.g. if not mixed with spaces) or report error
        
        Variations on 'any', e.g. 'any character' ??
        
        Super-modes:
            things like 'repeat' that translate into /g, but can't be part of
            the generated regex itself. They can be held as part of a regex
            object, and can have effect when methods are invoked.
        Capture-as, a syntactic variation of 'capture as'
        As, a syntactic variation of 'capture as'
        Warning if spurious pseudo-range seen, e.g. a - d, or 0 - 5
        
        
    Bugs
        
          
    Minor bugs
        - Capture with optional and a quantifier: early-Perl named capture gets
          the ? in the wrong place
        - Checking if anything is less indented than first non-blank line
        - Using the embed_source_regex option changes the generated regex, as
          the check for atomicity is affected. The generated regex is still
          correct, just longer than necessary

    Target: specifies language, version, options (e.g. /x mode)
        Note: choosing a target mode does not affect the interpretation of the
        indented regex - it just controls how it will be implemented
        

        
    
    
    
    Design Decisions
    
        Synonyms
        
        Unicode approach
            Should it default to /aa (for Perl targets that support this)?
            It is probably the fastest, and has security advantages (it won't
            treat Bengali digits as digits, for example).
            [Note that I have decided that 'digit' always means [0-9]], so you have
             to use 'numeric' if you want to match all Unicode numerics]
            This may have to be target-specific, as it may not be possible to
            guarantee ascii-only for all targets, although generating character
            classes rather than groups should be possible for all targets, e.g.
            generate [0-9] for \d and [^0-9] for \D. Would need to ensure that
            this does not break when negated groups are mixed with other stuff.
            
            [unichars.pl is a utility that lists Unicode characters filtered by
            property and/or by Perl character class notation. 
            E.g. to count all non-ASCII digits:
                 perl unichars.pl -a '\d' '\P{ASCII}' | wc -l
            ]
    
    Implemented, more testing needed
        - Generate overall mode span to lock in modes, e.g. xms-i
        - Groups: make sure they all work, including character(s), char(s)
        - Negated literals: not, except, non-, any but
        - Start/end of string/line and other matchers (word boundary/start/end,
            etc.), including mixtures with literals
            
    Possible Extensions/Improvements
        
        - any/anything, any character, any character but/except, any-character
        - Plurals
        - Pretty output
        - Unicode character names, e.g. 'unicode two women holding hands'
        - 'or' as noiseword (when not first word on line)
        - Quoted space means whitespace
        - Other noisewords ('of', 'the', 'and/or' ... ???)
        - Generalised multi-word input (non-hyphenated)
        - Version numbers (like Perl 'use 5.12')
        - Change generated overall mode span to suit regex, e.g. for .*
        - keyword 'of': after a digit, or a digit range makes it a quantifier (e.g. 3 of)
        - 'or more' or 'or more of' after a digit makes it a quantifier (e.g. 1 or more)
        - Refinement ('five of the letters a, b or c or the digits 1 through 7')
            where 'the letters' and 'the digits' are redundant
        - Keyword 'literal', causing rest of line to be taken as quoted string
        
    Deferred Implementation
        Detect and flag as 'Unimplemented'
            - Mixed singulars and plurals
            - 'any' means 'zero or more' when it precedes a plural
            
    Terminology and documentation
    
    Synonyms    

        Candidate approaches:
        
        (A) Provide built-in synonyms only for:
                - abbreviated forms
                - alternative punctuation
                    hyphens/underscore/omitted
                    (s) for plurals
                - multi-word variants
                    (e.g. quotation mark, double quotes)
        (B) Allow most variants(as above), plus any where there are multiple
            variants in common use (e.g. dash/hyphen, dot/period/full-stop)
            
        The rationale for restricting the vocabulary is so that someone reading
        a regex needs to know less, but as long as more obscure words (such as
        'solidus') are omitted then the reader should be able to understand it.
        It is less obvious for variants such as allowing 'get' instead of
        'capture', where the reader has to know that they are just synonyms.
        
        The rationale for a wider vocabulary is so that the writer can choose
        the variant they prefer, rather than having to know which of the
        possible variants is the only one allowed.
        
        One approach to allowing the use of shorter alternate forms
        (such as get) is to provide an option to convert to canonical form, or
        even a choice of different levels of verbosity. 
        
        There is a related issue, where words such as 'pound' have two distinct
        meanings, at least in US usage (the symbol £ and the symbol #). Options
        include:
        - alternative modes (e.g. for US and European usages), or
        - only allowing unambiguous variants ('sterling' for £ and 'hash' for #),
          so that 'pound' would be reported as an error, or
        - a combined approach: e.g. 'pound' is disallowed unless US or European
          mode has been selected
          
            
    Plurals:
    
        Candidate Rule:
    
            <plural>                        : one or more <singular>
            optional <plural>               : zero or more <singular>
            <any other quantifier> <plural> : same as if <singular> was used
            
            If there is a number of occurences on the same line, a plural is
            treated exactly as if you had written the singular.

            Otherwise the plural form of a group name implies 'one or more'.
            
            If there any singulars on a line, you can only have one plural. The
            situation where there are muliple plurals and at least one singular
            on the same line is reported as an ambiguity error. [Maybe ??]
             
        It's an extension (it's possible to do all regexes without plurals), but
        a fairly useful one as it shortens a frequently occuring usage.

        One disadvantage is that the rule is fairly complex to explain.
        
        Another disadvantage is that it breaks the symmetry between indented and
        inset: the rule (as proposed) specifies 'on the same line' so that:
        
            five digits  # exactly five digits
        
        means something different from:
        
            five       # five occurences of...
                digits #    one or more digits, so effectively 'five or more digits'
                
        The reason for the rule being this way is partly because there might be
        more complicated stuff indented, but also because the alternative rule
        would be counter-intuitive as well as really messy to state.
        
        # Match one or more digits
            digits
        
        # Match exactly five digits (plural makes no difference)
            five digits
        
        # Match exactly five digits (singular makes no difference)
            five digit
        
        # Match exactly five digits
            five
                digit
            
        # Match zero characters, or five characters in any mix of spaces and tabs
        # Plurals ignored because of the 'five'
            optionally five spaces tabs
            
        # Match five or more digits
        # It's really one or more digits, five times
            five
                digits
            
        # Match five or more digits
            five
                one or more digits
        
        # Match five or more digits
            five or more digits
                
        # Match zero or more digits
            optional digits
        
        # Match zero or one digit
            optional digit
            
        # Match zero, or five or more digits
            optionally five or more digits
    
    Multiple Plurals
    
        The possible ambiguity when multiple plurals are specified is that it
        is not clear whether mixtures are allowed. In English, this is often
        resolved by saying:
            'tabs or spaces'   # meaning any non-zero number of tabs, or any
                               # non-zero number of spaces (but no mixtures)
            'tabs &/or spaces' # meaning any non-zero number of tabs, or any
                               # non-zero number of spaces, or any mixture
                               
        The usual implied alternation in indented regexes is 'or' when there is
        no quantifier, but 'and/or' when there is a quantifier:
            E G B       # one character: E or G or B       
            five E G B  # five characters: any mixture of E's &/or G's &/or B's

        But because plurals imply quantifiers, multiple plurals imply 'and/or'
        even without an explicit quantifier:
                                       
        tabs spaces                # One or more (tab or space), i.e. any mixture   
        five or more tabs spaces   # Plurals ignored, same as:
                                   #     five or more tab space
                                   # i.e. any mixture
        
    Mixed Plural(s) and Singular(s)
        
        % @ digits     # Multiple singulars, one plural
        # Match (one %) OR (one @) OR (one or more digits) - reasonably unambiguous
        

        % @ digits hyphens    # Multiple singulars and multiple plurals
        # How is this any different from multiple plurals?
        # Match (one %) OR (one @) OR (one or more digits) OR (one or more hyphens) ?? NO!
        # Match (one %) OR (one @) OR (one or more digits and/or hyphens) ?? YES!
        
        
        
        
    Terminology and Documentation:
        
        What do we call indented regular expressions?
            Do we just dream up a new name, e.g. Dream?
            Or flaunt the verbosity: Wordy or Wordie?
            Or just stick to 'indented regular expressions'
            Siren (Superior Indented Regular Expresssion Notation)
            LIRE (Language for Indented Regeular Expressions)
            AltRE
            
        How should we refer to conventional regular expressions?
            conventional
            cryptic
            terse
            punctuation soup?
            
        Should we allow lots of synonyms, e.g. lazy/minimal/non-greedy?
        This may be an advantage for people writing indented regexes, but at the
        cost of making it harder for those reading them as they have to know all
        the synonyms.
        
        One possibility is to have a canonical form, with a utility that will
        convert from any valid form into the canonical form: this would replace
        any non-canonical synonyms and also expand any abbreviations.
        
        The conventional-to-indented converter would always produce the canonical
        form, except that it might use abbreviations such as eosx.
        
        Matchers
            character matchers
                naked / solo characters
                quoted literals
                character names (singular and plural), e.g. tab, commas
                character group names (singular and plural), e.g. digit, letters
                negated characters and groups (non-, not, except)
            position matchers
                start/end of string/line
                word boundary / before word / word start / after word / word end
            back references
                
        Controllers and Modifiers
            Capture
            Quantifiers
            Optional
            Case-sensitivity
            Unicode: ascii, full-unicode, locale-specific,
            Laziness/greediness
            Atomic/possessive
            
            
    Keyword 'then' - implemented, but check whether implementation matches this description
    
        'then' keyword: allows simple sequence on a single line of a wre
            e.g. two digits then : then two digits then opt 'am' 'pm'
            Definition is 'indent equally, except also indent from either/or'
            So:
                'as hh one or two digits then : then as mm two digits'
            becomes:
                 as hh two digits
                 :
                 as mm two digits
            
            Note that:
                 as time-hhmm one or two digits then : then two digits
            becomes:
                 as time-hhmm two digits
                 :
                 two digits
            which is probably not what the user wants. They would have to write:
                 as time-hhmm
                    one or two digits then : then two digits
            to capture the hh:mm value in a single capture.
            

            'then' interacts wth either/or, as it binds more tightly
                either two a then b
                or     c then three d
                four e
            is equivalent to:
                either
                   two a
                   b
                or
                   c
                   three d
                four e
            
            Any line with a 'then' is not allowed anything indented from it:
            there should be at least one matcher before the 'then'.
                    
            Handling:
                First 'then':
                    Check that some matcher(s) seen (error if not)
                    
                    Set 'then-seen'
                    Start building second child (for matchers following the
                      first 'then' to go into)
                Subsequent 'then':
                    Start building another child (for matchers following this
                      'then' to go into)    
        
    Named Sub-Patterns
    
        Perl 5.10+
        Defines sub-regex with (?(DEFINE) (?<name>pattern)... ) where the < and >
        around the name must be present. This is a special case of (?(cond)...)
        Can be used before being defined, syntax is (?&name)
        
        Don't need to regenerate (?name) syntax if round-tripping from
        conventional, as long as the functionality is unchanged.???
        Do modes get baked into the definition??
        
        
        Keyword: define
            define alnum as letter digit
            define time as
                two digits
                :
                two digits
            Creates named sub-regex from the text on the same line, or indented
            So:
                optional time
            would be equivalent to:
                optional
                    two digits
                    :
                    two digits
        Extra rules:
        - If it defines multiple lines, then the use of it must be the
          last (or only) thing on a line
            
        - If it is a one-liner that defines literals or matchers, it
          counts as a literal or matcher and the usual rules apply - it
          can't have anything indented, and it can only be followed on the
          same by literals or matchers.

    Design Decisions Needing to be Made
    ===================================
    
        User Interface(s)
        
            Use Cases
                New code, simple to medium complexity regexes
                New code, complex regexes
                Maintain existing code, simple to medium regexes
                Maintain existing code, complex regexes
                Convert existing code from tre to wre
        
            Aims:
                - Keep it as similar to existing tre usage as far as possible
                - Allow the user to put the wre in the code and have the tre
                  created invisibly behind the scenes
                - Allow the user to use the generated tre in the code directly,
                  but include the wre from which it was generated as a comment
                - Allow the user to use the generated tre in the code directly,
                  without the wre from which it was generated being shown
                - Allow the user to put the wre in the code, but with the
                  original tre visible as comment text - either in parallel with
                  the wre or as as a separate comment block
              
            Method 1: 
               User runs a utility, passes it the input in a text file, or as text
               to stdin.
               Utility sends conventional regex (and optionally the wre) to stdout.
               User takes output and pastes it into code.
               
            Method 2: 
               User runs a utility, passes it the input via the clipboard
               Utility places output on the clipboard. User pastes output into
               code.
               
            Method 3: 
               User runs an add-in within IDE, passes it the selection as input.
               Add-in replaces selection with output.
               
            Method 4: 
               User passes the input to a web server, by pasting or typing into a
               textbox or by uploading a text file.
               Web server displays result.
               User copies result and pastes it into code.
               
            Method 5:
                User invokes utility and passes it the source file name.
                Utility reads the source file, converts all regexes in place,
                writes updated source file.

            Method 6:
                User opens a web page and passes it the source file name.
                Server uploads and reads the source file, converts all regexes
                in place, and creates an updated source file the user can
                download and save.
                
            wre to TRE Direction:
                Indented regex might already have a conventional regex, e.g. the
                wre might be present as /x comments on a conventional regex, or
                as a comment block. The conventional regex would be ignored.
                
            TRE to wre Direction:
                Conventional regex might already have an indented  regex, e.g. the
                tre might have the wre as /x comments. The indented regex would
                be ignored.
        
        Unicode approach
        
            - Do we need to have modes?
                - Security issues, e.g. don't accept Bengali digits as numeric
                  by default
                - Some programs will want to handle full Unicode
            - Should we allow modes?
            - Can/should we make the regex as written entirely self-contained?
                i.e. not affected by any modes
            - Can/should we make the regex as generated entirely self-contained?
                i.e. not affected by any modes
            - Should (and could) we detect what modes apply to the context where
              the indented regex is being used? The actual regex handling will
              be in a module, presumably unaffected by the modes in the calling
              routine.
            - Should we have a pragma or equivalent, that changes the mode for
              all indented regexes within its scope? e.g.:
                    use Regex::Wre (:ascii)
            - Is 'ascii' the right keyword to use for Perl's /a mode?
            - Conventional Perl regexes can specify (for example) digit as \d
              or as \p{}, so the same regex could mix unicode and ascii-only.
              To do the same, we would have to change mode - but that would be
              unusual within a single regex.
            - Should we allow sub-modes: e.g. ascii digits but full unicode
              letters? Otherwise have to use explicit range 0-9 for ascii when
              in full unicode mode.
              Answer: 'digits' always means ascii digits: use 'numeral' or
                      'numeric-character' to include non-ascii digits when in
                      full unicode mode, or use 'unicode-digit' anywhere.
              
            ..............
            - if you don't specify, the behaviour is defined, but might vary
              between targets. For Perl 5.14+, it will be based on the Perl /aa
              mode, which avoids the security issues. For earlier Perl targets,
              the generated regex will attempt to emulate /aa, at least for
              digit, letter and whitespace.
               
            - you can specify full Unicode mode
                This has a single set of rules that will apply - so any regex
                generated for any target will conform, or will warn if it can't.
            - ?? you can specify Unicode sub-modes, e.g. for letters, digits and
                whitspace characters independently. Any sub-modes that you don't
                specify are left as undefined.
            - ASCII is available as an option, if you want to be sure that, for
              example, a non-ASCII letter won't match 'letter'. There could even
              an option to specify 'any means ascii', so that a non-ASCII
              character won't match anything except a negated character. Or just
              use the keyword 'ascii-character' instead of 'character'.
            - Possible extension to limit entire character set, e.g. to ASCII,
              or 7-bit ASCII, or ASCII excluding non-whitespace control
              characters. If applied, this would result in regexes never
              matching any characters outside the specified set - the data being
              matched might contain other characters, but any matched would be
              guaranteed to be within the set.
        
            - What do 'digit', 'letter' or 'whitespace' mean, and how much
              should that vary depending on what you specify as the unicode
              mode?

                - digit
                    - ascii
                    - unicode digit ??
                - numeral
                    - anything that has the unicode property Number
                - letter
                    - ascii (7-bit)
                    - ascii (8-bit)
                    - unicode
                    
                For Perl at least, it's quite dodgy to have non-ASCII digits
                match \d (in legacy regexes) or the keyword 'digit' (in wres),
                as the common use case is that the digits will then be used for
                arithmetic. But if they are non-ASCII digits or a mixture of
                ASCII and non-ASCII digits, then Perl will not do the right thing
                as it will terminate the number at the first non-ASCII digit.
                
                So the intention (not implemented yet) is that 'digit' will always
                mean an ASCII digit, even if the mode is Unicode: if you want
                the full range of unicode digits you have to say 'numeral'.
                
                - whitespace
                
                    Which characters count as whitespace when in unicode mode?
                    The simplest way is to use the same as Perl does, so the
                    generated regex can just use \s or \S.
                    
                    whitespace can always be a plural, with whitespace-character
                    available if only a single character is wanted - but which
                    characters qualify as whitespace may vary with unicode mode
                    
            - What case-folding rules apply for case-insensitive matches?
            - Should 'any character' match an extended grapheme cluster?
                  Other stuff (such as \w) doesn't: \w would match the G of an
                  extended grapheme cluster for an accented G, not the accent [I
                  think - not checked]. Having one group matching extended
                  grapheme clusters and others that don't match seem more likely
                  to be confusing than useful.
                  So the answer is 'no': if you want to match any logical
                  character (including an extended grapheme cluster) you have to
                  explicitly say 'any logical-character' to get \X
                
            - How do we handle conversion from legacy regexes?
                - We need to know what modes apply, to correctly interpret
                    a legacy regex
                - \d, \w, \s, \D, \W, \S
                - \h, \n, \v
                - \X (extended grapheme cluster)
                - \C 
                - Posix character classes, e.g. [[:alnum:]]
                - unicode properties, e.g. \p{PosixAlnum}  \p{XPosixAlnum}
                - mode spans
                - flags on operators, e.g. m/.../d
                - default mode (system, pragmas, etc.)

        Indented regex version numbers (like Perl 'use 5.12')
        
        Alternatives
        
            This is a different way of getting multi-line alternation, using
            the keyword 'alternatives' with the alternative items indented.
            
            Items need quotes unless they are explicitly literals
            each item immediately indented is an alternative, e.g.:
                alternative literals
                    cat & mouse
                    dog & bone
                    cow
            
            The current equivalent is either/or, which isn't quite so clean, as
            it doesn't lend itself to an block implied-quoting mode:
                either literal  cat & mouse
                or     literal  dog & bone
                or     literal  cow


========= Interfacing ===========

 Terminology and Naming
    Regexp::Wre
    'tre' or 'terse' for conventional regexes
    'wre' or 'wordy' for wordy regexes?
 
 Pathways for existing code:
 
  For any language:
    Use utility to 'explain' an existing regexp by converting to a wre
    Embellish existing code with comments showing
      - the equivalent wre
      - the tre that wre would generate (in case it's wrong)
 
 For language(s) with a wre library (Probably just Perl for a while)
 
    Auto change existing code to use wre directly, but
       - leave previous regex as comment (in case conversion is wrong)
       - show generated regex (in case generation is wrong)
    Auto change existing code to use wre directly, 
       - leave previous regex as comment (in case conversion is wrong)
    Auto change existing code to use wre directly. Discard original regex

 Pathways for new code
 
   OO interface
   
        Can provide different and extended facilities as well as those provided
        by existing regexes.
        
        Provides a convenient place to store last-match information per regex:
        standard Perl mostly just holds only last match (but scoped dynamically)
        

        
   Non-OO interface
        Can do matches in-line, so very little syntactic and semantic change
        compared to conventional regexes.
        
        Can return qr regex literals for efficiency. But this can cause problems
        because options (or their absence) are baked into regex literals. For
        example, the regex literal qr/a/ will only ever match a lower-case a,
        even if a regex that interpolates it specifies /i.
        
        If an in-line legacy regex is being replaced, then the options used are
        available, and can safely be baked into a qr regex literal.
        
            # Original in-line regex, with case-insensitive option
            my $match = $a =~ /[cat]/i;   
            
            # Equivalent match using a qr regex literal
            my $cat_qr_regex = qr/[cat]/i; # case-insensitive
            my $match = $a =~ /$cat_qr_regex/; # still case-insensitive
            
            # Possible replacement wre calls that return qr literals
            my $match = $a =~ wre("c a t", {uncased => 1}); # PBP-style option list
            my $match = $a =~ wre("uncased c a t");  # option part of wre itself

        Options: /i /m /s/ /x /o /g /c /d /u /a /aa /l /p
        
        /i      Cased / uncased in wre
        /m  /s  Not needed in wre
        /x      Does not affect wre, except could pass comments
        /o      Once-only: optimisation hint
        /g  /c  Global, global don't reset on match failure
                 
        /d  /u  /a  /aa /l
                Unicode options in wre
        
        
 OO Interface

    

 Does the user want entire string match ?      
 Does the wre already have sos/eos (or eosx) ? 
 Does the wre contain any named captures ?
 Does the wre contain any unnamed captures ?
 Is this an iterative match ?
 What options (/i /m /s /o /x /g /c ) has the user supplied ?

 Does the regex have any interpolation ?
 Is the regex entirely a single variable being interpolated ?
 Is the interpolated regex a regex literal already ?
   If so, we know it's not a wre

 Are we converting existing code?
 How are the regex(es) delimited?
 What language is the code in? What version of that language?
 Should we replace the legacy regexes with equivalent wre's?
 Should we leave the original hand-written legacy regexes visible as comments?
 Should we just add wre's as comments and leave the existing code untouched?
 Should we show the generated regexes, even if we don't have to?
   e.g. if we call a routine that generates them dynamically 

 Is there a threshold for very simple legacy regexes where we leave them alone?

 Is the user accessing any dynamically-scoped regex-related variables?
   If so, any replacement code can't replace in-line matches with calls to
   functions.

   This severely constrains what replacement can be done, unless major parsing
   was also done.

   $1  $2 etc.

   $& $MATCH     entire matched string                  Slows Perl, avoid
   $` $PREMATCH  everything before the matched string   Slows Perl, avoid
   $' $POSTMATCH everything after the matched string    Slows Perl, avoid

   ${^PREMATCH}   only active if preserve mode specified  Perl 5.10+
   ${^MATCH}      only active if preserve mode specified  Perl 5.10+
   ${^POSTMATCH}  only active if preserve mode specified  Perl 5.10+

   $+  last bracket match

  @-        Array of offsets of start postions
  @+        Array of offsets of end position

  %+        Hash (keyed by capture name) of named capture values

  %-        Hash (keyed by capture name) of arrays each containing the values
              matched by all the captures with that name

   $^N      The text matched by the used group most-recently closed (i.e. the
            group with the rightmost closing parenthesis) of the last successful
            search pattern.

==============================================================================
==============================================================================
#### WARNING - DEVELOPER'S NOTES ONLY  #####
#### WARNING - DEVELOPER'S NOTES ONLY  #####
#### WARNING - DEVELOPER'S NOTES ONLY  #####
==============================================================================
## The syntax and semantics of the regular expression notation supported by this
## code has evolved substantially.


##############################################################################
####                                                                       ###
#### The examples below DO NOT correctly reflect what has been implemented ###
####                                                                       ###
##############################################################################




Design Aims

    * No Punctuation Soup *
    
    The aim is to provide an alternative notation (wordy regular expressions)
    that is easier than the conventional regular expression notation.
    
    Regular expressions are really a special-purpose programming language, but
    one that is declarative rather than procedural: the user tells the regex
    engine *what* they want to do, not *how* to do it.
    
    The conventional notation is exceedingly concise, allowing an extremely
    powerful regex to be entered as a single line of text. This is a useful
    attribute when a regex has to be manually typed in, for example into a
    command line. However, it is achieved by having a notation that uses
    punctuation characters and defines particular meanings for individual
    letters, rather than a language that uses words.
    
    For a regex that is used within a conventional program or script, the
    advantage of brevity is often outweighed by the difficulties of correctly...
        - writing
        - understanding
        - modifying
        ... all but the simplest regexes.
        
    This is mostly due to the arcane character patterns required by the
    conventional notation.
    
    Reword is simply a notation: it doesn't avoid the need for its users to
    understand how regular expressions are handled by regex engines, although
    for simple regexes a basic understanding is all that is necessary.
    
    A subsidiary aim is to provide a unified format that is consistent across
    different languages. This may seem irrelevant to a user who is using only
    one language, but it means that documentation such as introductory texts and
    examples can be used by anyone who is using Reword.
    
    Other minor design aims include the possibility of internationalisation (by
    allowing keywords to be in other languages), and support for Unicode to the
    extent supported by the target regex engine.
    
    Efficiency of conversion from Reword notation to conventional is not a high
    priority for this implementation: typically the conversion can be done just
    once for each regex.
    
    Another aim is that the meaning of a Reword regex should not differ greatly
    from the same words used in English. This does not mean that it attempts to
    cope with any possible construction: just that the meaning of a valid Reword
    regex should be the same as its natural sense in English. This is clearly
    only an aspirational aim, due to the ambiguities and complexities of
    English, and the desirability of keeping Reword simple.
    
    Support for dynamically varying the detail by inserting the contents of a
    variable into the regex ('interpolation') is provided, but this only allows
    variation of the characters being matched. This is very limited compared to
    conventional regexes in Perl and most other languages, where the entire
    meaning can be changed at run time.
    
    Full interpolation is easily available, by creating a string containing the
    indented regex, which can be done using interpolation. The limitations are
    that the string must be constructed to be a valid indented regex, and the
    conversion process that converts the indented regex to a conventional regex
    has to be repeated.
    
    The intention is that any regex that can be expressed in conventional
    notation should be able to expressed using Reword. There will no doubt be
    gaps in implementation, but they will hopefully be limited to the more
    obscure options such as explicit recursion.
    
    
    -------------------------------------------
    Options/Modes: start with keyword
        Options at top level apply to entire regex, e.g. an initial
        'option case-insensitive' line applies to the entire regex, even though the
        regex is not indented from the options line. It is recognised as a
        top-level option from the (whatever?) keyword: it must have nothing
        directly indented from it. Multiple options can be stacked on a
        single line.
        
        Parser could have compulsory options. A compulsory option is where you
        have to choose, rather than allowing some default to be taken - the
        obvious candidate for this is complete string vs. partial string
        matching.
        
        Options come in two sorts:
            - ones that affect matching, and
            - ones that control what will be generated
            
        Options are not introduced by 'options', mostly because 'optional' and
           'optionally' and the abbreviation 'opt' are already used, and would
           be a source of confusion. 'Modes' might not be a good choice either,
           depending on whether it clashes with the use of the same word for
           the modes used with conventional regexes (/i, /s/, /m, /x etc.)
        
    Matchers: Literals, character names and anchors:
        
        Can generally be intermixed, but cannot have anything else inset or
        indented from them.
        Negated matchers (such as non-whitespace and non-digit) can only be
        intermixed with other negated matchers, e.g.:
            one or more non-whitespace or non-digit
               ## That 'or' is debatable, it's either:
               ##     not (whitespace or digit)      , or
               ##     not whitespace and not digit)
               ## We could make 'and' a noiseword like 'or', but only
               ## when the literals are negated
               
            one or more any character except whitespace or digit
            one or more any characters except whitespaces and digits
            five characters anything except whitespaces and digits
        Literals
            single naked characters (except quotes, comment-introducers)
            ranges of letters (same case) or digits
            quoted strings
        Other matchers
            Names of characters (e.g. tab) or groups of characters (e.g. digits)
            Anchors - names of places to match such as 'start of line'
    Quantifiers:
        Implied quantifier is one (except for plurals??)
        Non-consecutive numbers  ('one or four') could be implemented as alternations
    Modifiers:
        'optional'
        lookbehind: 'preceding'
        lookahead:  'followed by'
        negative lookbehind: 'not preceding'
        negative lookahead:  'not followed by'
    Alternations:
        either/or
    
    
=cut


#my $regexp_schema = <<'...';
#name:       REGEXP-NODE
#type:       map
#required:   yes
#define:     node-rule
#mapping:
#    a_raw_line: scalar
#    comment:    scalar
#    capture:    text            # Ordinal number if anonymous capture
#    lazy:       boolean         # Can omit if unspecified, defaults to false
#    ## case_insensitive: boolean   # Can omit if unspecified, defaults to false
#    literal:
#        - value:   scalar
#          type:    text values chars range group
#          raw:     scalar
#          negated: boolean default false
#          plural:  boolean
#    max:               text     # Integer, or 'more'
#    min:               integer  # Minimum occurences
#    greed:             text  values 'minimal', 'possessive'
#    look_direction:    text  values 'ahead', 'behind'
#    look_match:        text  values 'positive', 'negative'
# '=', '!', '<=', '<!'
#    optional:          boolean  # Can omit if unspecified, defaults to false
#    some_negated:      boolean  # True if at least one literal is in negated form
#    some_non_negated:  boolean  # True if any literals are not in negated form
#    overall_negation:  boolean  # True if 'not' or 'anything except' 
#    either_start:      boolean
#    leading_or:        boolean
#    either_end:        boolean
#    modes:            
#        - text                  # Flag characters
#    z_children:
#        - use node-rule
#
#...

my $sample_ire = <<'...';
start-of-string
capture as hours
    one or two digits
colon
capture as minutes
    two digits
optional
    colon
    capture as seconds
        two digits
optional
    opt spaces
    capture as am_pm
        uncased 'am' or 'pm' or 'a.m.' or 'p.m.'
end-of-string
...


sub wre_sample {
    '\A(?<hours>\d{1,2}):(?<minutes>\d{2})(?::(?<seconds>\d{2}))?(?:[ ]*[ ]*[ ]?[ ]?[ ]*(?<am_pm> (?i: am | pm | a\.m\. | p\.m\. )))?\z';
}

sub sample_b {
#   Samples of possible interfaces
#
#   wre(string) returns a string containing the regex
#
#   The generated string is not visible, so there is no point in making it
#   free-form - so no need for /x mode when it is used.
#
#   wre() has to be responsible for any caching/memoisation, otherwise the
#   complete generation process will be repeated each time wre is invoked.
    my $data = "12:52:30";
    my $h_m_s_re = wre_sample("
        start-of-string
        capture
            one or two digits
        colon
        capture
            two digits
        optional
            colon
            capture
                two digits
        optional
            optionally spaces
            capture
                uncased 'am' or 'pm' or 'a.m.' or 'p.m.'
        end-of-string");
    if (my ($h, $m, $s) = $data =~ /$h_m_s_re/) {
        _output("$h $m $s\n");
    }

    my $pause2 = 2;

#   wre(string) returns a string containing the regex
#
#   The generated string is not visible, so there is no point in making it
#   free-form - so no need for /x mode when it is used.
#   Except if it is possible to create an invalid regex (e.g. by interpolation),
#   in which case the diagnostics may be more useful if the generated regex is
#   in /x mode and includes the original regex.
#
#   The generation process will be done only once, courtesy of the state
#   initialiser. ????? Not true! The value would be saved between invocations
#   of the sub containing the state variable, but if the assignment is
#   unconditional then the call to wre() might be executed every time. ??
#When combined with variable declaration, simple scalar assignment to state
#variables (as in state $x = 42) is executed only the first time. When such
#statements are evaluated subsequent times, the assignment is ignored.
# It's not clear whether assigning the result of a unction counts as 'simple
# scalar assignment', e.g. does it have to be a simple scalar on both sides?

=for Perl 5.10+
    my $data_2 = "13:53:31 pm";
    state $h_m_s_re_2 = wre("
        start of string
        capture as hours
            one or two digits
        :
        capture as minutes
            two digits
        optional
            :
            capture as seconds
                two digits
        optional
            zero or more spaces
            capture as am_pm
                uncased 'am' or 'pm' or 'a.m.' or 'p.m.'
        end of string");
    if ($data_2 =~ /$h_m_s_re/) {
        _output("$+{hours} $+{minutes} $+{seconds} $+{am_pm}\n");
    }
=cut
my $pause2_2 = 2;

# What about having a match object, along the lines of Python?
# For complex matches, standard Perl returns the results via %+ and/or %- as
# well as in various other special variables such as @+ an @-. But the cases
# where the complexity matters are probably few enough that the user can wend
# their way through the standard Perl interface.
#
# A regex object could provide anything useful wanted from a match object,
# including reformatted captured data (numbers normalised by removing commas,
# dates converted to a standard form such as yyyy-mm-dd or epoch seconds).
# It would need to save the captured data from the most recent match method call
# to enable this, as it wouldn't know if reformatted data would be requested:
# that is probably the best argument for supporting match objects.
#
# In theory, we could embed code in the generated regex to do the same stuff
# even when using the object directly as a regex or interpolating it into a
# regex. But the complexity would be very high, and the semantics of how to
# access the reformatted data would be messy.

if (0) {
    my $re_date = Regexp::Wre->new('date dmy');     # dmy implies loose date allowed
    my $sample_date = "23rd December 2012";
    if ($re_date->matches_all($sample_date)) {
        # Date matches regex completely
        # so retrieve the date
        my $ymd = $re_date->date('yyyymmdd');
    }
}
if (0) {
    # This approach doesn't put any reformatting info into the regex itself, so
    # it has to:
    #   (1) specify the format in some later call, and
    #   (2) have the date automatically saved, in case reformatting is requested
    my $re_tight_date = Regexp::Ire->new('date dd/mm/yy dd/mmmm/yyyy "ddth mmmm yyyy"');
    my $sample_tight_date = "Arriving 24th December 2012";
    if ($re_tight_date->matches_part($sample_tight_date)) {
        # Date matches regex somewhere
        # so retrieve the date
        my $ymd = $re_tight_date->date('yyyymmdd');
    }
}
if (0) {
    my $re_time = Regexp::Ire->new('time hh:mm:ss hh:mm');
    my $sample_time = "Arriving 12:45 pm";
    if ($re_time->matches_part($sample_time)) {
        # Time matches regex somewhere, so retrieve the time.
        # But how do we handle the am/pm/noon/midnight bit, if it is allowed or
        # required, and if it is optionally preceded by a space?
        # Are both 'am' and 'a.m.' allowed? '12 noon' and just 'noon'?
        # 05:45 implies 24-hour notation because of the leading zero. But 10:30
        # without a following am/pm could be 24-hour notation, or it might just
        # be ambiguous and expected to be resolved by context (e.g. "I had a 10:30
        # appointment" (assumed a.m.) versus "I was asleep by 10:30" (assumed p.m.))
        
        my $secs = $re_time->time('seconds');
    }
}
if (0) {
    # Speculative: do we assume single value captured?
    my $date = matches_all('23/12/2011', 'capture date dmy to epoch');
}

if (0) {
    # Really speculative: do we assume single value returned (reformatted)?
    # The 'epoch' implies both that the input will be a date or timestamp,
    # and that reformatting should be done (at least if the input isn't just a
    # number). Maybe the default is any format date with some way of defaulting
    # to dmy or mdy. But this is really straining the design of wre's
    my $date = matches_all('23/12/2011', 'epoch');
}

} ########## END OF sample_b() #########
=format

If user-defined macro types are implemented, how are they defined?
    - Simple pattern replacement: when the parser sees the macro name, it
      inserts the macro replacement string, which may be multi-line
    - Pattern replacement with parameters
Should additional types be definable by supplying code, some executed when a
regex using the new type is converted, and some at (or after) regex matching.
      




date 




\A                   # start-of-string
(?<hours>            # capture as hours
    (?:\d            #     one or two digits
){1,2}):             # :
(?<minutes>          # capture as minutes
    (?:\d            #     two digits
){2})(?:             # optional
    :                #     :
    (?<seconds>      #     capture as seconds
    (?:\d            #     two digits
){2}))?(?:           # optional
    [ ]              #     zero or more spaces
    *(?<am_pm>       #     capture as am_pm
        (?i: (?: am | pm | a\.m\. | p\.m\. )
                     #         uncased 'am', 'pm', 'a.m.', 'p.m.'
)))?\z               # end-of-string


\A                   # start-of-string
(?<hours>            # capture as hours
    (?:\d){1,2}      #     one or two digits
)    
:                    # :
(?<minutes>          # capture as minutes
    (?:\d){2}        #     two digits
)    
(?:                  # optional
    :                #     :
    (?<seconds>      #     capture as seconds
       (?:\d){2}     #         two digits
    )
)?    
(?:                  # optional
    [ ]*             #     zero or more spaces
    (?<am_pm>        #     capture as am_pm
        (?i: (?: am | pm | a\.m\. | p\.m\. ))
                     #         uncased 'am', 'pm', 'a.m.', 'p.m.'
    )
)?
\z                   # end-of-string
=cut


=format

metacharacters, within and outside character classes
[ ??
]
\
$  Perl interpolation

meta within character class only if first character
meta outside character class
^

meta within character class except if first character, or 2nd after ^
Not meta outside character class
[Code ensures it is used properly within character class]
-


not meta within character class (unless being used as the delimiter)
but meta outside of character class
.
+
*
?
#
|
(
)
{
}




start of string
capture hours
    optional digit
    digit
colon
capture minutes
    two digits
optional
    colon
    capture seconds
        two digits
optional
    optional space(s)
    # optional one or more spaces
    uncased literal alternatives
        # following four lines are literal strings
        am
        pm
        a.m.
        p.m.
end of string

m/^ ( [012]?\d ) : ( \d\d ) (?: : ( \d\d ) )? (?: [ ]* (am|pm|a\.m\.|p\.m\.))? $ /x

char keywords
    any
    dot period dash hyphen slash forward-slash backslash back-slash
    space comma semi-colon colon pipe vertical-bar 

char keywords only available as keywords
    tab
    newline/new-line
Assertions
    start of string
    end of string
    word boundary
    start of word
    end of word
    
quantifier keywords
    <numbers> zero through ten
    some
    optional, optionally
Alternations
    either, or
    alternatives
Capture
    Capture, collect
    
Character classes
    --------------------
    -- positive character classes
    --------------------
    # Simplest: one character itself or its name
    --------------------
    plus
    --------------------
    +
    --------------------
    # Simple choice
    ---------------------
    + or -
    --------------------
    + or - or :
    --------------------
    plus or minus or colon
    --------------------
    one character + -
    --------------------
    one character   
        +
        -
        tab
    
    --------------------
    1 to 5 characters 
    --------------------
    1 or more of comma, colon or hyphen
    --------------------
    any one of the characters colon, hyphen or slash
    --------------------
    one of the characters colon, hyphen or slash
    --------------------
    any of the characters colon, hyphen or slash
    --------------------
    any of colon, hyphen or slash
    --------------------
    colon, hyphen or slash ??
    --------------------
    --------------------
    --------------------
    -- negative character classes

    any character except + or -
    any single character except + or -
    any character except + or -
    any character but + or -
    any character except
        +
        -
        tab
    anything but + or -
    anything except + or -
    any char but newline
    anything but newline

    none-of + - tab  ??
    neither + nor -  ??
    not + or -       ??

    --------------------
+ve
zero or more of the characters comma, space or colon # zero or more
optionally any number of the characters comma, space or colon # zero or more
optionally one or more of the characters comma, space or colon # zero or more
any number (including zero) of the characters comma, space or colon # zero or more
any number of the characters comma, space or colon # zero or more ??

-ve    
any character(s) except comma space or colon # zero or more ??
any characters except comma, space or colon # zero or more ??

-ve
any character except comma, space or colon # one 
non-digit # one
two or three non-space characters

+ve
one of the characters comma space or colon # one
one of comma space or colon # one
exactly one of the characters comma space or colon # one
-ve
any single character except comma space or colon # one
any one character except comma space or colon # one
any character except comma space or colon # one ??

+ve
one or more of the characters comma space or colon # one or more
one or more of comma space or colon # one or more
one or more comma, space or colon # one or more
-ve
one or more of any character, except comma, space or colon # one or more


    
# If there is an 'or' between each, then it's an alternation, whether the things
# are literals or naked characters or names of characters:

    'per' or slash
    'per' or slash or :

# If there is an 'or' between each, then it's an alternation, whether the things
# are literals or naked characters or names of characters, but a plural character
# name implies 'one or more' of that character:

    comma or whitespaces or colon   #  (?x: [,:] | \s+ )
    
# If more than one character name is pluralised, then any mixture of those
# characters is allowed

    dashes or commas or colon   # allows -,-  or  ,,  or  - or  : or  , etc.
                                #  (?x: [:] | [-,]+ )

# If there is a quantifier, then it's an alternation regardless of
# whether there are any or's, and whether there are literals as well as chars:
# ???

    2 3 4 5  # By above rule, this means [345]{2} -  not intuitive
    2 of the chars 3 4 5
    2 chars 3 4 5
    one of ' per ' or '/'  # ???
    one of ' per ' / ;     # ???
    one of a, b or c       # allowed because of the commas???

    2 to 6 spaces commas or tabs
    one or more of space tab colon
    optional one or more of space tab colon
    one or more of 'spoke' tab space 'column'
       # =  (?: spoke | [\t ] | column)+
    one or two spaces, tabs or newlines # ???
    one or two
        space or tab or newline
    one or two characters space tab newline
      # = [ \t\n]{1,2}
    once or twice
        choose from the characters space, tab and newline
    any character except whitespace    # exactly one char
    any characters except whitespace   # one or more chars
    any character(s) except whitespace # one or more chars
    
      
    zero or more * & % - tab backspace =  # consecutive literals ??
    zero or one '++' = '--'  # consecutive literals ??

# If chars or characters (or some sub-class such as letters) are specified,
# possibly preceded by a quantifier, then it's an character alternation
# regardless of whether there are any or's - and only naked characters, single
# character literals and character names are allowed. Or is allowed but ignored

    character tab '*' @
    character tab '*' or @
    one or two char(s) ! > <
    


    
'per' or slash
'per' or /        # (?x: per | \/ )

either ' per ' or forward-slash
either space 'per' space or '/'


delimited by comma  (  a, b, :, -,  c, or d)


'dd-' or '/mm'
optional
    'dd'
    - or /
    'mm'
('dd' dash) or (slash 'mm')
'dd' (dash or slash) 'mm' 
'/*' or '--'
/* or --
'dd-mm' or 'dd/mm'
A - or B +   (A -) or (B +)
A + or - B    A (+ or -) B



# The use case that might be likely is mixing literals with white space, where
# the whitespaces keyword means one or more white space characters.
# This lets the user say:
#   'able' whitespaces 'baker'
# when they want more flexibility than the single literal space character within
#   'able baker'
#
# But better to use space-mean-whitespace(s)
#       'ab' spaces 'cd' or 'ef'
#       ('ab' spaces 'cd') or 'ef'
#       'ab' spaces ('cd' or 'ef')
#       'ab' or spaces or 'cd' or 'ef'
#
#       'ab', spaces, 'cd' or 'ef' # a list of alternatives separated by commas
#                                  #    or the word 'or'.

 Either 'ab' spaces 'cd'
 or     'ef'

 'ab' spaces
 'cd' or 'ef'

p q r or s  # Disallow! #  'pqr' or 's'  OR p or q or r or s
'pqr' or s  # Allowed
p, q, r or s # Allowed

char p q r s
one of the characters p q r s  # Allowed because we know we are in a character class
char p q r s
one of the characters p q r or s
one of the characters p, q, r or s
one of the characters p, q, r, s
one of the characters p or q or r or s

// or /* or --   # allowed
//, /* or --     # warn? disallow because it is naked punctuation delimited by comma?
//  /* or --     # not allowed

the cat sat on the mat   # Not allowed - not literal
'the cat sat on the mat' # allowed - quoted literal
'dog' whitespace 'cat'   # allowed, it's a sequence

'dog' whitespace 'cat' or 'animal'
either 'dog' whitespace 'cat'
or     'animal'

' ' means whitespace(s)
    'dog cat' or 'animal'  # literal space between dog and cat becomes \s+

allow extra whitespace mode
    'cat(4)' becomes / \s* cat \s* \( \s* 4 \s* ) \s*  /x   # What about hyphen?

 The Plurals Rules:
 -----------------
 A plural character name means one or more, unless there is an explicit
 quantifier. So 'spaces' means one or more spaces, and 'tabs' means one
 or more tab characters. The variants with parentheses - 'space(s)' and
 'tab(s)' - mean exactly the same but make this clearer.

spaces or hyphens # Means spaces or hyphens, but not a mixture ????
 If you want a mixture:
 any mix of spaces and/or hyphens
 one or more of the characters space or hyphen
 
 colon or space(s)
 
  three spaces or dashes or commas
        #      [ ]{3} | [-]{3} | [,]{3}
        #  or  [-, ]{3}
 
 
 Special Rules for White Space
 -----------------------------
 
 Non-negated 'whitespace' is interpreted to mean 'one or more consecutive
 white-space characters' unless it has a quantifier:
    one whitespace
or
    one whitespace or colon
or
    two comma or whitespace
or
    two whitespace characters

There is (well, there should be) an option to cause spaces within quoted literals
to mean whitespace, so words or whatever separated by one space in a quoted
literal will match the same words separated by one or more whitespace characters.
 

a or b or c
a or 'bc' or d  # naked character literals, mixed with quoted literals
a or 'bc' or comma or d # naked character literals, mixed with quoted literals
                        # and singular character names
a or commas or b        # One a or one or more commas or one b
a or spaces or b        # One a or one or more spaces or one b
a or whitespace or b    # One a or one or more whitespace chars or one b



# After 'one or more', singulars and plurals are equivalent although 'one or
# more spaces' is probably more grammatically correct English than 'one or more
# space'.
#
# Without a quantifier, 'spaces or commas' is ambiguous: does it mean 'one or
# more spaces, or one or more commas', or 'any mixture of commas and spaces'.
# 'Spaces and/or commas' is unambiguous.
#
#

Opt # Optionality
    # Usually first thing on a line, (but line can end with 'or nothing')
    
    'optional' or 'opt' or 'optionally'
    
Opt # Quantifiers
    
        A number or number word (none, zero, one, two...)
        opt
            to or - or through
            A number or number word or 'more'
    
Opt # type
    'literal'
    'characters' or 'chars'
    'any of'
    
Alternation
    - implied alternation after 'characters'
    - alternation if items all separated by 'or'
    - either/or
 
            either
                'cat '
                'and' or ampersand
                ' mouse'
            or  'dog'
            or
                'cow'
            
    
   quoted literal
       - single character   
       - multi-character
   unquoted literal text
       - indented from explicit keyword 'literal'
   named character
       - singular
       - plural
       - ambiguous (e.g. 'equals')
   naked character
       - any except space, #, control characters, white-space
       -? single and double quotes only after 'characters'
             e.g. one of the characters " or ' or /
       -? single and/or double quotes, but not mixed with quoted literals, and
             must no be matched even within a comment
             
             "  '       # This is allowed
             "  '       # This 'experiment' is not allowed
             "          # This "\x
   keywords
       optionality:
           - 'optional', 'optionally', 'opt'
           - 'nothing or'
           - 'or nothing' as the last element after some things?
               Doesn't make sense if already optional, or if quantifier starts
               at zero.
       quantity:
           - number words (zero, none, one, two...)
           - integers
           - 'any'
           - may be followed by 'of' or 'of the'

       range:
           - 'or' (and the next number, e.g. 2 or 3)
           - 'or more'
           - 'to' or '-' or 'through' or 'thru'
                 ('-' also works as a naked character)
                 ambiguity A - Z vs. A-Z vs. 'A' thru 'Z'
                 resolved by content, e.g. letter - later-letter-same-case is
                  recognised as a range, as is digit - higher-digit.
           - 'to' works with quantifiers and characters
       type:
           - 'literal' or 'literals' or 'string'
           - 'character' or 'char' or 'characters' or 'chars'
           - 'any character except', 'any char but', 'characters except'
           - if omitted, indented items are parsed
           - if present, indented items are treated as literals or chars
           - syntax checking for chars:
               no duplicates allowed
               special rules for quotes
                    individual characters can be quoted
               must have spaces between characters
               can have ' or ' between characters
               
       groups:
           - can have singular and plural forms
           - digit, digits, digit(s)
               
           - word, word-char, word-chars (but tied to programming language)
           - letter
           - upper case letter, upper-case-letter, upper-case letter
           - lower case letter, lower-case-letter, lower-case letter
        noise:
            - 'the'
        special
            - optional white space, optional-white-space, opt-ws, ows
               all allow zero or more white space characters



----------------------------------
 Newline matching: /s and /m modes
----------------------------------
   dot-matches-all mode (/s) affects dot
   enhanced line anchor mode (/m) affects ^ and $

 If the indented regexp module spares the regex writer from ever using dot or ^
 or $, then they shouldn't need to ever care or know about the /s and /m modes.
 However, if it is desirable that the generated regex is the same as a person
 would normally write, then constructions like .* should be produced. As their
 meaning depends on the mode that applies at that point, the generated regex
 must specify the mode, either by a mode-modified span, a mode modifier that
 applies within the relevant sub-regex or by generating the context such as /sm.
 

 One approach is to stick to PBP's approach and always use /s or the
 equivalent mode-modified span. So 'any' can use dot, and explicit 'any except
 newline' will use [^\n].

 Similarly, always using /m allows consistent mappings for start/end of string
 (/A and /z) and for start/end of line (^ and $).

A mode-modified span that encloses the entire is probably the simplest, but
a typical hand-written would use /sm if necessary and (contra PBP) would take
advantage of their absence if that suited.

-------------------------------
 Full vs Partial String Matches
-------------------------------
 Perl doesn't have alternative matches for 'entire string' and 'anywhere within
 string', although some other implementations do. So in Perl you have to use
 the 'start of string' and 'end of string' notation within the regex itself -
 which can easily be forgotten, and result in unintended matches.

 The default in Perl is partial match: 'match anywhere within string', but
 this doesn't have to be the behaviour for this module. It could:
   - insist on being told whether a full or partial match is required
   - default to generate full matches, with partial matches on request
   - support objects with different full and partial match methods
   - have options (use :tags or command-line?) to choose the default
   - support two classes, one for partial matchers

   Java uses 'find' method for partial match, 'matches' for full string match.
   Javascript and .NET are like Perl: full/partial is determined solely by the
   pattern, so partial match is implied unless ^ and $ are used.
   Python has 'search' for partial match, 'match' for a match that must start
   at the start of the string, but doesn't have to match all the way to the end
   
   
   The camel book suggests that 'contains' makes more sense as the name for the
   =~ operator, rather than 'matches'. As a function or method name, 'contains'
   is tidier than 'matches-part', although not as strong as the infix operator:
        if ($text contains "trop")       # Very clear
        if (contains($text, "trop") )    # Not quite as clear
        if (matches($text, "trop") )     # Arguably misleading: it relies on the
                                         # reader knowing that 'matches' actually
                                         # means 'contains' for simple patterns
   Is there an equivalent that implies a complete match? It's not needed if the
   pattern has start-of-string / end-of-string, but they are easily forgotten.
   
   I am tempted to have only:
        contains (or its synonym 'matches_part'), and
        matches_all
   or at least not automatically providing plain 'match' unless specifically
   requested by something like use RegExp::Ire qw{ match }

   If wres are going to be largely language-independent, then the syntax needs
   to work for all of them. Explicitly including start-of-string and
   end-of-string should never cause an issue: the question is what should we do
   when they are not both present (and for some nasty corner cases such
   involving alternations and/or optionality).
   
   
------------------------------------------------
Whitespace / whitespaces / Whitespace-characters
------------------------------------------------

'Whitespace' is problematic: does it mean 'one or more whitespace characters' or
simply 'any single whitespace character'?

So 'whitespace' might be used to refer to the visual effect of white space (non
graphic characters) between graphic characters, where the nature of whitespace
can make it impossible to tell by simple visual inspection whether there is more
than one character. For example, the visual effect of a single tab character
will often be identical to that of multiple spaces.

However, having 'whitespace' mean 'one or more whitespace characters' is probably
more confusing than is worthwhile: it would be a special case of an apparent
singular actually meaning a plural, plus it would mean that 'whitespace-character'
would also have to be implemented to allow the regex writer to specify an exact
number.

So what has been implemented is 'whitespace' meaning the same as \s in a terse
regexp:, i.e. a single character. If you want to specify one or more whitespace
characters, you have to use the plural form 'whitespaces' or its abbreviation 'wss'.


-----------------------------------
Plural Character and Group Names
-----------------------------------

    - You don't have to use plurals, ever - they are only a shortcut. So if you
      haven't bothered to learn the rules or you don't understand them, you can
      still write a regex that does what you want.
    - Tre2Wre.pm may generate plurals for some simple cases, so if you are using
      Tre2Wre you will need to understand the basics - but they are easy.
    - A plural without a numeric quantifier implies 'one or more':

    tabs             # One or more tab characters
    double-quotes    # One or more double-quote characters
    two tabs         # Exactly two tab characters
    two tab          # Same
    optional tabs    # Zero or more tab characters
    zero or one tabs # Zero or ONE tab character
    
    - 'optional' without any quantifier with a plural implies zero or more
      Explicit 'zero or one' with a plural means zero or one. 
      So 'optional' does not always mean the same thing as 'zero or one'.
     
    - Alternative characters allow any mixture ??? Debatable ??? Don't implement yet ???
    
    tabs spaces      # One or more characters, any mix of tabs and/or spaces
    tabs &/or spaces # One or more characters, any mix of tabs and/or spaces
    six tabs or dots # Six characters, any mix of tabs and/or dots
    opt tabs spaces  # Zero or more characters, any mix of tabs and/or spaces

    - Space(s) means the same as spaces, and similarly for other names.
    
    tab(s)           # One or more tab characters

    - A mixture of plural name(s) with singular name(s) or single character(s)
      allows: ??? Debatable ??? Don't implement yet ???
        - exactly one of the singular things, or
        - any mix of one or more of the plural things
    
    stars dots a b c # Mixed plural(s) and singular(s)   #  (?: [*.]+ | [abc] )
    either stars dots
    or     a b c

-----------------------------------
 Negated Matchers
-----------------------------------



    Only characters, groups, ranges and some matchers can be negated - not
    quoted strings.
    
    Groups can be negated by prefixing them with 'non-'.
    The word-boundary assertion can be negated by prefixing it with 'non-'.
    
    Multiple negated groups could be disallowed.
        Non-x means 'anything but x', so the implicit alternation of items on
        the same line results in:
            not-x not-y 
        meaning:
            'anything but x' or 'anything but y'
        which means:
            'anything'
        Common sense would interpret 'non-x non-y' as 'neither x nor y'.
        Otherwise the user has to write:
            not x y
    
    Other matchers?:
        - start/end of string/line, eosx: no negation possible?
            Could probably implement using negative lookbehind (for start) and
            negative lookahead (for end)
        - start/end of word (when implemented)
            If implemented using lookbehind/lookahead, they could presumably be
            negated using negative lookbehind/lookahead

    
    
    anything except space
    anything except spaces
    any but newline
    anything but newline tab
    any except a b 9
    not space       # implies any single character except space
    not spaces      # plural implies one or more
    non-spaces
    non-digits      # plural without quantifier implies one or more
    opt non-digits  # optional + plural, so zero or more
    opt non-digit   # optional + singular, so just one
    non-whitespace  # Is this singular or plural? The whitespace would imply 
                    # plural, but negated? Other negated plurals such as
                    # non-digits do imply 'one or more', so non-whitespace
                    # should do the same for consistency
    non-whitespace-characters
                    # Unambiguously a plural, so it's 'one or more'
    non-whitespace-character
                    # Unambiguously a singular, so it's just one character
    non-digit non-letter
                    # Interpreted as 'not digit letter', as the usual treatment
                    # of multiple literals as alternative would result in it
                    # matching any character, whereas the intent is clear.
    non-digit letter
                    # Not allowed: negated group name mixed with non-negated
                    # literal
    letter non-digit
                    # Not allowed: negated group name mixed with non-negated
                    # literal
    not newline tabs
                    # Not allowed: negated, mixed plural(s) and singular(s)

    Rules for Intermixing Negated Matchers
    --------------------------------------

        We have to be careful to only allow possible combinations: if we are
        going to create a negated character class, then only things that are
        allowed in a character class can be combined.
        
        
        - Negated matchers (such as non-whitespace and non-digit) can only be
          intermixed with other negated matchers, e.g.:

            one or more non-whitespace non-digit
            
        - A 'not' applies to everything after it on the line
        
            not a g f
            one or more not whitespace or digit
            one or more not whitespaces or digits
            
            
            one or more any character except whitespace or digit

            one or more any characters except whitespaces and digits
            five characters anything except whitespaces and digits
            
    Should we allow 'neither/nor'? It would be very different from either/or,
    as neither/nor would only be allowed within a single line, whereas
    either/or is only allowed on multiple lines. The complication of
    explaining the difference is probably not worth the gain.
        
       
            
-----------------------------------
 Any
-----------------------------------
    
    'any' is complex!
    
    It can precede a singular group name ('any digit', 'any letter'), and has no
    effect there.
    
    Mixtures of 'any character' with other literals should be disallowed: there
    are some that sort of make sense, such as: 'any character or 'dog' but they
    don't seem particularly useful. If required, they can be obtained using
    either/or.
    
    Mixtures of 'any character' with matchers such as end-of-string might be
    needed - but it may be better to disallow them now and allow them later if
    they turn out to be needed.
    
    
    Should it imply 'zero or more' when used with a plural group?
        - 'any digits'
        - 'any non-space'
        - 'any digits or letters'
        - 'any characters'   # equivalent of .* with /s mode
        - 'any non-newlines' # equivalent of .* without /s mode
        - 'any non-newline characters'
                             # equivalent of .* without /s mode
                             
    The semantics is that preceding a singular group name, it means 'one of the
    set', so 'any letter' means 'one character that is a letter'. But as the
    group name used alone means the same thing, there is no need for 'any'.
    
    But preceding a plural, it changes to mean 'if any', so 'match any digits'
    means 'match all the digits you find here, but there may be none'.
    
        digit           # Exactly one digit
        any digit       # Exactly one digit ??
        digits          # One or more digit characters
        any digits      # Zero or more digit characters ??
        non-digit       # Exactly one non-digit
        non-digits      # One or more non-digits
        any non-digit   # Exactly one non-digit
        any non-digits  # Zero or more non-digits ??
        
    With a quantifier, the use of 'any' with a plural becomes obscure:
        five of any letter  # OK
        five of any letters # Not OK
                    
\letter meaning: based on Perl 5.14
a Alarm(bell)              A Start of string
b Backspace/word boundary  B Not word boundary
c Control character \cx    C Single byte
d Digit                    D Not digit
e Escape character         E End quoting meta, casing, etc.
f Form feed                F
g Back reference           G End of previous match
h Horizontal whitespace    H Non-horizontal-whitespace
i                          I
j                          J
k Named back reference     K Keep
l Lower case next char     L Lower case until \E
m                          M
n Newline                  N Non-newline, \N{Unicode-name}
o                          O
p Unicode property         P Negated Unicode property
q                          Q Start quoting meta
r Carriage Return          R Generic newline
s Whitespace characater    S Non-whitespace character
t Tab                      T
u Titlecase next character U Uppercase until \E
v Vertical whitespace      V Non-vertical-whitespace
w Word character           W Non-word character
x Hex number  also \x{num} X Unicode combining sequence
y                          Y
z Absolute end of string   Z Almost end of string (eosx)

MRE2 Index - backslash sequences. Need to add Perl 5.10 and later
\? 139
\<...\> 21, 25, 50, 131-132, 150 in egrep 15 in Emacs 100 mimicking in Perl 341-342
\+ 139
\(...\) 135
\+ history 87
\0 116-117
\1 136, 300, 303 (also see backreferences) in Perl 41
\A 111, 127-128 (also see enhanced line-anchor mode) in Java 373 optimization 246
\a 114-115
\b 65, 114-115, 400 (also see: word boundaries; backspace) backspace and word boundary 44, 46 in Perl 286
\b\B 240
\C 328 
\D 49, 119 \d 49, 119 in Perl 288
\e 79, 114-115
\E 290 (also see literal-text mode)
\f 114-115 introduced 44
\G 128-131, 212, 315-316, 362 (also see pos) advanced example 130  in Java 373 in .NET 402 optimization 246
\kname (see named capture)
\l 290
\L ... \E 290 inhibiting 292
\n 49, 114-115 introduced 44 machine-dependency 114
\N{name} 290 (also see pragma) inhibiting 292
\p{property} 119
\Q...\E 290
\r 49, 114-115 machine-dependency 114
\s 49, 119 introduction 47 in Emacs 127 in Perl 288
\S 49, 56, 119
\t 49, 114-115 introduced 44
\u 116, 290, 400
\U 116
\U...\E 290 inhibiting 292
\V 364
\v 114-115, 364
\W 49, 119
\w 49, 65, 119 in Emacs 127 many different interpretations 93 in Perl 288
\x 116, 400 in Perl 286
\X 107, 125
\z 111, 127-128, 316 (also see enhanced line-anchor mode) in Java 373 optimization 246
\Z 111, 127-128 (also see enhanced line-anchor mode) in Java 373 optimization 246



=cut

sub sample {
# URL parser

# Example taken from "JavaScript: The Good Parts"
# In JavaScript, there is no /x option and you if you want to assemble a regex
# from parts you have to use strings rather than regex literals so backslashes
# then have to be escaped

# Perl equivalent to JavaScript regex literal
# Could recognise regex literals, but hard to detect whether an assignment of a
# string literal is actually a regex. 
# 
my $url_parser_js = qr/^(?:([A-Za-z]+):)?(\/{0,3})([0-9.\-A-Za-z]+)(?::(\d+))?(?:\/([^?#]*))?(?:\?([^#]*))?(?:\#(.*))?$/;
=format
var url_parser =  new RegExp("^(?:([A-Za-z]+):)?" +     // scheme
                             "(\/{0,3})"          +     // slash
                             "([0-9.\-A-Za-z]+)"  +     // host
                             "(?::(\d+))?"        +     // port
                             "(?:\/([^?#]*))?"    +     // path
                             "(?:\?([^#]*))?"     +     // query
                             "(?:\#(.*))? );            // fragment
                             
var url_parser_JS_string =
                             "^(?:([A-Za-z]+):)?"  +     // scheme
                             "(\\/{0,3})"          +     // slash
                             "([0-9.\\-A-Za-z]+)"  +     // host
                             "(?::(\\d+))?"        +     // port
                             "(?:\\/([^?#]*))?"    +     // path
                             "(?:\\?([^#]*))?"     +     // query
                             "(?:\\#(.*))?";             // fragment                             
=cut
my $url_parser = qr/ ^ (?:([A-Za-z]+) :  )? # scheme
                       ( \/{0,3}         )  # slash
                       ( [0-9.\-A-Za-z]+ )  # host
                       (?:  : ( \d+    ) )? # port
                       (?: \/ ( [^?#]* ) )? # path
                       (?: \? ( [^#]*  ) )? # query
                       (?: \# ( .*     ) )? # fragment
                    $ /x;
my $url_parser_named_captures =
                 qr/ ^ (?:([A-Za-z]+) :  )? # scheme
                       ( \/{0,3}         )  # slash
                       ( [0-9.\-A-Za-z]+ )  # host
                       (?:  : ( \d+    ) )? # port
                       (?: \/ ( [^?#]* ) )? # path
                       (?: \? ( [^#]*  ) )? # query
                       (?: \# ( .*     ) )? # fragment
                    $ /x;
my @url_bits = "http://www.ora.com:80/goodparts?q#fragment" =~ $url_parser;

my $url_ire = <<"END_IRE";
start of string
optional
    capture as scheme
        one or more letters
    :
capture as slashes
    zero to three /
capture as host
    one or more chars digit dot hyphen letter
optional
    :
    capture as port
        one or more digits
optional
    /
    capture as path
        zero or more characters except '#' or ?
optional
    ?
    capture as query
        zero or more characters except '#'
optional
    '#'
    capture as fragment
        zero or more characters
end of string
END_IRE


my $href_parser = qr/<A[^>]+?HREF\s*=\s*["']?([^'" >]+?)['"]?\s*>/i;

my $href_ire = <<"END_IRE";

    ignore case
    '<A'
    zero or more any characters except >
    'href'
    optional whitespace
    =
    optional whitespace
    optional " or '
    capture
        one or more characters but as few as possible anything except ^ or ' or "
    optional " or '
    optional whitespace
END_IRE

my $href_ire_2 = <<"END_IRE";

ignore case
mode ' ' is ows     # Literal space becomes optional whitespace
    '<A'
    zero or more not >
    'href = '
    opt " '
    get
        one or more lazy not ^ ' "
    opt char " '
    ' '
END_IRE


} # end of sample


=format
Possible character names that could be supported
This list is intended to suggest possibilities: it's not definitive requirements

Possible serious simplification coud be done by supporting just the really
common names (such as those needed for Unicode code points below FF), and
require the full Unicode names for others, either fully-hyphenated or bracketted
in some way to make it trivial to find the end of the name.


    Latin small letter
    Latin capital letter
    Latin letter
    letter
    capital letter
    upper-case letter
    upper case letter
    Latin capital letter A with macron
    Capital letter A with macron
    Capital A with macron
    letter A with macron
    A with macron
    letter A or B
    two of the letters A, B or C
    letter
    capital letter
    capital or small d, e or f
    upper or lower case D, E or F
    upper- or lower-case d, e or f
    case-insensitive d, e or f
    case insensitive d, e or f
    uncased d, e or f
    left-pointing double angle quotation mark
    left double angle quote

    Ambiguity? This is a result of specialisation
        letter a, b or c        # letter is noise word
        letter, or digit 2 or 5 # letter means 'any letter'

Possible ambiguities with naked quotes?
---------------------------------------

  two or three ' 'cat' "dog" # 2nd apos not followed by space or comma-space
                             # 1st apos is preceded and followed by space
                             # So 1st apos is naked, no ambiguity
  four to six  ' " ' dot '     ' tab '
               N N A-----A     B-----B    # Probably what was intended
               A---A     B-----B     N    # but will be interpreted as this
  four to six apostrophe double-quote ' dot ' ' tab ' # OK
                                      A-----A B-----B
  four to six ' dot ' ' tab ' ' " # Will work, but not a good idea
              A-----A B-----B N N
  four to six apostrophe, double-quote, ' dot ' or ' tab ' # Best?
                                        A-----A    B-----B
  seven or eight ' ' "O'Reilly"
                 A-A B--------B
  seven or eight '   "O'Reilly" # 2nd apos not followed by space or comma
                 A----------
  nine or ten ' " ' tab ' "
              A---A     N N  # 2nd apostrophe followed by space, so it matches 1st
  
  When we find an apostrophe (that isn't enclosed within double-quotes) it must
  be preceded by whitespace. If the next apostrophe is followed by whitespace or
  by a comma and whitespace, then those apostrophes are treated as a pair of
  single quotes. Otherwise the first apostrophe is treated as a naked character
  (and it must itself be followed by whitespace or a comma and whitespace).
 
  So the rules aren't ambiguous, but they are more complex than is desirable.
  But the alternatives presumably would either:
    - involve escape characters, which might be an easy rule to state (and
      implement) but is ugly in practice, or
    - forbid the use of naked ' and ", which breaks symmetry
  
  The problem is best avoided by using literal names rather than the naked
  characters ' and ", especially in the unusual cases where there are quoted
  literals and naked characters on the same line.

  For a literal that has both apostrophes and double quotes, such as:
    I said "Mrs. O'Reilly has gone"
  turning it into a quoted string is messy:
    'I said "Mrs. O'
    "'"
    'Reilly has gone"'

  Options to improve this include:
    - Adding new characters that are treated as quoting strings if they aren't
      naked: suitable candidates would preferably be on standard keyboards, so
      for US keyboards the back-tick character is the only obvious choice. Any
      kind of bracket has the disadvantage of the possible confusion with the
      use of square brackets for character classes
    - Using a keyword such as 'literal':
        literal  I said "Mrs. O'Reilly has gone"
      which takes the rest of the line (except for leading/trailing whitespace)
      as being a quoted string, regardless of embedded quotes 
  
  Names for ' and "
   Unicode calls them APOSTROPHE and QUOTATION MARK.
   'Quote' is ambiguous, as the characters are often referred to as single quote
   and double quote.
   'Quotes' may be intended to mean quotation mark, but it is also the plural of
   the ambiguous word 'quote'.
   Support: apostrophe, apos, single-quote, single quote
            apostrophes, aposes, single-quotes, single quotes [as plurals]
            quotation mark,  quotation,  double-quote,  double quote
            quotation marks, quotations, double-quotes, double quotes



Following is a quotation, from: http://perldoc.perl.org/perlretut.html

Principle 0: Taken as a whole, any regexp will be matched at the earliest
             possible position in the string.
Principle 1: In an alternation a|b|c... , the leftmost alternative that allows a
             match for the whole regexp will be the one used.
Principle 2: The maximal matching quantifiers ?, * , + and {n,m} will in general
             match as much of the string as possible while still allowing the
             whole regexp to match.
Principle 3: If there are two or more elements in a regexp, the leftmost greedy
             quantifier, if any, will match as much of the string as possible
             while still allowing the whole regexp to match. The next leftmost
             greedy quantifier, if any, will try to match as much of the string
             remaining available to it as possible, while still allowing the
             whole regexp to match. And so on, until all the regexp elements are
             satisfied.
Principle 0 overrides the others. The regexp will be matched as early as
possible, with the other principles determining how the regexp matches at that
earliest character position.



.............................
MRE2 p46 "As we move through this book, we'll see numerous (sometimes complex)
 situations where we need to take advantage of multiple levels of
 simultaneously interacting metacharacters"

With indented regular expressions you don't have to understand how to "take
advantage of multiple levels of simultaneously interacting metacharacters": for
a start there are no metacharacters.
.............................
"This document varies from difficult to understand to completely and utterly
opaque. The wandering prose riddled with jargon is hard to fathom in several
places." - this might be true of this code, but is actually a quote from
http://perldoc.perl.org/perlre.pdf, which is Perl's formal regex documentation.
.............................


--------------------------------------
Design Issue: Full or Partial Matching
--------------------------------------

Perl doesn't explicitly allow the regex or the operator (such as m//) to specify
whether the pattern must match the entire string. If the pattern has explicit
start and end of string matchers that must always be matched, then it is de
facto a full-string match: otherwise it's a partial match. Some languages provide
different method calls for full and partial matches: the question is whether
indented regexes should provide a way to specify full/partial, and whether it
should be mandatory to specify which.


    full/partial mandatory
    
        regex states 'full'
            start-of-string / end-of-string implied
        regex states 'partial'
            regex used as supplied
        regex does not state full/partial
            error (or maybe a warning, and use as supplied)
    
    full/partial not mandatory
    
        regex states 'full'
            start-of-string / end-of-string implied
        regex states 'partial'
            regex used as supplied
        regex does not state full/partial
            regex used as supplied

.............................
Unicode


.............................

From: http://www.regular-expressions.info/posixbrackets.html:
Note that Java only matches ASCII
  POSIX      Description             ASCII         Unicode     Shorthand  Java
[:alnum:] Alphanumeric characters [a-zA-Z0-9]     [\p{L&}\p{Nd}]        \p{Alnum}
[:alpha:] Alphabetic characters   [a-zA-Z]        \p{L&}                \p{Alpha}
[:ascii:] ASCII characters        [\x00-\x7F]     \p{InBasicLatin}      \p{ASCII}
[:blank:] Space and tab           [ \t]           [\p{Zs}\t]            \p{Blank}
[:cntrl:] Control characters      [\x00-\x1F\x7F] \p{Cc}                \p{Cntrl}
[:digit:] Digits                  [0-9]           \p{Nd}             \d \p{Digit}
[:graph:] Visible characters (i.e. anything except spaces, control characters, etc.)
                                  [\x21-\x7E]     [^\p{Z}\p{C}]         \p{Graph}
[:lower:] Lowercase letters       [a-z]           \p{Ll}                \p{Lower}
[:print:] Visible characters and spaces (i.e. anything except control characters, etc.)
                                  [\x20-\x7E]     \P{C}                 \p{Print}
[:punct:] Punctuation & symbols   [!"#$%&'()*+,\-./:;<=>?@[\\\]^_`{|}~]
                                                  [\p{P}\p{S}]          \p{Punct}
[:space:] All whitespace characters, including line breaks
                                  [ \t\r\n\v\f]   [\p{Z}\t\r\n\v\f]  \s \p{Space}
[:upper:] Uppercase letters       [A-Z]           \p{Lu}                \p{Upper}
[:word:]  Word characters (letters, numbers and underscores)
                                  [A-Za-z0-9_]    [\p{L}\p{N}\p{Pc}] \w   N/A
[:xdigit:] Hexadecimal digits     [A-Fa-f0-9]     [A-Fa-f0-9]           \p{XDigit}



From http://perldoc.perl.org/perlreref.pdf:

POSIX character classes and their Unicode and Perl equivalents:
          ASCII-  Full-
POSIX     range   range     backslash
[[:...:]] \p{...} \p{...}   sequence   Description
-----------------------------------------------------------------------
alnum PosixAlnum XPosixAlnum           Alpha plus Digit
alpha PosixAlpha XPosixAlpha           Alphabetic characters
ascii ASCII Any ASCII character
blank PosixBlank XPosixBlank   \h      Horizontal whitespace
                  full-range also written as \p{HorizSpace} (GNU extension)
cntrl PosixCntrl XPosixCntrl           Control characters
digit PosixDigit XPosixDigit   \d      Decimal digits
graph PosixGraph XPosixGraph           Alnum plus Punct
lower PosixLower XPosixLower           Lowercase characters
print PosixPrint XPosixPrint           Graph plus Print, but not any Cntrls
punct PosixPunct XPosixPunct           Punctuation and Symbols in ASCII-range,
                                                  just punct outside it
space PosixSpace XPosixSpace           [\s\cK]
      PerlSpace  XPerlSpace            \s      Perl's whitespace definition
upper PosixUpper XPosixUpper           Uppercase characters
word  PerlWord   XPosixWord    \w      Alnum + Unicode marks + connectors, like '_' (Perl extension)
xdigit           XPosixDigit           Hexadecimal digit, ASCII-range is [0-9A-Fa-f]
      ASCII_Hex_Digit

-------------------------------------------
start-of-word (?<!\w)(?=\w)
    not preceding
        word-char
    followed by
        word-char
end-of-word   (?<=\w)(?!\w)
    preceding
        word-char
    not followed by
        word-char
not start-of-word (?: (?<=\w) | (?!\w) )
    either
        preceding word-char
    or
        not followed by word-char
not end-of-word (?: (?<!\w) | (?=\w) )
    either
        not preceding word-char
    or
        followed by word-char
-------------------------------------------        
        
## Optional, quantifiers/laziness, capture, modes (case), alternations
##
## Capture can share parentheses with optional/{0,1}, but not with other
## quantifiers. 'Capture two or three x' means ( x{2,3} ) not (x){2,3},
## but 'optional capture x' or capture optional x' can be (x)? or (x?).
## We generate the (x)? form that works even if x is really an
## alternation.
##
## If we know that a quantifier applies to a single atom, it doesn't
## need parentheses. We can easily tell if the current node has more
## than one atom, but if it has child nodes it is more difficult. We
## could check to see whether the combined regex from all the
## descendants is not a single atom, by examining the sub-regex. A
## single character or a single character class is an atom. A single
## alternation may also be enclosed in non-capturing parentheses, but
## this needs to be distinguished from anything more complex.
##
##
##  Does the regex content already have fully-enclosing parentheses?
##      The initial ( must match with the ending ), although there may
##      be nested parenthesised elements, or parentheses that are
##      character matchers e.g. \( or [(]
##  Is the regex content a single atom?
##      This may be a single character, or a character class
##      So   A   or  \(  or  [ABC(+)12] are all single atoms, 
##      But  AB  and [AB][CD] and [AB]C and A[BC] are not
##
## 
## Optional cannot share with numeric quantifiers: {2,3}? means lazy,
## rather than optional. 'optional' is mostly shorthand for {0,1}, but
## it makes sense to be able to say:
##      optional two or three A
##          --> (?: A{2,3} )?
##      optional two or three 'cat' or 'dog'
##          --> (?: (?: cat | dog ){2,3} )?
##             where we need two sets of parentheses
## Optional followed by a plural group means zero or *more*
##      optional hyphens
##          --> [-]*
## but 'optional' differs from 'zero or one' with plurals:
##      zero or one hyphens
##          --> [-]?
## which is the same as:
##      zero or one hyphen
##          --> [-]?

## Modes can share parentheses with quantifiers
##
## Any parentheses suffice for alternation, so they can share with
## capture.
##
## Optional can modify the minimum of a numeric quantifier from one to
## zero: if the minimum is one then all it needs to do is to change it
## to zero.

## We treat 'two or three capture' identically with 'capture two or three'.
## We should enforce ordering: capture->optional->numeric quantifiers on
## a single line, and issue error if different ordering used
## 'Two or three optional A' maps naturally to (?: A? ){2,3}
## 'Optional two or three A' maps naturally to (?: A{2,3} )?
## 



## ? means 'optional' when it is the first quantifier, but 'lazy' when
## it is the second. The idea is that 'lazy' or 'greedy' only make sense
## if there is a qualifier for them to modify. We can have a
## quantifier+lazy nested within another quantifier, but the laziness
## only affects the nested stuff. The structure:
##      one or more
##          lazy
##              a
##          b
## is not valid, because the 'lazy' has no quantifier to modify, but it
## is hard to detect because we don't know until we reach the 'b'.
## The easy and probably correct solution is to make lazy/greedy
## modifiers of an individual quantifier, rather than being a mode that
## is inherited, and to allow them only on the same line as that
## quantifier.

Capture
    Either omitted (no capture)
    or     Capture (with no name)
    or     Capture as xxxx (where xxxx is the name to capture into)
Optionality
    Either omitted  (not optional)
    or     Optional (everything  inset/indented is optional)
Quantifier(s)
    How many
        Either Number
        or     Number to Number
        or     Number or More
    Laziness/greediness/atomicity
        Either omitted (greedy by default)
        or     Greedy  (explicitly greedy)
        or     Lazy
        or     Atomic
Matchers(s)
    Quoted literals = Sequences
        Either one or more characters within apostrophes
        or     one or more characters within quotation-marks
    Naked character(s)
        One or more characters, separated by spaces
    Ranges
    Groups - digit, word-char, letter, whitespace-char
    Hex, Octal, Control characters
    Assertion(s)
        Either word-boundary
        or     start-of-string
        or     end-of-string
        or     start-of-line
        or     end-of-line
        or     almost-end-of-string
    Back-references

Other Stuff
    Laziness/Greediness/Atomicity - tie in with quntifiers?
    Lookahead/lookbehind
    Patterns/Macros
    Conditions
==============================================================================
Interpolation Possibilities

    1) Interpolate into the indented regex
    
        This requires the regex to be re-generated each time it is needed.
        
        Caching of the generated regex could be automated, so that requests
        using the same interpolated values would not need re-generation - and
        the compiled version of the generated regex could presumably be stored
        as well, avoiding recompilation.
        
        The values interpolated would need to conform to the indented regex
        notation: the main effects would be:
         - alternative characters (creating a character class) would need to be
           separated by spaces
         - a literal space would need to be quoted, or represented by 'space'
         - a literal newline would need to be represented by 'newline'
         
        
    2) Generate regex with 'classic' interpolation
    
       This only works if the generated regex is pasted or 'required' into the
       program source.
       
       The syntax of the 
    
    3)
    
==============================================================================
Notes on Perl rules for deciding which character set modifier is in effect
--------------------------------------------------------------------------

This is my analysis of the Perl documentation. The rules are complex, and the
precedence is not always clear.

The level of complexity is one of the reasons for wanting to have a simpler,
context-free method for deciding modes in indented regexes.

Perl is partly forced to have this complexity to provide backward compatibility.

The /a mode would be better as the default behaviour than /d as it is simpler
and more consistent. The /d behaviour tries to guess whether to use unicode
semantics, so the meaning of the regex depends on the contents of the data. The
/a behaviour is consistent regardless of data content, and avoids some of the
unicode-related security issues.

Indented regexes can be retro-fitted into Perl scripts that were written for
earlier versions of Perl which implicitly used the /d behaviour. If those
scripts need Perl's /d behaviour they can explicitly request it by using
'legacy-unicode' in the indented regex.

The Existing Rules:
...................
If there are one or more explicit modifiers (?d/u/a/l) or (?d/u/a/l: ... ) that 
apply to this point in the regular expression

    Use the innermost modifier
    
If there is an explicit modifier on the regex operator (e.g. m/.../d)

    Use that modifier

If there is a 'use bytes' in effect...
    ... then something is probably wrong. See the notes on 'use bytes' below.


If there is a use re '/flags' pragma in effect

    Use those flags
    
If there is a 'use locale' in effect...

    then /l mode will be used

If any of the following are specified

    use feature '5.1n';
    use 5.1n.0;
    use 5.01n;

    where n is 2 or more, then mode /u will be used


If "use feature 'unicode_strings'" is in effect
or the regular expression being used was compiled while it was in effect

    then mode /u will be used
    
If none of the above apply

    then mode /d will be used

................................................

use bytes

    From the "use bytes" documentation:
    If you feel that the functions here within might be useful for your
    application, this possibly indicates a mismatch between your mental model of
    Perl Unicode and the current reality

    


    


==============================================================================


Conditions affecting combinations of matchers

    Literals have leading 'not'
    One or more ranges
    One or more quoted strings
    One or more naked characters
    One or more assertions
    One or more groups (non-negated)
    One or more negated groups

'anything except' as synonym for 'not'

Backspace: has to be hex (or octal, or control) outside character cless (in
Perl), as \b means 'word-boundary' outside a character class




? Are there any valid situations where there is a 'not' that does not apply
  to all the literals on a line?
  
    non-digit non-letter not + - =          # [^-p{Letter}\d+=]
    anything except digit letter + - =      # [^-p{Letter}\d+=]
    not digit letter + - =                  # [^-p{Letter}\d+=]
  
    any letter except a g f     # 'except' isn't 'not' here
                                # How would we implement this in Unicode? ???
    any character except a g f  # 'except' does mean 'not' here
                                # Always [^agf] whether Unicode or not
    not a g f
    any except a g f
    anything except a g f
    any but a g f
    
    'cat' 'dog' not letter digit     # Do we allow this? (?: cat | dog | [^\d\pL])
    'cat' 'dog' non-letter non-digit # Do we allow this?
    
    We can allow any combination that can be fitted into a single character
    class.
    
# This decision table is design documentation only: it's not complete enough to
# be worth turning into executable code, particularly as the combination rules
# aren't that complex. Some of the checking may be done at tokenising/parsing
# time, while the actions (apart from error reporting) will mostly be done at
# generation time

Literals have leading 'not' (or 'anything except') Y Y Y Y - Y   Y Y N N N N N N N N
One or more multi-character quoted strings         - - - Y - -   - - - - - - Y - - - 
One or more ranges                                 - - - - - Y   - - - Y - - - - - -
One or more naked character                        - - - - - -   Y - - - Y - - - - -
One or more groups or properties (non-negated)     - - - - - -   - Y - - - Y - - - -
One or more assertions \b ^ $ \A \Z \z             Y - - - - -   - - - - - - - Y - -
One or more negated assertions \B                  - Y - - - -   - - - - - - - - Y -
One or more negated groups or properties           - - Y - - -   - - - - - - - - - Y
Any negated                                        - - - - Y -   - - - - - - - - - -
Any non-negated                                    - - - - Y -   - - - - - - - - - -

Err: Not + negated group                           - - X - - -   - - - - - - - - - -
Err: Not + assertion                               X - - - - -   - - - - - - - - - -
Err: Not + negated assertion                       - X - - - -   - - - - - - - - - -
Err: Not + string(s)                               - - - X - -   - - - - - - - - - -
Err: Mixed negated/non-negated                     - - - - X -   - - - - - - - - - -
Add to character class                             - - - - - X   X X - X X X - - - X 
Negate character class                             - - - - - X   X X - - - - - - - -

Add to alternatives list                           - - - - - -   - - - - - - X X X -


===========
Macro Types
===========

    These match a sequence of characters, rather than a single character. The
    nearest equivalent in conventional regexes are patterns such as \w+ or \d+
    which match a sequence of word-characters or of digits.
    
    Like other regex elements, if unanchored they can start anywhere and end
    anywhere, e.g. toys4u would match as an integer because it has an integer
    embedded. The use of matches_all() or matches_part() can help - and not
    importing matches() would force the user to specify whether full or partial
    matching is wanted.
    
    One major difference is the option of returning a reformatted version of the
    captured data, rather than just the raw captured character string. This may
    be as simple as removing commas from numbers, or much more complex as in
    converting a date such as '23rd December 2011' to its equivalent in yyyymmdd
    format, epoch seconds or Excel days.
    
    This requires ways for the regex and/or the interface to specify what is
    allowed in the input and how the results are to be returned. There is a
    trade-off between allowing potentially very complex mixtures of macro types
    and ordinary regex elements, and keeping the interface simple and easy to
    describe. The initial approach is to limit the complexity: e.g to a single
    date with multiple input formats and multiple captured and returned fields.
    
    Design musings:
        'Capture' always captures the raw characters.
        'Return' returns reformatted data. It specifies the name and/or format
            of reformatted fields or sub-fields.
        'As' and 'to' and 'in' and 'into' are ambiguous - they could mean the
        name under which to store the captured/reformatted data, or the format.
        That doesn't preclude using them, but it may be a cause of user errors.
        There may be situations where both storage-name and reformatting are
        required - and two storage-names may be needed, one for raw captured
        data and one for reformatted.
        
        
        Strict vs. Liberal
        
            Liberal formats attempt to allow any unambiguous representation of
            the data, at least within normal variations.
            
            So a liberal d/m/yyyy date match would allow dash or slash as a separator,
            and one or two digits for day and month, and two or four for year.
            
                00 to 30:  add 2000
                31 to 99:  add 1900
                otherwise: add nothing (already validated to be 1900 to 2099)
            
            
            A liberal dd/mmm/yy format would allow month names or numbers. It
            would only match if the month is valid, so month will be
            
                if ($data =~ wre q"capture d/m/y") {
                    # Date matches, fix up two-digit years
                    $year = $+{year} +=  $+{year} < 31  ? 2000 :
                                         $+{year} < 100 ? 1900 : 0;
                    # Convert month                                         
                    $month = $month_number{lc $+{month}} || $+{month}; 
                    $day   = $+{day};
                } else {
                    # Not an acceptable date
                }
            Strict formats only match if the data exactly conforms. So d/m/yyyy would
            not allow leadng zeros on day or month, would require four digits
            for the year, and would require the separators to be slashes.
            
            
            d/m/y
            dd/mm/yy
            dd/mm/yyyy
            
            Strict vs. liberal is likely to apply to an entire regex
            
        Plain match vs. Capture vs. Reformat
        
        Plain match just reports whether the regex matches, returning no data.
        
        
        Some data may match the regex pattern but be invalid, e.g. 29/02/2011.
        The hardest cases would ones such as 29/02/2000: the regex or validation
        code would have to embed the rules for leap years (divisible by 400, or
        divisible by 4 unless also divisible by 100). The interface should provide
        consistent behaviour regardless of whether the data doesn't match or
        matches but is invalid: a single check should cover both situations.
        
        match_all() and match_part() or find() are the recommended interface.
        match() is provided and does match_part(), but if the pattern starts
        with start-of-string and ends with end-of-string then match()
        effectively does match_all().
        
        - Boolean: whether the data matches the macro type.
          Multiple captures:
            - one that contains the raw input for 
        - Capture string only: captures the raw data if it matched, otherwise
          undef.
        - Reformatted value only: gets a single reformatted value if it
          matches and is valid, otherwise undef. A different function or method
          to one that returns captured text? Or just different keyword, e.g.
          'return' instead of 'capture'?
        - Reformatted sub-values: gets array of reformatted sub-values.
          Sub-values might be the separate day, month and year parts of a date.
          A different function or method to one that returns captured text?
        - Reformatted values or sub-values via named results. Captured
          characters, reformatted values and sub-values all available via
          $+{name}, with names for the reformatted versions generated from the
          'capture as' name.
          So 'capture as date_sold date to epoch' would populate:
                $+{date_sold}
                $+{date_sold_epoch}
          'Capture as date_sold return dd return mm return yyyy date' would populate:
                $+{date_sold}
                $+{date_sold_dd}
                $+{date_sold_mm}
                $+{date_sold_yyyy}
          'Capture as date_sold return ddmmyyyy date' would populate:
                $+{date_sold}
                $+{date_sold_ddmmyyyy}
    
        There is a balance in what should attempted by a regex: the ideal is
        that the regex does what regexes do well, leaving more complex
        processing to its user but providing the user with pre-parsed input.
        So a generalised date handler might match dates in various formats,
        including allowing month numbers or names. It could return the month as
        a single digit, two digits as month_number or mm, or the first three letters
        of its name (with variants such a Jan, jan and JAN all allowed) as
        month_name or mmm. Code that handles a matched date could assume that
        either mm or mmm (but not both) will be populated, and that a populated
        field will meet validation rules. Similarly, if two and four digit years
        are allowed, yy or yyyy would be populated. There would be a guarantee
        that day numbers would be between 1 and 31, but not that they were valid
        for their month. The exception might be for strictly-formatted dates
        such as yyyy-mm-dd (and possibly d/m/yyyy or m/d/yyyy) 
        
            ( 19 | 20 (?: [02468][048] | [13579][26] )
            
            Correctly predicts leap years for dates from 1901 to 2099.
            It incorrectly matches 1900, which was not a leap year.
            
            ( 1[6-9] | 2[0-4] (?: (?: [02468][048] ) | (?: [13579][26]) )
            Is almost correct for dates from 1601 to 2499: it incorrectly
            allows 29th February in 1700, 1800, 1900, 2100, 2200 and 2300.
            
            1900 not a leap year (divisible by 100 but not by 400)
            2000 is  a leap year (divisible by 400)
            2100 not a leap year (divisible by 100 but not by 400)
            
        <Leap year> then 02 01-29 or 04|06|09|11 01-30 or 01|03|05|07|08|10|12
        30 days hath September, April, June and November
                      9           4     6        11
        dmy 29 / 02 / <leap year>
            31 / 04|06|09|11 / <any year>
            30|29 / 01|03-12 / <any year>
            01-28 / 01-12    / <any year>
        
        
        (?<yyyy> 19 | 20 (?: [02468][048]  | [13579][26] ) )
        
        mdy 02          / 29    / <leap year>
            04|06|09|11 / 31    / <any year>
            01|03-12    / 30|29 / <any year>
            01-12       / 01-28 / <any year>
        
                          
                      
                      
Use Cases for regular expressions
    User input validation
    
        This use case applies when some end-user entered data is to be validated.
        The ideal would be validation that allowed any unambiguous format, and
        captured the data in the desired immediately-processable form.
        
        The data may have to be returned in a relatively raw state, unless:
        - executable code is embedded within the regex, or
        - an object is provided with methods that return the reformatted data, or
        - procedural routines support returning reformatted data, perhaps by
          saving the result of the most recent match, or
        - procedural routines are alerted that reformatted data will be wanted,
          e.g. by explicit request in the regex
        
        Some ambiguities are nearly insoluble except by having arbitrary rules:
        for example 01/02/03 as a date could be dd/mm/yy, mm/dd/yy or yy/mm/dd. 
        
        The approach taken for dates is to require the pattern to specify the
        basic format (the sequence in which day, month and year are presented),
        even if there are variants in details (such as the separator character,
        whether the month can be specified by a number, its abbreviated name or
        its full name). If alternative formats are to be allowed they have to be
        explicitly requested.
        
        For numbers, similar constraints mean that further processing is needed
        to use the value captured, e.g. to remove embedded commas used to
        separate the number into groups of at most three digits, or to handle a
        negative value that is indicated by parentheses.
        
        
    Predetermined exact format
    
        This use case applies when the data being matched has been created by an
        automated process, and has a known format. The purpose of the regex is
        generally to filter the data, and possibly to extract one or more
        fields.
        

    Plurals
    
        Plurals of characters names match one or more of that character, unless
        there is an explicit numeric quantifier.
        
    Masks
        
        
    Types
    
        The idea behind types is to support something more complex than simple
        sequences of word characters or sequences of digits.
        
        There are significant problems, such as different definitions of what
        constitutes a word (for example) depending on which natural of
        programming is being parsed. Similarly the definition of an integer may
        vary depending on locale
    
        Word
            Common built-in is letters, digits and underscore as
            word-characters. 'Word' as a type could default to these characters.
            They are an odd set as they are derived from a programming language
            concept of a word. The more natural set for English would exclude
            digits and underscores but include embedded hyphens, and probably
            embedded apostrophes for words such as "can't".
            
            Another question would be what to use as delimiters. Options include
            that words have to be surrounded by whitespace, or that any character
            (such as punctuation) that isn't part of a word ends a word. 
            
        Integer
            Signed or unsigned, with or without commas (or locale-specific digit
            separators?).
            Less common options include allowing spaces between sign and digits,
            using parentheses to indicate negative values, etc.
            Would a regex object include methods that returned numbers in a
            normalised format, e.g. with commas removed?
            
            
        Number
            Decimal number, with optional decimal point
            
        Float
            Decimal, with optional exponent
        
        
        
        Hex/Octal/Binary
            Can be just digits of the appropriate range, but also allow various
            explicit formats
        
        Money
        
        Date
            Allowed input formats:
                Masked (with alternative masks allowed in a single capture)
                    e.g.
                    dd/mm/yyyy
                    mm/yy mm/yyyy
                    dd.mm.yyyy, where . means allow - or / or space or null
                Liberal-dmy (any reasonable date in dmy format)
                    dd-mm-yy
                    dd-mm-yyyy
                    dd-mmm-yy
                    dd-mmm-yyyy
                    mmm-dd-yy
                    mmm-dd-yyyy
                    yyyy-mm-dd
                    where '-' is a separator that can be hyphen, space, slash or null
                Liberal-mdy (any reasonable date in mdy format)
            Allowed returned formats:
                Epoch seconds
                Excel days (Win or Mac)
                Masked, such as yyyymmdd, dd/mm/yy dd-mmm-yyyy etc.
                Separate day dd, month mm and/or year yyyy
                Perlish day (1 to 31), month (0 to 11) and year (yyyy - 1900)
                
        Time
    
    Attributes
        Min/max
        Thousands separators


==============================================================================

#### WARNING - DEVELOPER'S NOTES ONLY  #####
#### WARNING - DEVELOPER'S NOTES ONLY  #####
#### WARNING - DEVELOPER'S NOTES ONLY  #####

## The syntax and semantics of the regular expression notation supported by this
## code has evolved substantially. The examples in the comments above above DO
## NOT accurately reflect what has been implemented


...In fact, the main challenge in learning regular expressions is just getting
used to the terse notation used to express these concepts.
      --perlretut (the definitive regex tutorial for Perl)

	

# Some people, when confronted with a problem, think “I know, I'll use regular
# expressions.” Now they have two problems.
#    --Jamie Zawinski, in comp.emacs.xemacs


# I define UNIX as “30 definitions of regular expressions living under one roof.” —Don Knuth
#
# http://swtch.com/~rsc/regexp/regexp4.html
# In fact, Tom Christiansen recently told me that even people in the Perl
# community use it (perl -Mre::engine::RE2), to run regexp search engines (the
# real kind) on the web without opening themselves up to trivial denial of
# service attacks.
# 
# http://xkcd.com/208/
==============================================================================
==============================================================================
Documentation
    For newbies to regular expressions
        - an intro to regexes, using wre examples
        
        - how to use the tools for converting a wre to a terse regex
        
        - how to write new code using wres
            - procedural routines
            - oo interface
        
        - how to use the tools for converting terse regexes to wres,
            e.g. when working on an existing program that has terse regexes
            Using the terse-to-ire tools:
                - standalone, one regex at a time
                - to add wres as comments to existing code
                - to replace terse regexes with equivalent wres
                
    For users working with existing code containing terse regexs
    
        - an intro to wres, with examples showing wre and terse versions
        
        - how to use the tools for converting a terse regex to a wre
        - how to use the tools for converting a wre to a terse regex
    
    
    Formal, exhaustive
    
        Full description of syntax and semantics
        
        Keywords indexed by group (quantifiers, character names, etc.)
        Keywords indexed alphabetically
        Keywords indexed by terse equivalent
        
==============================================================================
==============================================================================

Procedural Interface

  The wre() function
    
    This is passed a wre, and returns the equivalent terse regex. So where you
    would have written a terse regex you put a call to wre(), passing it the
    equivalent wre.
    
    Options that would be appended to a terse regex (such as /i /s /m etc.) are
    generally passed as part of the wre. The exceptions are /g and /gc, which
    affect how the regex is used: they are best handled by using wret() instead.
    
  The wret() function
    
    This is passed a wre and returns a reference to the equivalent terse regex.
    It is intended to be used as an alternative to wre() in a match where /g or
    /gc are required:
    
        if ( $data =~ qr/${wret 'a b c'}/gc ) {...}  ## Doesn't work!!
    
    
    

==============================================================================
==============================================================================


=head1 AUTHOR

Derek Mead

=head1 COPYRIGHT

Copyright (c) 2011, 2012 Derek Mead

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut


1;  # Package must end with 1
