#!/usr/bin/perl -w

########################################################
# This script takes as input two files from the ImageJ #
# makro. The first file contains the coordinates for   #
# each track: x, y, and time encoded as frame number.  #
# The second file contains the vertical distribution   #
# of the larvae in text-image format.                  #
# The second file is implicitly given by the name of   #
# the first file, which is appended by                 #
# _vertical.text_image.txt to form the name of the     #
# second file.                                         #
# This script takes additional input parameters, see   #
# below.                                               #
# This script writes its output to the file            #
# Results.txt in the folder of the input files. If it  #
# does not exit it creates it otherwise it appends it. #
# The output contains for each file the file name with #
# full path, the average horizonatal and vertical      #
# displacement, and the number of larvae that were     #
# meassured.                                           #
########################################################

use strict;
use warnings;

# Get the directory of this script:
use FindBin qw($Bin);
use lib $FindBin::Bin;
FindBin::again(); # Just to be sure that it hasn't been called in another script before

use MTrack;
use File::Basename;

########################################################
# NormalizeToCount devides a value by count, which     #
# should be positive. Returns zero if count is not     #
# bigger zero.                                         #
########################################################

sub NormalizeToCount
{
	my $value = $_[0];
	my $count = $_[1];
	
	if($count > 0)
	{
		return $value / $count;
	}
	else
	{
		return 0;
	}
}

########################################################
# Min and Max functions                                #
########################################################

sub max ($$) { $_[$_[0] < $_[1]] }
sub min ($$) { $_[$_[0] > $_[1]] }

########################################################
# Deal with script input                               #
########################################################

my $usage  = "usage: perl program.pl infile.res fps column_width_in_px air_at_top_in_px not_visible_bottom_in_px (isMTrack3), (column_width_in_mm)\n\n"
           . "perl:                     Start perl\n"
           . "program.pl:               This script\n"
           . "infile.res:               mTrack output file: Do not use files containing spaces, unless you escape the spaces\n"
           . "fps:                      The frame rate the video was recorded with\n"
           . "column_width_in_px:       The witdh of the view field on screen in pixels\n"
           . "air_at_top_in_px:         Number of pixels that should be removed from the top\n"
           . "not_visible_bottom_in_px: Number of pixels that should be cut from the bottom\n"
           . "isMTrack3:                The version of mTrack that was used to generate the tracks, default value 2\n"
           . "                          Use 2 for mTrack, for mTrack3 use any other value.\n"
           . "column_width_in_mm:       The witdht of the column on screen in mm, default value 31 mm\n"
           . "                          If not default value is used, isMTrack3 must be specified.\n"
           . "\n";


# Check that everything is okay, sometimes tabs, spaces, and newlines make trouble. The number of arguments could hint about this.
print "Number of arguments: ", scalar(@ARGV), "\n";

die $usage unless (@ARGV == 5 or @ARGV == 6 or @ARGV == 7 or @ARGV == 8);

my $infile = $ARGV[0];
print "Input file ", $infile, "\n";

my $mTrackVersion = (@ARGV > 5) ? $ARGV[5] : 2;
print "mTrack version used: ", $mTrackVersion, "\n";

# Variable parameters fetched from the script arguments:
my $frame_rate                        = $ARGV[1];
my $columnWidth_in_px                 = $ARGV[2];
my $columnWidth_in_mm                 = (@ARGV > 6) ? $ARGV[6] : 31;
my $mm_per_pixel                      = $columnWidth_in_mm/$columnWidth_in_px;
my $pixels_air                        = $ARGV[3];
my $pixels_bottom                     = $ARGV[4];

# Print input parameters on screen, to display that everything is right.
print "Frame Rate: ",              $frame_rate,
      "\nColumn Width in pixel: ", $columnWidth_in_px,
      "\nColumn Width in mm: ",    $columnWidth_in_mm,
      "\nmm per pixel: ",          $mm_per_pixel,
      "\nPixels air: ",            $pixels_air,
      "\nPixels bottom: ",         $pixels_bottom,
      "\n";

########################################################
# Create Results file if there is none.                #
########################################################

# Get input file name without suffix
my($filename, $path, $suffix) = fileparse($infile, qr/\.[^.]*/);
my $basefile = File::Spec->catfile($path, $filename);

# Put the output result file into the same folder as the input files
my $ResultsFile = File::Spec->catfile($path, "Results.txt");

# Create the results file if it does not exist and write a header to it.
if(! -e $ResultsFile)
{
	open (RESULTS, ">$ResultsFile") or die "Error: ", print "\nCannot open file!\n$ResultsFile! \n";
	print RESULTS  "File Name",
	               "\t#Average x Displacement", # Horizontal displacement
	               "\t#Average y Displacement", #   Vertical displacement
	               "\t#Larvae",                 #  Number of larvae
	               "\n";

	close RESULTS;
}

########################################################
# Get the number of lines from the text image.         #
########################################################

open (RESULTS_IN, "<$basefile"."_vertical.text_image.txt") or die "Error: ", print "\nCannot open file!\n$! \n";

# Open and run through, to get the number of lines
while (<RESULTS_IN>) {}

my $no_of_lines = $.; # Get the number of lines


########################################################
# Read in the tracks from the mTrack output            #
########################################################

print "Read tracks\n";

# Read in all the tracks from the mTRack output file.
my @tracks = MTrack::ReadTracks($infile, $mTrackVersion);

########################################################
# Invalidate all the parts of the tracks that reach    #
# beyond the cutoff pixel values at the top and the    #
# bottom of the column. Split the tracks if necessary. #
########################################################

for(my $t = scalar(@tracks)-1; $t >= 0; $t--)
{
	my $frameCounter = 0;
	my $continiousCounter = 0;
	my $continuity = 0;
	for(my $f = $#{$tracks[$t]}; $f >= 0; $f--)
	{
		# Save this into a local variable,
		# and use that for the testing. Otherwise
		# we run out of memory with big data sets.
		# Bug in perl.
		my $pos = $tracks[$t][$f];
		if
		(
		     $pos->{isValid}
		  && 
		     (
		          $pos->{y} < $pixels_air
		       || $pos->{y} > $no_of_lines - $pixels_bottom
		     )
		)
		{
			$pos->{isValid} = 0;
		}
		
		if($pos->{isValid})
		{
			$frameCounter++;
			$continiousCounter++;
		}
		elsif(!$pos->{isValid} && $continiousCounter == 1)
		{
			my $pos2 = $tracks[$t][$f+1];
			$pos2->{isValid} = 0;
			$continiousCounter = 0;
			$frameCounter--;
		}
		elsif(!$pos->{isValid})
		{
			$continuity = max($continuity, $continiousCounter);
			$continiousCounter = 0;
		}
	}

	$continuity = max($continuity, $continiousCounter);

	if($frameCounter <= 1)
	{
		splice @tracks, $t, 1;
		next;
	}

	if($continuity < $frameCounter)
	{
		# Copy subarray, including its elemts and not only the refferences to those elements
		my @tracks_copy = @{dclone($tracks[$t])};
		
		$frameCounter      = 0;
		$continiousCounter = 0;

		for(my $f = $#{$tracks[$t]}; $f >= 0; $f--)
		{
			my $pos      = $tracks[$t][$f];
			my $pos_copy = $tracks_copy[$f];

			if($pos->{isValid})
			{
				$frameCounter++;
				$continiousCounter++;

				if($frameCounter == $continiousCounter)
				{
					$pos_copy->{isValid} = 0;
				}
				else
				{
					$pos->{isValid} = 0;
				}
			}
			else
			{
				$continiousCounter = 0;
			}
		}
		unshift(@tracks, \@tracks_copy); # Insert at the beginning
		$t++; # Correct index, after insert
	}
}

# Exit if we have no tracks, but record the current input file in the results file.
if(scalar(@tracks) == 0)
{
	open (RESULTS, ">>$ResultsFile") or die "Error: ", print "\nCannot open file!\n$! \n";

	# Write the data to the results file.
	print RESULTS $infile, "\n";
	close RESULTS;
	
	print "Exit: No tracks found\n";
	exit;
}

# Figure out the length of the longest track in the dataset
my $track_length                       = 0;

for(my $t = 0; $t < scalar(@tracks); $t++)
{
	if($track_length < $#{$tracks[$t]}+1)
	{
		$track_length = $#{$tracks[$t]}+1;
	}
}

########################################################
# Calculate the average displacements of the larvae    #
# in along the x- and y-axis.                          #
########################################################

# Initialze variables
my $Total_Single_X_Move                = 0;
my $Total_Single_X_Move_Counter        = 0;

my $Total_Single_Y_Move                = 0;
my $Total_Single_Y_Move_Counter        = 0;

print "Analyse tracks\n";

# Sum up all the x and y components separately of the single components of the tracks
for(my $t = 0; $t < scalar(@tracks); $t++)
{
	my $lastPos           = ({x => 0, y => 0});
	my $gotFirstFrame     = 0;
	my $distanceCounter   = 0;

	for(my $f = 0; $f < $#{$tracks[$t]}+1; $f++)
	{
		# Put this into a local variable, so that perl does not freak out at big data sets.
		# May have been fixed in a later version of perl.
		my $pos = $tracks[$t][$f];
		# Get the start frame of the current track
		if($pos->{isValid} && !$gotFirstFrame)
		{
			$gotFirstFrame = 1;
			$lastPos = ({x => $pos->{x}, y => $pos->{y} - $pixels_air});

			# Go to next loop iteration
			next;
		}

		# Last frame with track reached, so leave the inner loop
		if(!$pos->{isValid} && $gotFirstFrame)
		{
			# Leave loop
			last;
		}

		# Do the actual counting and summing.
		if($gotFirstFrame)
		{
			my $thisPos = ({x => $pos->{x}, y => $pos->{y} - $pixels_air});

			my $x = $thisPos->{x} - $lastPos->{x};
			my $y = $thisPos->{y} - $lastPos->{y};


			# Average the x component the larvae traveled
			$Total_Single_X_Move += $x;
			$Total_Single_X_Move_Counter++;

			# Average the y component the larvae traveled
			$Total_Single_Y_Move -= $y; # 0 on y-axis is on top, so reverse sign
			$Total_Single_Y_Move_Counter++;

			$lastPos = ({x => $pos->{x}, y => $pos->{y} - $pixels_air});
		}
	}
}

# Get the average
$Total_Single_X_Move         = NormalizeToCount($Total_Single_X_Move,           $Total_Single_X_Move_Counter);
$Total_Single_Y_Move         = NormalizeToCount($Total_Single_Y_Move,           $Total_Single_Y_Move_Counter);

########################################################
# Estimate the number of larvae in the view field. The #
# maximum number of tracks in any frame gives the      #
# minimum number of larvae in the view field.          #
########################################################

print "Calculate number of larvae\n";

my $number_of_larvae_in_field = 0;

for(my $f = 0; $f < $track_length; $f++)
{
	my $validCounter = 0;
	for(my $t = 0; $t < scalar(@tracks); $t++)
	{
		# That's now really rediculous, do we really need
		# to use up all the memory for dereferencing?
		my $pos = $tracks[$t][$f];

		if($pos->{isValid})
		{
			$validCounter++;
		}
	}

	if($validCounter > $number_of_larvae_in_field)
	{
		$number_of_larvae_in_field = $validCounter;
	}
}

########################################################
# Write the data to the results file; data from        #
# different calls of this script can go to the same    #
# results file                                         #
########################################################

# We made already sure that the file exists
open (RESULTS, ">>$ResultsFile") or die "Error: ", print "\nCannot open file!\n$! \n";

# Write the data to the results file.
print RESULTS $infile,
              "\t", $Total_Single_X_Move * $mm_per_pixel * $frame_rate, # Average horizontal displacement, convert to mm/s
              "\t", $Total_Single_Y_Move * $mm_per_pixel * $frame_rate, # Average   vertical displacement, convert to mm/s
              "\t", $number_of_larvae_in_field,                         # The number of larvae
              "\n";
close RESULTS;


