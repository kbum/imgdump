#!/usr/bin/perl 

package id_thread;

use strict;
use warnings;
use WWW::Mechanize;
use Tk;
use id_params;
use Try::Tiny;

my $VERSION     = 1.00;


sub new {
   my $class = shift;
   my $self = {
      _name       => shift,
      _url        => shift,
      _dest       => shift,
      _img_links  => shift,
      _img_names  => shift,
      _img_xpms   => shift,
      _xpm_data   => shift,
      _thumbnails => shift,
      _img_count  => shift,
   }; 
   bless $self, $class;
   return $self;
}

sub name {
   my ($self, $name) = @_;
   chomp $name if defined($name);
   $self->{_name} = $name if defined($name);
   return $self->{_name};
}

sub url {
   my ($self, $url) = @_;
   $self->{_url} = $url if defined($url);
   return $self->{_url};
}

sub dest {
   my ($self, $dest) = @_;
   $self->{_dest} = $dest if defined($dest);
   return $self->{_dest};
}

sub img_count {
   my ($self, $img_count) = @_;
   $self->{_img_count} += $img_count if defined($img_count);
   return $self->{_img_count};
}

sub img_links {
   my ($self, @img_links) = @_;
   foreach my $link (@img_links) {
      push (@{$self->{_img_links}}, $link) if $link;
   }
   return $self->{_img_links};
}

sub img_names {
   my ($self, @img_names) = @_;
   push (@{$self->{_img_names}}, @img_names) if @img_names;
   return $self->{_img_names};
}

sub img_xpms {
   my ($self, @img_xpms) = @_;

#   if (!@img_xpms) {
#      $img_xpms[0] = 'bulldog_pixmap.xpm';
#   }
   push (@{$self->{_img_xpms}}, @img_xpms) if @img_xpms;
   return $self->{_img_xpms};
}

# ----- generate_xpms
#
#   currently has to parameters
#   generates a list of filenames in $self->{_img_xpms} for thumbnails
#   if thumbnail isn't found it tries to convert the original file. 
#   if that doesn't work it adds the default pic to $self->{_img_xpms}
#
#   now it also opens each xpm it finds and reads it into _xpm_data
#   img_xpms and xpm_data should be idexed so that 
#   $self->{_img_xpms}[5] is the name of the image in $self->{_xpm_data}[5]
#
sub generate_xpms {
   my ($self, %params) = @_;
   my $count = 0;
   my $fail_count = 0;
   my $no_convert = 0;
   my $single_image;
   my $parse_names_only;
   my $fix_broken_xpms;
   my $verbos = 0;

   my %params_def = (
      single_image => {
         assign  => \$single_image,
         default => 0,
      },
      parse_names_only => {
         assign => \$parse_names_only,
         default => 0,
      },
      fix_broken_xpms => {
         assign => \$fix_broken_xpms,
         default => 0,
      },
   );

   id_params::assign(\%params, \%params_def);

   if ($single_image) {
      print STDERR "id_thread::generate_xpms 102: generating large xpm "
                 . "for file [$single_image]\n";
      return;
   }

   # if _img_xpms doesn't have the same number of elements as
   # _img_names just remake all the xpms. now that it's reading
   # the xpm data for each xpm it might be a good idea to
   # make this better.
   # maybe use a hash so xpm_name => xpm_data.
   if (!defined $self->{_img_xpms}[$#{$self->{_img_names}}]
                               || $parse_names_only || $fix_broken_xpms) {

      # if no params are given we just generate xpm names for $self
      foreach my $image (@{$self->{_img_names}}) {
         my $thumbnail;
         $image = id_params::fix_path($image);

         if ($fix_broken_xpms) {
            if (!defined $self->{_img_xpms}[$count]) {
               $self->{_xpm_data}[$count] = undef;
               $self->{_thumbnails}[$count] = undef;
            }
            elsif ($self->{_img_xpms}[$count] !~ /bulldog_pixmap\.xpm/) {
               if (defined $self->{_thumbnails}[$count]) {
                  $count++;
                  next;
               }
               elsif (defined $self->{_xpm_data}[$count]) {
                  $count++;
                  next;
               }
            }
            else {
               $self->{_thumbnails}[$count] = undef;
               $self->{_xpm_data}[$count] = undef;
            }
         }
         
         if ($image =~ /.*?(\w+)\.\w*/) {
            $thumbnail = "temp\/$1.xpm";
            $thumbnail = id_params::fix_path($thumbnail);

            $self->{_img_xpms}[$count] = $thumbnail;
         }
         
         if ($parse_names_only) {
            $count++;
            next;
         }

         if (!-f $thumbnail && -f $image) {
         
            # convert and resize the image. it will be scaled so 
            # it's largest dimention is 100 pixels
            if (-e "C:\\Windows") {
               system("bin\\ImageMagick-6.7.7-5\\convert.exe -size 100x100 "
                    . "$image -resize 100x100 "
                    . "+profile '*' -delete 1-1000 $thumbnail");
            }
            else {
               system("convert -size 100x100 $image -resize 100x100 "
                    . "+profile '*' -delete 1-1000 $thumbnail");
            }
         }
         if (!-f $thumbnail) {
            print STDERR "id_thread::generate_xpms 138: could not find "
               . "thumnail [$thumbnail] using default\n"
               if $verbos;
            $self->{_img_xpms}[$count] = "bulldog_pixmap.xpm";

            open(IN, "<bulldog_pixmap.xpm");
            my @lines = <IN>;
            my $xpm_data;
            foreach my $line (@lines) {
               $xpm_data .= $line;
            }
            $self->{_xpm_data}[$count] = $xpm_data;
            close(IN);

            $no_convert = 1;
            $fail_count++;
         }
         # if the xpm is found copy the data from it into the
         # _xpm_data array
         elsif (!defined $self->{_xpm_data}[$count]) {
            open(IN, "<$thumbnail");
            my @lines = <IN>;
            my $xpm_data;
            foreach my $line (@lines) {
               $xpm_data .= $line;
            }
            $self->{_xpm_data}[$count] = $xpm_data;
            close(IN);

         }

         $count++;
      }

      print STDERR "id_thread::generate_xpms 149: generated "
                 . "[$#{$self->{_img_xpms}}] xpm names for thread "
                 . "[$self->{_name}]\n"
         if $verbos;
   
      if ($no_convert) {
         print STDERR "id_thread::generate_xpms 150: "
                    . "could not find or make [$fail_count/$count] images"
                    . " for thread [$self->{_name}]\n";
      } 
   }
}

sub img_exists {
   my ($self, $image_name);
   foreach my $known_image (@{$self->{_img_names}}) {
      if ($known_image eq $image_name) {
         return 1;
      }
   }
   return 0;
}

sub generate_thumbnails {
   my ($self, %params) = @_;
   my $frame;
   my $fix_broken;
   my $single_index;
   my $verbos = 1;

   my %params_def = (

      # Tk frame object to use for creating the thumbnail objects
      frame => {
         assign => \$frame,
      },

      # only generate thumbnails for images using the default thumbnail
      fix_broken_thumbnails => {
         assign  => \$fix_broken,
         defualt => 0,
      },

      # only generate the thumbnail for the specified index
      index => {
         assign => \$single_index,
      },
   );

   id_params::assign(\%params, \%params_def);

   if (defined $single_index) {
      $self->{_thumbnails}[$single_index] = $frame->Pixmap(
         -data => $self->{_xpm_data}[$single_index],
      );
      return;
   }

   # if there are already thumnail objects in the array then 
   # we only want to add the new ones.
   if (defined $self->{_thumbnails}) { 

      if (defined $self->{_thumbnails}[ $#{$self->{_img_xpms}} ]
                                                      && !$fix_broken) {
         print STDERR "id_thread::generate_thumbnails 183: thread "
                    . "[$self->{_name}] already has all thumbnails\n"
            if $verbos;
         return;
      }

      my $index = 0;
      print STDERR "id_thread::generate_thumbnails 184: thread "
                 . "[$self->{_name}] has "
                 . "images: $#{$self->{_img_names}} "
                 . "xpms: $#{$self->{_img_xpms}} "
                 . "thumbs: $#{$self->{_thumbnails}}\n"
         if $verbos;

      # while there are more elements in _img_xpms than
      # in _thumbnails. check each element of _img_xpms against
      # each element in _thumbnails then generate thumbnail objects
      # for the ones that are missing
#      while ($#{$self->{_img_xpms}} > $#{$self->{_thumbnails}}
#                                                   || $fix_broken) {
      foreach my $xmp_name (@{$self->{_img_xpms}}) {

         if (defined $self->{_thumbnails}[$index]) {
            $index++;
            next;
         }

         # if the image in xpm_data isn't the default
         # image then skip this iteration
         if ($fix_broken) { 

            # get out of the loop if _img_xpms is undefined
            if (!defined $self->{_img_xpms}[$index]) {
               return;
            }
            # if _thumbnails is defined then skip it
            elsif (defined $self->{_thumbnails}[$index]) {
               $index++;
               next;
            }
         }
print STDERR "generating thumbnail for image $self->{_img_xpms}[$index]\n";

         if (defined $self->{_img_xpms}[$index]
               && !defined $self->{_thumbnails}[$index]) {

            if (defined $self->{_xpm_data}[$index]) {
               $self->{_thumbnails}[$index] = $frame->Pixmap(
                  -data => $self->{_xpm_data}[$index],
               );
            }
            else {
               $self->{_thumbnails}[$index] = $frame->Pixmap(
                  -file => "bulldog_pixmap.xpm",
               );
               print STDERR "id_thread::generate_thumbnails 201: missing "
                          . "xpm data in thread [$self->{_name}] for "
                          . "[$self->{_img_xpms}[$index]]\n"
                          . "using default thumbnail";
            }
         }
         $index++;
      }
   }
   else {
      $self->{_thumbnails} = undef;

      foreach my $xpm_data (@{$self->{_xpm_data}}) {
         my $xpm_object = $frame->Pixmap(
            -data => $xpm_data,
         );
         push (@{$self->{_thumbnails}}, $xpm_object);
      }
      print STDERR "id_thread::generate_thumbnails 218: generated all new "
                 . "thumbnails for thread [$self->{_name}]\n"
         if $verbos;
   }
}

# ----- printable
# params
#   (none)  - prints only the name url and dest.
#   'long' - prints the whole damn thing
#
sub printable {
   my ($self, $length) = @_;
   my $string;

   $string = "name='";
   $string .= $self->{_name} if defined($self->{_name});
   $string .= "' ";

   $string .= "img_count='$self->{_img_count}' " if defined($self->{_img_count});

   $string .= "url='$self->{_url}' " if defined($self->{_url});
   
   $string .= "dest='$self->{_dest}' " if defined($self->{_dest});
  
   if (defined($length) && $length =~ /long/i) {
      $string .= "img_names='@{$self->{_img_names}}' "
         if @{$self->{_img_names}};
      
      $string .= "img_links='@{$self->{_img_links}}' " 
         if @{$self->{_img_links}};

      $string .= "img_xpms='@{$self->{_img_xpms}}' "
         if @{$self->{_img_xpms}};
      
   }

   return $string;
}

sub read_line {
   my ($self, $string) = @_;

   chomp $string;
    
   if ($string =~ /name='(.*?)'/m) {
      $self->{_name} = $1;
   }
   if ($string =~ /url='(.*?)'/m) {
      $self->{_url} = $1;
   }
   if ($string =~ /dest='(.*?)'/m) {
      $self->{_dest} = $1;
   }
   if ($string =~ /img_count='(.*?)'/m) {
      $self->{_img_count} = $1;
   }
   if ($string =~ /img_links='(.*?)'/m) {
      my @links = split(/\s/, $1);
      
      push(@{$self->{_img_links}}, @links);
   }
   if ($string =~ /img_names='(.*?)'/m) {
      my @names = split(/\s/, $1);

      push(@{$self->{_img_names}}, @names);
   }
   if ($string =~ /img_xpms='[(.*?)]'/m) {
      my @xpms = split(/\s/, $1);

      push(@{$self->{_img_xpms}}, @xpms);
   } 
   return $self;
}

1;
