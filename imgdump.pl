#!/usr/bin/perl -w

# imgdump
# cumbrumber
# created 1/25/2012
# modified 5/10/2012

use strict;
use warnings;
use threads;
use threads::shared;
use Tk;
use Tk::MainWindow;
use Tk::DHList;
use WWW::Mechanize;
use id_core;
use id_thread;
use id_store;
use id_params;
use Storable qw(nstore retrieve);

open STDERR, ">errorlog.txt" or die;
open STDOUT, ">errorlog.txt" or die;

my $prog_title  = "ImgDump V2.4";

# objects
my $mw; # main window
my ($fr1, $fr2, $fr3, $fr4, $fr5); # frames
my ($text, $url, $path, $name); # buttons and entry boxes
my ($listbox, $listbox2, $listbox3); # the listbox in $fr3

my $url_con;
my @links;
my $dest_list_index = 0;

my $name_entry;
my $viewtext = 1;

my $dest_path;
my @dest_list;

# gui tools
my $selected_thread = "NO";
my $packed_listbox = 1;
my $mode;
my $clock = id_core::clock->new();

my %params = @ARGV;
my %params_def = (
   -clock => {
      assign => \$clock->{_active},
      default => 0,
   },
   -mode => {
      assign => \$mode,
      default => 'main',
   },
);
id_params::assign(\%params, \%params_def);

$clock->start("startup");

# load bin_store.ids and build

# MODES:
# main has all threads and images in bin_store.ids
# sfw just has sfw threads
# nsfw just has nsfw threads (ones who's destination is store/nsfw/)
# net has whatever is in net_store.ids
my %id_stores = (
   main => id_store->new(),
   sfw  => id_store->new(),
   nsfw => id_store->new(),
   net  => id_store->new(),
);

if (-f 'bin_store.ids') {
   $id_stores{main} = ${retrieve('bin_store.ids')};
}
if (-f 'net_store.ids') {
   $id_stores{net} = ${retrieve('net_store.ids')};
}

print STDERR "imgdump 52: retrieved bin_store.ids for first time.\n";
print STDERR "imgdump 54: generating all xpms for first time.\n";

foreach my $thread (@{$id_stores{main}->{_store}}) {
   $thread->id_thread::generate_xpms();

   $id_stores{sfw}->id_store::add_thread(
      thread => $thread,
      mode => 'sfw',
   );
   $id_stores{nsfw}->id_store::add_thread(
      thread => $thread,
      mode => 'nsfw',
   );
}

if (-e "C:\\Windows") {
   $dest_path = "store\\";
   @dest_list = (
      "store\\",
      "store\\nsfw\\",
      "C:\\Users\\dankoz\\Pictures\\dump\\", 
      "C:\\Users\\dankoz\\Pictures\\", 
      "F:\\m\\b\\");
}
else {
   $dest_path = "store/";
   @dest_list = (
      "store/",  
      "store/nsfw/",
      "/home/dankoz/pictures/dump/",
      "/home/dankoz/pictures/",
      "/home/dankoz/",
      "/home/",
      "/");
}

# shared variables
share(@links); share($dest_path); share($url_con); share($name_entry);

# main execution
create_gui();

sub create_gui {
   $mw = new MainWindow(-title => $prog_title);
   $mw->geometry("725x560");
   my $icon = $mw->Pixmap(-file => "bulldog_pixmap.xpm");
   $mw->Icon(-image => $icon);

   # fr1 box
   $fr1 = $mw->Frame;
   $fr1->configure(-relief => 'raised', -borderwidth => 3);
   $fr1->pack(-expand => 0, -fill => 'x', -side => 'top');   
   
   # set up the labels and entry boxes.
   
   $url = $fr1->Entry(-width => 35, -justify => 'left');
   my $lbl = $fr1->Label( -text => 'enter the url');
   $lbl->pack($url, -side => 'left', -anchor => 'n');
   $url->pack(-expand => 1, -fill => 'x', -side => 'top', -anchor => 'w');
   $url->focus;
   $url->bind(
      "<Return>" => sub {
         $url_con = $url->get;
         parse_page()
      }
   );
   
   
   my $lbl3 = $fr1->Label( -text => 'name' );
   $name = $fr1->Entry(-width => 35, -justify => 'left');
   $name->configure(-textvar => $name_entry);
   $lbl3->pack($name, -in => $fr1, -anchor => 'nw', -side => 'left');
   $name->pack(-expand => 1, -fill => 'x');

   $path = $fr1->Entry(-width => 35, -justify => 'left');
   my $lbl2 = $fr1->Label( -text => 'destination' );
   $path->configure(-textvar => $dest_path);
   $lbl2->pack($path, -side => 'left', -anchor => 'nw', -after => $name);
   $path->pack(-expand => 1, -fill => 'x', -side => 'top');
   $path->bind("<Return>" => sub {change_dest()});
   $path->bind("<Up>" => sub {change_dest_up()});
   $path->bind("<Down>" => sub {change_dest_down()}); 


   # fr4 box
   $fr4 = $mw->Frame;
   $fr4->configure(-relief => 'raised', -borderwidth => 0);
   $fr4->pack(-expand => 0, -fill => 'x', -side => 'top');

   # BUTTON download 
   #
   #   download the images in webpage
   #
   my $download = $fr4->Button(-text => 'download', -takefocus => 1);
   $download->configure(
      -command => sub{
         $url_con = $url->get; 
         $dest_path = $path->get;
         $name_entry = $name->get;

#         id_core::parse_page(
#            url   => $url_con,
#            dest  => $dest_path,
#            name  => $name_entry,
#         );
         $id_stores{main}->download_images(
            url  => $url_con,
            dest => $dest_path,
            name => $name_entry,
         );
         $id_stores{main}->id_store::save();
      }
   );
   $download->pack(-side => 'right'); 

   # BUTTON apply changes
   #
   # saves the information from the input boxes to the selected thread
   #
   my $btn2 = $fr4->Button(-text => 'apply changes', -takefocus => 0);
   $btn2->configure(
      -command => sub{
         $url_con = $url->get; 
         $dest_path = $path->get;
         $name_entry = $name->get;

         my $index = $id_stores{main}->id_store::exists_in(
            thread_name => $selected_thread,
         );
         if (!defined $index) {
            return;
         }

         print STDERR "BUTTON apply changes: changing attributes for "
             . "thread [$selected_thread]\n"
             . "from:\n"
             . "  name->[$id_stores{main}->{_store}[$index]->{_name}]\n"
             . "  url ->[$id_stores{main}->{_store}[$index]->{_url}]\n"
             . "  dest->[$id_stores{main}->{_store}[$index]->{_dest}]\n"
             . "to:\n"
             . "  name->[$name_entry]\n"
             . "  url ->[$url_con]\n"
             . "  dest->[$dest_path]\n";
         print "BUTTON apply changes: changing attributes for "
             . "thread [$selected_thread]\n";

         $id_stores{main}->{_store}[$index]->{_name} = $name_entry;
         $id_stores{main}->{_store}[$index]->{_url} = $url_con;
         $id_stores{main}->{_store}[$index]->{_dest} = $dest_path;
      }
   );
   $btn2->pack(-side => 'right');

   # BUTTON back 
   # 
   # repacks listbox1
   #
   my $view_images = $fr4->Button(
      -text => 'back', 
      -takefocus => 0
   );
   $view_images->configure(
      -command => sub{
         $listbox2->packForget();
         $listbox->packForget();
         $listbox->pack(-expand => 1, -fill => 'both');
         $packed_listbox = 1;
      }
   );
   $view_images->pack(-side => 'left');

   # BUTTON refresh
   #
   # remove all listboxes and start from scratch
   # open bin_store.ids and update $id_stores{main}
   #
   my $images = $fr4->Button(-text => 'refresh', -takefocus => 0);
   $images->configure(
      -command => sub{

         $clock->start("refresh");

         print STDERR "imgdump 255: REFRESH rebuilding [$mode] store "
                    . "from bin_store.ids\n";
         print "BUTTON refresh: rebuilding [$mode] store "
             . "from bin_store.ids\n";

         # rebuild listbox
         if ($packed_listbox == 1) {

            # remove all the items in listbox
            $listbox->delete('all');

            # get rid of any other listboxes
#            $listbox->packForget();
#            $listbox2->packForget();
#            $listbox3->packForget();
#            $listbox->pack(-expand => 1, -fill => 'both');

#            $id_stores{$mode}->id_store::read_all(
#               mode => $mode,
#            );

            # add each thread name and op to listbox
            foreach my $thr (@{$id_stores{$mode}->{_store}}) {

               $thr->id_thread::generate_xpms(
                  fix_broken_xpms => 1,
               );
               $thr->id_thread::generate_thumbnails(
                  frame => $fr3,
                  fix_broken_xpms => 1,
                  index => 0,
               );

               id_core::addto_listbox(
                  thread  => $thr,
                  frame   => $fr3,
                  listbox => $listbox,
               ); 
            }
            $listbox->pack(-expand => 1, -fill => 'both');
         }
         # rebuild listbox2
         elsif ($packed_listbox == 2) {

#            $id_stores{$mode}->id_store::read_all(
#               mode => $mode,
#            );

            # find the thread we're in using $selected_thread
            my $index = $id_stores{$mode}->id_store::exists_in(
               thread_name => $selected_thread,
            );

            my $thread = $id_stores{$mode}->{_store}[$index];
            

#            $listbox2->packForget();
            $listbox2->delete('all');
#            $listbox2->pack(-expand => 1, -fill => 'both');
#            $packed_listbox = 2;

            $thread->id_thread::generate_xpms(
               fix_broken_xpms => 1,
            );
            $thread->id_thread::generate_thumbnails(
               frame => $fr3,
               fix_broken_thumbnails => 1,
            );

            id_core::addto_listbox(
               thread => $thread,
               frame => $fr3,
               listbox => $listbox2,
               all_images => 1,
            );
         }

         $clock->stop;
      }
   );
   $images->pack(-side => 'left');

   # BUTTON mode
   #
   # Change modes between sfw/main/nsfw/net
   #
   # sfw - use $id_stores{sfw} - only loads threads in store/
   # main - use $id_stores{main} - loads all threads from bin_store.ids
   # nsfw - use $id_stores{nsfw} - only loads threads in store/nsfw/
   # net - use $id_stores{net} - loads store from net_store.ids
   #
   my $content_mode = $fr4->Button(
      -text => 'mode', 
      -takefocus => 0
   );
   $content_mode->configure(
      -relief => 'raised',
      -command => sub{
         if ($mode =~ /^main/i) {
            print "NSFW MODE\n";
            $mode = 'nsfw';
         }
         elsif ($mode =~ /^nsfw/i) {
            print "NET MODE\n";
            $mode = 'net';
         }
         elsif ($mode =~ /^net/i) {
            print "SFW MODE\n";
            $mode = 'sfw';
         }
         elsif ($mode =~ /^sfw/i) {
            print "MAIN MODE\n";
            $mode = 'main';
         }
      }
   );
   $content_mode->pack(
      -fill => 'x',
      -side => 'left',
   );

   # FRAME button box
   my $fr2 = $mw->Frame;
   $fr2->pack( -fill => 'y', -side => 'right');
 
   # BUTTON server download
   #
   # sends parse_page command to id@itzaserver, requests net_store.ids
   # from id@itzaserver, requests xpms in net_store.ids from id@itzaserver
   #
   my $server_download = $fr2->Button(
      -text => 'server download', 
      -takefocus => 1
   );
   $server_download->configure(
      -relief => 'raised',
      -command => sub{
         print STDERR "imgdump BUTTON server download: sending download "
                    . "request to chat_server\n";
         print "BUTTON server download: sending download "
             . "request to chat_server\n";

         $url_con = $url->get; 
         $dest_path = $path->get;
         $name_entry = $name->get;

         my $cmd;
         if (-e "C:\\Windows") {
            $cmd = "C:\\Python27\\python.exe bin\\";
         }
         else {
            $cmd = 'python2.7 bin/';
         }

         $cmd .= "chat_client.py id_run.pl "
               . "-url $url_con "
               . "-dest $dest_path "
               . "-name $name_entry "
               . "-save_as net_store.ids";

         my $return = system($cmd);

         if ($return) {
            print STDERR "server error: $return";
            return;
         }

         if (-e "C:\\Windows") {
            $cmd = "C:\\Python27\\python.exe bin\\";
         }
         else {
            $cmd = 'python2.7 bin/';
         }
         $cmd .= "chat_client.py request_net_store";
         
         print STDERR "imgdump BUTTON server download: sending "
                    . "request_net_store\n";
         print "BUTTON server download: sending "
             . "request_net_store\n";

         $return = system($cmd);

         if ($return) {
            print STDERR "server error: $return";
            return;
         }

         $id_stores{net} = ${retrieve('net_store.ids')};
         $id_stores{net}->{_store}[0]->id_thread::generate_xpms(
            parse_names_only => 1,
         );
         $id_stores{main}->id_store::add_thread(
            thread => $id_stores{net}->{_store}[0],
         );

         $id_stores{main}->id_store::save(
            mode => 'data_dumper',
         );

         if (-e "C:\\Windows") {
            $cmd = "start C:\\Python27\\python.exe bin\\"
                 . "python bin/chat_client.py request_xpms "
                 . "@{$id_stores{net}->{_store}[0]->{_img_xpms}}";
         }
         else {
            $cmd = "python2.7 bin/chat_client.py request_xpms "
                 . "@{$id_stores{net}->{_store}[0]->{_img_xpms}} &";
         }
         
         print STDERR "imgdump BUTTON server download: sent command:\n"
                    . $cmd . "\n"
                    . "imgdump BUTTON server download: getting [" 
                    . ($#{$id_stores{net}->{_store}[0]->{_img_xpms}} + 1) 
                    . "] xpms\n";
         print "BUTTON server download: recieving [";
         print ($#{$id_stores{net}->{_store}[0]->{_img_xpms}} + 1); 
         print "] xpms from server\n";

         $return = system($cmd);

         if ($return) {
            print STDERR "server error: $return";
            return;
         }
      }
   );
#   $server_download->pack(
#      -fill => 'x',
#      -side => 'top'
#   );

   # BUTTON get xpms
   my $list_links = $fr2->Button(-text => 'get xpms', -takefocus => 0);
   $list_links->configure(
      -relief => 'raised',
      -command => sub{
         my $index = $id_stores{$mode}->id_store::exists_in(
            thread_name => $selected_thread,
         );

         my @index_list;
         my $xpm_index = 0;
         foreach my $name 
               (@{$id_stores{$mode}->{_store}[$index]->{_img_xpms}}) {

            if ($name =~ /bulldog_pixmap\.xpm/ 
                  || !defined
      $id_stores{$mode}->{_store}[$index]->{_thumbnails}[$xpm_index]) {

               push(@index_list, $xpm_index);
            }
            $xpm_index++;
         }

         $id_stores{$mode}->{_store}[$index]->{_img_xpms} = undef;
         $id_stores{$mode}->{_store}[$index]->id_thread::generate_xpms(
            parse_names_only => 1,
         );

         my @xpm_list;
         foreach my $xpm_index (@index_list) {
            push(@xpm_list, 
              $id_stores{$mode}->{_store}[$index]->{_img_xpms}[$xpm_index]);
         }
         
         my $cmd;
         if (-e "C:\\Windows") {
            $cmd = "start C:\\Python27\\python.exe bin\\"
                 . "chat_client.py request_xpms @xpm_list";
         }
         else {
            $cmd = 'python2.7 bin/';
            $cmd .= "chat_client.py request_xpms @xpm_list &";
         }
         

         print STDERR "imgdump BUTTON server download: running command\n"
                    . $cmd."\n";

         if (scalar(@xpm_list) > 0) {
            system($cmd);        
            print "getting all xpms for thread [$selected_thread] from "
                . "server\n";
         }
         else {
            print "already have all the xpms for thread "
                . "[$selected_thread]\n";
         }
      }
   );
#   $list_links->pack(
#      -fill => 'x'
#   );

   # BUTTON get images
   my $btn8 = $fr2->Button(-text => 'get images', -takefocus => 0);
   $btn8->configure(
      -relief => 'raised',
      -command => sub{
         my $index = $id_stores{$mode}->id_store::exists_in(
            thread_name => $selected_thread,
         );
         
         my $cmd;
         if (-e "C:\\Windows") {
            $cmd = "start C:\\Python27\\python.exe bin\\"
                 . "chat_client.py request_xpms "
                 . "@{$id_stores{$mode}->{_store}[$index]->{_img_names}}";
         }
         else {
            $cmd = "python2.7 bin/chat_client.py request_xpms "
               . "@{$id_stores{$mode}->{_store}[$index]->{_img_names}} &";
         }

         print STDERR "imgdump BUTTON get images: running command\n"
                    . $cmd."\n";
         system($cmd);        
         print "getting all images for thread [$selected_thread] from "
             . "server\n";
      }
   );
#   $btn8->pack(
#      -fill => 'x'
#   );

   # BUTTON open 
   #
   # opens the image selected with the default software
   # if the image isn't found on the local machine get it from server.
   #
   my $change_path = $fr2->Button(-text => 'open', -takefocus => 0);
   $change_path->configure(
      -relief => 'raised',
      -command => sub{
         print STDERR "imgdump BUTTON open: opening image with "
                    . "default sofware\n";
         
         my $image_name = $listbox2->getcurselection_text();
         $image_name = id_params::fix_path($image_name);

         if (!-f $image_name) {
            print STDERR "imgdump 507: image [$image_name] not found on "
                       . "local machine. requesting image from server\n";

            print "getting image from server\n";
            my $cmd;
            if (-e "C:\\Windows") {
               $cmd = "C:\\Python27\\python.exe bin\\";
            }
            else {
               $cmd = 'python2.7 bin/';
            }
            $cmd .= "chat_client.py request_xpms $image_name";
   
            print STDERR "imgdump BUTTON open: [cmd] '$cmd'\n";
            system($cmd); 
            sleep(.1);
         }

         # if on windows make sure we use the right file seperator
         my $return;
         if (-e "C:\\Windows") {
            $return = system("$image_name");
         }
         elsif (-e "/usr/bin/eog") {
            $return = system("eog $image_name &");
         }
         elsif (-e "/usr/bin/kde-open") {
            $return = system("kde-open $image_name &");
         }
         elsif (-e "/usr/bin/gnome-open") {
            $return = system("gnome-open $image_name &");
         }
         elsif (-e "/usr/bin/mate-open") {
	    $return = system("mate-open $image_name &");
         }

         print STDERR "imgdump BUTTON open: [cmd] '$image_name' returned: ["
                    . "$return]\n"
      }
   );
   $change_path->pack(-fill => 'x');

   # BUTTON post
   #
   # post the selected image in the thread specified in url bar
   #
   my $post_single = $fr2->Button(-text => 'post', -takefocus => 0);
   $post_single->configure(
      -relief => 'raised',
      -command => sub{
         print STDERR "imgdump BUTTON post: posting image\n";
         
         my $image_name = $listbox2->getcurselection_text();
         $image_name = id_params::fix_path($image_name);

         if (!-f $image_name) {
            print STDERR "imgdump 658: image [$image_name] not found on "
                       . "local machine. requesting image from server\n";

            print "getting image from server\n";
            my $cmd;
            if (-e "C:\\Windows") {
               $cmd = "C:\\Python27\\python.exe bin\\";
            }
            else {
               $cmd = 'python2.7 bin/';
            }
            $cmd .= "chat_client.py request_xpms $image_name";
   
            print STDERR "imgdump BUTTON post: [cmd] '$cmd'\n";
            my $return = system($cmd); 
            
            if ($return) {
               print STDERR "server error: $return";
               return;
            }
            sleep(.1);
         }

         my $challenge = id_core::display_captcha();
         my $vericode;

         my $posting_window = $mw->Toplevel;
         my $mw_position = $mw->geometry;
         $mw_position =~ s/\d+x\d+//;
         if ($mw_position =~ /(.)(\d+)(.)(\d+)/) {
            $mw_position = $1 . ($2 + 105) . $3 . ($4 + 130);
         }
         $posting_window->geometry($mw_position);
         system("convert captcha.jpg captcha.xpm");
         my $display_frame = $posting_window->Frame;
         my $c_image = $display_frame->Pixmap(-file => 'captcha.xpm');
         $display_frame->pack;

         my $c_listbox = $display_frame->Scrolled('DHList',
            -scrollbars => '',
            -relief     => 'sunken',
            -borderwidth => '2',
            -width => '39',
            -height => '4',
            -background => 'white',
            -databackground => 'white',
            -selectmode => 'browse',
            -viewtype => 'withdata',
            -numeric_primary_sort => '1',
            -numeric_secondary_sort => '1',
         );
         $c_listbox->add(
            "captcha",
            -itemtype => 'imagetext',
            -data => " ",
            -itemtype => 'imagetext',
            -text => " ",
            -image => $c_image,
         );
         $c_listbox->pack;

         $posting_window->Label(-text => 'enter captcha:')->pack;
         $posting_window->focus;
         my $captcha_entry = $posting_window->Entry(-width => 39);
         $captcha_entry->pack;
         $captcha_entry->focus;
         $captcha_entry->bind(
            "<Return>" => sub {
               $vericode = $captcha_entry->get;
               print $vericode . "\n";
               $posting_window->withdraw;
               id_core::submit_post(
                  url => $url->get,
                  recaptcha_challenge => $challenge,
                  recapthca_response => $vericode,
                  image => $image_name,
               );
            },
         );
      }
   );
#   $post_single->pack(-fill => 'x');

   # BUTTON dump to disk
   my $data_dump = $fr2->Button(-text => 'dump to disk', -takefocus => 0);
   $data_dump->configure(
      -relief => 'raised',
      -command => sub{
         print STDERR "imgdump BUTTON dump to disk: saving main store to "
                    . "disk with Storable::store function\n";
         print "BUTTON dump to disk: saving main store to "
             . "bin_store.ids\n";
         $id_stores{main}->id_store::save(
            mode => 'data_dumper',
         );
      }
   );
   $data_dump->pack(
      -fill => 'x',
      -side => 'bottom',
   );

   # BUTTON print store
   #
   # print the short version of store.ids to STDOUT
   #
   my $getpage = $fr2->Button(-text => 'print store', -takefocus => 0);
   $getpage->configure(-relief => 'raised');
   $getpage->pack(-fill => 'x', -side => 'bottom');
   $getpage->configure(
      -command => sub {
         $id_stores{main}->id_store::print_all(spacing => 2);

         my $test_path = "\/this\/is\/a\/test_path.test\/";
         print "original path: [$test_path]\n";

         $test_path = id_params::fix_path($test_path);
         print "new_path: [$test_path]\n";

         $test_path = "this\\is\\a\\test_path.test\\";
         print "original path: [$test_path]\n";

         $test_path = id_params::fix_path($test_path);
         print "new_path: [$test_path]\n";

         $test_path = "this\\is\\a\\test_path.test";
         print "original path: [$test_path]\n";

         $test_path = id_params::fix_path($test_path);
         print "new_path: [$test_path]\n";


      }
   );

   # BUTTON 
   my $clock_subs = $fr2->Button(-text => 'clock subs', -takefocus => 0);
   $clock_subs->configure(
      -relief => 'raised',
      -command => sub{
         if (!$clock->{_active}) {
            print STDERR "imgdump BUTTON clock subs: logging time taken for "
                       . " each button press\n";
            print "BUTTON clock subs: ON\nlogging time taken for each button "
                . "press\n";
            $clock->{_active} = 1;
         }
         else {
            print STDERR "imgdump BUTTON clock subs: done logging time "
                       . "taken for each button press\n";
            print "BUTTON clock subs: OFF ";
            $clock->{_active} = 0;
         }
      }
   );
   $clock_subs->pack(
      -fill => 'x',
      -side => 'bottom',
   );

   # FRAME listbox 
   $fr3 = $mw->Frame;
   $fr3->pack(-expand => 1, -fill => 'both', -side => 'top');

   # now that we have the frame generate the thumbnail objects.
   foreach my $thread (@{$id_stores{main}->{_store}}) {
      $thread->id_thread::generate_thumbnails(
         frame => $fr3,
      );

      my $index = $id_stores{sfw}->id_store::exists_in(thread => $thread);
      if (defined $index) {
         @{$id_stores{sfw}->{_store}[$index]->{_thumbnails}} = 
               @{$thread->{_thumbnails}};
      }
      my $index2 = $id_stores{nsfw}->id_store::exists_in(thread => $thread);
      if (defined $index2) {
         @{$id_stores{nsfw}->{_store}[$index2]->{_thumbnails}} = 
               @{$thread->{_thumbnails}};
      }
   }
   foreach my $thread (@{$id_stores{net}->{_store}}) {
      $thread->id_thread::generate_thumbnails(
         frame => $fr3,
      );
   }

   print STDERR "imgdump 329: generated thumbnails for all threads\n";


   # list box for all threads
   $listbox = $fr3->Scrolled('DHList',
      -scrollbars => 'e',
      -relief     => 'sunken',
      -borderwidth => '2',
      -width => '600',
      -height => '15',
      -background => 'white',
      -databackground => 'white',
      -selectmode => 'browse',
      -sizecmd => \&size_cb,
      -viewtype => 'withdata',
      -numeric_primary_sort => '1',
      -numeric_secondary_sort => '1',
   );

   $listbox->bind('<Button-1>',

      # unpack the main list showing all threads and build
      # the list for an individual thread
      sub{

         my $item_name = $listbox->getcurselection_text();

         # this is for the double-click function
         if ($selected_thread eq $item_name) {

            my $index = $id_stores{$mode}->id_store::exists_in(
               thread_name => $item_name,
            );

            my $thread = $id_stores{$mode}->{_store}[$index];
            $listbox->packForget();

            # fill the entry boxes with the thread info
            $path->configure(-textvar => $thread->{_dest});
            $url->configure(-textvar => $thread->{_url});
            $name->configure(-textvar => $thread->{_name});

            $listbox2->delete('all');
            $listbox2->pack(-expand => 1, -fill => 'both');
            $packed_listbox = 2;

#            $thread->id_thread::generate_xpms(
#               fix_broken_xpms => 1,
#            );
#            $thread->id_thread::generate_thumbnails(
#               frame => $fr3,
#               fix_broken_thumbnails => 1,
#            );

            id_core::addto_listbox(
               thread => $thread,
               frame => $fr3,
               listbox => $listbox2,
               all_images => 1,
            );
         }
         else {
            $selected_thread = $item_name;
         }
      },
   );

   $listbox->pack(-expand => 1, -fill => 'both');


   # this listbox is for individual threads
   $listbox2 = $fr3->Scrolled('DHList',
      -scrollbars => 'e',
      -relief     => 'sunken',
      -borderwidth => '2',
      -width => '600',
      -height => '15',
      -background => 'white',
      -databackground => 'white',
      -selectmode => 'browse',
      -sizecmd => \&size_cb,
      -viewtype => 'withdata',
      -numeric_primary_sort => '1',
      -numeric_secondary_sort => '1',
   );

   $listbox2->bind('<Button-1>',

      # get the image that was selected and make it big
      sub{

#         my $image_name = $listbox2->getcurselection_text();

#         $listbox2->packForget();
#         $listbox3->delete('all');
#         $listbox3->pack(-expand => 1, -fill => 'both');

#         id_core::addto_listbox(
#            frame        => $fr3,
#            listbox      => $listbox3,
#            single_image => $image_name,
#         );
#         print STDERR "imgdump 300: selected image [$image_name] \n";


      },
   );

   # this listbox is for individual threads
   $listbox3 = $fr3->Scrolled('DHList',
      -scrollbars => 'e',
      -relief     => 'sunken',
      -borderwidth => '2',
      -width => '600',
      -height => '15',
      -background => 'white',
      -databackground => 'white',
      -selectmode => 'single',
      -sizecmd => \&size_cb,
      -viewtype => 'withdata',
      -numeric_primary_sort => '1',
      -numeric_secondary_sort => '1',
   );

   # populate the listbox for the first time. every time after this
   # it will be done by refresh button
   foreach my $thr (@{$id_stores{$mode}->{_store}}) {
      id_core::addto_listbox(
         thread  => $thr,
         frame   => $fr3,
         listbox => $listbox,
      );      

   }

   $fr5 = $mw->Frame;
   $fr5->pack(-expand => 0, -fill => 'both', -side => 'top');

   # box for text
   $text = $fr5->Text(-takefocus => 0);
   $text->configure(-height => 5);
   $text->pack(-expand => 0, -fill => 'both',);
   tie *STDOUT, ref $text, $text;


  
#   print "                       __,-----._                       ,-. 
#                    ,'   ,-.    \\`---.          ,-----<._/ 
#                   (,.-. o:.`    )),\"\\\\-._    ,'         `. 
#                  ('\"-` .\\       \\`:_ )\\  `-;'-._          \\ 
#                 ,,-.    \\` ;  :  \\( `-'     ) -._     :   `: 
#                (    \\ `._\\\\ ` ;             ;    `    :    ) 
#                 \\`.  `-.    __   ,         /  \\        ;, ( 
#                  `.`-.___--'  `-          /    ;     | :   | 
#                    `-' `-.`--._          '           ;     | 
#                          (`--._`.                ;   /\\    | 
#                           \\     '                \\  ,  )   : 
#                           |  `--::----            \\'   ;  ;| 
#                           \\    .__,-      (        )   :  :| 
#                            \\    : `------; \\      |    |   ; 
#                             \\   :       / , )     |    |  ( 
#                    -hrr-     \\   \\      `-^-|     |   / , ,\\ 
#                               )  )          | -^- ;   `-^-^' 
#                            _,' _ ;          |    | 
#                           / , , ,'         /---. : 
#                           `-^-^'          (  :  :,' 
#                                            `-^--' \n"
#." -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=IMAGE-DUMP-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
   
   $clock->stop;
   MainLoop;
}

sub change_dest {
   $dest_path = $path->get;
   $dest_list_index = 0;
   
   # add new destination to dest_list

   if ($dest_path ne $dest_list[0]) {
      unshift (@dest_list, $dest_path);
   }   
   
   #if destination has a space then a word on the end
   if ($dest_path =~ /.*\s+\w+$/) {
   
      # look in the pictures directory
      if ($dest_path =~ /(.*)\s+dir$/) {
         my $in = $1; 
         if ($in !~ m/.*[\\|\/]$/ && $in =~ m/.*([\\|\/]).*/) {
            $in .= $1;
         }

         opendir (DIR, $in) or die $!;
         my @out = readdir(DIR);
         my $printing = "";
         
         print "-----[$in]-----\n";
         foreach my $line (@out) {
            if ($line =~ /^\w+$/) {
               $printing .= "$line   ";
            }
         }
         print $printing."\n";
         $path->configure(-textvar => $in);
         $dest_path = $in;
         close DIR;
      }
   } 
   
   # there's no command given. change the dir.
   elsif ($dest_path =~ /\w+\S+\w+/) {
      
      # check for \ or / on the end
      if ($dest_path !~ m/.*[\\|\/]$/ && $dest_path =~ m/.*([\\|\/]).*/) {
         $dest_path .= $1;
      }
      
      if (!-e $dest_path) {
         system("mkdir $dest_path");
         
         print "created path [$dest_path]\n";
      }
      print "path changed to [$dest_path]\n";

      $path->configure(-textvar => $dest_path);
   }
   $path->SetCursor("end");
}

sub change_dest_up {
   if ($dest_list_index != $#dest_list) {
      $dest_list_index++;
   }
   
   $path->configure(-textvar => $dest_list[$dest_list_index]);
   $path->SetCursor("end");
}

sub change_dest_down {
   if ($dest_list_index != 0) {
      $dest_list_index--;
   }
   
   $path->configure(-textvar => $dest_list[$dest_list_index]);
   $path->SetCursor("end");
}

sub size_cb {
#   print "we have resized\n";
}
