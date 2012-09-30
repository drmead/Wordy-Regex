use strict;
use warnings;
use 5.014;
use YAML::XS;
use Test::More;
use lib "../yaml_schema";
use YAML::Validator;
use RegExp::Wre qw(wre wret flag_value _wre_to_tre);
use RegExp::Tre2Wre qw( tre_to_wre );
use RegExp::Slr;

##our $flag = 'mendacious';


$YAML::Validator::YAML_LIB = 'XS';   # Force YAML::Validator to use YAML::XS

=format

Test Types

    Some questions that the tests aim to answer:
        - Does the wordy-to-terse converter produce a correct tre given a
          particular wordy?
        - Does the terse-to-wordy converter produce a correct wordy given a
          particular tre?          
        - If we convert wordy->terse->wordy->terse, does the resulting tre match
          in the same way as the original wordy?
        - If we convert terse->wordy->terse, does the resulting tre match
          in the same way as the original wordy? In this case we start with a
          manually written tre, which may make use of features that are never
          used by tre's generated from wordies.
          
    Wordy-to-terse conversion
        Supplied a wordy, some match tests, and optionally a terse version.
        Converts the wordy
        Runs the match tests against the tre resulting from conversion
        If a terse version is supplied, it is:
          - compared to the generated version to determine (e.g.) whether the
            conversion has changed
          - used for the match tests
        Any failures in matching or capturing are reported.
        
    Terse-to-wordy conversion
        Supplied a tre, some match tests, and optionally a wordy version.
        Converts the tre to a wordy
        Converts the wordy back to a tre
        Runs the match tests against the tre resulting from conversion
        If a wordy version is supplied, it is
          - compared to the generated version to determine (e.g.) whether the
            conversion has changed
          - converted to a tre and used for the match tests
        Any failures in matching or capturing are reported.    
    
    Round-trip wordy-terse-wordy
        Supplied a wordy.
        Converts the wordy to terse then back to wordy
        
    Pre-converted
        This is more applicable to a test harness in a language that does not
        support the conversions in a library, and does not have access to
        comnverters implemented as executables.
        Supplied a wre and the corresponding tre, already converted, e.g. by
        a conversion utility. No conversion is done, but the same match tests
        are applied to both versions and any differences are reported. 
        

=cut


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
          notes: str
          wordy:
          terse:
          terse-options: /[-gcimsoxdual]*/
          # Unidirectional tests
          wordy-to-terse:  boolean   # Must have wordy supplied if true
          terse-to-wordy:  boolean   # Must have terse supplied if true
          
          # Round trip tests
          terse-wordy-terse: boolean
          wordy-terse-wordy: boolean
          
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
    - group-name: Examples terse-to-wordy A
      terse-to-wordy: true
      tests:
        - name: Test 0
          terse: |
              \G \# ( .* ) 
          terse-options: x
          wordy: |
              end-of-previous-match
              #
              capture
                  zero or more  non-newline    
    - group-name: Examples wordy-to-terse
      wordy-to-terse: true
      tests:

        - name: Paragraph numbers and headings
          notes:
          wordy: |
            (
            capture
                either one letter
                or one to three  i v x
                or one or two digits    
            )
            spaces
            capture
                zero or more  non-newline
          terse: |
            [(]((?:[A-Za-z]{1,1}|[ivx]{1,3})|\d{1,2})[)][ ]+([^\n]*)
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
                
        - name: Individual named characters, part 1
          notes: One at a time, one per line so we can easily check with a match
          wordy: |
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

          terse: |
                -[.]\/-[.]\/-\/\/[+]=[*]=[*]=\\&\\:;;\/\/\/[*][*][+]===\\\\&:;;'''""
          matches:
            -   match: true
                data: |
                    -./-./-//+=*=*=\&\:;;///**+===\\&:;;'''""
        - name: Individual named characters, part 2
          notes: One at a time, one per line so we can easily check with a match
          wordy: |
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
          terse: |
                \x0a\t\n\n[ ]\x08\a\e\f\r\xa0\xad
          matches:
            -   match: true
                data: "\x0a\t\n\n \x08\a\e\f\r\xa0\xad"
        - name: Plural named characters, part 1
          notes: One at a time, one per line so we can easily check with a match
          wordy: |
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

          terse: |
                -+[.]+\/+-+[.]+\/+-+\/+[+]+\/+[*]+=+[*]+=+\\+&+\\+:+;+'+;+'+"+'+"+
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
          wordy: |
                sol
                'alias'
                wss
                get not wss
                wss
                get chs
          terse: |
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
          wordy: |
                start-of-line
                'alias'
                whitespaces
                capture as alias one or more non-whitespace
                whitespaces
                capture as value characters
          terse: |
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
                    
    - group-name: Examples terse-to-wordy
      terse-to-wordy: true
      tests:
      
        - name: Example from MRE
          notes: Extracting alias name and value, example used in MRE2
          wordy: |
                start-of-line
                'alias'
                one or more  whitespace
                capture
                    one or more  non-whitespace
                one or more  whitespace
                capture 
                    one or more  character
          terse: |
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


              
        - name: Test 1
          terse: |
              \( ( (?: [a-zA-Z] | [ivx]{1,3} | \d\d? ) ) \) \s+(.*)
          terse-options: x
          wordy: |
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
          terse: |
              name="p_flow_id" value="([^"]*)"
          terse-options: -x
          wordy: |
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
          terse: |
              p_flow_id" value="(.*?)"
          terse-options: -x
          wordy: |
              'p_flow_id'
              double-quote
              ' value='
              double-quote
              capture
                  zero or more minimal non-newline
              double-quote
              
        - name: Test 4
          terse: |
               \R \D [\R] 
          terse-options: x
          wordy: |
              generic-newline
              non-digit
              R
              
        - name: Test 5
          terse: |
               \b [\b] \B [\B] 
          terse-options: x
          wordy: |
              word-boundary
              backspace
              non-word-boundary
              B
              
        - name: Test 6
          terse: |
              ([012]?\d):([0-5]\d)(?::([0-5]\d))?(?i:\s(am|pm))?
          terse-options: x
          wordy: |
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
          terse: |
              <A[^>]+?HREF\s*=\s*["']?([^'" >]+?)['"]?\s*>
          terse-options: -x
          wordy: |
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
          terse: |
              ^0?(\d*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)
          terse-options: x
          wordy: |
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
          terse: |
              [a-g]{1,2}+
          terse-options: x
          wordy: |
              one or two possessive a-g
              
        - name: Test 10
          terse: |
              [a-g]*+
          terse-options: x
          wordy: |
              zero or more possessive a-g
              
        - name: Test 11
          terse: |
              [a-g]++
          terse-options: x
          wordy: |
              one or more possessive a-g
              
        - name: Test 12
          terse: |
              [a-g]?+
          terse-options: x
          wordy: |
              optional possessive a-g
              
        - name: Test 13
          terse: |
              [a-g]*?
          terse-options: x
          wordy: |
              zero or more minimal a-g
              
        - name: Test 14
          terse: |
              [a-g]+?
          terse-options: x
          wordy: |
              one or more minimal a-g
              
        - name: Test 15
          terse: |
              [a-g]??
          terse-options: x
          wordy: |
              optional minimal a-g
              
        - name: Test 16
          terse: |
              21
          terse-options: -x
          wordy: |
              '21'
              
        - name: Test 17
          terse: |
              20
          terse-options: -x
          wordy: |
              '20'
              
        - name: Test 18
          terse: |
              0
          terse-options: -x
          wordy: |
              0
              
        - name: Test 19
          terse: |
              ^(?:21|19)
          terse-options: -x
          wordy: |
              start-of-string
              '21' '19'
              
        - name: Test 20
          terse: |
              ^(?:20|19)
          terse-options: -x
          wordy: |
              start-of-string
              '20' '19'
              
        - name: Test 21
          terse: |
              ^(?:19|20)
          terse-options: -x
          wordy: |
              start-of-string
              '19' '20'
     
        - name: Test 21
          terse: |
              ^(?:20|19)
          terse-options: -x
          wordy: |
              start-of-string
              '20' '19'
              
        - name: Test 22
          terse: |
              ^(?:19|20)
          terse-options: -x
          wordy: |
              start-of-string
              '19' '20'
              
        - name: Test 23
          terse: |
              ^(?:0)
          terse-options: -x
          wordy: |
              start-of-string
              0
              
        - name: Test 24
          terse: |
              ^0
          terse-options: -x
          wordy: |
              start-of-string
              0
              
        - name: Test 25
          terse: |
              ^(?:19|20)\d{2}-\d{2}-\d{2}(?:$|[ ]+\#)
          terse-options: -x
          wordy: |
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
          terse: |
              ^[012]?\d:[0-5]\d(?:[0-5]\d)?(?:\s(?:AM|am|PM|pm))?(?:$|[ ]+\#)
          terse-options: -x
          wordy: |
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
          terse: |
              \G(?:(?:[+-]?)(?:[0123456789]+))
          terse-options: gc-x
          wordy: |
              end-of-previous-match
              optional  + hyphen
              one or more  0 1 2 3 4 5 6 7 8 9
              
        - name: Test 28
          terse: |
              (?:(?:[+-]?)(?:[0123456789]+))
          terse-options: -x
          wordy: |
              optional  + hyphen
              one or more  0 1 2 3 4 5 6 7 8 9
              
        - name: Test 29
          terse: |
              (?:(?:[-+]?)(?:[0123456789]+))
          terse-options: -x
          wordy: |
              optional  hyphen +
              one or more  0 1 2 3 4 5 6 7 8 9
              
        - name: Test 30
          terse: |
              (?i:J[.]?\s+A[.]?\s+Perl-Hacker)
          terse-options: -x
          wordy: |
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
          terse: |
              http://(?:(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|(?:(?:[a-z]|[A-Z])|[0-9])(?:(?:(?:[a-z]|[A-Z])|[0-9])|-)*(?:(?:[a-z]|[A-Z])|[0-9]))\.)*(?:(?:[a-z]|[A-Z])|(?:[a-z]|[A-Z])(?:(?:(?:[a-z]|[A-Z])|[0-9])|-)*(?:(?:[a-z]|[A-Z])|[0-9]))\.?|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(?::[0-9]*)?(?:/(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*(?:;(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*)*(?:/(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*(?:;(?:(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f])|[:@&=+$,])*)*)*(?:\?(?:[;/?:@&=+$,]|(?:(?:(?:[a-z]|[A-Z])|[0-9])|[\-\_\.\!\~\*\'\(\)])|%(?:[0-9]|[A-Fa-f])(?:[0-9]|[A-Fa-f]))*)?)?
          terse-options: -x
          wordy: |
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
          terse: |
              http://(?::?[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.[a-zA-Z]*(?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.?|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(?::[0-9]*)?(?:/(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*(?:;(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*)*(?:/(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*(?:;(?:(?:(?:[a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f])|[:@&=+$,]))*)*)*(?:\?(?:(?:[;/?:@&=+$,a-zA-Z0-9\-\_\.\!\~\*\'\x28\x29]|%[0-9A-Fa-f][0-9A-Fa-f]))*)?)?
          terse-options: -x
          wordy: |
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
          terse: |
              <A[^>]+?HREF\s*=\s*["']?([^'" >]+?)['"]?\s*>
          terse-options: -x
          wordy: |
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
          terse: |
              (.)\g1
          terse-options: -x
          wordy: |
              capture non-newline
              backref-1
              
        - name: Test 35
          terse: |
              (.)\1
          terse-options: -x
          wordy: |
              capture non-newline
              backref-1
              
        - name: Test 36
          terse: |
              (.)\g{-1}
          terse-options: -x
          wordy: |
              capture non-newline
              backref-relative-1
              
        - name: Test 37
          terse: |
              \b
          terse-options: -x
          wordy: |
              word-boundary
              
        - name: Test 38
          terse: |
              \B
          terse-options: -x
          wordy: |
              non-word-boundary
              
        - name: Test 39
          terse: |
              [a-g]
          terse-options: x
          wordy: |
              a-g
              
        - name: Test 40
          terse: |
              [a-g]*
          terse-options: x
          wordy: |
              zero or more  a-g
              
        - name: Test 41
          terse: |
              [a-g]+
          terse-options: x
          wordy: |
              one or more  a-g
              
        - name: Test 42
          terse: |
              [a-g]?
          terse-options: x
          wordy: |
              optional  a-g
              
        - name: Test 43
          terse: |
              [a-zA-Z0-9\x02-\x10]
          terse-options: x
          wordy: |
              a-z A-Z 0-9 range hex-02 to hex-10
              
        - name: Test 44
          terse: |
              [a-q ]
          terse-options: -x
          wordy: |
              a-q space
              
        - name: Test 45
          terse: |
              [\ca-\cq ]
          terse-options: -x
          wordy: |
              range control-A to control-Q space
              
        - name: Test 46
          terse: |
              [a\-g]*
          terse-options: x
          wordy: |
              zero or more  a hyphen g
              
        - name: Test 47
          terse: |
              [pa-gk]*
          terse-options: x
          wordy: |
              zero or more  p a-g k
              
        - name: Test 48
          terse: |
              [\x20 ]\?
          terse-options: x
          wordy: |
              hex-20 space
              ?
              
        - name: Test 49
          terse: |
              [\x34\cG ]\?
          terse-options: x
          wordy: |
              hex-34 control-G space
              ?
              
              
        - name: Test 54
          terse: |
              [\cA\cB\cC\cD\cE\cF\cG\cH\cI\cJ]
          terse-options: -x
          notes: |
              ctl-a thru ctl-j
          wordy: |
              control-A control-B control-C control-D control-E control-F control-G control-H control-I control-J
              
        - name: Test 55
          terse: |
              [\cK\cL\cM\cN\cO\cP\cQ\cR\cS\cT\cU\cV]
          terse-options: -x
          notes: |
              ctl-K thru ctl-V
          wordy: |
              control-K control-L control-M control-N control-O control-P control-Q control-R control-S control-T control-U control-V
              
        - name: Test 56
          terse: |
              [\cW\cX\cY\cZ]
          terse-options: -x
          notes: |
              ctl-W thru ctl-Z
          wordy: |
              control-W control-X control-Y control-Z
              
        - name: Test 57
          terse: |
              [abc]\?
          terse-options: x
          wordy: |
              a b c
              ?
              
        - name: Test 58
          terse: |
              [abc]\?*
          terse-options: x
          wordy: |
              a b c
              zero or more  ?
              
        - name: Test 59
          terse: |
              []]?
          terse-options: x
          wordy: |
              optional  ]
              
        - name: Test 60
          terse: |
              [\]]?
          terse-options: x
          wordy: |
              optional  ]
              
        - name: Test 61
          terse: |
              ]?
          terse-options: x
          wordy: |
              optional  ]
              
        - name: Test 62
          terse: |
              \]?
          terse-options: x
          wordy: |
              optional  ]
              
        - name: Test 63
          terse: |
              []X]?
          terse-options: x
          wordy: |
              optional  ] X
              
        - name: Test 64
          terse: |
              [[]?
          terse-options: x
          wordy: |
              optional  [
              
        - name: Test 65
          terse: |
              [a-g]+
          terse-options: x
          wordy: |
              one or more  a-g
              
        - name: Test 66
          terse: |
              X++Y
          terse-options: -x
          wordy: |
              one or more possessive X
              Y
              
        - name: Test 67
          terse: |
              X?+Y
          terse-options: -x
          wordy: |
              optional possessive X
              Y
              
        - name: Test 68
          terse: |
              X*+Y
          terse-options: -x
          wordy: |
              zero or more possessive X
              Y
              
        - name: Test 69
          terse: |
              X{3,4}+
          terse-options: -x
          wordy: |
              three or four possessive X
              
        - name: Test 70
          terse: |
              X{3,4}?
          terse-options: -x
          wordy: |
              three or four minimal X
              
        - name: Test 71
          terse: |
              X{3,4}
          terse-options: -x
          wordy: |
              three or four  X
              
        - name: Test 72
          terse: |
              \p{Ll}
          terse-options: -x
          wordy: |
              'p{Ll}'
              
        - name: Test 73
          terse: |
              <tr[^<]*><td>([^<]*)<\/td><td[^<]*>([^<]*)<\/td><td>[^<]*<\/td><td>([^<]*)<\/td><td>([^<]*)<\/td><td[^<]*>([^<]*)<\/td><\/tr>
          terse-options: -x
          wordy: |
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
          terse: |
              [\D\S\W]+
          terse-options: -x
          notes: |
              nonsensical regex: multiple negated
          wordy: |
              one or more  non-digit non-whitespace non-word-char
              
        - name: Test 75
          terse: |
              [\D\S\W]
          terse-options: -x
          notes: |
              nonsensical regex: multiple negated
          wordy: |
              non-digit non-whitespace non-word-char
              
        - name: Test 76
          terse: |
              [^ ]
          terse-options: -x
          wordy: |
              not space
              
        - name: Test 78
          terse: |
              \\w?  \\d
          terse-options: x
          wordy: |
              backslash
              optional  w
              backslash
              d

        - name: Test 80
          terse: |
              \n?\x12
          terse-options: -x
          wordy: |
              optional  newline
              hex-12
              
        - name: Test 81
          terse: |
              (cat) (mouse)
          terse-options: -x
          wordy: |
              capture 'cat'
              space
              capture 'mouse'
              
        - name: Test 82
          terse: |
              cat & mouse
          terse-options: -x
          wordy: |
              'cat & mouse'
              
        - name: Test 83
          terse: |
              \w?  \d{3}
          terse-options: x
          wordy: |
              optional  word-char
              three  digit
              
        - name: Test 84
          terse: |
              \w?  \d{4,}
          terse-options: x
          wordy: |
              optional  word-char
              four or more  digit
              
        - name: Test 85
          terse: |
              \w?  \d{5,6}
          terse-options: x
          wordy: |
              optional  word-char
              five or six  digit
              
        - name: Test 86
          terse: |
              \w?  \d
          terse-options: x
          wordy: |
              optional  word-char
              digit
              
        - name: Test 87
          terse: |
              \w?  \d
          terse-options: x
          wordy: |
              optional  word-char
              digit
              
        - name: Test 88
          terse: |
              \w?  \d
          terse-options: x
          wordy: |
              optional  word-char
              digit
              
        - name: Test 89
          terse: |
              \w?  \d
          terse-options: x
          wordy: |
              optional  word-char
              digit
              
        - name: Test 90
          terse: |
              \w?  \d
          terse-options: x
          wordy: |
              optional  word-char
              digit
              
        - name: Test 91
          terse: |
              \w?  \d
          terse-options: x
          wordy: |
              optional  word-char
              digit
              
        - name: Test 92
          terse: |
              \w?  \d
          terse-options: x
          wordy: |
              optional  word-char
              digit
              
        - name: Test 93
          terse: |
              \n?  \a
          terse-options: x
          wordy: |
              optional  newline
              alarm
              
        - name: Test 94
          terse: |
              \n?  \a
          terse-options: x
          wordy: |
              optional  newline
              alarm
              
        - name: Test 95
          terse: |
              \n?  \a
          terse-options: x
          wordy: |
              optional  newline
              alarm
              
        - name: Test 96
          terse: |
              \n?  \a
          terse-options: x
          wordy: |
              optional  newline
              alarm
              
        - name: Test 97
          terse: |
              ^cat.dog$
          terse-options: ms
          wordy: |
              start-of-line
              'cat'
              character
              'dog'
              end-of-line
              
        - name: Test 98
          terse: |
              t''"dog
          terse-options: 
          wordy: |
              t
              apostrophe
              apostrophe
              double-quote
              'dog'
              
        - name: Test 99
          terse: |
              cat""""dog
          terse-options: x
          wordy: |
              'cat'
              double-quote
              double-quote
              double-quote
              double-quote
              'dog'
              
        - name: Test 100
          terse: |
              cat''''dog
          terse-options: x
          wordy: |
              'cat'
              apostrophe
              apostrophe
              apostrophe
              apostrophe
              'dog'
        - name: Test 100
          terse: |
              cat''''dog
          terse-options: x
          wordy: |
              'cat'
              apostrophe
              apostrophe
              apostrophe
              apostrophe
              'dog'
              
        - name: Test 101
          terse: |
              cat["']dog
          terse-options: x
          wordy: |
              'cat'
              double-quote apostrophe
              'dog'
              
        - name: Test 102
          terse: |
              cat.dog
          terse-options: x
          wordy: |
              'cat'
              non-newline
              'dog'
              
        - name: Test 103
          terse: |
              cat.dog
          terse-options: s
          wordy: |
              'cat'
              character
              'dog'
              
        - name: Test 104
          terse: |
              cat.dog
          terse-options: s
          wordy: |
              'cat'
              character
              'dog'
              
        - name: Test 105
          terse: |
              ^cat.dog$
          terse-options: s
          wordy: |
              start-of-string
              'cat'
              character
              'dog'
              eosx
              
        - name: Test 106
          terse: |
              ^cat.dog$
          terse-options: 
          wordy: |
              start-of-string
              'cat'
              non-newline
              'dog'
              eosx
              
        - name: Test 107
          terse: |
              ^cat.dog$
          terse-options: s
          wordy: |
              start-of-string
              'cat'
              character
              'dog'
              eosx
              
        - name: Test 108
          terse: |
              ^cat.dog$
          terse-options: m
          wordy: |
              start-of-line
              'cat'
              non-newline
              'dog'
              end-of-line
              
        - name: Test 109
          terse: |
              ^cat.dog$
          terse-options: ms
          wordy: |
              start-of-line
              'cat'
              character
              'dog'
              end-of-line

              
        - name: Test 110
          terse: |
              ([^ ]+) +([^ ]+) +([^"]+)" +(\d+) +([^ ]+) +(\d+) +"([^"]+)" +"[^"]+"(?: +(.*))?
          terse-options: -x
          wordy: |
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
          terse: |
                             cd      (?i: (?:  ss                     ) uu (?: vv | [wx] )){5,}[34]
          terse-options: x
          wordy: |
              'cd'
              five or more  case-insensitive
                  'ss'
                  'uu'
                  'vv' w x
              3 4
              
        - name: Test 112
          terse: |
              ab[12\w]?  |  cd\dee* (?i: (?:  ss | (?<gmt> [g-m]+ tt)) uu (?: vv | [wx] )){5,}[34]
          terse-options: x
          wordy: |
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
          terse: |
              ab[12\w]?  |  cd\dee* (?i:                               uu (?: vv | [wx] )){5,}[34]
          terse-options: x
          wordy: |
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
          terse: |
              ab[12\w]?  |  cd\dee* (?i:                               uu (?: vv | [wx] )){5,}[34]
          terse-options: x
          wordy: |
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
          terse: |
              (?: aa\d | bb\w ) cc (?: dd\D | ee | ff\d ) (?: gg | hh | ii )
          terse-options: x
          wordy: |
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
          terse: |
              (?: aa \d | bb \w ) cc (?: dd \D | ee | ff \d ) (?: gg | hh | ii )
          terse-options: x
          wordy: |
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
          terse: |
              ^(?:([^,]+),)?((?:\d+\.){3}\d+)[^\[]+\[([^\]]+)\][^"]+"([^ ]+) +([^ ]+) +([^"]+)" +(\d+) +([^ ]+) +(\d+) +"([^"]+)" +"[^"]+"(?: +(.*))?
          terse-options: -x
          wordy: |
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
          terse: |
              ^(?:([^,]+),)?((?:\d+\.){3}\d+)[^\[]+\[([^\]]+)\][^"]+"([^ ]+) +([^ ]+) +([^"]+)" +(\d+) +([^ ]+) +(\d+) +"([^"]+)" +"[^"]+"(?: +(.*))?
          terse-options: -x
          wordy: |
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
          terse: |
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
          wordy: |
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
          terse: |
              
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
          wordy: |
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
          terse: |
              
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
          wordy: |
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
              

EOTESTS

my $v = YAML::Validator->new($schema);

my ($p, $q) = $v->load_data($tests);
die $q if $q;

my $data_loaded = $p->{groups}[0]{tests}[0];

my $groups_ref = $p->{groups};
for my $group_ref ( @{$groups_ref}) {
    my $group_name = $group_ref->{'group-name'} || '<unnamed>';
    my $group_wordy_to_terse = $group_ref->{'wordy-to-terse'};
    my $group_terse_to_wordy = $group_ref->{'terse-to-wordy'};
    log_text ("Starting group: $group_name");
    for my $tests_ref ($group_ref->{tests}) {
        for my $test_ref (@{$tests_ref}) {
            my $test_name = $test_ref->{'name'};
            log_text ("Test name: $test_name");
            
            my $test_wordy_to_terse = $test_ref->{'wordy-to-terse'};
            my $test_terse_to_wordy = $test_ref->{'terse_to_wordy'};
            $test_wordy_to_terse = defined $test_wordy_to_terse
                                   ? $test_wordy_to_terse
                                   : $group_wordy_to_terse;
            $test_terse_to_wordy = defined $test_terse_to_wordy
                                   ? $test_terse_to_wordy
                                   : $group_terse_to_wordy;                                   
            if ( ! $test_terse_to_wordy && ! $test_wordy_to_terse) {
                complain("Test '$test_name' in group '$group_name' has no direction");
            }
            my $wordy = $test_ref->{wordy};
            my $terse = $test_ref->{terse};
            chomp $terse if $terse;
            if ($test_wordy_to_terse) {
                if (! defined $wordy) {
                    # No wordy: no can do
                    complain("Test '$test_name' in group '$group_name' needs a wordy");
                } else {
                    # We have a wordy
                    ## Might need to call a more complex routine, e.g. to handle
                    ## errors more elegantly
                    my $generated_tre = _wre_to_tre($wordy,
                                                    {free_space  => 0,
                                                     wrap_output => 0}
                                                    );    # Makes a wre object
                    if (defined $terse) {
                        # We have been supplied a terse regexp to compare with
                        is($generated_tre, $terse, "$group_name: $test_name: tre as expected");
                    }
                    # Check the generated tre using the matches provided
                    check_matches($test_ref, $generated_tre, $group_name, $test_name);
                }
            }
            if ($test_terse_to_wordy) {
                if (! defined $terse) {
                    # No terse: no can do
                    complain("Test '$test_name' in group '$group_name' needs a terse");
                } else {
                    # We have a terse
                    ## Might need to call a more complex routine, e.g. to handle
                    ## errors more elegantly
                    my $terse_options = $test_ref->{'terse-options'} || '';
                    my $generated_wordy = tre_to_wre($terse, $terse_options); 
                    if (defined $wordy) {
                        # We have been supplied a wordy regexp to compare with
                        is($generated_wordy, $wordy, "$group_name: $test_name: wordy as expected");
                    }
                    # Check the wordy using the matches provided
                    check_matches($test_ref, wre($wordy), $group_name, $test_name);
                }                
            }
        }
    }
}

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