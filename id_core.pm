package id_core;

use strict;
use warnings;
use WWW::Mechanize;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use id_params;
use id_thread;
use id_store;
use Try::Tiny;
use Tk::DHList;
use Image::Xpm;

$VERSION     = 1.01;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(parse_page get_img);

sub get_img {
   
   my $thread2;
   my $thread_ref;
   my $dest_path;
   my $no_mkdir2;
   my $links_ref2;
   my @links2;
   my $save_as;

   my %params = @_;
   my %params_def = (
      dest => {
         assign => \$dest_path,
         required => 1,
         default  => "store/",
      },
      links_ref => {
         assign => \$links_ref2,
         required => 1,
      },
      no_mkdir => {
         assign  => \$no_mkdir2,
         default => 0,
      },
      id_thread => {
         assign => \$thread2,
         type   => 'id_thread',
      },
      save_as => {
         assign => \$save_as,
      },
   );

   id_params::assign(\%params, \%params_def);

   # if dest doesn't end with / give it one
   if ((!-e "C:\\") && ($dest_path !~ /.*\/$/)) {
      $dest_path .= '/';
   }
   
   $thread2->id_thread::dest($dest_path);

   # if the dir doesn't exist make it
   if (!-e $dest_path) {

      if ($no_mkdir2 == 1) {
         print "dir not found. can't make dir\n";
         return;
      }
      else {
         system("mkdir $dest_path");
         print "mkdir made dir $dest_path\n";
         if (!-e $dest_path) {
            print "mkdir failed to create path $dest_path\n";
            return;
         }
      }
   }

   my $img_count  = 0;
   my $save_count = 0;
   my $percent    = 0;

   my $mech = WWW::Mechanize->new();

   foreach my $link (@{$links_ref2}) {
      $img_count++;      
 
      # get the image name out of each link
      if ($link =~ m/.*\/(\d+\..*)/) {

         my $filename = $dest_path . $1;
         my $filenameonly = $1;
         
         if (!$thread2->id_thread::img_exists($filename) && (!-f $filename)) {

            # save the image to disk
            try { $mech->get($link) };

               

            my $next = 0;
            try { $mech->save_content($filename) }
            catch {$next = 1};
	         next if $next;

            # get the thumbnail and store it as xpm

            # resize the image, convert to xpm and store
            if (-f $filename && ($filenameonly =~ /(\w+)\.(.*)/)) {
	
               if (-e "C:\\Windows") {
                  system(
                     "bin\\ImageMagick-6.7.7-5\\convert.exe -size 100x100 "
                   . "$filename -resize 100x100 "
                   . "+profile '*' -delete 1-1000 temp\/$1\.xpm"
                  );
               }
	       else {
                  system("convert -size 100x100 $filename -resize 100x100 "
                       . "+profile '*' -delete 1-1000 temp\/$1\.xpm");
               }

               print STDERR "id_core::get_img 120:[cmd] convert "
                          . "-size 100x100 $filename -resize 100x100 "
                          . "-delete 1-1000 temp\/$1\.xpm\n";

               my $img = Image::Xpm->new(-file, "temp\/$1\.xpm") or die;
               $img->set(width => 100);
               $img->save("temp\/$1\.xpm");
               $thread2->id_thread::img_xpms("temp\/$2\.xpm");
            }

            $thread2->id_thread::img_links($link);
            $thread2->id_thread::img_names($filename); 

            $save_count++;
         }   
         while ($img_count/($#{$links_ref2}+1) >= $percent/50)  {
            $percent++;

         }
      }
   }# end of the foreach loop

   $thread2->id_thread::img_count($save_count);
   $thread2->id_thread::generate_xpms();

   if (defined $save_as) {
      my $single_thread_store = new id_store();
      $single_thread_store->id_store::add_thread(
         thread => $thread2,
      );
      if ($save_as =~ /net_store\.ids/) {
         $single_thread_store->id_store::save(
            mode => 'data_dumper',
            filename => $save_as,
            remove_xpms => 0,
         );
      }
      else {
         $single_thread_store->id_store::save(
            mode => 'data_dumper',
            filename => $save_as,
         );
      }
   }

   my $thread_store = new id_store();
   $thread_store->read_all();
   $thread_store->add_thread(
      thread => $thread2,
   );
   $thread_store->save(
      mode => 'data_dumper'
   );

   print "\n$img_count/".($#{$links_ref2}+1);
   print "\nimages in [$dest_path]\n";
   print "$save_count new images saved\n";
   
   return;
}# end of get_img sub


# ----- parse_page
# INPUTS
#
#   parse_page(
#      url  => string,
#      dest => string,
#      name => string,
#      no_mkdir => bool,
#      no_download => bool,
#   );
#
#      url     - page to download          - string - required
#      dest    - directory to save images  - string - required 
#                                                     optional if 
#                                                     no_download = 1
#      name    - name to give thread       - string - required
#      no_mkdir       -                    - bool   - optional 
#                                                     default 0
#      no_download - don't call get_dir    - bool   - optional 
#                                                     default 0
#      save_as - filename to save store    - string - optional
#                you can save a store to disk containing
#                only the newly downloaded thread object.
#                net_store.ids is used for transfering
#                new thread info to/from clients
#
sub parse_page {

   my $thread = new id_thread();

   my $url;
   my $dest;
   my $name;
   my $no_mkdir;
   my $no_download;
   my @links; 
   my $links;
   my $save_as;

   my %params = @_;
   my %params_def = (
      url => {
         assign   => \$url,
         required => 1,
      },
      dest => {
         assign   => \$dest,
         default  => "store/",
      },
      name => {
         assign   => \$name,
         default  => 'default',
      },
      no_mkdir => {
         assign   => \$no_mkdir,
         default  => 0,
      },
      no_download => {
         assign   => \$no_download,
         default  => 0,
      },
      save_as => {
         assign => \$save_as,
      }
   );

   id_params::assign(\%params, \%params_def);

   # keep the thread info for later
   $thread->id_thread::url($url);
   $thread->id_thread::name($name);

   print "attempting to view index from [$url]\n";

   my $mech = WWW::Mechanize->new(autocheck => 0);

   # check that url is defined
   if($url) {
      $mech->get($url);
   }
   else {
      print "url not defined, exiting\n";
      exit;
   }

   # check that page exists
   if ($url && $mech->status() == 200) {

      print "--->got the page\n";

      my @all_links = $mech->find_all_links(text_regex => qr/\d+/, url_regex => qr/(.*images\.4chan\.org.*|.*7chan\.org.*\/\d+\..*)/);

      # parse the page and get op's post text
      my @thread_lines = $mech->forms();
     
      my $i = 0;
      my $j = 0;
      while (defined($all_links[$i])) {
         my $link = $all_links[$i]->url;
         if (!defined($all_links[$i+1]) or $link ne $all_links[$i+1]->url) {
         
            # windows doesn't like the '//' at the begining of all the links
            # doesn't really make any sense why there's no http: there
            if ($link !~ m/^(http:).*$/) {
               $links[$j] = "http:" . $link;
            }
            else {
               $links[$j] = $link;
            }
            $j++;
         }      
         $i++;
      }
      print "found [$j] images\n";


      if ($ no_download == 1) {
         return @links;
      }
      else {
         get_img(
            dest      => $dest,
            no_mkdir  => $no_mkdir,
            links_ref => \@links,
            id_thread => $thread,
            save_as   => $save_as,
         );
      }
   }
   else {
      print "404 not found\n";
      return;
   }
   return;

}# end of parse_page sub

# ----- addto_listbox
#
#   addto_listbox(
#      thread => thread_object,
#      frame  => frame_object,
#      listbox => listbox_object,
#      all_images => bool,
#   );
#
#
sub addto_listbox {
   my %params = @_;

   my $thr;
   my $frame;
   my $listbox;
   my $all_images;
   my $single_image;

   my %params_def = (
      thread => {
         assign => \$thr,
      },
      frame  => {
         assign => \$frame,
      },
      listbox => {
         assign => \$listbox,
      },
      all_images => {
         assign  => \$all_images,
         default => 0,
      },
      single_image => {
         assign  => \$single_image,
         default => 0,
      },
   );

   id_params::assign(\%params, \%params_def);


   # if a thread is given we will add the first image in the thread
   # and the name of the thread
   if (defined $thr && !$all_images && !$single_image) {
     
      my $thumbnail;

      if (defined $thr->{_img_xpms} 
               && defined $thr->{_thumbnails}[0]) {
         $thumbnail = $thr->{_thumbnails}[0];
      }
      else {
         print STDERR "id_core::addto_listbox 366: couldn't find op's "
                    . "thumbnail in \$thr->{_thumbnails}[0] for thread "
                    . "[$thr->{_name}]\n";
         $thumbnail = $frame->Pixmap(
            -file => 'bulldog_pixmap.xpm',
         );
      }

      try {
         $listbox->add(
            $thr->{_name},
            -itemtype => 'imagetext',
            -data => "img_count: ".$thr->id_thread::img_count()."\n"
                   . ${$thr->img_names()}[0]."   ",
            -itemtype => 'imagetext',
            -text => $thr->{_name},
            -image => $thumbnail,
         );
      };
   }
   
   # in this case we will be adding each image in the thread to 
   # the listbox
   elsif (defined $thr && $all_images) {

      my @indexes = (0..($thr->id_thread::img_count - 1));

      foreach my $index (@indexes) {

         if (!defined $thr->{_thumbnails}[$index]) {
            $thr->{_thumbnails}[$index] = $frame->Pixmap(
               -file => 'bulldog_pixmap.xpm',
            );
         }

         $listbox->add(
            $index,
            -itemtype => 'imagetext',
            -data => "[". ($index + 1) ."/".$thr->id_thread::img_count()."]\n",
            -itemtype => 'imagetext',
            -text => $thr->{_img_names}[$index],
            -image => $thr->{_thumbnails}[$index],
         ) or print STDERR "id_core::addto_listbox 395: listbox->add "
                         . "failed on image "
                         . "[$thr->{_thumbnails}[$index]]\n";
      }
   }
   elsif (defined $thr && $single_image) {

      print STDERR "id_core::addto_listbox 402: got this far\n";

      $thr->id_thread::generate_xpms(
         single_image => $single_image,
      );
   }
} 

# ----- display_captcha
# 
# get a captcha image from google, save to captcha.jpg,
# return the challenge string associated with the image.
#
sub display_captcha {
   my %params = @_;

   my $captcha_entry;

   my $captcha_url = "http://www.google.com/recaptcha/api/challenge?k="
      . "6Ldp2bsSAAAAAAJ5uyx_lx34lJeEpTLVkP5k04qc";
   my $command = "curl $captcha_url --progress-bar -s -S -f";
   my $output = `$command`;
   return if $?;

   my ($challenge) = ($output =~ m/challenge : '(.*)',/);
   my $outfile = "captcha.jpg";
   
   $captcha_url = "http://www.google.com/recaptcha/api/image?c="
      . $challenge . " -o $outfile";
   $command = "curl $captcha_url --progress-bar -s -S -f";
   $output =  `$command`;
   return if $?;

   print STDOUT "got the captcha\n";

#   system("display $outfile &> /dev/null &");
   
   return $challenge;
}

sub submit_post {
   my %params = @_;

   my $url;
   my $comment;
   my $challenge;
   my $vericode;
   my $image;

   my %params_def = (
      url => {
         assign => \$url,
      },
      comment => {
         assign => \$comment,
      },
      recaptcha_challenge => {
         assign => \$challenge,
      },
      recaptcha_response => {
         assign => \$vericode,
      },
      image => {
         assign => \$image,
      },
   );
   id_params::assign(\%params, \%params_def);

   print "submitting post\n";
   my $mechanize = WWW::Mechanize->new();
   $mechanize->get($url);
   $mechanize->submit_form(
      form_number => 1,
      fields => {
         com => $comment,
         recaptcha_challenge_field => $challenge,
         recaptcha_response_field => $vericode,
         upfile => $image,
         pwd => 'dumping',
      },
   );

   print $mechanize->status . "\n";

   if ($mechanize->status == '403') {
      print "Banned by Dump-hating mods ;_;\n";
   }
   if ($mechanize->content =~ m/successful/i) {
      print "Post Successful!\n";
   }
   if ($mechanize->content =~ m/mistyped/i) {
      print "Mistyped Captcha\n";
   }
   if ($mechanize->content =~ m/flood/i) {
      print "Flood Detected\n";
   }
   if ($mechanize->content =~ m/duplicate/i) {
      print "Duplicate Image\n";
   }
   if ($mechanize->content =~ m/thread specified/i) {
      print "Thread 404'd\n";
   }
   if ($mechanize->content =~ m/max limit/i) {
      print "Image Limit Reached\n";
   }
   if ($mechanize->content =~ m/too long/i) {
      print "Comment Too Long\n";
   }
}

package id_core::clock;

use Time::HiRes;

sub new {
   my $class = shift;
   my $self = {
      _title    => shift,
      _start    => shift,
      _index    => -1,
      _active   => 0,
   };
   bless $self, $class;
   return $self;   
}

sub start {
   my ($self, $title) = @_;
   return 1 if !$self->{_active};

   $self->{_index}++;
   $self->{_title}[$self->{_index}] = $title;
   $self->{_start}[$self->{_index}] = Time::HiRes::gettimeofday();
   return 1;
}

sub stop {
   my ($self, $title) = @_;
   return 1 if !$self->{_active};

   my $time = Time::HiRes::gettimeofday - $self->{_start}[$self->{_index}];
   print STDERR "id_core::clock::stop 460: process ["
              . $self->{_title}[$self->{_index}] . "] finished with time ["
              . $time . "]\n";
   print "clock->stop: process ["
         . $self->{_title}[$self->{_index}] . "]\n finished with time ["
         . $time . "]\n";

   $self->{_index}--;
   return 1;
}


1;
