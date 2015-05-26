

########################################################
# MTrack.pm: Perl module file to parse the output of   #
# mTrack2 or mTrack3.                                  #
########################################################

package MTrack;

use strict;
use warnings;

use File::Basename;
use File::Spec;

########################################################
# ReadTracks reads tracks from an mTrack output file.  #
# infile is the file that it reads the tracks from.    #
# mTrackVersion gives the version of mTrack with that  #
# the output file was created with.                    #
# If mTrackVersion equals 3 then mTrack3 is assumed.   #
# Otherwise mTrack2 is assumed.                        #
# Returns an array of tracks. Each track is an array   #
# of positions. Each positions contains x and y        #
# coordinates and an isValid flag indicating wether    #
# the position is a real position or just a            #
# placeholder.                                         #
########################################################
sub ReadTracks
{
	my $infile        = shift;
	my $mTrackVersion = shift;

	if($mTrackVersion == 3)
	{
		return MTrack::ReadTracks3($infile);
	}
	else
	{
		return MTrack::ReadTracks2($infile);
	}
}

########################################################
# ReadDistances reads the distances for each track     #
# from mTrack output.                                  #
# infile is the file that it reads the distances from. #
# mTrackVersion gives the version of mTrack with that  #
# the output file was created with.                    #
# If mTrackVersion equals 3 then mTrack3 is assumed.   #
# Otherwise mTrack2 is assumed.                        #
########################################################
sub ReadDistances
{
	my $infile        = shift;
	my $mTrackVersion = shift;

	if($mTrackVersion == 3)
	{
		return MTrack::ReadDistances3($infile);
	}
	else
	{
		return MTrack::ReadDistances2($infile);
	}
}

########################################################
# ReadTracks2 reads tracks from an mTrack2 output      #
# file.                                                #
# infile is the file that it reads the tracks from.    #
# Returns an array of tracks. Each track is an array   #
# of positions. Each positions contains x and y        #
# coordinates and an isValid flag indicating wether    #
# the position is a real position or just a            #
# placeholder.                                         #
########################################################
sub ReadTracks2
{
	my $infile = shift;

	open (TRACKS_IN, "<$infile") or die "Error: ", print "\nCannot open file!\n$! \n";

	my @tracks       = ();
	my $blockCounter = 0;

	# We fill the data into an array of arrays
	while (defined (my $line = <TRACKS_IN>))
	{
		# We exclude the first line that starts with "Frame" and the lines with the track lengths
		unless ($line =~ m/^Track/ or $line =~ m/^Frame/ or $line =~ m/\:/)
		{
			my @tmp = split('\t', $line);

			for (my $i=1; $i < scalar(@tmp); $i+= 3)
			{
				my $valid = ($tmp[$i] ne " ") ? 1 : 0;
				my $position = ({x => $tmp[$i], y => $tmp[$i+1], isValid => $valid});
				my $j = (($i - 1) / 3) + $blockCounter;

				$tracks[$j][$tmp[0]-1] = $position;
			}
		}

		# A new block starts
		if($line =~ m/^Track/)
		{
			$blockCounter = scalar(@tracks);
		}

		# Stop looking for data if we encounter the dinstance traveled section:
		if($line =~ m/Nr of Frames$/)
		{
			last;
		}
	}

	close TRACK_IN;

	return @tracks;
}

########################################################
# ReadTracks2 reads tracks from an mTrack3 output      #
# file.                                                #
# infile is the file that it reads the tracks from.    #
# Returns an array of tracks. Each track is an array   #
# of positions. Each positions contains x and y        #
# coordinates and an isValid flag indicating wether    #
# the position is a real position or just a            #
# placeholder.                                         #
########################################################
sub ReadTracks3
{
	my $infile = shift;

	open (TRACKS_IN, "<$infile") or die die "Error: ", print "\nCannot open file!\n$! \n";
	my @tracks       = ();
	my $blockCounter = 0;

	# We fill the data into an array of arrays
	while (defined (my $line = <TRACKS_IN>))
	{
		# We exclude the first line that starts with "Frame" and the lines with the track lengths
		unless ($line =~ m/^ \tTrack/ or $line =~ m/^Frame/ or $line =~ m/\:/)
		{
			my @tmp = split('\t', $line);

			my $position = ({x => $tmp[3], y => $tmp[5], isValid => 1});
			$tracks[$tmp[1]-1][$tmp[2]-1] = $position;
		}
	}

	close TRACK_IN;

	return @tracks;
}

########################################################
# ReadDistances2 reads the distances for each track    #
# from mTrack output.                                  #
# infile is the file that it reads the distances from. #
########################################################
sub ReadDistances2
{
	my $saveDistances = 0;
	my $infile = shift;

	open (TRACKS_IN, "<$infile") or die "Error: ", print "\nCannot open file!\n$! \n";

	# For debugging the distances can be saved to a file
	if($saveDistances){ open (DISTANCE_PER_LENGTH, ">$infile"."_distance_per_length.txt") or die "Error: ", print "\nCannot open file!\n$! \n";}

	my @distance_per_length = ();
	my $hasStarted          = 0;

	# We check the number of track blocks, the track lengths and number of tracks by looking at the second number in the last line "Tracks"
	while (defined (my $line = <TRACKS_IN>))
	{
		if
		   (
		       $line =~ /\:/ # These are the lines with the track lengths, but only if you do not directly save the output to a file.
		    || $hasStarted   # The above issue is fixed with that
		   )
		{
			my @length              = split (/\t/, $line);
			my $length              = $length[1];
			my $distance_travelled  = $length[2];

			if($length != 0.0)
			{
				my $distance_per_length = $distance_travelled/$length; # Calculate the distance/length parameter for each track
				push (@distance_per_length, $distance_per_length);
				if($saveDistances){ print DISTANCE_PER_LENGTH $distance_per_length, "\n";}
			}
			else
			{
				# For debugging the distances can be saved to a file
				if($distance_travelled >= 0)
				{
					if($saveDistances){ print DISTANCE_PER_LENGTH Math::BigFloat->binf(), "\n";}
				}
				else
				{
					if($saveDistances){ print DISTANCE_PER_LENGTH Math::BigFloat->binf('-'), "\n";}
				}
			}
		}
		else
		{
			# Scan the file until we reach the dinstance traveled section and then we parse the distances
			if($hasStarted == 0 && $line =~ m/Track/ && $line =~ m/Length/ && $line =~ m/Distance traveled/)
			{
				$hasStarted = 1;
			}
		}
	}

	close TRACKS_IN;
	if($saveDistances){ close DISTANCE_PER_LENGTH;}

	return @distance_per_length;
}

########################################################
# ReadDistances2 reads the distances for each track    #
# from mTrack output.                                  #
# infile is the file that it reads the distances from. #
########################################################
sub ReadDistances3
{
	my $saveDistances = 0;
	my $infile = shift;
	
	my($filename, $path, $suffix) = fileparse($infile, qr/\.[^.]*/);

	my $prefixed_infile = File::Spec->catfile($path, "Summary_" . $filename . $suffix);
	my $distance_file   = File::Spec->catfile($path, $filename . "_distance_per_length.txt");


	open (TRACKS_IN, "<$prefixed_infile") or die "Error: ", print "\nCannot open file!\n$! \n", $prefixed_infile, "\n";

	# For debugging the distances can be saved to a file
	if($saveDistances){ open (DISTANCE_PER_LENGTH, ">$distance_file") or die "Error: ", print "\nCannot open file!\n$! \n", $distance_file, "\n";}

	my @distance_per_length = ();

	# We check the number of track blocks, the track lengths and number of tracks by looking at the second number in the last line "Tracks"
	while (defined (my $line = <TRACKS_IN>))
	{
		unless ($line =~ m/Track/)
		{
			my @length              = split (/\t/, $line);
			my $length              = $length[2];
			my $distance_travelled  = $length[3];

			if($length != 0.0)
			{
				my $distance_per_length = $distance_travelled/$length; # Calculate the distance/length parameter for each track
				push (@distance_per_length, $distance_per_length);
				if($saveDistances){ print DISTANCE_PER_LENGTH $distance_per_length, "\n";}
			}
			else
			{
				# For debugging, the distances can be saved to a file
				if($distance_travelled >= 0)
				{
					if($saveDistances){ print DISTANCE_PER_LENGTH Math::BigFloat->binf(), "\n";}
				}
				else
				{
					if($saveDistances){ print DISTANCE_PER_LENGTH Math::BigFloat->binf('-'), "\n";}
				}
			}
		}
	}

	close TRACKS_IN;
	if($saveDistances){ close DISTANCE_PER_LENGTH;}

	return @distance_per_length;
}

1; # Return that everything is fine






