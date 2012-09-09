package id_params;

use strict;
use warnings;
use WWW::Mechanize;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(assign);

# subroutines
#
# assign
# make_ARGV_hash
# fix_path

# ----- assign
# 
#   takes two hash references as parameters. first parameter
#   is %params hash, or %{$_[0]}, second is %params_def, or %{$_[0]}.
#
#   my %params = @_;
#   my %params_def = (
#      param1 => {
#         assign => \$param1,
#         default => $default_value, # This could be any scalar value
#                                    # including references.
#         required => (1||0),        # Doesn't actually do anything
#                                    # right now.
#      },
#      param2 => {
#         assign => \$param2,
#      },
#   );
#
#   id_params::assign(\%params, \%params_def);
#   
sub assign {
#   my %params = %{$_[0]};
#   my %params_def = %{$_[1]};

   # for each parameter in the definition hash
   foreach my $key_def (keys %{$_[1]}) {

      # check if the param was assigned
      my $param_assigned = 0;

      # each parameter passed in the params hash
      foreach my $key_given (keys %{$_[0]}) {

         # if the param given matches a key from the definition hash
         # assign the value to the scalar referenced in the 
         # definition hash 
         if ($key_given eq $key_def) {

            ${${$_[1]}{$key_def}{assign}} = ${$_[0]}{$key_given}; 

            if (defined( ${${$_[1]}{$key_def}{assign}} )) {
               $param_assigned = 1;
            }

            last;
         }

      }# end of foreach

      # if param wasn't assigned then assign default
      if (!$param_assigned) {

         # dereferenced variable given by caller being assigned
         # default value  
         ${${$_[1]}{$key_def}{assign}} = ${$_[1]}{$key_def}{default}; 
      }
   }# end of foreach
}

sub make_ARGV_hash {
   my %argv_hash;
   my $param;
   for ($param = 0, $param <= $#{@_}, $param++) {
      $argv_hash{$_[$param]} = $_[$param + 1]; 
   }  
   return %argv_hash; 
}

# ----- fix_path
#
# fixes file seperators in path names depending on os.
# if C:\Windows exists use \
# if it doesn't use /
# 
sub fix_path {
   my $pathname = $_[0];
   my $seperator;
   my $new_name = '';

   my @sections = split(/[\\|\/]/, $pathname);

   # if the pathname uses \
   if ($pathname =~ /\\/) {

      # if the machine is windows leave the pathname alone 
      if (-e "C:\\Windows") {
         return $pathname;
      }
      else {
         $seperator = "\/";
      }
   }
   # if the pathnames uses / 
   elsif ($pathname =~ /\//) {

      # if the machine is unix leave the pathname alone 
      if (!-e "C:\\Windows") {
         return $pathname;
      }
      else {
         $seperator = "\\";
      }
   }
   # if no file seperators return the pathname
   else {
      return $pathname;
   }

#   print STDERR "sections: [@sections]\n"
#              . "seperator: [$seperator]\n";

   if ($sections[0] eq $seperator) {
      $sections[1] = $seperator . $sections[1];
      $sections[0] = undef;
   }
   if ($pathname =~ /$seperator$/ && $sections[0] ne $seperator) {
      $sections[$#sections] = $sections[$#sections] . $seperator;
   }

   my $next_index = 1;
   foreach my $name (@sections) {
      if (defined $name) {
         $new_name .= $name;
      
         if (defined $sections[$next_index]) {
            $new_name .= $seperator;
         }
      }
      $next_index++;
   }

   return $new_name;
}
1;
