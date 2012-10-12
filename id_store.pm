#!/usr/bin/perl

package id_store;

use strict;
use warnings;
use WWW::Mechanize;
use id_params;
use id_thread;
use Try::Tiny;
use Storable;

sub new {
   my $class = shift;

   my $self = {
      _store      => [],
      _theadcount => 0,
      _filename   => 'store.ids',
   };
   bless $self, $class;
   return $self;
}

# ----- exists_in
#
#    Searches through threads in $self->{_store}.
#    If given a $thread object we will search through $self->{_store} for a 
#    thread with the same name.
#    If given a $thread_name we will do the same thing. In this case though
#    we just get the scalar name as a param so it's one less step.
#
sub exists_in {
   my ($self, %params) = @_;
   my $thread;
   my $thread_name;

   my %params_def = (
      thread => {
         assign => \$thread,
      },
      thread_name => {
         assign => \$thread_name,
      },
   );

   id_params::assign(\%params, \%params_def);

   my $count = 0;
#   print STDERR "id_store::exists_in 52: looking for thread "
#              . "[$thread_name] in store\n"
#      if defined $thread_name;
#   print STDERR "id_store::exists_in 55: looking for thread "
#              . "[".$thread->id_thread::name()."] in store\n"
#      if defined $thread;
  
   
   if (defined $thread) {
      foreach my $known_threads (@{$self->{_store}}) {
         if ($self->{_store}[$count]->id_thread::name() 
                  eq $thread->id_thread::name()) {

            return $count;
         }
         $count++;
      }
      return undef;
   }
   elsif (defined $thread_name) {
      foreach my $known_threads (@{$self->{_store}}) {

         if ($self->{_store}[$count]->id_thread::name() eq $thread_name) {

            return $count;
         }
         $count++;
      }
      return undef;
   }
}

# ----- updatethread
#
#   updates $self with new information in $thread
#   or with information from store.ids
#
sub updatethread { 
   my ($self, %params) = @_;

   my $thread;
   my $thread_name;
   my $from_store;
   my $temp_store_ref;
   my $temp_store;

   my %params_def = (
      thread => {
         assign => \$thread,
      },
      thread_name => {
         assign => \$thread_name,
      },
      from_store => {
         assign => \$from_store,
         default => 0,
      },
      store => {
         assign => \$temp_store,
         default => 0,
      },
   );

   id_params::assign(\%params, \%params_def);

   # if from_store param is 1 we're gonna re-read $thread
   # from store.ids, exclude any images that are already
   # in $thread, and add the new images to $thread
   #
   # CHANGE store.ids to bin_store.ids, don't parse just retrieve
   if ($from_store) {

      if (defined $thread) {
         $thread_name = $thread->id_thread::name;
      }
      $thread = undef;

      # if nobody gave us a store we'll just retrieve from bin_store.ids
      if (!$temp_store) {
         $temp_store = id_store->new();
         $temp_store->id_store::read_all(
            mode => 'main',
         );
      }

      # get the index of the thread to update
      my $index = $self->id_store::exists_in(
         thread_name => $thread_name,
      );

      # get the index of the stored thread
      my $stored_index = $temp_store->id_store::exists_in(
         thread_name => $thread_name,
      );

      if (!defined $stored_index) {
         print STDERR "id_store::updatethread 150: couldn't find "
                    . "[$thread_name] in temp_store\n   index was "
                    . "[$stored_index]\n";
         return;
      };

      my $stored_thread = $temp_store->{_store}[$stored_index];

      my $new_img_count = $stored_thread->id_thread::img_count
         - $self->{_store}[$index]->id_thread::img_count;
      
      if ($new_img_count > 0) {

         $thread = new id_thread();

         # @stored_images will start off with all the images
         # in $stored_thread. each iteration of this foreach
         # loop will build the same array excluding one image
         # from $self->{_store}[$index]->id_thread::img_names
         my @stored_images = @{$stored_thread->id_thread::img_names};
         my @temp_stored_images;
         foreach my $known_image (
            @{$self->{_store}[$index]->id_thread::img_names}) {
            
            foreach my $stored_image (@stored_images) {
               if ($known_image ne $stored_image) {
                  push(@temp_stored_images, $stored_image);
               }
            }
            @stored_images = ();
            @stored_images = @temp_stored_images;
            @temp_stored_images = ();
         }

         $thread->id_thread::img_names(@stored_images);
         $thread->id_thread::img_count($new_img_count);
         $thread->id_thread::name($thread_name);
         $thread->id_thread::generate_xpms();
         @{$thread->{_thumbnails}} = undef;
         @{$thread->{_thumbnails}} = 
            @{$self->{_store}[$index]->{_thumbnails}};
      }
      $temp_store = undef;
   }
 
   my $index = $self->exists_in(
         thread => $thread,
   );
   if (defined($index) && defined($thread)) {
      
      print STDERR "id_store::updatethread 201: updating thread ["
                 . $thread->id_thread::name()
                 . "] in store at index [$index]\n"
                 . "thread had ["
                 . $self->{_store}[$index]->id_thread::img_count()
                 . "] images\n"
                 . "adding ["
                 . $thread->id_thread::img_count()
                 . "] images to thread\n";

      # these ones will be added to
      $self->{_store}[$index]->id_thread::img_links(
         @{$thread->id_thread::img_links()}
      ) if (ref($thread->id_thread::img_links()) eq 'ARRAY');

      $self->{_store}[$index]->id_thread::img_names(
         @{$thread->id_thread::img_names()}
      ) if (ref($thread->id_thread::img_names()) eq 'ARRAY');

      $self->{_store}[$index]->id_thread::img_count(
         $thread->id_thread::img_count()
      );
     
      # the rest will just be replaced
      $self->{_store}[$index]->id_thread::name(
         $thread->id_thread::name()
      ) if defined $thread->id_thread::name();

      $self->{_store}[$index]->id_thread::dest(
         $thread->id_thread::dest()
      ) if defined $thread->id_thread::dest();

      $self->{_store}[$index]->id_thread::url(
         $thread->id_thread::url()
      ) if defined $thread->id_thread::url();
   }
   else {
      return undef;
   }
} 

# ----- add_thread
#
#   adds a thread to $self. If the thread name already exists in $self
#   then update the thread. otherwise just push it onto @{$self->{_store}}
# 
#   $store->id_store::add_thread(
#      thread => $thread,            # the thread you want to add
#      mode => $mode,                # modes are: main, sfw, nsfw
#   );                               # main - loads all threads into store
#                                    # sfw - only loads threads that arent
#                                    # in store/nsfw
#
sub add_thread {
   my ($self, %params) = @_;
   my $thread;
   my $mode;

   my %params_def = (
      thread => {
         assign => \$thread,
      },
      mode => {
         assign => \$mode,
         default => 'main',
      },
   );

   id_params::assign(\%params, \%params_def);

   # $mode is main. doesn't matter if it's sfw or not add the thread
   if ($mode =~ /^main/i) {
      my $index = $self->exists_in(
            thread => $thread,
      );
      if (defined($index)) {
         print "thread exists. updating thread info\n";
         $self->id_store::updatethread(
            thread => $thread
         );
      }   
      elsif(defined($thread)) {
         push(@{$self->{_store}}, $thread);
         $self->{_threadcount}++; 
      }
      return $self->{_store};
   }

   # $mode is sfw. here we're only gonna add the thread to the store if 
   # the destination of $thread, $thread->{_dest}, is not in 
   # the nsfw folder
   elsif ($mode =~ /^sfw/i && $thread->{_dest} !~ /nsfw/i) {
      my $index = $self->exists_in(
            thread => $thread,
      );
      if (defined($index)) {
         $self->id_store::updatethread(
            thread => $thread
         );
      }   
      elsif(defined($thread)) {
         push(@{$self->{_store}}, $thread);
         $self->{_threadcount}++; 
      }
      return $self->{_store};
   }

   elsif ($mode =~ /^nsfw/i && $thread->{_dest} =~ /nsfw/i) {
      my $index = $self->exists_in(
            thread => $thread,
      );
      if (defined $index) {
         $self->id_store::updatethread(
            thread => $thread
         );
      }   
      elsif(defined $thread) {
         push(@{$self->{_store}}, $thread);
         $self->{_threadcount}++; 
      }
      return $self->{_store};
   }
#   else {
#      print STDERR "id_store::add_thread 317: unknown mode parameter "
#                 . "[$mode]\n";
#   }
}

sub read_all {
   my ($self, %params) = @_;
   my $mode;
   my $filename;

   my %params_def = (
      mode => {
         assign => \$mode,
         default => 'main',
      },
      filename => {
         assign => \$filename,
         default => 'bin_store.ids',
      },
   );
   id_params::assign(\%params, \%params_def);
   
   if ($mode eq 'main') {
      my $temp_store = ${retrieve($filename)};

      foreach my $thread (@{$temp_store->{_store}}) {
         $thread->id_thread::generate_xpms();
         
         my $index = $self->id_store::exists_in(
            thread => $thread,
         );
         if (defined $index) {
            $self->id_store::updatethread(
               thread => $thread,
               from_store => 1,
               store => $temp_store,
            );
         }
         else {
            push(@{$self->{_store}}, $thread);
         }
      }
   }
   elsif ($mode eq 'sfw' || $mode eq 'nsfw') {
      my $thread_count = 0;
      my $temp_store = ${retrieve($filename)};

      foreach my $thread (@{$temp_store->{_store}}) {
         $thread->id_thread::generate_xpms(); 

         my $index = $self->id_store::exists_in(
            thread => $thread,
         );

         # if mode is safe for work, the thread exists in $self,
         # and the thread does not have 'nsfw' in the destination
         if ($mode eq 'sfw' 
               && defined $index 
                     && $thread->{_dest} !~ /nsfw/i) {
            $self->id_store::updatethread(
               thread => $thread,
               from_store => 1,
               store => $temp_store,
            );
            $thread_count++;
         }
         
         # if mode is safe for work and the destination doesn't have
         # 'nsfw' in it then push the new thread onto $self->{_store}
         elsif ($mode eq 'sfw' && $thread->{_dest} !~ /nsfw/i) {
            push(@{$self->{_store}}, $thread);
            $thread_count++;
         }
         
         # if mode is not safe for work, the thread exists in $self,
         # and the thread has 'nsfw' in the destination. update the
         # thread from bin_store.ids
         elsif ($mode eq 'nsfw' 
                  && defined $index
                     && $thread->{_dest} =~ /nsfw/) {
            $self->id_store::updatethread(
               thread => $thread,
               from_store => 1,
               store => $temp_store,
            );
            $thread_count++;
         }
         
         # if mode is not safe for work, the thread doesn't exist in
         # $self, and the thread 'nsfw' is in the destination. push the 
         # thread onto $self->{_store}
         elsif ($mode eq 'nsfw' && $thread->{_dest} =~ /nsfw/) {
            push(@{$self->{_store}}, $thread);
            $thread_count++;
         }
      }
      $self->{_thread_count} = $thread_count;
   }
   elsif ($mode eq 'net') {
      my $self = ${retrieve('net_store.ids')};

      foreach my $thread (@{$self->{_store}}) {
         $thread->id_thread::generate_xpms(
            parse_names_only => 1,
         );
      }
   }
}

sub print_all {
   my ($self, %params) = @_;

   my $length;
   my $spacing;

   my %params_def = (
      length => {
         assign => \$length,
         default => 'short',
      },
      spacing => {
         assign => \$spacing,
         default => 1,
      },
   );

   id_params::assign(\%params, \%params_def);
   
   my $count = 0;
   foreach my $thread (@{$self->{_store}}) {
      print "index='$count'\n" . $thread->id_thread::printable($length) . "\n";
      
      for (my $i = 1; $i < $spacing; $i++) {
         print "\n";
      }
      $count++;
   }
}

# ----- download_images
# INPUTS
#
#   parse_page(
#      url  => string,
#      dest => string,
#      name => string,
#      save_as => string,
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

sub download_images {
   my ($self, %params) = @_;

   my $thread = id_thread->new();
   my $url;
   my $dest;
   my $name;
   my $save_as;
   my @links;
   
   my %params_def = (
      url => {
         assign => \$url,
         default => 0,
      },
      dest => {
         assign => \$dest,
         default => id_params::fix_path('store/'),
      },
      name => {
         assign => \$name,
         default => 'default',
      },
      save_as => {
         assign => \$save_as,
      },
   );
   id_params::assign(\%params, \%params_def);

   $thread->id_thread::url($url);
   $thread->id_thread::name($name);

   print "attempting to view index from [$url]\n";
   my $mech = WWW::Mechanize->new(autocheck => 0);

   print "url not given\n" && return 0 if !$url;
   $mech->get($url);

   # check that the page exists
   if ($mech->status() == 200) {
      print "--->got the page\n";
      my @all_links = $mech->find_all_links(
         text_regex => qr/\d+/,
         url_regex => qr/(.*images\.4chan.org.*|.*7chan\.org.*\/\d+\..*)/
      );

      my $i = 0;
      my $j = 0;
      while (defined($all_links[$i])) {
         my $link = $all_links[$i]->url;
         if (!defined $all_links[$i+1] || $link ne $all_links[$i+1]->url) {
            # windows doesn't like the '//' at the begining of all the links
            # doesn't really make snse why there's no http: there
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
      return 1 if !$j;
   } 
   else {
      print "404 not found\n";
      return 0;
   }

   if ($dest !~ /[\\|\/]$/) {
      $dest .= id_params::fix_path("\/");
   }
   print "ERROR destination [$dest] not found\n" && return 0 if !-e $dest;

   $thread->id_thread::name($name);
   $thread->id_thread::url($url);
   $thread->id_thread::dest($dest);

   my $img_count  = 0;
   my $save_count = 0;
   my $percent    = 0;
   
   foreach my $link (@links) {
      $img_count++;
      
      my $filename;
      my $filenameonly;
   
      # get the image name out of each link
      if ($link =~ m/.*\/(\d+\..*)/) {
         $filename = $dest . $1;
         $filenameonly = $1;
      }
      else {
         next;
      }

      if (!$thread->id_thread::img_exists($filename) && !-f $filename) {

         # save the image
         try { $mech->get($link) };
         my $next = 0;
         try { $mech->save_content($filename) }
         catch { $next = 1};
         next if $next;
         
         # get the thumbnail and store it as xpm
         # resize the image, convert to spm and store
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

            my $img = Image::Xpm->new(-file, "temp\/$1\.xpm"
            ) or die "could not get image from file [temp\/$1\.xpm]";

            $img->set(width => 100);
            $img->save("temp\/$1\.xpm");

            open(IN, "<", "temp\/$1\.xpm");
            my @lines = <IN>;
            close(IN);
            my $xpm_data;
            foreach my $line (@lines) {
               $xpm_data .= $line;
            }

            $thread->id_thread::img_xpms("temp\/$1\.xpm");
            $thread->id_thread::xpm_data($xpm_data);
         }

         $thread->id_thread::img_links($link);
         $thread->id_thread::img_names($filename);

         $save_count++;
      }
      while ($img_count/($#links+1) >= $percent/50)  {
         $percent++;
      }
   }

   $thread->id_thread::img_count($save_count);

   foreach my $xpm_data (@{$thread->{_xpm_data}}) {
      print "\n\n$xpm_data\n\n";
   }

   if (defined $save_as) {
      my $single_thread_store = new id_store();
      $single_thread_store->id_store::add_thread(
         thread => $thread,
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
   
   $self->id_store::add_thread(
      thread => $thread,
   );
   $self->id_store::save(
      mode => 'data_dumper'
   );

   print "$img_count/" . ($#links+1);
   print "\nimages in [$dest]\n";
   print "$save_count new images saved\n";

   return 1;
}

sub save {
   my ($self, %params) = @_;
   my $mode;
   my $filename;
   my $remove_xpms;

   my %params_def = (
      mode => {
         assign => \$mode,
         default => 'normal',
      },
      filename => {
         assign => \$filename,
         default => 'bin_store.ids',
      },
      remove_xpms => {
         assign => \$remove_xpms,
         default => 1,
      },
   );
   id_params::assign(\%params, \%params_def);

   if (!defined $filename || !$filename) {
      $filename = 'bin_store.ids';
   }

   if ($mode =~ /normal/i) {
      open(OUT, ">store.ids");
   
      foreach my $thread (@{$self->{_store}}) {
         print OUT $thread->id_thread::printable('long')."\n";
      }
      close(OUT);
   }
   elsif ($mode =~ /data_dumper/i) {
      # remove _thumbnails since we can't store those yet
      # remove _img_xpms because otherwise thumbnails that weren't
      # found will always have bulldog_pixmap.xpm as the thumbnail
      # remove _img_links because i will never need these after they 
      # have already been downloaded

      foreach my $thread (@{$self->{_store}}) {
         $thread->{_thumbnails} = undef;
         $thread->{_img_links} = undef;
         if ($remove_xpms) {
            $thread->{_img_xpms} = undef;
            $thread->{_xpm_data} = undef;
         }
      }
      print STDERR "id_store::save 472: mode is [$mode] removing "
                 . "unwanted info and saving to "
                 . $filename . "\n";

      Storable::nstore(\$self, $filename)
   }
}

# ----- remove_thread
#
# remove a thread's information and all images and all thumbnails
#
sub remove_thread {
   my ($self, %params) = @_;
   my $thread_name;
   my $remove_count;

   my %params_def = (
      thread_name => {
         assign => \$thread_name,
         default => 'NO NAME',
      },
   );

   id_params::assign(\%params, \%params_def);

   if ($thread_name eq "NO NAME") {
      print "id_store::remove NO THREAD NAME GIVEN\n";
      return 0;
   }

   foreach my $thread (@{$self->{_store}}) {
      next if ($thread->id_thread::name() ne $thread_name);

      print "are you sure you want to remove thread [$thread_name] and all "
          . "of it's images? [y/N]: ";
      my $response = 'n';
      $response = <STDIN>;

      next if ($response !~ /y/i);

      $remove_count++;
      foreach my $image_name (@{$thread->{_img_names}}) {
         system("rm -f $image_name");
      }
      $thread->{_img_names} = undef;
      foreach my $xpm_name (@{$thread->{_img_xpms}}) {
         system("rm -f $xpm_name");
      }
      $thread->{_img_xpms} = undef;
      $thread->{_xpm_data} = undef;
      $thread->{_thumbnails} = undef;
      $thread->{_img_count} = 0;
      $thread->{_url} = undef;
      $thread->{_dest} = undef;

      my $remove_index = $self->id_store::exists_in(
         thread_name => $thread_name
      );

      splice(@{$self->{_store}}, $remove_index, 1);

   }

   if (!$remove_count) {
      print "no thread named [$thread_name] exists in store\n";
   }
   else {
      print "successfully removed [$thread_name] from store\n";
   }

   return 1;
}

1;
