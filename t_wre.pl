use strict;
use warnings;
## use diagnostics;
no warnings 'utf8';
use 5.008;

use YAML::XS;
use Test::More;
use lib "../yaml_schema";
use YAML::Validator;
use RegExp::Wre qw(wre wret flag_value _wre_to_tre);
use RegExp::Tre2Wre qw( tre_to_wre );
use RegExp::Slr;

binmode STDOUT, ":utf8";
$YAML::Validator::YAML_LIB = 'XS';   # Force YAML::Validator to use YAML::XS

=format

Test Types (Warning: it might not be like this yet)

    Some questions that the tests aim to answer:
        - Does the wordy-to-terse converter produce a correct tre given a
          particular wordy?
        - Does the wordy-to-terse converter produce the same tre as it used to?          
        - Does the terse-to-wordy converter produce a correct wordy given a
          particular tre?
        - Does the terse-to-wordy converter produce the same wordy as it used to?
                  
        - If we convert wordy->terse->wordy->terse, does the resulting tre match
          in the same way as the original wordy?
        - If we convert terse->wordy->terse, does the resulting tre match
          in the same way as the original wordy? In this case we start with a
          manually written tre, which may make use of features that are never
          used by tre's generated from wordies.
          
    Wordy-to-terse conversion
        Supplied a wordy, some match tests, and optionally a terse version (tre1).
        Converts the wordy, producing tre2
        Runs the match tests against tre2
        If a terse version (tre1) is supplied, it is:
          - compared to the generated version (tre2) to determine (e.g.) whether the
            conversion has changed
          - used for the match tests
        Any failures in matching or capturing are reported.
        
    Terse-to-wordy conversion
        Supplied a tre (tre1), some match tests, and optionally a wordy version.
        Converts tre1 to a wordy
        Converts the wordy back to a tre (tre2)
        Runs the match tests against tre1:
            failures indicate an error in the test
        Runs the match tests against tre2:
            failures indicate an error in the conversion (or possibly the test)
        If a wordy version is supplied, it is
          - compared to the generated version to determine (e.g.) whether the
            conversion has changed
          - converted to a tre (tre3) and used for the match tests
            Any failures in matching or capturing are reported.    
    
    Round-trip wordy-terse-wordy
        Supplied a wordy.
        Converts the wordy to terse then back to wordy.
        Probably not useful as automated tests comparing the original wordy with
        the result of the round-trip, as there will usually be minor layout
        differences even if there are no major differences.
        
    Pre-converted
        This is more applicable to a test harness in a language that does not
        support the conversions in a library, and does not have access to
        converters implemented as executables.
        Supplied a wre and the corresponding tre, already converted, e.g. by
        a conversion utility. No conversion is done, but the same match tests
        are applied to both versions and any differences are reported. 
        

=cut


my $parms = shift;
my $selected_group = $parms || '';


my $schema = <<'EOSCHEMA';
overall:
groups:
    # A group of tests
    # Tests can be grouped as desired: there are some options that will default
    # through into each test in the group
    #
    
    - group-name: text
      wordy-to-terse:  boolean   # Default for entire group
      terse-to-wordy:  boolean   # Default for entire group
      tests:
        - name: required text
          pause: boolean
          notes: str
          wordy:
          wordy-in:
          wordy-out:
          terse:
          terse-in:
          terse-out:
          terse-options: /[-gcimsoxdual]*/
          embed-original: boolean default false
          prefer-class-to-escape: boolean default true
          solo-space-as-class: boolean
          # Unidirectional tests
          wordy-to-terse:  boolean   # Must have wordy-in supplied if true
          terse-to-wordy:  boolean   # Must have terse-in supplied if true
          
         
          # Matches are optional.
          # They are tested using both the before and after versions of the regex
          
          matches:
            -
                data:
                match: boolean default true
                global: boolean
                # Either or neither named-matches or match-array can be specified
                # Specifying both is legal, but unexpected
                named-matches:
                  <match_key>:
                match-array:
                  - string

EOSCHEMA
          
my $tests = <<'EOTESTS';
overall:
groups:
    # A group of tests
    # Tests can be grouped as desired: there are some options that will default
    # through into each test in the group
    #
    - group-name: Aspects currently under investigation
      terse-to-wordy: true
      tests:
        - name: Error unbalanced parentheses 1
          terse-in: |
            (ab
          wordy-out: |
            Error: Unbalanced parentheses
            capture 'ab'

        - name: Error unbalanced parentheses 2
          terse-in: |
            (ab))
          wordy-out: |
            Error: Unbalanced parentheses
            capture 'ab'
            
        - name: Fancy URL checker
          notes: |
            http://mathiasbynens.be/demo/url-regex
          terse-in: |
              ^(?:(?:https?|ftp)://)(?:\S+(?::\S*)?@)?(?:(?!10(?:\.\d{1,3}){3})(?!127(?:\.\d{1,3}){3})(?!169\.254(?:\.\d{1,3}){2})(?!192\.168(?:\.\d{1,3}){2})(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z\x{00a1}-\x{ffff}0-9]+-?)*[a-z\x{00a1}-\x{ffff}0-9]+)(?:\.(?:[a-z\x{00a1}-\x{ffff}0-9]+-?)*[a-z\x{00a1}-\x{ffff}0-9]+)*(?:\.(?:[a-z\x{00a1}-\x{ffff}]{2,})))(?::\d{2,5})?(?:/[^\s]*)?$
          wordy-out: |
            start-of-string
            either
                'http'
                optional  s
            or 'ftp'
            '://'
            optional
                one or more  non-whitespace
                optional
                    :
                    zero or more  non-whitespace
                @
            either
                not followed by
                    '10'
                    three
                        .
                        one to three  digit
                not followed by
                    '127'
                    three
                        .
                        one to three  digit
                not followed by
                    '169.254'
                    two
                        .
                        one to three  digit
                not followed by
                    '192.168'
                    two
                        .
                        one to three  digit
                not followed by
                    '172.'
                    either
                        1
                        6-9
                    or
                        2
                        digit
                    or
                        3
                        0-1
                    two
                        .
                        one to three  digit
                either
                    1-9
                    optional  digit
                or
                    1
                    digit
                    digit
                or
                    2
                    0 1
                    digit
                or
                    '22'
                    0-3
                two
                    .
                    either
                        optional  1
                        one or two  digit
                    or
                        2
                        0-4
                        digit
                    or
                        '25'
                        0-5
                .
                either
                    1-9
                    optional  digit
                or
                    1
                    digit
                    digit
                or
                    2
                    0-4
                    digit
                or
                    '25'
                    0-4
            or
                zero or more
                    one or more  a-z hex-00a1 to hex-ffff 0-9
                    optional  hyphen
                one or more  a-z hex-00a1 to hex-ffff 0-9
                zero or more
                    .
                    zero or more
                        one or more  a-z hex-00a1 to hex-ffff 0-9
                        optional  hyphen
                    one or more  a-z hex-00a1 to hex-ffff 0-9
                .
                two or more  a-z hex-00a1 to hex-ffff
            optional
                :
                two to five  digit
            optional
                /
                zero or more  not whitespace
            eosx
          
          matches:
            - data:     http://foo.com/blah_blah
            - data:     http://foo.com/blah_blah/
            - data:     http://foo.com/blah_blah_(wikipedia)
            - data:     http://foo.com/blah_blah_(wikipedia)_(again)
            - data:     http://www.example.com/wpstyle/?p=364
            - data:     https://www.example.com/foo/?bar=baz&inga=42&quux
            - data:     http://✪df.ws/123
            - data:     http://userid:password@example.com:8080
            - data:     http://userid:password@example.com:8080/
            - data:     http://userid@example.com
            - data:     http://userid@example.com/
            - data:     http://userid@example.com:8080
            - data:     http://userid@example.com:8080/
            - data:     http://userid:password@example.com
            - data:     http://userid:password@example.com/
            - data:     http://142.42.1.1/
            - data:     http://142.42.1.1:8080/
            - data:     http://➡.ws/䨹
            - data:     http://⌘.ws
            - data:     http://⌘.ws/
            - data:     http://foo.com/blah_(wikipedia)#cite-1
            - data:     http://foo.com/blah_(wikipedia)_blah#cite-1
            - data:     http://foo.com/unicode_(✪)_in_parens
            - data:     http://foo.com/(something)?after=parens
            - data:     http://☺.damowmow.com/
            - data:     http://code.google.com/events/#&product=browser
            - data:     http://j.mp
            - data:     ftp://foo.bar/baz
            - data:     http://foo.bar/?q=Test%20URL-encoded%20stuff
            - data:     http://مثال.إختبار
            - data:     http://例子.测试
            - data:     http://उदाहरण.परीक्षा
            - data:     http://-.~_!$&'()*+,;=:%40:80%2f::::::@example.com
            - data:     http://1337.net
            - data:     http://a.b-c.de
            - data:     http://223.255.255.254
            - data:     http://
              match:    false
            - data:     http://.
              match:    false
            - data:     http://..
              match:    false
            - data:     http://../
              match:    false
            - data:     http://?
              match:    false
            - data:     http://??
              match:    false
            - data:     http://??/
              match:    false
            - data:     http://#
              match:    false
            - data:     http://##
              match:    false
            - data:     http://##/
              match:    false
            - data:     http://foo.bar?q=Spaces should be encoded
              match:    false
            - data:     //
              match:    false
            - data:     //a
              match:    false
            - data:     ///a
              match:    false
            - data:     ///
              match:    false
            - data:     http:///a
              match:    false
            - data:     foo.com
              match:    false
            - data:     rdar://1234
              match:    false
            - data:     h://test            
            - data:     http:// shouldfail.com
              match:    false
            - data:     :// should fail
              match:    false
            - data:     http://foo.bar/foo(bar)baz quux
              match:    false
            - data:     ftps://foo.bar/
              match:    false
            - data:     http://-error-.invalid/
              match:    false
            - data:     http://a.b--c.de/
              match:    false
            - data:     http://-a.b.co
              match:    false
            - data:     http://a.b-.co
              match:    false
            - data:     http://0.0.0.0
              match:    false
            - data:     http://10.1.1.0
              match:    false
            - data:     http://10.1.1.255
              match:    false
            - data:     http://224.1.1.1
              match:    false
            - data:     http://1.1.1.1.1
              match:    false
            - data:     http://123.123.123
              match:    false
            - data:     http://3628126748
              match:    false
            - data:     http://.www.foo.bar/
              match:    false
            - data:     http://www.foo.bar./
              match:    false
            - data:     http://.www.foo.bar./
              match:    false
            - data:     http://10.1.1.1
              match:    false
            - data:     http://10.1.1.254
              match:    false

          
    - group-name: ExamplesA
      terse-to-wordy: true
      tests:            
        - name: Test Wrox Beginning Perl Chapter 8 Example 8.2
          terse-options: x
          terse-in: |
            (?x-ism:(?-xism:(?:(?i)(?:[+-]?)(?:(?=[.]?[0123456789])
            (?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])
            (?:(?:[+-]?)(?:[0123456789]+))|))|(?-xism:[[:upper:]][[:alnum:]_]*))
            (?:\s*(?-xism:[-+*/%])\s*(?-xism:(?:(?i)(?:[+-]?)
            (?:(?=[.]?[0123456789])(?:[0123456789]*)(?:(?:[.])
            (?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[+-]?)
            (?:[0123456789]+))|))|(?-xism:[[:upper:]][[:alnum:]_]*)))*)                        
          wordy-out: |
            case-sensitive
                case-sensitive
                        either
                            case-insensitive
                                optional  + hyphen
                                followed by
                                    optional  .
                                    0 1 2 3 4 5 6 7 8 9
                                newline
                                zero or more  0 1 2 3 4 5 6 7 8 9
                                optional
                                    .
                                    zero or more  0 1 2 3 4 5 6 7 8 9
                                E
                                newline
                                optional  + hyphen
                                one or more  0 1 2 3 4 5 6 7 8 9
                        or
                            case-sensitive
                                posix-upper
                                zero or more  posix-alnum _
                zero or more
                    zero or more  whitespace
                    case-sensitive hyphen + * / %
                    zero or more  whitespace
                    case-sensitive
                            either
                                case-insensitive
                                    optional  + hyphen
                                    newline
                                    followed by
                                        optional  .
                                        0 1 2 3 4 5 6 7 8 9
                                    zero or more  0 1 2 3 4 5 6 7 8 9
                                    optional
                                        .
                                        newline
                                        zero or more  0 1 2 3 4 5 6 7 8 9
                                    E
                                    optional  + hyphen
                                    newline
                                    one or more  0 1 2 3 4 5 6 7 8 9
                            or
                                case-sensitive
                                    posix-upper
                                    zero or more  posix-alnum _
        
        - name: Test 0
          terse-in: |
              \G \# ( .* ) 
          terse-options: x
          wordy-out: |
              end-of-previous-match
              #
              capture
                  zero or more  non-newline
                  
        - name: Paragraph numbers and headings
          notes:
          terse-in: |
            \(([a-zA-Z]|[ivx]{1,3}|\d{1,2})\) +(.*)
          wordy-out: |
            (
            capture
                    either a-z A-Z
                    or
                        one to three  i v x
                    or
                        one or two  digit
            )
            one or more  space
            capture
                zero or more  non-newline
          matches:
            -
              global: true
              data: |
                  (ix) The Larch
                      Stuff about larch trees
                  (42) The Oak
                      Stuff about oak trees
                  (d) The Pine
                      Stuff about pine trees
              match-array:
                - ix
                - The Larch
                - 42
                - The Oak
                - d
                - The Pine

    - group-name: Known problems wordy-to-terse
      wordy-to-terse: true
      tests:
        - name: unicode not accepted
          wordy-in:  ascii case-insensitive word-ch
          terse-out: (?ai:\w)
          matches:
            - match: no
              data: "ĈŃŃ-ĈŃŃ"
            - match: yes
              data: "cnn-cnn"
        - name: unicode accepted
          wordy-in:  full-unicode case-insensitive word-ch
          terse-out: (?ui:\w)
          matches:
            - match: yes
              data: "ĈŃŃ-ĈŃŃ"
            - match: yes
              data: "cnn-cnn"              
        - name: Single space within literal, space-means-wss
          terse-out: cat\s+dog
          notes: 
          terse-options: -x
          embed-original: No
          wordy-in: |
            space-means-wss 'cat dog'
      
        - name: meta characters generate single-char class not escaped char
          notes: 
          embed-original: No
          prefer-class-to-escape: Yes
          wordy-in: |
            .
          terse-options: -x
          terse-out: "[.]"

        - name: meta characters generate escape not single-char class
          notes: 
          embed-original: No
          prefer-class-to-escape: No
          wordy-in: |
            .
          terse-options: -x
          terse-out: \.

        - name: meta characters generate single-char class not escaped char 2
          notes: 
          embed-original: No
          prefer-class-to-escape: Yes
          wordy-in: |
            .
            *
          terse-options: -x
          terse-out: "[.][*]"

        - name: meta characters generate escape not single-char class 2
          notes: 
          embed-original: No
          prefer-class-to-escape: No
          wordy-in: |
            .
            *
          terse-options: -x
          terse-out: \.\*
        - name: meta characters generate single-char class not escaped char 3
          notes: 
          embed-original: No
          prefer-class-to-escape: Yes
          wordy-in: |
            .
            *
            (
            )
            [
            ]
            {
            }
            ?
            \
            /
            +
            |
            
            . * ( ) [ ] { } ? \ / + |
            ". * ( ) [ ] { } ?  / + | "
          terse-options: x
          
          terse-out: |
            [.][*][(][)]\[\][{][}][?]\\[\/][+][|][.*()\[\]{}?\\\/+|] \.[ ]\*[ ]\([ ]\)[ ]\[[ ]\][ ]\{[ ]\}[ ]\?[ ][ ]\/[ ]\+[ ]\|[ ]
        - name: meta characters generate single-char class not escaped char 3B
          notes: 
          embed-original: No
          prefer-class-to-escape: Yes
          wordy-in: |
            b
            .
            *
            (
            )
            [
            ]
            {
            }
            ?
            \
            /
            +
            |
            
            . * ( ) [ ] { } ? \ / + |
            ". * ( ) [ ] { } ?  / + |"
          terse-options: -x
          
          terse-out: b[.][*][(][)]\[\][{][}][?]\\[\/][+][|][.*()\[\]{}?\\\/+|]\. \* \( \) \[ \] \{ \} \?  \/ \+ \|

        - name: meta characters generate escape not single-char class 3
          notes: 
          embed-original: No
          prefer-class-to-escape: No
          wordy-in: |
            .
            *
          terse-options: -x
          terse-out: \.\*
          
        - name: plural and singular within capture, embed original
          terse-out: "                             # capture\n(- | \\d+ )                    #     digits dash\n"
          notes: Generated empty comment line, didn't collapse capture
          terse-options: x
          embed-original: Yes
          wordy-in: |+
            capture
                digits dash


        - name: plural and singular within capture
          terse-out: "(-|\\d+)"
          notes: Generated Leading space, plus two spaces before dash when /x mode off. Fixed
          terse-options: -x                    
          wordy-in: |
            capture
                digits dash                                
    - group-name: Examples wordy-to-terse
      wordy-to-terse: true
      tests:
        - name: capture-optional-a
          terse-out: |
              ( (?: dog | a )?)
          terse-options: x
          wordy-in: |
            capture
                optional
                    a 'dog'
                    


                    
                    
                    
        - name: optional-capture-a
          terse-out: |
              ( dog | a )?
          terse-options: x
          wordy-in: |
            optional
                  capture
                      a 'dog'
        - name: Range using 'to'
          terse-out: |
              [a-zA-Z0-9\x{02}-\x{10}]
          terse-options: x
          wordy-in: |
              a-z A-Z 0-9 hex-02 to hex-10       
        - name: Quoted string, free spacing mode
          notes: 
          wordy-in: |
            "Plain quoted string"
            'Mrs. O'Grady said "Hello!"'
            'Mrs. O'Grady said "Hello!"'
            "Mrs. O'Grady said 'Hello!'"
            'Mrs. O'Grady said 'Hello!''
            "Mrs. O'Grady said "Hello!""
            'Mrs. O'Grady said "Hello!" and laughed'
            "Mrs. O'Grady said 'Hello!' and laughed"

          terse-options: x
          # Note the terse output is really one long string, but we input it
          # here using a YAML block that puts a single space between each line
          terse-out: >
            Plain[ ]quoted[ ]string
            Mrs\.[ ]O'Grady[ ]said[ ]"Hello!"
            Mrs\.[ ]O'Grady[ ]said[ ]"Hello!"
            Mrs\.[ ]O'Grady[ ]said[ ]'Hello!'
            Mrs\.[ ]O'Grady[ ]said[ ]'Hello!'
            Mrs\.[ ]O'Grady[ ]said[ ]"Hello!"
            Mrs\.[ ]O'Grady[ ]said[ ]"Hello!"[ ]and[ ]laughed
            Mrs\.[ ]O'Grady[ ]said[ ]'Hello!'[ ]and[ ]laughed

        - name: whitespace
          notes: Check that whitepace is not always treated as a plural
          wordy-in: |
            whitespace
            whitespaces
            one whitespace
            two or three whitespace
          terse-out: |
            \s\s+\s\s{2,3}

        - name: Quoted string with embedded space, explicit solo 1
          solo_space-as-class: no
          wordy-in: |
            'cat and dog'
          terse-options: -x
          terse-out: |
            cat and dog

        - name: Quoted string with embedded space, explicit solo 2
          solo_space-as-class: yes
          wordy-in: |
            'cat'
            space
            'dog'
          terse-options: -x
          terse-out: |
            cat[ ]dog

        - name: Quoted string with embedded space, default solo
          wordy-in: |
            'cat and dog'
          terse-options: -x
          terse-out: |
            cat and dog

        - name: Quoted string
          notes: 
          wordy-in: |
            'Mrs. O'Grady said "Hello!"'
            ";"
            "Mrs. O'Grady said 'Hello!'"
            ";"
            'Mrs. O'Grady said 'Hello!''
            ";"
            "Mrs. O'Grady said "Hello!""
            ";"
            'Mrs. O'Grady said "Hello!" and laughed'
            ";"
            "Mrs. O'Grady said 'Hello!' and laughed"
          terse-options: -x
          terse-out: |
            Mrs\. O'Grady said "Hello!";Mrs\. O'Grady said 'Hello!';Mrs\. O'Grady said 'Hello!';Mrs\. O'Grady said "Hello!";Mrs\. O'Grady said "Hello!" and laughed;Mrs\. O'Grady said 'Hello!' and laughed
        
        - name: Quoted string, free spacing mode with semi-colons
          notes: 
          wordy-in: |
            'Mrs. O'Grady said "Hello!"'
            ";"
            "Mrs. O'Grady said 'Hello!'"
            ";"
            'Mrs. O'Grady said 'Hello!''
            ";"
            "Mrs. O'Grady said "Hello!""
            ";"
            'Mrs. O'Grady said "Hello!" and laughed'
            ";"
            "Mrs. O'Grady said 'Hello!' and laughed"
          terse-options: x
          terse-out: |
            Mrs\.[ ]O'Grady[ ]said[ ]"Hello!"; Mrs\.[ ]O'Grady[ ]said[ ]'Hello!'; Mrs\.[ ]O'Grady[ ]said[ ]'Hello!'; Mrs\.[ ]O'Grady[ ]said[ ]"Hello!"; Mrs\.[ ]O'Grady[ ]said[ ]"Hello!"[ ]and[ ]laughed; Mrs\.[ ]O'Grady[ ]said[ ]'Hello!'[ ]and[ ]laughed

        - name: Solo space 1
          solo-space-as-class: yes
          terse-options: -x
          wordy-in: |
            ' '
          terse-out: |
            [ ]
        - name: Solo space 2
          solo-space-as-class: no
          terse-options: -x
          wordy-in: |
            ' '
          terse-out: " "
            
        - name: Paragraph numbers and headings
          notes:
          solo-space-as-class: yes
          wordy-in: |
            (
            capture
                either one letter
                or one to three  i v x
                or one or two digits    
            )
            spaces
            capture
                zero or more  non-newline
          terse-out: |
            [(]((?:[A-Za-z]|[ivx]{1,3}|\d{1,2}))[)][ ]+([^\n]*)
          matches:
            -
              global: true
              data: |
                  (ix) The Larch
                      Stuff about larch trees
                  (42) The Oak
                      Stuff about oak trees
                  (d) The Pine
                      Stuff about pine trees
              match-array:
                - ix
                - The Larch
                - 42
                - The Oak
                - d
                - The Pine

        - name: Paragraph numbers and headings, full unicode
          notes: Test doesn't include unicode character because YAML::XS:Load barfs
          wordy-in: |
            full-unicode
                (
                capture
                    either one letter
                    or one to three  i v x
                    or one or two digits    
                )
                spaces
                capture
                    zero or more  non-newline
          solo-space-as-class: no
          terse-out: |
            (?u:[(]((?:(?:\p{Letter})|[ivx]{1,3}|\d{1,2}))[)] +([^\n]*))
          matches:
            -
              global: true
              data: |
                  (ix) The Larch
                      Stuff about larch trees
                  (42) The Oak
                      Stuff about oak trees
                  (Z) The Pine
                      Stuff about pine trees
              match-array:
                - ix
                - The Larch
                - 42
                - The Oak
                - Z
                - The Pine
                
        - name: Individual named characters, part 1
          notes: One at a time, one per line so we can easily check with a match
          wordy-in: |
                minus
                dot
                slash
                dash
                period 
                forward-slash
                hyphen
                forward_slash
                solidus
                plus
                equals
                star
                equals-sign
                asterisk
                equals_sign
                backslash
                ampersand
                back-slash
                colon
                semi-colon
                semicolon
                slash
                forward_slash
                solidus
                star
                asterisk
                plus
                equals
                equal_sign
                equals_sign
                backslash
                back_slash
                ampersand
                colon
                semi_colon
                semicolon
                apostrophe
                sq        
                single_quote
                double_quote
                dq         
          prefer-class-to-escape: Yes
          terse-out: |
                -[.][\/]-[.][\/]-[\/][\/][+]=[*]=[*]=\\&\\:;;[\/][\/][\/][*][*][+]===\\\\&:;;'''""
          matches:
            -   match: true
                data: |
                    -./-./-//+=*=*=\&\:;;///**+===\\&:;;'''""
        - name: Individual named characters, part 2
          notes: One at a time, one per line so we can easily check with a match
          wordy-in: |
                line_feed 
                tab
                newline
                new_line
                space
                backspace
                alarm
                escape      # the character x1B, not to be confused with backslash
                form_feed      
                carriage_return
                no_break_space 
                soft_hyphen    
          terse-out: |
                \x0A\t\n\n \x08\a\e\f\r\xA0\xAD
          matches:
            -   match: true
                data: "\x0a\t\n\n \x08\a\e\f\r\xa0\xad"
        - name: Plural named characters, part 1
          notes: One at a time, one per line so we can easily check with a match
          prefer-class-to-escape: No
          wordy-in: |
                minuses
                dots
                slashes
                dashes
                periods 
                forward-slashes
                hyphens
                forward_slashes
                pluses
                soliduses
                stars
                equals-signs
                asterisks
                equals_signs
                backslashes
                ampersands
                back-slashes
                colons
                semi-colons
                apostrophes
                semicolons
                sqs        
                double_quotes
                single_quotes
                dqs         

          terse-out: |
                -+\.+\/+-+\.+\/+-+\/+\++\/+\*+=+\*+=+\\+&+\\+:+;+'+;+'+"+'+"+
          matches:
            -
                match: True
                data: |
                    -./-./-/+/*=*=\&\:;';'"'"
            -
                match: True
                data: |
                    --..//--..//--//++//**==**==\\&&\\::;;'';;''""''""
            -
                match: False
                data: |
                    --..//--..//--//++//**==*X*==\\&&\\::;;'';;''""''""
        - name: Plural named characters, part 1B
          notes: One at a time, one per line so we can easily check with a match
          prefer-class-to-escape: Yes
          wordy-in: |
                minuses
                dots
                slashes
                dashes
                periods 
                forward-slashes
                hyphens
                forward_slashes
                pluses
                soliduses
                stars
                equals-signs
                asterisks
                equals_signs
                backslashes
                ampersands
                back-slashes
                colons
                semi-colons
                apostrophes
                semicolons
                sqs        
                double_quotes
                single_quotes
                dqs         

          terse-out: |
                -+[.]+[\/]+-+[.]+[\/]+-+[\/]+[+]+[\/]+[*]+=+[*]+=+\\+&+\\+:+;+'+;+'+"+'+"+
          matches:
            -
                match: True
                data: |
                    -./-./-/+/*=*=\&\:;';'"'"
            -
                match: True
                data: |
                    --..//--..//--//++//**==**==\\&&\\::;;'';;''""''""
            -
                match: False
                data: |
                    --..//--..//--//++//**==*X*==\\&&\\::;;'';;''""''""                    
        - name: Example from MRE
          notes: Extracting alias name and value, example used in MRE2
          wordy-in: |
                sol
                'alias'
                wss
                get not wss
                wss
                get chs
          terse-out: |
                (?sm:^alias\s+(\S+)\s+(.+))
          matches:
            -
                data: |
                    alias Jeff jfriedl@regex.info
                match-array:
                  - Jeff
                  - jfriedl@regex.info
            -
                data: |
                    alias Perlbug perl5-porters@perl.org
                match-array:
                  - Perlbug
                  - perl5-porters@perl.org
            -
                data: |
                    alias Prez president@whitehouse.gov
                match-array:
                  - Prez
                  - president@whitehouse.gov
            -
                match: false
                data: |
                    alias Prez=president@whitehouse.gov
      
        - name: Example from MRE except uses named captures
          notes: Extracting alias name and value, example used in MRE2
          wordy-in: |
                start-of-line
                'alias'
                whitespaces
                capture as alias one or more non-whitespace
                whitespaces
                capture as value characters
          terse-out: |
                (?sm:^alias\s+(?<alias>\S+)\s+(?<value>.+))
          matches:
            -
                data: |
                    alias Jeff jfriedl@regex.info
                named-matches:
                  alias: Jeff
                  value: jfriedl@regex.info
            -
                data: |
                    alias Perlbug perl5-porters@perl.org
                named-matches:
                    alias: Perlbug
                    value: perl5-porters@perl.org
            -
                data: |
                    alias Prez president@whitehouse.gov
                named-matches:
                    alias: Prez
                    value: president@whitehouse.gov

        - name: Alias, but with named captures and named back-ref
          notes: Extracting alias name and value, example used in MRE2
          wordy-in: |
                start-of-line
                'alias'
                whitespaces
                capture as alias one or more non-whitespace
                whitespaces
                capture as value characters
                =
                backref-alias
          terse-out: |
                (?sm:^alias\s+(?<alias>\S+)\s+(?<value>.+)=\g{alias})
          matches:
            -
                data: |
                    alias Jeff jfriedl@regex.info=Jeff
                named-matches:
                  alias: Jeff
                  value: jfriedl@regex.info
            -
                data: |
                    alias Perlbug perl5-porters@perl.org=Perlbug
                named-matches:
                    alias: Perlbug
                    value: perl5-porters@perl.org
            -
                data: |
                    alias Perlbug perl5-porters@perl.org=Perlbugfree
                named-matches:
                    alias: Perlbug
                    value: perl5-porters@perl.org
            -
                data: |
                    alias Perlbug perl5-porters@perl.org=perlbug
                match: false
            -
                data: |
                    alias Prez president@whitehouse.gov=Prez
                named-matches:
                    alias: Prez
                    value: president@whitehouse.gov

    - group-name: Unicode terse-to-wordy
      terse-to-wordy: true
      tests:
        - name: Unicode modes  1
          terse-in: |
                 (?u: cd | ef  )
          terse-options: x
          wordy-out: |
             full-unicode 'cd' 'ef'
          
        - name: Unicode modes 2
          terse-in: |
                 (?u) cd | ef 
          terse-options: x
          wordy-out: |
              either full-unicode 'cd'
              or full-unicode 'ef'

        - name: Unicode modes 3
          terse-in: |
                 (?u) cd | e (?a) f 
          terse-options: x
          wordy-out: |
              either full-unicode 'cd'
              or full-unicode
                  e
                  ascii
                      f
        - name: Unicode modes 4
          terse-in: |
                 (?u) c (?i) d | e (?a) f 
          terse-options: x
          wordy-out: |
                either
                    full-unicode
                        c
                    case-insensitive full-unicode
                        d
                or case-insensitive full-unicode
                    e
                    case-insensitive ascii
                        f

        - name: Unicode modes 5
          terse-in: |
                 ( (?u) c (?i) d (?ds) d.d (?-i) | e.e (?a) f ) g.h 
          terse-options: x
          wordy-out: |
                capture
                        either
                            full-unicode
                                c
                            case-insensitive full-unicode
                                d
                            case-insensitive legacy-unicode
                                d
                                character
                                d
                        or case-sensitive legacy-unicode
                            e
                            character
                            e
                            case-sensitive ascii
                                f
                g
                non-newline
                h

        - name: Unicode modes 5 A
          terse-in: |
            c (?i) d (?d) | w
          terse-options: x
          wordy-out: |
            either
                c
                case-insensitive
                    d
            or case-insensitive legacy-unicode w
      
        - name: Unicode modes 5 good
          terse-in: |
            c (?i) d (?d) e | w
          terse-options: x
          wordy-out: |
                either
                    c
                    case-insensitive
                        d
                    case-insensitive legacy-unicode
                        e
                or case-insensitive legacy-unicode w

        - name: Unicode modes 6
          terse-in: |
            c (?i) d (?d) e | w
          terse-options: x
          PAUSE: YES
          wordy-out: |
                either
                    c
                    case-insensitive
                        d
                    case-insensitive legacy-unicode
                        e
                or case-insensitive legacy-unicode w   
    - group-name: Examples terse-to-wordy
      terse-to-wordy: true
      tests:
      
        - name: Example from MRE
          notes: Extracting alias name and value, example used in MRE2
          wordy-out: |
                start-of-line
                'alias'
                one or more  whitespace
                capture
                    one or more  non-whitespace
                one or more  whitespace
                capture 
                    one or more  character
          terse-in: |
                (?sm:^alias\s+(\S+)\s+(.+))
          matches:
            -
                data: |
                    alias Jeff jfriedl@regex.info
                match-array:
                  - Jeff
                  - jfriedl@regex.info
            -
                data: |
                    alias Perlbug perl5-porters@perl.org
                match-array:
                  - Perlbug
                  - perl5-porters@perl.org
            -
                data: |
                    alias Prez president@whitehouse.gov
                match-array:
                  - Prez
                  - president@whitehouse.gov
            -
                match: false
                data: |
                    alias Prez=president@whitehouse.gov

        - name: Lexical modes  1
          terse-in: |
                 (?i) cd | ef  
          terse-options: x
          wordy-out: |
              either case-insensitive 'cd'
              or case-insensitive 'ef'
              
        - name: Lexical modes  2
          terse-in: |
                 (?i: cd | ef )
          terse-options: x
          wordy-out: |
              case-insensitive 'cd' 'ef'
              
        - name: Lexical modes  3
          terse-in: |
              (?:(?i: cd | ef))
          terse-options: x
          wordy-out: |
              case-insensitive 'cd' 'ef'
              
        - name: Lexical modes  4
          terse-in: |
              (?:(?i: cd | ef)g)
          terse-options: x
          wordy-out: |
              case-insensitive 'cd' 'ef'
              g
              
        - name: Lexical modes  5
          terse-in: |
                  a (?i) b | (?-i) c (\d) w       d
          terse-options: x
          notes: |
              Leading mode-switch end
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or
                  case-sensitive
                      c
                      capture digit
                      'wd'
              
        - name: Lexical modes  6
          terse-in: |
                  a (?i) b | (?-i) c (\d) w  (?i) d
          terse-options: x
          notes: |
              Leading mode-switch end
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or
                  case-sensitive
                      c
                      capture digit
                      w
                  case-insensitive
                      d
              
        - name: Lexical modes  7
          terse-in: |
                  a (?i) b | c (\d (?-i) Q)  w  (?i) d
          terse-options: x
          notes: |
              Nested lexical mode-switches
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or case-insensitive
                  c
                  capture
                      digit
                      case-sensitive
                          Q
                  w
                  case-insensitive
                      d
              
        - name: Lexical modes  8
          terse-in: |
                  a (?i) b | c (\d (?-i) Q+) w  (?i) d
          terse-options: x
          notes: |
              Nested lexical mode-switches
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or case-insensitive
                  c
                  capture
                      digit
                      case-sensitive
                          one or more  Q
                  w
                  case-insensitive
                      d
              
        - name: Lexical modes  9
          terse-in: |
                  a (?i) b | c (\d (?-i) Q++)w  (?i) d
          terse-options: x
          notes: |
              Nested lexical mode-switches
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or case-insensitive
                  c
                  capture
                      digit
                      case-sensitive
                          one or more possessive Q
                  w
                  case-insensitive
                      d
              
        - name: Lexical modes  10
          terse-in: |
                  a (?i) b | c (\d) (?-i) w  (?i) d
          terse-options: x
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or case-insensitive
                  c
                  capture digit
                  case-sensitive
                      w
                  case-insensitive
                      d
              
        - name: Lexical modes  11
          terse-in: |
              (?: a (?i) b | c (?-i) | p ) d
          terse-options: x
          notes: |
              trailing mode-switch
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or case-insensitive c
              or case-sensitive p
              d
              
        - name: Lexical modes  12
          terse-in: |
              (?: a (?i) b | c ) d
          terse-options: x
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or case-insensitive c
              d
              
        - name: Lexical modes  13
          terse-in: |
              (?: a (?i) b | c (?-i) w) d
          terse-options: x
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or case-insensitive
                  c
                  case-sensitive
                      w
              d
              
        - name: Lexical modes  14
          terse-in: |
                  a (?i) b | c (?-i) w  d
          terse-options: x
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or case-insensitive
                  c
                  case-sensitive
                      'wd'
              
        - name: Lexical modes  15
          terse-in: |
                  a (?i) b | c (?-i) w  (?i) d
          terse-options: x
          wordy-out: |
              either
                  a
                  case-insensitive
                      b
              or case-insensitive
                  c
                  case-sensitive
                      w
                  case-insensitive
                      d
              
        - name: Lexical modes  16
          terse-in: |
              \W{4} (?: a (?i) b | c ) d
          terse-options: x
          wordy-out: |
              four  non-word-char
              either
                  a
                  case-insensitive
                      b
              or case-insensitive c
              d
              
        - name: Lexical modes  17
          terse-in: |
              ab (?i) cd | ef
          terse-options: x
          wordy-out: |
              either
                  'ab'
                  case-insensitive
                      'cd'
              or case-insensitive 'ef'
              
        - name: Lexical modes  18
          terse-in: |
                 (?i) cd | ef [gh]
          terse-options: x
          wordy-out: |
              either case-insensitive 'cd'
              or case-insensitive
                  'ef'
                  g h
              
        - name: Lexical modes  19
          terse-in: |
              ab (?i) cd (?-i) ef
          terse-options: x
          wordy-out: |
              'ab'
              case-insensitive
                  'cd'
              case-sensitive
                  'ef'
              
        - name: Lexical modes  20
          terse-in: |
              ab (?i) (cd) q (?-i) ef
          terse-options: x
          wordy-out: |
              'ab'
              case-insensitive
                  capture 'cd'
                  q
              case-sensitive
                  'ef'
              
        - name: Lexical modes  21
          terse-in: |
              ab (?i) (cd) (?-is: p . r) q (?-i) ef
          terse-options: x
          wordy-out: |
              'ab'
              case-insensitive
                  capture 'cd'
                  case-sensitive
                      p
                      non-newline
                      r
                  q
              case-sensitive
                  'ef'
                  
        - name: Lexical modes 22 modes on & off
          terse-in: |
              ab (?i) (cd) (?s-i: p . r) q (?-i) ef
          terse-options: x
          wordy-out: |
              'ab'
              case-insensitive
                  capture 'cd'
                  case-sensitive
                      p
                      character
                      r
                  q
              case-sensitive
                  'ef'
        - name: Lexical modes 23 modes on & off
          terse-in: |
                ^ab (?i) (c.d) (?sm-i) ^ p . r q (?i-s) ^e.f (?-m) $
          terse-options: x
          wordy-out: |
                start-of-string
                'ab'
                case-insensitive
                    capture
                        c
                        non-newline
                        d
                case-sensitive
                    start-of-line
                    p
                    character
                    'rq'
                case-insensitive
                    start-of-line
                    e
                    non-newline
                    f
                    eosx
                
        - name: Test 1
          terse-in: |
              \( ( (?: [a-zA-Z] | [ivx]{1,3} | \d\d? ) ) \) \s+(.*)
          terse-options: x
          wordy-out: |
              (
              capture
                  either a-z A-Z
                  or
                      one to three  i v x
                  or
                      digit
                      optional  digit
              )
              one or more  whitespace
              capture
                  zero or more  non-newline
              
        - name: Test 2
          terse-in: |
              name="p_flow_id" value="([^"]*)"
          terse-options: -x
          wordy-out: |
              'name='
              double-quote
              'p_flow_id'
              double-quote
              ' value='
              double-quote
              capture
                  zero or more  not double-quote
              double-quote
              
        - name: Test 3
          terse-in: |
              p_flow_id" value="(.*?)"
          terse-options: -x
          wordy-out: |
              'p_flow_id'
              double-quote
              ' value='
              double-quote
              capture
                  zero or more minimal non-newline
              double-quote
              
        - name: Test 4
          terse-in: |
               \R \D [\R] 
          terse-options: x
          wordy-out: |
              generic-newline
              non-digit
              R
              
        - name: Test 5
          terse-in: |
               \b [\b] \B [\B] 
          terse-options: x
          wordy-out: |
              word-boundary
              backspace
              non-word-boundary
              B
              
        - name: Test 6
          terse-in: |
              ([012]?\d):([0-5]\d)(?::([0-5]\d))?(?i:\s(am|pm))?
          terse-options: x
          wordy-out: |
              capture
                  optional  0 1 2
                  digit
              :
              capture
                  0-5
                  digit
              optional
                  :
                  capture
                      0-5
                      digit
              optional  case-insensitive
                  whitespace
                  capture 'am' 'pm'
              
        - name: Test 7
          terse-in: |
              <A[^>]+?HREF\s*=\s*["']?([^'" >]+?)['"]?\s*>
          terse-options: -x
          wordy-out: |
              '<A'
              one or more minimal not >
              'HREF'
              zero or more  whitespace
              =
              zero or more  whitespace
              optional  double-quote apostrophe
              capture
                  one or more minimal not apostrophe double-quote space >
              optional  apostrophe double-quote
              zero or more  whitespace
              >
              
        - name: Test 8
          terse-in: |
              ^0?(\d*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)
          terse-options: x
          wordy-out: |
              start-of-string
              optional  0
              capture
                  zero or more  digit
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              ,
              capture
                  zero or more  not ,
              
        - name: Test 9
          terse-in: |
              [a-g]{1,2}+
          terse-options: x
          wordy-out: |
              one or two possessive a-g
              
        - name: Test 10
          terse-in: |
              [a-g]*+
          terse-options: x
          wordy-out: |
              zero or more possessive a-g
              
        - name: Test 11
          terse-in: |
              [a-g]++
          terse-options: x
          wordy-out: |
              one or more possessive a-g
              
        - name: Test 12
          terse-in: |
              [a-g]?+
          terse-options: x
          wordy-out: |
              optional possessive a-g
              
        - name: Test 13
          terse-in: |
              [a-g]*?
          terse-options: x
          wordy-out: |
              zero or more minimal a-g
              
        - name: Test 14
          terse-in: |
              [a-g]+?
          terse-options: x
          wordy-out: |
              one or more minimal a-g
              
        - name: Test 15
          terse-in: |
              [a-g]??
          terse-options: x
          wordy-out: |
              optional minimal a-g
              
        - name: Test 16
          terse-in: |
              21
          terse-options: -x
          wordy-out: |
              '21'
              
        - name: Test 17
          terse-in: |
              20
          terse-options: -x
          wordy-out: |
              '20'
              
        - name: Test 18
          terse-in: |
              0
          terse-options: -x
          wordy-out: |
              0
              
        - name: Test 19
          terse-in: |
              ^(?:21|19)
          terse-options: -x
          wordy-out: |
              start-of-string
              '21' '19'
              
        - name: Test 20
          terse-in: |
              ^(?:20|19)
          terse-options: -x
          wordy-out: |
              start-of-string
              '20' '19'
              
        - name: Test 21
          terse-in: |
              ^(?:19|20)
          terse-options: -x
          wordy-out: |
              start-of-string
              '19' '20'
     
        - name: Test 21
          terse-in: |
              ^(?:20|19)
          terse-options: -x
          wordy-out: |
              start-of-string
              '20' '19'
              
        - name: Test 22
          terse-in: |
              ^(?:19|20)
          terse-options: -x
          wordy-out: |
              start-of-string
              '19' '20'
              
        - name: Test 23
          terse-in: |
              ^(?:0)
          terse-options: -x
          wordy-out: |
              start-of-string
              0
              
        - name: Test 24
          terse-in: |
              ^0
          terse-options: -x
          wordy-out: |
              start-of-string
              0
              
        - name: Test 25
          terse-in: |
              ^(?:19|20)\d{2}-\d{2}-\d{2}(?:$|[ ]+\#)
          terse-options: -x
          wordy-out: |
              start-of-string
              '19' '20'
              two  digit
              hyphen
              two  digit
              hyphen
              two  digit
              either eosx
              or
                  one or more  space
                  #
              
        - name: Test 26
          terse-in: |
              ^[012]?\d:[0-5]\d(?:[0-5]\d)?(?:\s(?:AM|am|PM|pm))?(?:$|[ ]+\#)
          terse-options: -x
          wordy-out: |
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
                  whitespace
                  'AM' 'am' 'PM' 'pm'
              either eosx
              or
                  one or more  space
                  #
              
        - name: Test 27
          terse-in: |
              \G(?:(?:[+-]?)(?:[0123456789]+))
          terse-options: gc-x
          wordy-out: |
              end-of-previous-match
              optional  + hyphen
              one or more  0 1 2 3 4 5 6 7 8 9
              
        - name: Test 28
          terse-in: |
              (?:(?:[+-]?)(?:[0123456789]+))
          terse-options: -x
          wordy-out: |
              optional  + hyphen
              one or more  0 1 2 3 4 5 6 7 8 9
              
        - name: Test 29
          terse-in: |
              (?:(?:[-+]?)(?:[0123456789]+))
          terse-options: -x
          wordy-out: |
              optional  hyphen +
              one or more  0 1 2 3 4 5 6 7 8 9
              
        - name: Test 30
          terse-in: |
              (?i:J[.]?\s+A[.]?\s+Perl-Hacker)
          terse-options: -x
          wordy-out: |
              case-insensitive
                  J
                  optional  .
                  one or more  whitespace
                  A
                  optional  .
                  one or more  whitespace
                  'Perl'
                  hyphen
                  'Hacker'
              
        - name: Test 31
          terse-in: |
              http://(?:(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|(?:(?:[a-z]|[A-Z])|[0-9])(?:(?:(?:[a-z]|[A-Z])|[0-9])|-)*(?:(?:[a-z]|[A-Z])|[0-9]))\.)*(?:(?:[a-z]|[A-Z])|(?:[a-z]|[A-Z])(?:(?:(?:[a-z]|[A-Z])|[0-9])|-)*(?:(?:[a-z]|[A-Z])|[0-9]))\.?|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(?::[0-9]*)?(?:/(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*(?:;(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*)*(?:/(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*(?:;(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*)*)*(?:\?(?:[;/?:@&=+$,]|(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f]))*)?)?
          terse-options: -x
          wordy-out: |
              'http://'
              either
                  zero or more
                      either
                          either
                              a-z A-Z
                          or 0-9
                      or
                          either
                              a-z A-Z
                          or 0-9
                          zero or more
                                  either
                                      either
                                          a-z A-Z
                                      or 0-9
                                  or hyphen
                          either
                              a-z A-Z
                          or 0-9
                      .
                  either
                      a-z A-Z
                  or
                      a-z A-Z
                      zero or more
                              either
                                  either
                                      a-z A-Z
                                  or 0-9
                              or hyphen
                      either
                          a-z A-Z
                      or 0-9
                  optional  .
              or
                  one or more  0-9
                  .
                  one or more  0-9
                  .
                  one or more  0-9
                  .
                  one or more  0-9
              optional
                  :
                  zero or more  0-9
              optional
                  /
                  zero or more
                          either
                              either
                                  either
                                      a-z A-Z
                                  or 0-9
                              or hyphen _ . ! ~ * apostrophe ( )
                          or
                              %
                              0-9 A-F a-f
                              0-9 A-F a-f
                          or : @ & = + $ ,
                  zero or more
                      ;
                      zero or more
                              either
                                  either
                                      either
                                          a-z A-Z
                                      or 0-9
                                  or hyphen _ . ! ~ * apostrophe ( )
                              or
                                  %
                                  0-9 A-F a-f
                                  0-9 A-F a-f
                              or : @ & = + $ ,
                  zero or more
                      /
                      zero or more
                              either
                                  either
                                      either
                                          a-z A-Z
                                      or 0-9
                                  or hyphen _ . ! ~ * apostrophe ( )
                              or
                                  %
                                  0-9 A-F a-f
                                  0-9 A-F a-f
                              or : @ & = + $ ,
                      zero or more
                          ;
                          zero or more
                                  either
                                      either
                                          either
                                              a-z A-Z
                                          or 0-9
                                      or hyphen _ . ! ~ * apostrophe ( )
                                  or
                                      %
                                      0-9 A-F a-f
                                      0-9 A-F a-f
                                  or : @ & = + $ ,
                  optional
                      ?
                      zero or more
                              either ; / ? : @ & = + $ ,
                              or
                                  either
                                      either
                                          a-z A-Z
                                      or 0-9
                                  or hyphen _ . ! ~ * apostrophe ( )
                              or
                                  %
                                  0-9 A-F a-f
                                  0-9 A-F a-f
              
        - name: Test 32
          terse-in: |
              http://(?::?[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.[a-zA-Z]*(?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.?|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(?::[0-9]*)?(?:/(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*(?:;(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*)*(?:/(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*(?:;(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*)*)*(?:\?(?:(?:[;/?:@&=+$,a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f]))*)?)?
          terse-options: -x
          wordy-out: |
              'http://'
              either
                  optional  :
                  a-z A-Z 0-9
                  optional
                      zero or more  a-z A-Z 0-9 hyphen
                      a-z A-Z 0-9
                  .
                  zero or more  a-z A-Z
                  optional
                      zero or more  a-z A-Z 0-9 hyphen
                      a-z A-Z 0-9
                  optional  .
              or
                  one or more  0-9
                  .
                  one or more  0-9
                  .
                  one or more  0-9
                  .
                  one or more  0-9
              optional
                  :
                  zero or more  0-9
              optional
                  /
                  zero or more
                      either
                          either a-z A-Z 0-9 hyphen _ . ! ~ * apostrophe hex-28 hex-29
                          or
                              %
                              0-9 A-F a-f
                              0-9 A-F a-f
                      or : @ & = + $ ,
                  zero or more
                      ;
                      zero or more
                          either
                              either a-z A-Z 0-9 hyphen _ . ! ~ * apostrophe hex-28 hex-29
                              or
                                  %
                                  0-9 A-F a-f
                                  0-9 A-F a-f
                          or : @ & = + $ ,
                  zero or more
                      /
                      zero or more
                          either
                              either a-z A-Z 0-9 hyphen _ . ! ~ * apostrophe hex-28 hex-29
                              or
                                  %
                                  0-9 A-F a-f
                                  0-9 A-F a-f
                          or : @ & = + $ ,
                      zero or more
                          ;
                          zero or more
                              either
                                  either a-z A-Z 0-9 hyphen _ . ! ~ * apostrophe hex-28 hex-29
                                  or
                                      %
                                      0-9 A-F a-f
                                      0-9 A-F a-f
                              or : @ & = + $ ,
                  optional
                      ?
                      zero or more
                          either ; / ? : @ & = + $ , a-z A-Z 0-9 hyphen _ . ! ~ * apostrophe hex-28 hex-29
                          or
                              %
                              0-9 A-F a-f
                              0-9 A-F a-f
              
        - name: Test 33
          terse-in: |
              <A[^>]+?HREF\s*=\s*["']?([^'" >]+?)['"]?\s*>
          terse-options: -x
          wordy-out: |
              '<A'
              one or more minimal not >
              'HREF'
              zero or more  whitespace
              =
              zero or more  whitespace
              optional  double-quote apostrophe
              capture
                  one or more minimal not apostrophe double-quote space >
              optional  apostrophe double-quote
              zero or more  whitespace
              >
              
        - name: Test 34
          terse-in: |
              (.)\g1
          terse-options: -x
          wordy-out: |
              capture non-newline
              backref-1
              
        - name: Test 35
          terse-in: |
              (.)\1
          terse-options: -x
          wordy-out: |
              capture non-newline
              backref-1
              
        - name: Test 36
          terse-in: |
              (.)\g{-1}
          terse-options: -x
          wordy-out: |
              capture non-newline
              backref-relative-1
              
        - name: Test 37
          terse-in: |
              \b
          terse-options: -x
          wordy-out: |
              word-boundary
              
        - name: Test 38
          terse-in: |
              \B
          terse-options: -x
          wordy-out: |
              non-word-boundary
              
        - name: Test 39
          terse-in: |
              [a-g]
          terse-options: x
          wordy-out: |
              a-g
              
        - name: Test 40
          terse-in: |
              [a-g]*
          terse-options: x
          wordy-out: |
              zero or more  a-g
              
        - name: Test 41
          terse-in: |
              [a-g]+
          terse-options: x
          wordy-out: |
              one or more  a-g
              
        - name: Test 42
          terse-in: |
              [a-g]?
          terse-options: x
          wordy-out: |
              optional  a-g
              
        - name: Test 43
          terse-in: |
              [a-zA-Z0-9\x02-\x10]
          terse-options: x
          wordy-out: |
              a-z A-Z 0-9 hex-02 to hex-10
           
        - name: Test 44
          terse-in: |
              [a-q ]
          terse-options: -x
          wordy-out: |
              a-q space
              
        - name: Test 45
          terse-in: |
              [\ca-\cq ]
          terse-options: -x
          wordy-out: |
              control-A to control-Q space
        - name: TODO Test 45A - range out of order
          terse-in: |
              [\cq-\ca ]
          terse-options: -x
          wordy-out: |
              control-Q to control-A space nonsense
          matches:
            - match: true
              data: " "
        - name: Test 46
          terse-in: |
              [a\-g]*
          terse-options: x
          wordy-out: |
              zero or more  a hyphen g
              
        - name: Test 47
          terse-in: |
              [pa-gk]*
          terse-options: x
          wordy-out: |
              zero or more  p a-g k
              
        - name: Test 48
          terse-in: |
              [\x20 ]\?
          terse-options: x
          wordy-out: |
              hex-20 space
              ?
              
        - name: Test 49
          terse-in: |
              [\x34\cG ]\?
          terse-options: x
          wordy-out: |
              hex-34 control-G space
              ?
              
              
        - name: Test 54
          terse-in: |
              [\cA\cB\cC\cD\cE\cF\cG\cH\cI\cJ]
          terse-options: -x
          notes: |
              ctl-a thru ctl-j
          wordy-out: |
              control-A control-B control-C control-D control-E control-F control-G control-H control-I control-J
              
        - name: Test 55
          terse-in: |
              [\cK\cL\cM\cN\cO\cP\cQ\cR\cS\cT\cU\cV]
          terse-options: -x
          notes: |
              ctl-K thru ctl-V
          wordy-out: |
              control-K control-L control-M control-N control-O control-P control-Q control-R control-S control-T control-U control-V
              
        - name: Test 56
          terse-in: |
              [\cW\cX\cY\cZ]
          terse-options: -x
          notes: |
              ctl-W thru ctl-Z
          wordy-out: |
              control-W control-X control-Y control-Z
              
        - name: Test 57
          terse-in: |
              [abc]\?
          terse-options: x
          wordy-out: |
              a b c
              ?
              
        - name: Test 58
          terse-in: |
              [abc]\?*
          terse-options: x
          wordy-out: |
              a b c
              zero or more  ?
              
        - name: Test 59
          terse-in: |
              []]?
          terse-options: x
          wordy-out: |
              optional  ]
              
        - name: Test 60
          terse-in: |
              [\]]?
          terse-options: x
          wordy-out: |
              optional  ]
              
        - name: Test 61
          terse-in: |
              ]?
          terse-options: x
          wordy-out: |
              optional  ]
              
        - name: Test 62
          terse-in: |
              \]?
          terse-options: x
          wordy-out: |
              optional  ]
              
        - name: Test 63
          terse-in: |
              []X]?
          terse-options: x
          wordy-out: |
              optional  ] X
              
        - name: Test 64
          terse-in: |
              [[]?
          terse-options: x
          wordy-out: |
              optional  [
              
        - name: Test 65
          terse-in: |
              [a-g]+
          terse-options: x
          wordy-out: |
              one or more  a-g
              
        - name: Test 66
          terse-in: |
              X++Y
          terse-options: -x
          wordy-out: |
              one or more possessive X
              Y
              
        - name: Test 67
          terse-in: |
              X?+Y
          terse-options: -x
          wordy-out: |
              optional possessive X
              Y
              
        - name: Test 68
          terse-in: |
              X*+Y
          terse-options: -x
          wordy-out: |
              zero or more possessive X
              Y
              
        - name: Test 69
          terse-in: |
              X{3,4}+
          terse-options: -x
          wordy-out: |
              three or four possessive X
              
        - name: Test 70
          terse-in: |
              X{3,4}?
          terse-options: -x
          wordy-out: |
              three or four minimal X
              
        - name: Test 71
          terse-in: |
              X{3,4}
          terse-options: -x
          wordy-out: |
              three or four  X
              
        - name: Test 72
          terse-in: |
              \p{Ll}
          terse-options: -x
          wordy-out: |
              'p{Ll}'
              
        - name: Test 73
          terse-in: |
              <tr[^<]*><td>([^<]*)<\/td><td[^<]*>([^<]*)<\/td><td>[^<]*<\/td><td>([^<]*)<\/td><td>([^<]*)<\/td><td[^<]*>([^<]*)<\/td><\/tr>
          terse-options: -x
          wordy-out: |
              '<tr'
              zero or more  not <
              '><td>'
              capture
                  zero or more  not <
              '</td><td'
              zero or more  not <
              >
              capture
                  zero or more  not <
              '</td><td>'
              zero or more  not <
              '</td><td>'
              capture
                  zero or more  not <
              '</td><td>'
              capture
                  zero or more  not <
              '</td><td'
              zero or more  not <
              >
              capture
                  zero or more  not <
              '</td></tr>'
              
        - name: Test 74
          terse-in: |
              [\D\S\W]+
          terse-options: -x
          notes: |
              nonsensical regex: multiple negated
          wordy-out: |
              one or more  non-digit non-whitespace non-word-char
              
        - name: Test 75
          terse-in: |
              [\D\S\W]
          terse-options: -x
          notes: |
              nonsensical regex: multiple negated
          wordy-out: |
              non-digit non-whitespace non-word-char
              
        - name: Test 76
          terse-in: |
              [^ ]
          terse-options: -x
          wordy-out: |
              not space
              
        - name: Test 78
          terse-in: |
              \\w?  \\d
          terse-options: x
          wordy-out: |
              backslash
              optional  w
              backslash
              d

        - name: Test 80
          terse-in: |
              \n?\x12
          terse-options: -x
          wordy-out: |
              optional  newline
              hex-12
              
        - name: Test 81
          terse-in: |
              (cat) (mouse)
          terse-options: -x
          wordy-out: |
              capture 'cat'
              space
              capture 'mouse'
              
        - name: Test 82
          terse-in: |
              cat & mouse
          terse-options: -x
          wordy-out: |
              'cat & mouse'
              
        - name: Test 83
          terse-in: |
              \w?  \d{3}
          terse-options: x
          wordy-out: |
              optional  word-char
              three  digit
              
        - name: Test 84
          terse-in: |
              \w?  \d{4,}
          terse-options: x
          wordy-out: |
              optional  word-char
              four or more  digit
              
        - name: Test 85
          terse-in: |
              \w?  \d{5,6}
          terse-options: x
          wordy-out: |
              optional  word-char
              five or six  digit
              
        - name: Test 86
          terse-in: |
              \w?  \d
          terse-options: x
          wordy-out: |
              optional  word-char
              digit
              
        - name: Test 87
          terse-in: |
              \w?  \d
          terse-options: x
          wordy-out: |
              optional  word-char
              digit
              
        - name: Test 88
          terse-in: |
              \w?  \d
          terse-options: x
          wordy-out: |
              optional  word-char
              digit
              
        - name: Test 89
          terse-in: |
              \w?  \d
          terse-options: x
          wordy-out: |
              optional  word-char
              digit
              
        - name: Test 90
          terse-in: |
              \w?  \d
          terse-options: x
          wordy-out: |
              optional  word-char
              digit
              
        - name: Test 91
          terse-in: |
              \w?  \d
          terse-options: x
          wordy-out: |
              optional  word-char
              digit
              
        - name: Test 92
          terse-in: |
              \w?  \d
          terse-options: x
          wordy-out: |
              optional  word-char
              digit
              
        - name: Test 93
          terse-in: |
              \n?  \a
          terse-options: x
          wordy-out: |
              optional  newline
              alarm
              
        - name: Test 94
          terse-in: |
              \n?  \a
          terse-options: x
          wordy-out: |
              optional  newline
              alarm
              
        - name: Test 95
          terse-in: |
              \n?  \a
          terse-options: x
          wordy-out: |
              optional  newline
              alarm
              
        - name: Test 96
          terse-in: |
              \n?  \a
          terse-options: x
          wordy-out: |
              optional  newline
              alarm
              
        - name: Test 97
          terse-in: |
              ^cat.dog$
          terse-options: ms
          wordy-out: |
              start-of-line
              'cat'
              character
              'dog'
              end-of-line
              
        - name: Test 98
          terse-in: |
              t''"dog
          terse-options: 
          wordy-out: |
              t
              apostrophe
              apostrophe
              double-quote
              'dog'
              
        - name: Test 99
          terse-in: |
              cat""""dog
          terse-options: x
          wordy-out: |
              'cat'
              double-quote
              double-quote
              double-quote
              double-quote
              'dog'
              
        - name: Test 100
          terse-in: |
              cat''''dog
          terse-options: x
          wordy-out: |
              'cat'
              apostrophe
              apostrophe
              apostrophe
              apostrophe
              'dog'
        - name: Test 100
          terse-in: |
              cat''''dog
          terse-options: x
          wordy-out: |
              'cat'
              apostrophe
              apostrophe
              apostrophe
              apostrophe
              'dog'
              
        - name: Test 101
          terse-in: |
              cat["']dog
          terse-options: x
          wordy-out: |
              'cat'
              double-quote apostrophe
              'dog'
              
        - name: Test 102
          terse-in: |
              cat.dog
          terse-options: x
          wordy-out: |
              'cat'
              non-newline
              'dog'
              
        - name: Test 103
          terse-in: |
              cat.dog
          terse-options: s
          wordy-out: |
              'cat'
              character
              'dog'
              
        - name: Test 104
          terse-in: |
              cat.dog
          terse-options: s
          wordy-out: |
              'cat'
              character
              'dog'
              
        - name: Test 105
          terse-in: |
              ^cat.dog$
          terse-options: s
          wordy-out: |
              start-of-string
              'cat'
              character
              'dog'
              eosx
              
        - name: Test 106
          terse-in: |
              ^cat.dog$
          terse-options: 
          wordy-out: |
              start-of-string
              'cat'
              non-newline
              'dog'
              eosx
              
        - name: Test 107
          terse-in: |
              ^cat.dog$
          terse-options: s
          wordy-out: |
              start-of-string
              'cat'
              character
              'dog'
              eosx
              
        - name: Test 108
          terse-in: |
              ^cat.dog$
          terse-options: m
          wordy-out: |
              start-of-line
              'cat'
              non-newline
              'dog'
              end-of-line
              
        - name: Test 109
          terse-in: |
              ^cat.dog$
          terse-options: ms
          wordy-out: |
              start-of-line
              'cat'
              character
              'dog'
              end-of-line

              
        - name: Test 110
          terse-in: |
              ([^ ]+) +([^ ]+) +([^"]+)" +(\d+) +([^ ]+) +(\d+) +"([^"]+)" +"[^"]+"(?: +(.*))?
          terse-options: -x
          wordy-out: |
              capture
                  one or more  not space
              one or more  space
              capture
                  one or more  not space
              one or more  space
              capture
                  one or more  not double-quote
              double-quote
              one or more  space
              capture
                  one or more  digit
              one or more  space
              capture
                  one or more  not space
              one or more  space
              capture
                  one or more  digit
              one or more  space
              double-quote
              capture
                  one or more  not double-quote
              double-quote
              one or more  space
              double-quote
              one or more  not double-quote
              double-quote
              optional
                  one or more  space
                  capture
                      zero or more  non-newline
              
        - name: Test 111
          terse-in: |
                             cd      (?i: (?:  ss                     ) uu (?: vv | [wx] )){5,}[34]
          terse-options: x
          wordy-out: |
              'cd'
              five or more  case-insensitive
                  'ss'
                  'uu'
                  'vv' w x
              3 4
              
        - name: Test 112
          terse-in: |
              ab[12\w]?  |  cd\dee* (?i: (?:  ss | (?<gmt> [g-m]+ tt)) uu (?: vv | [wx] )){5,}[34]
          terse-options: x
          wordy-out: |
              either
                  'ab'
                  optional  1 2 word-char
              or
                  'cd'
                  digit
                  e
                  zero or more  e
                  five or more  case-insensitive
                      either 'ss'
                      or
                          capture as gmt
                              one or more  g-m
                              'tt'
                      'uu'
                      'vv' w x
                  3 4
              
        - name: Test 113
          terse-in: |
              ab[12\w]?  |  cd\dee* (?i:                               uu (?: vv | [wx] )){5,}[34]
          terse-options: x
          wordy-out: |
              either
                  'ab'
                  optional  1 2 word-char
              or
                  'cd'
                  digit
                  e
                  zero or more  e
                  five or more  case-insensitive
                      'uu'
                      'vv' w x
                  3 4
              
        - name: Test 114
          terse-in: |
              ab[12\w]?  |  cd\dee* (?i:                               uu (?: vv | [wx] )){5,}[34]
          terse-options: x
          wordy-out: |
              either
                  'ab'
                  optional  1 2 word-char
              or
                  'cd'
                  digit
                  e
                  zero or more  e
                  five or more  case-insensitive
                      'uu'
                      'vv' w x
                  3 4
              
        - name: Test 115
          terse-in: |
              (?: aa\d | bb\w ) cc (?: dd\D | ee | ff\d ) (?: gg | hh | ii )
          terse-options: x
          wordy-out: |
              either
                  'aa'
                  digit
              or
                  'bb'
                  word-char
              'cc'
              either
                  'dd'
                  non-digit
              or 'ee'
              or
                  'ff'
                  digit
              'gg' 'hh' 'ii'
              
        - name: Test 116
          terse-in: |
              (?: aa \d | bb \w ) cc (?: dd \D | ee | ff \d ) (?: gg | hh | ii )
          terse-options: x
          wordy-out: |
              either
                  'aa'
                  digit
              or
                  'bb'
                  word-char
              'cc'
              either
                  'dd'
                  non-digit
              or 'ee'
              or
                  'ff'
                  digit
              'gg' 'hh' 'ii'
              
        - name: Test 117
          terse-in: |
              ^(?:([^,]+),)?((?:\d+\.){3}\d+)[^\[]+\[([^\]]+)\][^"]+"([^ ]+) +([^ ]+) +([^"]+)" +(\d+) +([^ ]+) +(\d+) +"([^"]+)" +"[^"]+"(?: +(.*))?
          terse-options: -x
          wordy-out: |
              start-of-string
              optional
                  capture
                      one or more  not ,
                  ,
              capture
                  three
                      one or more  digit
                      .
                  one or more  digit
              one or more  not [
              [
              capture
                  one or more  not ]
              ]
              one or more  not double-quote
              double-quote
              capture
                  one or more  not space
              one or more  space
              capture
                  one or more  not space
              one or more  space
              capture
                  one or more  not double-quote
              double-quote
              one or more  space
              capture
                  one or more  digit
              one or more  space
              capture
                  one or more  not space
              one or more  space
              capture
                  one or more  digit
              one or more  space
              double-quote
              capture
                  one or more  not double-quote
              double-quote
              one or more  space
              double-quote
              one or more  not double-quote
              double-quote
              optional
                  one or more  space
                  capture
                      zero or more  non-newline
              
              
              
        - name: Test 118
          terse-in: |
              ^(?:([^,]+),)?((?:\d+\.){3}\d+)[^\[]+\[([^\]]+)\][^"]+"([^ ]+) +([^ ]+) +([^"]+)" +(\d+) +([^ ]+) +(\d+) +"([^"]+)" +"[^"]+"(?: +(.*))?
          terse-options: -x
          wordy-out: |
              start-of-string
              optional
                  capture
                      one or more  not ,
                  ,
              capture
                  three
                      one or more  digit
                      .
                  one or more  digit
              one or more  not [
              [
              capture
                  one or more  not ]
              ]
              one or more  not double-quote
              double-quote
              capture
                  one or more  not space
              one or more  space
              capture
                  one or more  not space
              one or more  space
              capture
                  one or more  not double-quote
              double-quote
              one or more  space
              capture
                  one or more  digit
              one or more  space
              capture
                  one or more  not space
              one or more  space
              capture
                  one or more  digit
              one or more  space
              double-quote
              capture
                  one or more  not double-quote
              double-quote
              one or more  space
              double-quote
              one or more  not double-quote
              double-quote
              optional
                  one or more  space
                  capture
                      zero or more  non-newline
              
        - name: Test 119
          terse-in: |
              ^--\sappl\s+=\s+(\S*)                                       # application
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
                              
          terse-options: x
          wordy-out: |
              start-of-string
              hyphen
              hyphen
              whitespace
              'appl'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  zero or more  non-whitespace
              one or more  whitespace
              'host'
              one or more  whitespace
              =
              whitespace
              capture
                  zero or more  non-whitespace
              one or more  whitespace
              'user'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  zero or more  non-whitespace
              /
              one or more  whitespace
              'pid'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'elapsed'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              'seconds'
              one or more  whitespace
              'rows'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'tran'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'server'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  non-whitespace
              one or more  whitespace
              'database'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  zero or more  non-whitespace
              one or more  whitespace
              'client'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
                  .
                  one or more  digit
                  .
                  one or more  digit
                  .
                  one or more  digit
              /
              one or more  digit
              one or more  whitespace
              capture
                  one or more  word-char
              one or more  whitespace
              word-char
              word-char
              word-char
              one or more  whitespace
              word-char
              word-char
              word-char
              one or more  whitespace
              one or more  digit
              one or more  whitespace
              capture
                  one or more  digit
                  :
                  one or more  digit
                  :
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              one or more  digit
              one or more  whitespace
              hyphen
              one or more  whitespace
              word-char
              word-char
              word-char
              one or more  whitespace
              capture
                  word-char
                  word-char
                  word-char
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              capture
                  one or more  digit
                  :
                  one or more  digit
                  :
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              zero or more  non-newline
              'send'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              'sec'
              one or more  whitespace
              'receive'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              'sec'
              one or more  whitespace
              'send_packets'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'receive_packets'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'bytes_received'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  zero or more  hyphen
                  one or more  digit
              one or more  whitespace
              'errors'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              capture
                      either
                          capture 'sid'
                          one or more  whitespace
                          =
                          one or more  whitespace
                          capture
                              one or more  digit
                      or
                          capture
                              one or more  non-whitespace
              
        - name: Test 120
          terse-in: |
              
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
                              
          terse-options: x
          wordy-out: |
              start-of-string
              hyphen
              hyphen
              whitespace
              'appl'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  zero or more  non-whitespace
              one or more  whitespace
              'host'
              one or more  whitespace
              =
              whitespace
              capture
                  zero or more  non-whitespace
              one or more  whitespace
              'user'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  zero or more  non-whitespace
              /
              one or more  whitespace
              'pid'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'elapsed'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              'seconds'
              one or more  whitespace
              'rows'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'tran'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'server'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  non-whitespace
              one or more  whitespace
              'database'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  zero or more  non-whitespace
              one or more  whitespace
              'client'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
                  .
                  one or more  digit
                  .
                  one or more  digit
                  .
                  one or more  digit
              /
              one or more  digit
              one or more  whitespace
              capture
                  one or more  word-char
              one or more  whitespace
              word-char
              word-char
              word-char
              one or more  whitespace
              word-char
              word-char
              word-char
              one or more  whitespace
              one or more  digit
              one or more  whitespace
              capture
                  one or more  digit
                  :
                  one or more  digit
                  :
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              one or more  digit
              one or more  whitespace
              hyphen
              one or more  whitespace
              word-char
              word-char
              word-char
              one or more  whitespace
              capture
                  word-char
                  word-char
                  word-char
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              capture
                  one or more  digit
                  :
                  one or more  digit
                  :
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              zero or more  non-newline
              'send'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              'sec'
              one or more  whitespace
              'receive'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              'sec'
              one or more  whitespace
              'send_packets'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'receive_packets'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              'bytes_received'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  zero or more  hyphen
                  one or more  digit
              one or more  whitespace
              'errors'
              one or more  whitespace
              =
              one or more  whitespace
              capture
                  one or more  digit
              one or more  whitespace
              capture
                      either
                          capture 'sid'
                          one or more  whitespace
                          =
                          one or more  whitespace
                          capture
                              one or more  digit
                      or
                          capture
                              one or more  non-whitespace
              
        - name: Test 121
          terse-in: |
              
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
                              
          terse-options: x
          wordy-out: |
              start-of-string
              hyphen
              hyphen
              whitespace
              'appl'
              one or more  whitespace
              =
              one or more  whitespace
              capture as application
                  zero or more  non-whitespace
              one or more  whitespace
              'host'
              one or more  whitespace
              =
              whitespace
              capture as host
                  zero or more  non-whitespace
              one or more  whitespace
              'user'
              one or more  whitespace
              =
              one or more  whitespace
              capture as user
                  zero or more  non-whitespace
              /
              one or more  whitespace
              'pid'
              one or more  whitespace
              =
              one or more  whitespace
              capture as pid
                  one or more  digit
              one or more  whitespace
              'elapsed'
              one or more  whitespace
              =
              one or more  whitespace
              capture as elapsed
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              'seconds'
              one or more  whitespace
              'rows'
              one or more  whitespace
              =
              one or more  whitespace
              capture as rows
                  one or more  digit
              one or more  whitespace
              'tran'
              one or more  whitespace
              =
              one or more  whitespace
              capture as tran
                  one or more  digit
              one or more  whitespace
              'server'
              one or more  whitespace
              =
              one or more  whitespace
              capture as server
                  one or more  non-whitespace
              one or more  whitespace
              'database'
              one or more  whitespace
              =
              one or more  whitespace
              capture as database
                  zero or more  non-whitespace
              one or more  whitespace
              'client'
              one or more  whitespace
              =
              one or more  whitespace
              capture as client_IP
                  one or more  digit
                  .
                  one or more  digit
                  .
                  one or more  digit
                  .
                  one or more  digit
              /
              one or more  digit
              one or more  whitespace
              capture as operation
                  one or more  word-char
              one or more  whitespace
              word-char
              word-char
              word-char
              one or more  whitespace
              word-char
              word-char
              word-char
              one or more  whitespace
              one or more  digit
              one or more  whitespace
              capture as start_time
                  one or more  digit
                  :
                  one or more  digit
                  :
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              one or more  digit
              one or more  whitespace
              hyphen
              one or more  whitespace
              word-char
              word-char
              word-char
              one or more  whitespace
              capture as end_month
                  word-char
                  word-char
                  word-char
              one or more  whitespace
              capture as end_day
                  one or more  digit
              one or more  whitespace
              capture as end_time
                  one or more  digit
                  :
                  one or more  digit
                  :
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              capture as end_year
                  one or more  digit
              one or more  whitespace
              zero or more  non-newline
              'send'
              one or more  whitespace
              =
              one or more  whitespace
              capture as send_time
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              'sec'
              one or more  whitespace
              'receive'
              one or more  whitespace
              =
              one or more  whitespace
              capture as recv_time
                  one or more  digit
                  .
                  one or more  digit
              one or more  whitespace
              'sec'
              one or more  whitespace
              'send_packets'
              one or more  whitespace
              =
              one or more  whitespace
              capture as send_pkts
                  one or more  digit
              one or more  whitespace
              'receive_packets'
              one or more  whitespace
              =
              one or more  whitespace
              capture as recv_pkts
                  one or more  digit
              one or more  whitespace
              'bytes_received'
              one or more  whitespace
              =
              one or more  whitespace
              capture as recv_bytes
                  zero or more  hyphen
                  one or more  digit
              one or more  whitespace
              'errors'
              one or more  whitespace
              =
              one or more  whitespace
              capture as errors
                  one or more  digit
              one or more  whitespace
              either
                  capture as sid_text 'sid'
                  one or more  whitespace
                  =
                  one or more  whitespace
                  capture as sid_num
                      one or more  digit
              or
                  capture as sql_type
                      one or more  non-whitespace
    
    
    ##############

    - group-name: charnames
      wordy-to-terse: true
      tests:
        - name: Charnames 1
          terse-options: -x
          prefer-class-to-escape: false
          embed-original: true        
          terse-out: |
              \s*[\s\d]*\(\)(?:\s+)?\(+\}(?:aa|[},]|\(+)
          wordy-in: |
                zero or more whitespaces
                zero or more whitespaces digits
                left-parenthesis
                right-parenthesis
                opt wss
                left-parentheses
                close-brace
                left-parentheses or close-brace or 'aa' or comma
        - name: Charnames 1B
          terse-options: -x
          embed-original: true
          prefer-class-to-escape: true
          terse-out: |
              \s*[\s\d]*[(][)](?:\s+)?[(]+[}](?:aa|[},]|[(]+)
          wordy-in: |
                zero or more whitespaces
                zero or more whitespaces digits
                left-parenthesis
                right-parenthesis
                opt wss
                left-parentheses
                close-brace
                left-parentheses or close-brace or 'aa' or comma                
    - group-name: space-means-wss
      wordy-to-terse: true
      tests:
        - name: space-means-wss 1
          terse-options: -x
          prefer-class-to-escape: no
          solo-space-as-class: no
          wordy-in: |
                space-means-wss
                     'quoted string with space-means-wss'
                     ' ' hash
                     '  ' colon # two-space string
                     ' '        # single-space string
                space-means-ws
                     'quoted string with space-means-ws'
                     ' ' hash
                     '  ' colon # two-space string
                     ' '        # single-space string
                     space-means-space
                        'quoted string with space-means-space'
                        ' ' hash
                        '  ' colon # two-space string
                        ' '        # single-space string
                     'back to with space-means-ws'
                     ' ' hash
                     '  ' colon # two-space string
                     ' '        # single-space string
          terse-out: |
              quoted\s+string\s+with\s+space-means-wss(?:\#|\s+)(?:\s+\s+|:)\s+quoted[\s]string[\s]with[\s]space-means-ws[\s#](?:[\s][\s]|:)[\s]quoted string with space-means-space[ #](?:  |:) back[\s]to[\s]with[\s]space-means-ws[\s#](?:[\s][\s]|:)[\s]
        - name: space-means-wss 1B
          terse-options: -x
          prefer-class-to-escape: no
          solo-space-as-class: no
          wordy-in: |
                space-means-wss
                     'quoted string with space-means-wss'
                     ' ' hash
                     '  ' colon # two-space string
                     ' '        # single-space string
                space-means-ws
                     'quoted string with space-means-ws'
                     ' ' hash
                     '  ' colon # two-space string
                     ' '        # single-space string
                     space-means-space
                        'quoted string with space-means-space'
                        ' ' hash
                        '  ' colon # two-space string
                        ' '        # single-space string
                     'back to with space-means-ws'
                     ' ' hash
                     '  ' colon # two-space string
                     ' '        # single-space string
          terse-out: |
              quoted\s+string\s+with\s+space-means-wss(?:\#|\s+)(?:\s+\s+|:)\s+quoted[\s]string[\s]with[\s]space-means-ws[\s#](?:[\s][\s]|:)[\s]quoted string with space-means-space[ #](?:  |:) back[\s]to[\s]with[\s]space-means-ws[\s#](?:[\s][\s]|:)[\s]

        - name: space-means-wss x-mode on
          terse-options: x
          embed-original: false      
          
          wordy-in: |
                space-means-wss
                     'quoted string with space-means-wss'
                     ' ' hash
                     '  ' colon # two-space string
                     ' '        # single-space string
                space-means-ws
                     'quoted string with space-means-ws'
                     ' ' hash
                     '  ' colon # two-space string
                     ' '        # single-space string
                     space-means-space
                        'quoted string with space-means-space'
                        ' ' hash
                        '  ' colon # two-space string
                        ' '        # single-space string
                     'back to with space-means-ws'
                     ' ' hash
                     '  ' colon # two-space string
                     ' '        # single-space string
          terse-out: |
              quoted\s+string\s+with\s+space-means-wss (?:\# | [\s]+ ) (?: \s+\s+ | : )[\s]+ quoted[\s]string[\s]with[\s]space-means-ws[\s#] (?: [\s][\s] | : )[\s] quoted[ ]string[ ]with[ ]space-means-space[ #] (?: [ ][ ] | : )[ ] back[\s]to[\s]with[\s]space-means-ws[\s#] (?: [\s][\s] | : )[\s]


    - group-name: very-long
      wordy-to-terse: true
      tests:
        - name: Richards monster without space-means-wss
          terse-out: >
            \A--\sappl = (?<application>(?:\S+)?) host =\s(?<host>(?:\S+)?)
            user = (?<user>(?:\S+)?)\/ pid = (?<pid>\d+) elapsed =
            (?<elapsed>\d+[.]\d+) seconds rows = (?<rows>\d+) tran =
            (?<tran>\d+) server = (?<server>\S+) database = (?<database>(?:\S+)?)
            client = (?<client_IP>\d+[.](?:[.]|\d+)\d+[.]\d+)[\/]\d+\s+(?<operation>\w+)\s+\w{3}\s+\w{3}\s+\d+\s+(?<start-time>\d+:\d+(?::|\d+)[.]\d+)\s+\d+\s+-\s+\w{3}\s+(?<end-month>\w{3})\s+(?<end-day>\d+)\s+(?<end-time>\d+:\d+(?::|\d+)(?:[.]|\d+))\s+(?<end-year>\d+)\s+(?:[^\n]+)?send  =
            (?<send-time>\d+[.]\d+) sec receive = \d+[.]\d+ sec
            send_packets = (?<send-pkts>\d+) receive_packets = (?<rcv_pkts>\d+)
            bytes_received = (?<bytes-rcv>(?:-+)?\d+) errors = (?<errors>\d+)\s+(?:(?<sid-text>sid)
            = (?<sid-num>\d+)|(?<sql-type>\S+))
          wordy-in: |
            space-means-space
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
                ' sec receive = ' then                     digits then . then digits 
                ' sec send_packets = ' then as send-pkts   digits 
                ' receive_packets = '  then as rcv_pkts    digits
                ' bytes_received = '   then as bytes-rcv 
                                                           opt hyphens then digits
                ' errors = '           then as errors      digits               then wss
                either 
                                            as sid-text    'sid' 
                                            ' = '
                                            as sid-num     digits 
                or 
                                            as sql-type    non-wss 
            
        - name: Richards monster with space-means-wss
          terse-out: >
            \A--\sappl\s+=\s+(?<application>(?:\S+)?)\s+host\s+=\s(?<host>(?:\S+)?)\s+user\s+=\s+(?<user>(?:\S+)?)\/\s+pid\s+=\s+(?<pid>\d+)\s+elapsed\s+=\s+(?<elapsed>\d+[.]\d+)\s+seconds\s+rows\s+=\s+(?<rows>\d+)\s+tran\s+=\s+(?<tran>\d+)\s+server\s+=\s+(?<server>\S+)\s+database\s+=\s+(?<database>(?:\S+)?)\s+client\s+=\s+(?<client_IP>\d+[.](?:[.]|\d+)\d+[.]\d+)[\/]\d+\s+(?<operation>\w+)\s+\w{3}\s+\w{3}\s+\d+\s+(?<start-time>\d+:\d+(?::|\d+)[.]\d+)\s+\d+\s+-\s+\w{3}\s+(?<end-month>\w{3})\s+(?<end-day>\d+)\s+(?<end-time>\d+:\d+(?::|\d+)(?:[.]|\d+))\s+(?<end-year>\d+)\s+(?:[^\n]+)?send\s+\s+=\s+(?<send-time>\d+[.]\d+)\s+sec\s+receive\s+=\s+\d+[.]\d+\s+sec\s+send_packets\s+=\s+(?<send-pkts>\d+)\s+receive_packets\s+=\s+(?<rcv_pkts>\d+)\s+bytes_received\s+=\s+(?<bytes-rcv>(?:-+)?\d+)\s+errors\s+=\s+(?<errors>\d+)\s+(?:(?<sid-text>sid)\s+=\s+(?<sid-num>\d+)|(?<sql-type>\S+))
          
          wordy-in: |
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
                ' sec receive = ' then                     digits then . then digits 
                ' sec send_packets = ' then as send-pkts   digits 
                ' receive_packets = '  then as rcv_pkts    digits
                ' bytes_received = '   then as bytes-rcv 
                                                           opt hyphens then digits
                ' errors = '           then as errors      digits               then wss
                either 
                                            as sid-text    'sid' 
                                            ' = '
                                            as sid-num     digits 
                or 
                                            as sql-type    non-wss 
            
        
        
    - group-name: Adhoc
      wordy-to-terse: true
      tests:
        - name: Embedded spaces in quoted string, /x mode
          terse-out: |
              to[ ]be
          terse-options:  x
          embed-original: false
          wordy-in: |
            'to be'
        - name: non-nl
          terse-out: |
              [^\n]\S[^\sdef]\S[^\n][^\nabc]
          terse-options:  x
          embed-original: false
          wordy-in: |
            not newline
            not whitespace
            not whitespace d e f
            non-whitespace
            non-newline
            not newline a b c

        - name: Then example 1
          terse-out: |
              ((?:(?:cc[dc]|d))?)[ab](?:cd|e)(?:hi|[gj])(?:go|stop)pqr{2}s(t)u{3}
          terse-options: -x
          embed-original: false
          wordy-in: |
            capture optional
                either 'cc' then d c
                or     d
            a or b then 'cd' or e then g or 'hi' or j then 'go' or 'stop'
            p then q
            two r then s then capture t then three u      
        - name: casing of control constants
          wordy-in: |
            control-A to control-G
          terse-out: |
            [\cA-\cG]
        - name: Then examples
          terse-out: |
              ((?:(?:cc[dc]|d))?)[ab](?:cd|e)(?:hi|[gj])(?:go|stop)pqr{2}s(t)u{3}
          terse-options: -x
          embed-original: false
          wordy-in: |
            capture optional
                either 'cc' then d c
                or     d
            a or b then 'cd' or e then g or 'hi' or j then 'go' or 'stop'
            p then q
            two r then s then capture t then three u
        - name: Then example 2
          terse-out: |
              (?s:\[(.+)\]\[([^\n]+)\])
          terse-options: -x
          embed-original: false
          wordy-in: |
            [ then get chs then ]
            [ then get non-newlines then ]
        - name: Then example 3
          terse-out: |
              squares\[([^\n]+)\] angles<(\D+)> rounds[(]((?u:\P{Letter}+))[)][A-Za-z]+ queries[?]([^?*]+)[?]
          terse-options: x
          embed-original: false
          wordy-in: |
            'squares'
            [ then get non-newlines then ]
            'angles'
            < then get non-digits   then >
            'rounds'
            ( then get uni non-letters  then ) then letters
            'queries'
            ? then get one or more not ? or *   then ?
        - name: TODO Incorrect (s/be disallowed) order of capture/optional
          wordy-in: |
            capture optional a
            optional capture b
            capture optional
                either c
                or     d
            optional capture
                either e
                or     f
          terse-options: -x
          terse-out: |
              (a?)(b)?((?:(?:c|d))?)((?:(?:e|f)))?
            
        - name: Either/or at end of wordy
          terse-out: |
              (?:aa\d|bb\w|b2|b3)cc(?:dd\D|ee|ff\d) 
          terse-options: -x
          wordy-in: |
              either
                  'aa'
                  digit
              or
                  'bb'
                  word-char
              or  'b2'
              or  'b3'
              'cc'
              either
                  'dd'
                  non-digit
              or 'ee'
              or
                  'ff'
                  digit
        - name: Either/or at end of wordy 2
          terse-out: |
              (?:aa\d|bb\w)cc(?:dd\D|ee|ff|ww) 
          terse-options: -x
          wordy-in: |
              either
                  'aa'
                  digit
              or
                  'bb'
                  word-char
              'cc'
              either
                  'dd'
                  non-digit
              or 'ee'
              or 'ff'
              or 'ww'

        - name: Either/or not at end of wordy
          terse-out: |
              (?:aa\d|bb\w)cc(?:dd\D|ee|ff\d)gg
          terse-options: -x
          wordy-in: |
              either
                  'aa'
                  digit
              or
                  'bb'
                  word-char
              'cc'
              either
                  'dd'
                  non-digit
              or 'ee'
              or
                  'ff'
                  digit
              'gg'
EOTESTS
#

#my $data = 'a B d c E h b m';
#my $w = wre 'control-a';
#my $w2 = wre <<"...";
##              hex-34 control-G space
##              ?
#...
#my $w3 = wret <<"...";
##              hex-34 control-G space
##              ?
#...
#
## $data =~ s/${wret 'a b c'}//);
#$data =~ s/${wret 'uncased e h'}/k/gx;
#
#
## $data =~ s/${wre 'b'}/k/gx;  # Fails because wre does not return a reference
#
#my $wre_obj = wre 'uncased b';
#$data =~ s/$wre_obj/k/gx;  # OK, as $wre_obj interpolates as a qr-literal
#eval {
#    $data =~ s/${wre 'uncased b'}/k/gx;  # Fails because wre does not return a reference
#};
#print "wre(): $@";
#
#eval {
#    $data =~ s/${wret 'uncased b'}/k/gx;  # OK because wret returns a reference
#};
#print "wret(): $@";
#
#$data =~ s/${wret 'b'}/k/gx;
#
#$data =~ s/[ ]/q/g;
#$w = wret "capture a b c";
#while ($data =~ /${wret "capture a b c"}/g) {
#    print "# next abc letter: $1\n"
#}
#while ($data =~ /${wret "as let a b c"}/g) {
#    print "# next letter: $+{let}\n"
#}
#
#
#while ($data =~ /${wret "\tas let\n  \ta b c"}/g) {
#    # Tab rules mean that 'a b c' is not indented from 'as let'
#    # So we don't capture anything: there is an error message, but it is not
#    # checked for
#    print "# dodgy next letter: $+{let}\n"
#}
#
#
#while ($data =~ /${wret "      as let\n\t   a b c"}/g) {
#    print "# tabby next letter: $+{let}\n"
#}
#
#while ($data =~ /${wret "      as let\n  \t   a b c"}/g) {
#    print "# tabby2 next letter: $+{let}\n"
#}
#
#my @n = ( $data =~ /[^x]/g );
#if ( $data =~ /${wret 'a b c'}/g ) {
#    my $pause = 1
#};


my $v = YAML::Validator->new($schema);

my ($p, $q) = $v->load_data($tests);
die $q if $q;

my $data_loaded = $p->{groups}[0]{tests}[0];

my $groups_ref = $p->{groups};
my $count_of_matching_groups = 0;
for my $group_ref ( @{$groups_ref}) {
    my $group_name = $group_ref->{'group-name'} || '<unnamed>';
    next if $selected_group && ($group_name !~ /\Q$selected_group\E/i); # --->>>>
    $count_of_matching_groups++;
    my $group_wordy_to_terse = $group_ref->{'wordy-to-terse'};
    my $group_terse_to_wordy = $group_ref->{'terse-to-wordy'};
    log_text ("Starting group: $group_name");
    for my $tests_ref ($group_ref->{tests}) {
        for my $test_ref (@{$tests_ref}) {
            my $test_name = $test_ref->{'name'};
            log_text ("Test name: $test_name");
            
            my $test_wordy_to_terse = $test_ref->{'wordy-to-terse'};
            my $test_terse_to_wordy = $test_ref->{'terse_to_wordy'};
            my $test_pause          = $test_ref->{'pause'};
            $test_wordy_to_terse = defined $test_wordy_to_terse
                                   ? $test_wordy_to_terse
                                   : $group_wordy_to_terse;
            $test_terse_to_wordy = defined $test_terse_to_wordy
                                   ? $test_terse_to_wordy
                                   : $group_terse_to_wordy;                                   
            if ( ! $test_terse_to_wordy && ! $test_wordy_to_terse) {
                complain("Test '$test_name' in group '$group_name' has no direction");
            }
            my $wordy;
            my $terse;
            if ($test_pause) {
                my $pause_here_if_desired_by_setting_breakpoint;
            }
            if ($test_wordy_to_terse) {
                $wordy = $test_ref->{wordy} || $test_ref->{'wordy-in' };
                $terse = $test_ref->{terse} || $test_ref->{'terse-out'};
                chomp $terse if $terse;
                if (! defined $wordy) {
                    # No wordy: no can do
                    complain("Test '$test_name' in group '$group_name' needs a wordy");
                } else {
                    # We have a wordy
                    ## Might need to call a more complex routine, e.g. to handle
                    ## errors more elegantly
                    my $terse_options = $test_ref->{'terse-options'} || '';
                    my $free_space = $terse_options =~  /  ^ [^-]* x /x;
                    my $generated_tre =
                          _wre_to_tre($wordy,
                                    {free_space     => $free_space,
                                     embed_original => $test_ref->{'embed-original'},
                                     prefer_class_to_escape
                                                    => $test_ref->{'prefer-class-to-escape'},
                                     solo_space_as_class
                                                    => $test_ref->{'solo-space-as-class'},
                                     wrap_output    => 0}
                                     );    # Makes a wre object
                    chomp $generated_tre;
                    if ($group_name =~ / todo /ix || $test_name =~ / todo /ix) {
                      TODO:
                        local $TODO = "To Do items";

                        if (defined $terse) {
                            # We have been supplied a terse regexp to compare with
                            is($generated_tre, $terse, "$group_name: $test_name: tre as expected");
                        }
                        # Check the generated tre using the matches provided
                        check_matches($test_ref, $generated_tre, $group_name, $test_name);
                    } else {
                        if (defined $terse) {
                            # We have been supplied a terse regexp to compare with
                            is($generated_tre, $terse, "$group_name: $test_name: tre as expected");
                        }
                        # Check the generated tre using the matches provided
                        check_matches($test_ref, $generated_tre, $group_name, $test_name);
                    }
                }
            }
            if ($test_terse_to_wordy) {
                $terse = $test_ref->{terse} || $test_ref->{'terse-in' };
                $wordy = $test_ref->{wordy} || $test_ref->{'wordy-out'};
                chomp $terse if $terse;
                if (! defined $terse) {
                    # No terse: no can do
                    complain("Test '$test_name' in group '$group_name' needs a terse");
                } else {
                    # We have a terse
                    ## Might need to call a more complex routine, e.g. to handle
                    ## errors more elegantly
                    my $terse_options = $test_ref->{'terse-options'} || '';
                    my $generated_wordy = tre_to_wre($terse, $terse_options);
                    if ($group_name =~ / todo /ix || $test_name =~ / todo /ix) {
                      TODO:
                        local $TODO = "To Do items";
                        if (defined $wordy) {
                            # We have been supplied a wordy regexp to compare with
                            is($generated_wordy, $wordy, "$group_name: $test_name: wordy as expected");
                            # Check the wordy using the matches provided
                            my $wre;
                            eval {$wre = wre($wordy)};
                            if ($@) {
                                fail "$group_name: $test_name: wre() aborted, $@";
                            } else {
                                check_matches($test_ref, wre($wordy), $group_name, $test_name);
                            }
                        }
                    } else {
                        if (defined $wordy) {
                            # We have been supplied a wordy regexp to compare with
                            is($generated_wordy, $wordy, "$group_name: $test_name: wordy as expected");

                        }
                        # Check the wordy using the matches provided
                        my $wre;
                        eval {$wre = wre($generated_wordy)};
                        if ($@) {
                            fail "$group_name: $test_name: wre() aborted, $@";
                        } else {
                            check_matches($test_ref, $wre, $group_name, $test_name);
                        }
                    }
                }                
            }
        }
    }
}
fail ("No test groups matched: $selected_group") if $selected_group && ($count_of_matching_groups == 0);

### Start of ad hoc tests ###
        ok('a b d 3 g' =~ wre 'letters');
        $_ = 'a b d 3 g';
        ok(wre 'letters');
        $_ = 'a b d 3 g';
        ok(not wre 'colons');
        $_ = ':::';
        ok(wre 'colons');
        ok(not wre 'letters');
        
        my $data = 'a b d 3 g';
        if ($data =~ wre 'letter')  { pass 'wre1' } else {fail 'wre1'};
        
        $data = '4 3 1';
        if ($data =~ wre 'letter')  { fail 'wre1a' } else {pass 'wre1a'};
        
        # Decide if the contents of $_ matches your wordy regexp
        $_ = 'h k 7 p';
        if (wre 'letter')  { pass 'wre2' } else {fail 'wre2'};
        
        $_ = '4 3 1';
        if (wre 'letter')  { fail 'wre2a' } else {pass 'wre2a'};
        
        $data = 'a b d 3 g';
        my $wre_1 = wre 'letter';
        if ($data =~ /$wre_1/)  { pass 'wre3' } else {fail 'wre3'};
        
        
        $data = '1 3 8';
        if ($data =~ /$wre_1/)  { fail 'wre3a' } else {pass 'wre3a'};
        
        my $wre_2 = wre 'get one letter';
        $data = 'a b d 3 g';
        while ($data =~ /$wre_2/g){
            print "$1\n";
        }

        my $pause = 1;
## end of ad hoc tests
done_testing();


############################
sub check_matches {
    my ($test_ref, $tre, $group_name, $test_name) = @_;
    my $match_index = 0;
    my $terse_options = $test_ref->{'terse-options'} || '';
    my ($free_space)  = $terse_options =~ / ( [-] \w* x | x ) /ix;  # x, or -..x
    $free_space = '' if ! defined $free_space || substr($free_space, 0, 1) eq '-';
    if ($free_space eq 'x') {
        my $pause = 0;
    }
    for my $match_ref ( @{$test_ref->{matches}} ) {

        my $data         = $match_ref->{data};
        chomp $data;
        my $should_match = $match_ref->{match};
        my $global_match = $match_ref->{global};
        my $flags = $free_space . ($global_match ? 'g' : '');
        
        my @match_result_array;
        my %named_captures;
        eval '@match_result_array = $data =~ /$tre/' . $flags
            .';%named_captures = %+';
        ## @match_result_array = $data =~ /$tre/g if     $global_match;
        ## @match_result_array = $data =~ $tre    unless $global_match;

        my $did_match = ( scalar @match_result_array != 0 );
        if (! $should_match) {
            # Should not match
            ok(! $did_match, "$group_name: $test_name: [$match_index]: data: $data should not match");
        } else {
            # Should match
            ok($did_match, "$group_name: $test_name: [$match_index]: data: $data should match");
            if ($did_match) {
                my $match_array_ref   = $match_ref->{'match-array'};
                my $match_array_count = defined $match_array_ref ? scalar @{$match_array_ref} : 0;
                my $named_matches_ref = $match_ref->{'named-matches'};
                my $named_matches_count = defined $named_matches_ref ? scalar keys %{$named_matches_ref} : 0;
                
                if (scalar @match_result_array == 1 && $match_result_array[0] == 1
                    && $match_array_count == 0 && $named_matches_count == 0) {
                    # A match with no captures
                } else {
                    # Did match, and we have captures to check
                    if ($match_array_count > 0) {
                        is_deeply(\@match_result_array, $match_array_ref, " [$match_index]: $match_array_count numbered captures");
                    }
                    if ($named_matches_count > 0){
                        is_deeply(\%named_captures, $named_matches_ref, " [$match_index]: $named_matches_count named captures");
                    }
                }
            }
        }
        $match_index++;
    }    
}

#-----------------
sub log_text {
    my ($text) = @_;
    diag("Log: \n $text");
}
#-----------------
sub complain {
    my ($text) = @_;
    print "Complaint: $text\n";
}