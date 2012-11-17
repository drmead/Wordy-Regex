#!/usr/bin/perl
use strict;
use warnings;
use YAML::XS;
use lib "../Regexp";
use RegExp::Wre qw(wre wret _wre_to_tre);

use 5.014;
 {
 package MyWebServer;
 
 use HTTP::Server::Simple::CGI;
 use base qw(HTTP::Server::Simple::CGI);
 use RegExp::Tre2Wre qw( tre_to_wre ); 
 my %dispatch = (
     '/'         => \&create_wre_form,
     '/wre'      => \&create_wre_form,
     '/wre_resp' => \&resp_wre_form,
     '/test'     => \&resp_form_generic,
     # ...
 );


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
        
    my $x_mode_tre_in  = $cgi->checkbox('x_mode_terse_in' ,'checked','ON','X mode terse in');
    my $x_mode_tre_out = $cgi->checkbox('x_mode_terse_out','checked','ON','Generate free-space mode /x');
    my $embed_original = $cgi->checkbox('embed_original'  ,'checked','ON','Embed wordy as comments');
    
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
    my $css = <<'EOF';
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
td { border: 1px solid #666666; }
th { border: 1px solid #111111; }
-->
</style>
</head>
EOF

 return $css;
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
     
     my $dump = YAML::XS::Dump $cgi;

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
           '<br><br>' . $cgi->p(no_flow($dump)),
           $cgi->end_html;
 }
 
  
  sub resp_form_generic {
     my $cgi  = shift;   # CGI.pm object
     return if !ref $cgi;
     
     my $dump = YAML::XS::Dump $cgi;
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
            $cgi->p(no_flow($dump)),
            $cgi->end_html;
 }
 
 
 } # end stuff inside package MyWebServer
 
 ##############################################################
 # start the server

 my $port = shift(@ARGV) || 5678;
 
 ##my $pid = MyWebServer->new($port)->background();
 my $server = MyWebServer->new($port);
 $server->run();
 ## print "Use 'kill $pid' to stop server.\n";



