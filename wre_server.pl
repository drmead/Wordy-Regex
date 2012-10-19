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
 
 my %dispatch = (

     '/wre'      => \&create_wre_form,
     '/wre_resp' => \&resp_wre_form,
     # ...
 );


sub wre_form {
    my ($wre_box_content_parm, $tre_box_content_parm) = @_;
    my $wre_box_content = $wre_box_content_parm || '?';
    my $tre_box_content = $tre_box_content_parm || '??';
    return <<"EOF";
<form name ="wre" action="wre_resp" method="post">
    Action
    <select name="action">
        <option value="wre_to_tre" selected="selected">wordy to terse</option>
        <option value="tre_to_wre">terse to wordy</option>
    </select>
    <br>
    Wordy
    <textarea name="wre">$wre_box_content</textarea>
    <br>
    Terse
    <textarea name="tre">$tre_box_content</textarea>
    <br>
    <input type="submit" value="Submit" />
</form>
EOF
}

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
        wre_form();
        $cgi->end_html;
  }
  
  sub resp_wre_form {
     my $cgi  = shift;   # CGI.pm object
     return if !ref $cgi;
     
     my $dump = YAML::XS::Dump $cgi;
     my $action = $cgi->param('action') || 'no action';
     my $wre_in = $cgi->param('wre');
     my $tre_in  = $cgi->param('tre');
     
     my $new_wre = $wre_in;
     my $new_tre = 'not supplied tre';
     
     my $response = "Internal error in wre_server";
     
     eval {
        if ($action eq "no action") {
            $response = "OK\n"
        } elsif ($action eq "wre_to_tre") {
                my $wre_obj = RegExp::Wre->new($wre_in);
                $new_tre = "$wre_obj";
                $response = no_flow("\n$wre_in converted\n\n$new_tre\n");

        } elsif ($action eq "tre_to_wre") {
           
           $response = '$tre_in converted';

        } else {
           $response = "Unimplemented action: $action"
           # Unimplemented action
        }
     };
     if ($@) {
        $response = "Internal error trapped: $@";
     }
     
     print $cgi->header,
           $response,
           '<br><br>' . $cgi->p(no_flow($dump)),
           wre_form($new_wre, $new_tre),
           $cgi->end_html;
 }
 
  
  sub resp_form_generic {
     my $cgi  = shift;   # CGI.pm object
     return if !ref $cgi;
     
     my $dump = YAML::XS::Dump $cgi;
     my $who = $cgi->param('name');
     
     print $cgi->header,
           $cgi->start_html("Hello"),
           $cgi->head(css_head()),
           $cgi->h1("Hello, form user!"),
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



