#!/usr/bin/perl
use strict;
use warnings;
## use YAML::XS;  # Only used for debug purposes, can easily be removed
use lib "../Regexp";
use RegExp::Wre qw(wre wret);

use 5.008;

=format
hre_server.pl

This is a test harness for the new regex notations, providing a web app that
converts to and from the terse regex notation, and allows regexes to be tested

Originally I planned to have it support a different variant of the wordy
notation. That plan is now abandoned, but the naming and structure bear the
scars - and it only supports the wordy notation.

Although it is a web server, it's not currently suitable for use as a public
service:
    - It uses the ultra-simple HTTP::Server::Simple, so it is single-threaded.
      This might be a feature rather than a defect: it does restrict of CPUs
      at risk from the next issue.
    - It has no defence against denial-of-service attacks (intentional or not)
      caused by bad regexes which cause excessive back-tracking.
      
Although the Perl CGI technology is ancient, this is the first place where I
have made any non-trivial use of it. So the way it is used may be idiosyncratic.
DRM

.......................
SECURITY CONSIDERATIONS
.......................

It allows the user to run arbitrary *wordy* regular expressions.
Users currently do not have the ability to run arbitrary *conventional* regexes,
so they probably cannot use Perl's ability to embed code within the regex. It
might be possible to craft a wordy regex which exploited defective regex
generation to insert malicious code, but that seems low risk.

It is intended that later versions of this server will have a regex
test option that allows the user to enter a terse regex and some sample data,
then executes both the *original user-entered* terse regex as well as the one
produced from the generated wordy. This 'both-ways' testing will help to detect
situations where the either the terse-to-new or new-to-terse conversion is not
correct. If this happens the user will be alerted: the regex and data should be
logged and an automatic report created. However, it will expose an increased
risk of  malicious terse regexes getting past the defences.

.....................................................................

To Do:

BUGS (KNOWN): See also bugs noted in Tre2Wre.pm and Wre.pm.

Does not handle terse regexes that are entered with free-spacing mode off
(x-mode terse unchecked) that have newlines. The newlines are seen as a
carriage-return then a newline, presumably because they are web-style cr/lf
sequences and Perl is assuming that newlines will be just lf.

Long-term the intention is to make newline in a wordy always match crlf, just cr
or just lf. But that might not always be appropriate in the other direction: if
an existing terse regex is being converted that only matches \n, then it should
be a option to say whether the wordy should match generic-newline ( \R in terse)
or only newline ( \n ). There may also be Unicode mode issues about what \n
matches.


=cut


 {
 package MyWebServer;
 
 use HTTP::Server::Simple::CGI;
 use base qw(HTTP::Server::Simple::CGI);
 use RegExp::Tre2Wre qw( tre_to_wre ); 
 my %dispatch = (
     '/'         => \&create_hre_form,
     '/wre'      => \&create_wre_form,
     '/wre_resp' => \&resp_wre_form,
     '/hre'      => \&create_hre_form,
     '/hre_resp' => \&resp_hre_form,
     '/test'     => \&resp_form_generic,
     # ...
 );


sub form_start {
    my ($form_url, $form_name) = @_;
    my $form_text = <<"EOF";
<form action="$form_url" name="$form_name" method="post">
  First name: <input type="text" name="$form_name:fname" /><br />
                            <!--   -->
  Last name: <input type="text" name="$form_name:lname" /><br />
  <input type="submit" value="Submit" />
  <input type="number" name="aNumber" />
  <p> <button name="action" value="update">Save</button> </p>
EOF
}
 
 
sub no_flow {
    my ($txt)  = @_;
    $txt =~ s/\n/\n<br>/gx;
    $txt =~ s/<br>   [ ] /<br>&nbsp;/gx;
    $txt =~ s/&nbsp; [ ] /&nbsp;&nbsp;/gx;
    my $style = '<p class="mono">';
    my $end_p = '</p>';
    return $style . $txt . $end_p;
 }

 
sub css_head {
    my $css_part_1 = <<'EOF';
<head>
<style type="text/css">
.mono{font-family:monospace;}
.sansserif{font-family:Arial,Helvetica,sans-serif;}
</style>
<style type="text/css">
<!--
table {
border: 1px solid #666666;
width:100px;
border-collapse: collapse;
}
td { border: 1px solid #666666; color: #ffffff }
th { border: 1px solid #111111; }
-->
</style>
<style>
body{font-family:futura, helvetica, arial;font-size:19px;background-color:#232300}
form{margin:0px;padding:0px}
#form_wrapper{border-bottom:1px solid #5E5D5E;min-height:270px}
a{color:#ffffff}a:hover{text-decoration:none}
h1{margin-bottom:0px;padding-bottom:0px;padding-top:0px;margin-top:18px;font-size:60px;font-weight:normal;letter-spacing:-3px;margin-left:-6px}
h1 a,.birdseed_note a{color:#F2F179;text-decoration:none}h1 a:hover,.birdseed_note a:hover{color:#FFFFAA}h2{margin-top:0px;padding-top:0px;font-size:20px;font-weight:normal;color:#F2F179;margin-bottom:20px;letter-spacing:-0.01em}h3{color:#6178D8;font-weight:normal;margin-bottom:10px;font-size:22px;margin-top:22px}#main{width:1035px;margin-left:auto;margin-right:auto;text-align:center}#inner{position:relative;text-align:left;border:20px solid #e6e6e6;padding:10px;padding-right:15px;margin-left:auto;margin-right:auto;background-color:#5E5D5E;color:#ffffff}#match_string.match_string_nowrap{white-space:pre}#match_string,#match_captures,input[type="text"],textarea,.slash{font-size:12px;font-family:monaco, courier}#match_captures table{border-collapse:collapse;margin:5px}#match_captures table th{font-family:futura, helvetica, arial;font-variant:small-caps;color:#84bde7;font-size:12px;padding-top:10px;font-weight:normal}#match_captures table th:first-child{padding-top:5px}#match_captures table tbody tr:first-child td{padding-top:10px}#match_captures table tbody tr:nth-last-child(1) td{padding-bottom:10px}#match_captures table tr td:nth-child(1){padding-top:4px}#match_captures table tr td:nth-child(2){padding-left:8px;padding-top:4px}#match_captures td.named_group span{font-size:12px;padding:1px 2px 1px 2px;background-color:#F2F179;color:#000}#match_string,#match_captures{border:1px solid #DDDDDD;padding:15px;background-color:#000000;color:#ffffff;margin-bottom:10px}#match_string,#match_captures{margin-top:1px}#match_string{white-space:pre-wrap}#match_captures{padding-top:5px;padding-bottom:5px}#match_string_inner{background-color:#000000}code{font-family:monaco, courier;font-weight:bold}#regex{width:800px}#options{width:80px}.slash{font-size:20px;margin-left:3px;margin-right:3px}#form_wrapper input[type="text"]{font-size:16px}#form_wrapper input[type="text"],#form_wrapper textarea{background-color:#000000;color:#ffffff;padding:10px;border:1px solid #DDDDDD}.match{padding:2px;color:#0066B3;background-color:#BFE4FF}#test_and_result{margin-top:10px;margin-left:20px;margin-right:3px;text-align:left;position:relative}#test_string{float:left;padding-left:0px;width:408px;height:165px}input[type="text"]:focus,#test_string textarea:focus{background-color:#221e1e !important}#test_string textarea{width:100%;height:125px;margin-bottom:4px}#result{margin-left:450px;width:490px;margin-bottom:0px}.notice,.error{padding:20px;position:relative;font-size:16px;text-align:center;margin-bottom:26px}.notice{top:18px;border:10px solid #779A73;background-color:#CDF3C9;color:#283A26}.notice a{color:#283A26}.error{top:50px;background-color:#FDD2D2;border:10px solid #D37979;color:#4D3838}label,.result_label{letter-spacing:1px;font-size:16px}#ajax_note{clear:both;text-align:center;color:#F2F179;font-size:14px;padding:0px;margin:0px;margin-top:13px;margin-bottom:0px;margin-left:auto;margin-right:auto;width:550px}#ajax_note a{color:#F2F179}.form_controls{clear:both;text-align:center;padding-bottom:10px;padding-top:15px}.form_controls a{background-color:#6E6E6E;padding:3px 10px 3px 10px;margin-left:10px;font-size:11px;letter-spacing:1px;text-decoration:none}.form_controls a:hover{background-color:#8B8B8B}#regex_label{padding-left:20px;line-height:24px}#quickref{text-align:left;background-color:#e6e6e6;border:10px solid #5E5D5E;font-size:13px;padding:5px}#quickref td{padding-right:18px}.birdseed{margin-top:20px;color:#ffffff;font-size:14px}.birdseed a{color:#F2F179}.birdseed_note{font-size:12px;color:#9F9F9F}.birdseed_note a{text-decoration:none}#ajax_loader_wrapper{position:absolute;bottom:10px;right:10px}#ad{margin-top:20px}#regex_options{margin-top:8px;margin-left:10px;margin-right:10px;border-top:1px solid #cecece;padding-top:4px;font-size:12px}#regex_options p{margin:3px}#regex_options code{margin-left:25px;margin-right:8px}#modal_birdseed{display:none}#insert_links,#test_settings,#test_settings label{padding:2px}#insert_links,#test_settings,#test_settings label{font-family:futura, helvetica, arial;font-size:11px}#test_settings input{padding:0px;margin:0px;margin-left:2px}#test_settings label{color:#BFBFBF;letter-spacing:0px;padding-left:9px}#test_settings label:nth-child(1){padding-left:0px}#insert_links{padding-top:6px;font-size:10px;color:#283A26}#insert_links span{background-color:#CDF3C9;padding:2px 2px 2px 3px}#test{margin-top:1px}#notice{margin-top:-10px;background-color:#FFFFAA;border:4px solid #BEBF83;border-top:0px;font-size:13px;padding:5px;padding-top:7px;color:#1F1F13;width:920px;margin-left:auto;margin-right:auto}#notice a{color:#1F1F13}.invis_char{color:#5F5F5F}.match .invis_char{color:#0066B3}
</style>
EOF

    return $css_part_1 . '<style>' . visible_if_css() . '</style>' . '</head>' ;
}
    
sub handle_request {
    my $self = shift;
    my $cgi  = shift;
  
    my $path = $cgi->path_info();
    my $handler = $dispatch{$path};

    if (ref($handler) eq "CODE") {
        print "HTTP/1.0 200 OK\r\n";
        $handler->($cgi);
        
    } else {
        print "HTTP/1.0 404 Not found\r\n";
        print $cgi->header,
              $cgi->start_html('Not found'),
              $cgi->h1('Not found'),
              $cgi->end_html;
    }
}
 
sub hre_form {
    my ($cgi,
        $hre_box_content_parm,
        $tre_box_content_parm,
        $results_box_content_parm,
        $test_pass_box_content_parm,
        $test_fail_box_content_parm,
        $replace_box_content_parm,
        $x_mode_terse_parm,
        $repeatedly_parm,
        $m_mode_terse_parm,
        $s_mode_terse_parm,
        $i_mode_terse_parm,
        $flavour_parm,
        
        ) = @_;
    
    my $hre_box_content  = $hre_box_content_parm || "'You can enter a wordy regex here'";
    my $tre_box_content  = $tre_box_content_parm ||  "You can enter a terse regex here" ;
    my $test_pass_content = $test_pass_box_content_parm || "test data should match";
    my $test_fail_content = $test_fail_box_content_parm || "test data should not match";
    my $replace_box_content = $replace_box_content_parm || 'replace with this'; 
    my $results_box_content = $results_box_content_parm || 'results';
    my $x_mode_terse        = $x_mode_terse_parm ? 'checked' : '';
    my $m_mode_terse        = $m_mode_terse_parm ? 'checked' : '';
    my $s_mode_terse        = $s_mode_terse_parm ? 'checked' : '';
    my $i_mode_terse        = $i_mode_terse_parm ? 'checked' : '';
    my $repeatedly          = $repeatedly_parm   ? 'checked' : '';
        
    my $cb_x_mode_terse   = $cgi->checkbox('x_mode_terse'    , $x_mode_terse,'checked','/x free spacing');
    my $cb_m_mode_terse   = $cgi->checkbox('m_mode_terse'    , $m_mode_terse,'checked','/m multi-line   ');
    my $cb_s_mode_terse   = $cgi->checkbox('s_mode_terse'    , $s_mode_terse,'checked','/s dot-means-all');
    my $cb_i_mode_terse   = $cgi->checkbox('i_mode_terse'    , $i_mode_terse,'checked','/i case-insensitive');
    my $flavour = 'Perl';

my $radio =
$cgi->radio_group(-label    => "Level 1",
                         -name     => 'flavour',
                         -variable => \$flavour,
                         -values   =>['Perl','.NET','Java','JavaScript', 'Python'],
                         -rows     =>1,
                         -columns  =>5
                    );
                         #-value    => 1) .

#$cgi->radio_group(-label    => "Level 2",
#                         -variable => \$log_level,
#                         -value    => 2) .
#
#$cgi->radio_group(-label    => "Level 3",
#                         -variable => \$log_level,
#                         -value    => 3);
# 
#   $cgi->radio_group(-name=>'group_name',
#-values=>['eenie','meenie','minie','moe'],
#-rows=>2,-columns=>2);
    

    my $embed_original    = $cgi->checkbox('embed_original'  , 'checked',    'ON','Embed wordy as comments');
    my $cb_repeatedly     = $cgi->checkbox('repeatedly'      , '',           'ON','Repeatedly');
    
    my $wrap_in;

    
    return <<"EOF";
<form name ="hre" action="hre_resp" method="post">

    <br>
    <h2>Terse
    $cb_m_mode_terse $cb_s_mode_terse $cb_i_mode_terse</h2>
    $radio
    <textarea name="tre" rows ="10" cols="80">$tre_box_content</textarea>    
    <h2>$cb_x_mode_terse</h2>
    <br>
    <div class="form_controls" style="float:left">
      <input type="submit" name="chosen" value="Terse to Wordy &darr;" />
      <input type="submit" name="chosen" value="Wordy to Terse &uarr;" />
      <h2>$embed_original<h2>
    </di>
    <h2>Wordy
        <br>
    </h2>
    <textarea name="hre" rows ="10" cols="80">$hre_box_content</textarea>
    
    <textarea name="results" rows ="10" cols="40">$results_box_content</textarea>
    <p>

    <input type="submit" name="chosen" value="Match" />
    <input type="submit" name="chosen" value="Replace" />
    <input type="submit" name="chosen" value="Split" />
    $cb_repeatedly
    <br>
    <h2>Test Data
    <textarea name="text" rows ="2" cols="40">$test_pass_content</textarea>
    Replace with
    <textarea name="replacement" rows ="2" cols="40">$replace_box_content</textarea>
    </h2>
    <br>
    


    
</form>
EOF
}
    ## <input type="submit" name="Action" value="Shout" /><input type="submit" name="Action" value="Scream" />
    
    ##Action<br>
    ##<select name="action">
    ##    <option value="wre_to_tre" selected="selected">wordy to terse</option>
    ##    <option value="tre_to_wre">terse to wordy</option>
    ##</select>

#    <button name="BUTTON" value="wordy to terse">Wordy to Terse</button>
#    <button name="BUTTON" value="match">Match</button> 
#    <button name="BUTTON" value="match_repeatedly">Match Repeatedly</button>
#    <button name="BUTTON" value="replace">Replace</button>
#    <button name="BUTTON" value="replace_repeatedly">Replace Repeatedly</button>
#    <button name="BUTTON" value="split">Split</button> </p>
#    <button name="BUTTON" value="terse to wordy">Terse to Wordy</button>

#   <input type="submit" value="Submit" />
#   <p>before</p>
#   <input type="submit" name="chosen" value="Shout" /><input type="submit" name="chosen" value="Scream" />
#   <p>after</p>

  
  sub create_hre_form {
    # This was originally intended to be the form for calling the new
    # ( so new they have yet to be written) humane-to-terse and terse-to-humane
    # modules. However, it is has mutated into being the swept-up version of
    # the wordy form. When humane modules are available, they will probably
    # share this form, just invoke different conversion modules and parametering
    # the places where the new notation name is displayed.
    my $cgi = shift;   # CGI.pm object
    return if !ref $cgi;
    print $cgi->header,
        # $cgi->start_html("Hello"),
        "<!DOCTYPE HTML><html>",
        ## "<script>", js_inline(), "</script>",
        $cgi->head(css_head() ),
        $cgi->h2("<a>Welcome!</a>"),
        hre_form($cgi);
        $cgi->end_html;
  }
  
  sub resp_hre_form {
    # Handles the posted response from a hre form page
     my $cgi  = shift;   # CGI.pm object
     return if !ref $cgi;
     
     ## my $dump = YAML::XS::Dump $cgi;

     my $hre_in  = $cgi->param('hre');
     my $tre_in  = $cgi->param('tre');
     my $chosen  = $cgi->param('chosen') || 'unknown';
     my $text_in = $cgi->param('text')   || '';
     my $x_mode_terse  = $cgi->param('x_mode_terse' ) || '';
     my $m_mode_terse  = $cgi->param('m_mode_terse' ) || '';
     my $s_mode_terse  = $cgi->param('s_mode_terse' ) || '';
     my $i_mode_terse  = $cgi->param('i_mode_terse' ) || '';
     my $repeatedly    = $cgi->param('repeatedly'   ) || '';
     ##my $x_mode_terse_out = $cgi->param('x_mode_terse_out') || '';
     my $embed_original   = $cgi->param('embed_original') || '';
     my $flavour_in = $cgi->param('flavour') || '';
     my $new_hre = $hre_in;
     my $new_tre = $tre_in;
     my $new_results = '';
     
     my $response = "Internal error in hre_server";
     
     eval {
        if (lc $chosen =~ /to terse/i) {
            my $hre_obj = RegExp::Wre->new($hre_in,
                                            {
                                                free_space => $x_mode_terse,
                                                embed_original => $embed_original,
                                                flavour => $flavour_in,
                                                ## wrap_output => 1,
                                            }
                                           );
            $new_tre = "$hre_obj";
            # $response = no_flow("\n$wre_in converted\n\n$new_tre\n");
            $response = no_flow("wordy to terse OK\n");

        } elsif (lc $chosen =~ /terse to/i) {
            
            my $modes = ($x_mode_terse ? 'x' : '')
                      . ($m_mode_terse ? 'm' : '')
                      . ($s_mode_terse ? 's' : '')
                      . ($i_mode_terse ? 'i' : '');
            $new_hre = tre_to_wre($tre_in,
                                  $modes,
                                  {flavour => $flavour_in}
                                  );
            # $response = no_flow("$tre_in converted\n\n$new_wre\n");
            $response = no_flow("x_mode_terse: $x_mode_terse\nterse to wordy OK\n");
            
        } elsif (lc $chosen eq 'match'
              || lc $chosen eq 'split'
              || lc $chosen eq 'replace') {
            
            $response = "chose to do: $chosen";
            # Always convert to a Perl terse, so we can execute it
            my $hre_obj = RegExp::Wre->new($hre_in,
                                            {free_space => $x_mode_terse,
                                             embed_original => $embed_original,
                                             ## wrap_output => 1,
                                            }   );
            if ($hre_obj->{error}) {
                $new_results = "#### ERROR ###\n" . $hre_obj->{error};
            } else {
                $new_results = '';
                $new_tre = $hre_obj->{terse};
                my $capture_names_ref = $hre_obj->{capture_names};
                my $named_captures_present = join('', @{$capture_names_ref}) ne '';
                my $overall_name = $named_captures_present
                                 ? '(overall)' : '';
                my $current_index = 0;
                my @named_order;
                my @unnamed_order;
                            
                my $max_name_len = length $overall_name;
                for my $name (@{$capture_names_ref}) {
                    
                    if ($name) {
                        # This capture was named
                        if (length($name) > $max_name_len) {
                            $max_name_len = length($name);
                        }
                        push @named_order, $current_index++;
                        ## Return named captures in order of appearance
                    } else {
                        # Un-named capture
                        push @unnamed_order, $current_index++;
                    }
                }                                 
                                 
                $capture_names_ref->[0] = $overall_name;
                ## shift @{$capture_names_ref};
                my $flavoured_obj;
                if ($flavour_in !~ /perl/ix) {
                    # If the user wants something other than Perl, convert it to the
                    # requested flavour so that we can display it
                    $flavoured_obj = RegExp::Wre->new($hre_in,
                                                {free_space => $x_mode_terse,
                                                 embed_original => $embed_original,
                                                 flavour => $flavour_in,
                                                 ## wrap_output => 1,
                                                }
                                               );
                    $new_tre = $flavoured_obj->{terse};
                }
                
                if (lc $chosen ne "match") {
                    $new_results = "$chosen not yet implemented";
                } else {
                    my $keep_matching = 1;
                    my $repeat_count = 0;
                    while ($keep_matching) {
                        # Do the actual match: once, or repeatedly around this loop
                        my $matched;
                        my @results;
                        $repeat_count++;
                        $matched = $repeatedly ? ($text_in =~ /$hre_obj/g) :
                                                 ($text_in =~ $hre_obj);
                        $keep_matching =  $repeatedly ? $matched : 0;
                        my $named_results = '';
                        my @start_pos = @-;
                        my @end_pos   = @+;
                        
                        if (not $matched) {
                            # No (more) matches
                            $new_results .= $repeatedly ? "\nEnd of matches"
                                                        : 'No matches';
                        } else {
                            # Matched
                            for my $p (0 .. scalar @start_pos - 1) {
                                $results[$p] = substr($text_in,
                                                      $start_pos[$p],
                                                      $end_pos[$p] - $start_pos[$p]);
                            }
                            my @result_order;
                            my @results_copy = @results;
                            my (@named, @unnamed);
                            my @end_pos_copy   = @end_pos;
                            my $max_end_pos  = 0;

                            for my $this_end_pos (@end_pos){
                                if ($this_end_pos > $max_end_pos) {
                                    $max_end_pos = $this_end_pos;
                                }
                            }
                            if ( $flavour_in =~ /.net/ix) {
                                
                                # Under .NET, regexes return the captures in a different order to
                                # Perl when there are named as well as un-named captures.
                                # .NET returns all the un-named captures before any named ones.
                                # Perl returns all captures in the order in which they occur.
    
                                # User wants a .NET experience, so shuffle the results to
                                # match what would happen under .NET
                                push(@result_order, @unnamed_order, @named_order);
                            } else {
                                @result_order = 0 .. scalar @results - 1;
                            }
                            my $pos_fmt = '%' . length($max_end_pos) . 'd'
                                     . ' - %' . length($max_end_pos) . 'd'
                                     . ' [%d]' ;

                            for my $n (0 .. scalar @start_pos - 1) {
                                my $p = shift @result_order;
                                my $capture_name = $capture_names_ref->[$p];
                                my $space_count = $max_name_len
                                                  - length ($capture_name)
                                                  + 1;
                                my $capture_line = sprintf($pos_fmt,
                                                           $start_pos[$p],
                                                           $end_pos[$p],
                                                           $n
                                                           )
                                                   . ' ' x $space_count
                                                   . $capture_name
                                                   . ': '
                                                   . substr($text_in,
                                                            $start_pos[$p],
                                                            $end_pos[$p] - $start_pos[$p])
                                                   ;
                                $new_results .= $capture_line . "\n";
                            
                            }
                        }
                    }
                }
            }
     
        } else {
           $response    = "Do not know what to do! chosen: $chosen";
           $new_results = "Do not know what to do! chosen: $chosen"
           # Unimplemented action
        }
     };
     if ($@) {
        $response = "Internal error trapped: $@";
     }
     
     print $cgi->header,
            $cgi->head(css_head()),
            hre_form($cgi,
                     encode_amp($new_hre),
                     encode_amp($new_tre),
                     encode_amp($new_results),
                     encode_amp($text_in),
                     ),
            ## hre_form($cgi, $new_hre, $new_tre, $new_results, $text_in),
            '<br><br>',
            $response,
            # $cgi->p(no_flow($dump)),
            $cgi->end_html;
 }
 
sub encode_amp {
    my ($text) = @_;
    $text = $text || '';
    $text =~ s/ & /&amp;/gx;
    return $text;
}

sub visible_if_css {
    return <<'EOF';
    .visibleIf, .visibleif   {
	display: none;	
}


.visibleIf-visible, .visibleif-visible {
	display: block;
}

span.visibleIf-visible, span.visibleif-visible {
	display: inline;	
}

tr.visibleIf-visible, tr.visibleif-visible {
	display: block;
	display: table-row;
}


.visibleIf-rule, .mandatoryIf-rule, .visibleif-rule, .mandatoryif-rule {
	display: none;
}
EOF
  }
  
sub wre_form {
    my ($cgi,
        $wre_box_content_parm,
        $tre_box_content_parm,
        $results_box_content_parm,
        $text_box_content_parm,
        $replace_box_content_parm,
        ) = @_;
    my $wre_box_content  = $wre_box_content_parm || "'wre goes here'";
    my $tre_box_content  = $tre_box_content_parm ||  "tre goes here" ;
    my $text_box_content = $text_box_content_parm || "text to match";
    my $replace_box_content = $replace_box_content_parm || 'replacement text';
    my $results_box_content = $results_box_content_parm || 'results';
        
    my $x_mode_tre_in  = $cgi->checkbox('x_mode_terse_in' ,'','ON','X mode terse in');
    my $x_mode_tre_out = $cgi->checkbox('x_mode_terse_out','','ON','Generate free-space mode /x');
    my $embed_original = $cgi->checkbox('embed_original'  ,'','ON','Embed wordy as comments');
    
    ##my $x_mode_tre_in  = $cgi->checkbox('x_mode_terse_in' ,'checked','ON','X mode terse in');
    ##my $x_mode_tre_out = $cgi->checkbox('x_mode_terse_out','checked','ON','Generate free-space mode /x');
    ##my $embed_original = $cgi->checkbox('embed_original'  ,'checked','ON','Embed wordy as comments');
    
    my $wrap_in;
    #my $match_type = "<p>Regular expression will be used in:<br>"
    #      . $cgi->radio_group(
    #                -name=>'match_type',
    #                -values=>['Match','Match Repeatedly','Replace', 'Replace Repeatedly', 'Split'],
    #                -default=>'Match')
    #      . "<p>";
    
    return <<"EOF";
<form name ="wre" action="wre_resp" method="post">

    

    <br>
    Wordy
    $x_mode_tre_out$embed_original<br>
    <textarea name="wre" rows ="15" cols="80">$wre_box_content</textarea>
    
    <textarea name="results" rows ="15" cols="40">$results_box_content</textarea>
    <p>
    <input type="submit" name="chosen" value="Wordy to Terse" />
    <input type="submit" name="chosen" value="Match" />
    <input type="submit" name="chosen" value="Match Repeatedly" />
    <input type="submit" name="chosen" value="Replace" />
    <input type="submit" name="chosen" value="Replace Repeatedly" />
    <input type="submit" name="chosen" value="Split" />

    <br>
    Text
    <textarea name="text" rows ="2" cols="40">$text_box_content</textarea>
    Replace with
    <textarea name="replacement" rows ="2" cols="40">$replace_box_content</textarea>
    <br>
    Terse
    <textarea name="tre" rows ="10" cols="80">$tre_box_content</textarea>
    <br>
    
    <input type="submit" name="chosen" value="Terse to Wordy" />

    $x_mode_tre_in
    
</form>
EOF

    ## <input type="submit" name="Action" value="Shout" /><input type="submit" name="Action" value="Scream" />
    
    ##Action<br>
    ##<select name="action">
    ##    <option value="wre_to_tre" selected="selected">wordy to terse</option>
    ##    <option value="tre_to_wre">terse to wordy</option>
    ##</select>

#    <button name="BUTTON" value="wordy to terse">Wordy to Terse</button>
#    <button name="BUTTON" value="match">Match</button> 
#    <button name="BUTTON" value="match_repeatedly">Match Repeatedly</button>
#    <button name="BUTTON" value="replace">Replace</button>
#    <button name="BUTTON" value="replace_repeatedly">Replace Repeatedly</button>
#    <button name="BUTTON" value="split">Split</button> </p>
#    <button name="BUTTON" value="terse to wordy">Terse to Wordy</button>

#   <input type="submit" value="Submit" />
#   <p>before</p>
#   <input type="submit" name="chosen" value="Shout" /><input type="submit" name="chosen" value="Scream" />
#   <p>after</p>

}  
  sub create_wre_form {
    my $cgi = shift;   # CGI.pm object
    return if !ref $cgi;
    print $cgi->header,
        # $cgi->start_html("Hello"),
        "<!DOCTYPE HTML><html>",
        $cgi->head(css_head()),
        $cgi->h1("Hello, wre user!"),
        wre_form($cgi);
        $cgi->end_html;
  }
  
  sub resp_wre_form {
    # Handles the posted response from a wre form page
     my $cgi  = shift;   # CGI.pm object
     return if !ref $cgi;
     
     ## my $dump = YAML::XS::Dump $cgi;

     my $wre_in = $cgi->param('wre');
     my $tre_in  = $cgi->param('tre');
     my $chosen  = $cgi->param('chosen') || 'unknown';
     my $text_in = $cgi->param('text')   || '';
     my $x_mode_terse_in  = $cgi->param('x_mode_terse_in' ) || '';
     my $x_mode_terse_out = $cgi->param('x_mode_terse_out') || '';
     my $embed_original   = $cgi->param('embed_original') || '';
     my $new_wre = $wre_in;
     my $new_tre = $tre_in;
     my $new_results = '';
     
     my $response = "Internal error in wre_server";
     
     eval {
        if (lc $chosen eq "wordy to terse") {
            my $wre_obj = RegExp::Wre->new($wre_in,
                                           {
                                                free_space => $x_mode_terse_out,
                                                embed_original => $embed_original,
                                            }
                                           );
            $new_tre = "$wre_obj";
            # $response = no_flow("\n$wre_in converted\n\n$new_tre\n");
            $response = no_flow("wordy to terse OK\n");

        } elsif (lc $chosen eq "terse to wordy") {
            
            $new_wre = tre_to_wre($tre_in, $x_mode_terse_in ? 'x' : '');
            # $response = no_flow("$tre_in converted\n\n$new_wre\n");
            $response = no_flow("x_mode_terse: $x_mode_terse_in\nterse to wordy OK\n");
        } elsif (lc $chosen eq "match") {
            $response = "chose to do: $chosen";
            
            my $wre_obj = RegExp::Wre->new($wre_in,
                                            {
                                                free_space => $x_mode_terse_out,
                                                embed_original => $embed_original,
                                            }
                                           );
            my @results = $text_in =~ m/$wre_obj->{terse}/x;
            $new_tre = $wre_obj->{terse};
            if (scalar @results == 0) {
                # No matches
            } else {
                # Matched
                $new_results = join("\r\n", @results)
                             . "\r\nStart Positions:\r\n"
                             . join("\r\n", @-)
                             . "\r\nEnd Positions:\r\n"
                             . join("\r\n", @+)
                             ;
            }
            
        } elsif (lc $chosen eq "match repeatedly") {
            $response = "chose to do: $chosen";
        } elsif (lc $chosen eq "replace") {
            $response = "chose to do: $chosen";
        } elsif (lc $chosen eq "replace repeatedly") {
            $response = "chose to do: $chosen";
        } elsif (lc $chosen eq "split") {
            $response = "chose to do: $chosen";
        } else {
           $response = "Do not know what to do! chosen: $chosen"
           # Unimplemented action
        }
     };
     if ($@) {
        $response = "Internal error trapped: $@";
     }
     
     print $cgi->header,
           $response,
           wre_form($cgi, $new_wre, $new_tre, $new_results, $text_in),
           ## '<br><br>' . $cgi->p(no_flow($dump)),
           $cgi->end_html;
 }
 
  
  sub resp_form_generic {
     my $cgi  = shift;   # CGI.pm object
     return if !ref $cgi;
     
     ## my $dump = YAML::XS::Dump $cgi;
     my $who = $cgi->param('name');
     
     print  $cgi->header,
            $cgi->start_html("Hello"),
            $cgi->head(css_head()),
            $cgi->h1("Hello, test page user!"),
            $cgi->start_form,
            
            "<em>What's your name?</em><br>",
            $cgi->textfield('name'),
            $cgi->checkbox('Not my real name'),
 
            "<p><em>Where can you find English Sparrows?</em><br>",
            $cgi->checkbox_group(
                    -name=>'Sparrow locations',
                    -values=>['England','France','Spain','Asia','Hoboken'],
                    -linebreak=>'yes',
                    -defaults=>['England','Asia']),

            "<p><em>How far can they fly?</em><br>",
            $cgi->radio_group(
                    -name=>'how far',
                    -values=>['10 ft','1 mile','10 miles','real far'],
                    -default=>'1 mile'),
            "<p><em>What's your favourite color?</em>  ",
            $cgi->popup_menu(-name=>'Color',
                    -values=>['black','brown','red','yellow'],
                    -default=>'red'),
            $cgi->hidden('Reference','Monty Python and the Holy Grail'),

            "<p><em>What have you got there?</em><br>",
            $cgi->scrolling_list(
                    -name=>'possessions',
                    -values=>['A Coconut','A Grail','An Icon',
                              'A Sword','A Ticket'],
                    -size=>5,
                    -multiple=>'true'),

            "<p><em>Any parting comments?</em><br>",
            $cgi->textarea(-name=>'Comments',
                                  -rows=>10,
                                  -columns=>50),
            
            "<p>",
            "<table>",
            "<tr><th>Th-1</th><th>Th-2</th><th>Th-3</th></tr>",
            "<tr><td>cell-11</td><td>cell-12</td><td>cell-13</td></tr>",
            "<tr><td>cell-21xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</td><td>cell-22</td><td>cell-23</td></tr>",
            "</table>",
            $cgi->reset,
            $cgi->submit('Action','Shout'),
            $cgi->submit('Action','Scream'),
            $cgi->endform;
            ## $cgi->p(no_flow($dump)),
            $cgi->end_html;
 }

 sub ps {
    my ($txt) = @_;
    print STDERR "$txt\n";
 }
 
 } # end stuff inside package MyWebServer
 
 ##############################################################
 # start the server

 my $port = shift(@ARGV) || 5678;
 
 ##my $pid = MyWebServer->new($port)->background();
 my $server = MyWebServer->new($port);
 $server->run();
 ## print "Use 'kill $pid' to stop server.\n";



