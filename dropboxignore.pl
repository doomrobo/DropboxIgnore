#!/usr/bin/perl

use warnings;
use strict;

use constant DEBUG => 0;
use Switch;
use File::Path "make_path";
use File::Copy "move";
use File::Touch;
use Cwd "abs_path";

my $ignorefile = ".dropboxignore";
my $lockfile = "/var/lock/dropboxignore.lck";
my $cachefile = "/usr/share/dropboxignore/cache.txt";

my ($linked, $real);

my %linked_files;

sub debug {
	my $pretxt;
	if (defined($_[1])) {
		for (0..$_[1]-1) { 
			$pretxt .= "\t";
		}
	}
	$pretxt .= "DEBUG: ";
	print STDERR "$pretxt$_[0]" if DEBUG;
}

sub daemonize {
	my $pid = fork();

	if (!$pid) {
		&{$_[0]};
	} else {
		print "Child is $pid\n";
		exit 0;
	}
}

sub dosymlink {
	my ($sourcedir, $targetdir, $file) = @_;
	debug("Making symlink for $file\n");
	if (-e "$targetdir/$file") {
		debug("Link already exists!\n", 1);
		return;
	}
	if (!-e $targetdir) {  # Create folder if it doesn't exist
		make_path($targetdir);
	}
	debug("Linking $sourcedir/$file to $targetdir/$file");
	symlink("$sourcedir/$file", "$targetdir/$file");
}

sub sync_files {
	my ($local, $remote, @to_link_arr) = @_;
	my %to_link = map { $_ => 1 } @to_link_arr;

	foreach my $file (@to_link_arr) {
		if (!-e "$remote/$file") {
			# If link is deleted, so must be the hard file to it
			if ($linked_files{"$local/$file"}) { # If we know it has been linked in the past (not new)
				debug("Original $file has been deleted\n");
				unlink "$local/$file";
				delete $linked_files{"$local/$file"};
			} elsif (!-d "$local/$file") {
				dosymlink($local, "$remote", $file);
				debug("Linked $local/$file\n");
				$linked_files{"$local/$file"} = 1;
			}
		}
	}

	my $dh;
	if (!opendir($dh, $remote)) {
		return;   # Failed to open directory (doesn't exist)
	}

	my $empty = 1;

	# If a file is deleted, so must be the link to it
	foreach my $file (readdir $dh) {
		if ($file !~ m/(\.){1,2}/) {
			$empty = 0;
		}

		# If real file exists, move it locally and link it
		if (-f "$remote/$file" && !-l "$remote/$file") {
			debug("Moving \"$remote/$file\" to \"$local\"");
			move("$remote/$file", "$local/$file");
			symlink("$local/$file", "$remote/$file\n");
		}

		# If original file was deleted, delete link
		elsif (!defined($to_link{$file})) {
			debug("Removing link \"$remote/$file\"\n");
			unlink "$remote/$file";
		}
	}

	if ($empty) {
		debug("Empty directory\n");
		rmdir $remote;
	}
}

sub loadignore {
	my ($base, $subdir) = @_;
	my $fulldir = "$base/$subdir";
	my ($dh, $IGN_FILE);
	if (!opendir($dh, $fulldir) ||
		!open($IGN_FILE, "<$fulldir/$ignorefile")) {
		die if DEBUG;
		return -1;
	}
	my @files = readdir($dh);
	my %to_link = map { $_ => 1 } @files;

	my @no_link;

	while(my $line = readline($IGN_FILE)) {
		chomp $line;
		foreach my $file (@files) {
			# We don't want to link to "." or ".."
			if ($file =~ m/^(\.){1,2}$/ || -d "$fulldir/$file") {
				next;
			}
			elsif ($file !~ m/$line/) {
				debug("$file doesn't match \"$line\"\n");
			} else {
				debug("$file matches \"$line\"\n");
				push(@no_link, $file);
			}
		}
	}
	debug("\@no_link = @no_link\n");
	delete @to_link{@no_link};
	sync_files($fulldir, "$linked/$subdir", keys %to_link)
}

sub iterate {
	# Remains constant
	my ($prefix, $dir) = @_;
	if (!$dir) {
		$dir = ".";
	}

	#print "Checking $prefix/$dir/$ignorefile\t| ";
	my $linkall;
	my @to_link;

	if (-e "$prefix/$dir/$ignorefile") {
		#	print "Yes\n";
		loadignore($prefix, $dir);
	} else {
		#print "No\n";
		$linkall = 1;
	}

	my $dh;
	if (!opendir($dh, "$prefix/$dir")) {return -1;}
	foreach my $item (readdir($dh)) {
		my $special = $item =~ m/^(\.){1,2}$/;
		debug("$item\n", 1);
		if (-d "$prefix/$dir/$item" && !$special) {
			debug("Going to $dir/$item\n\n");
			iterate($prefix, "$dir/$item");
			debug("Back in $prefix/$dir:\n");
		} elsif ($linkall && -f "$prefix/$dir/$item") {
			push(@to_link, $item);
		}
	}
	if ($linkall) {
		sync_files("$prefix/$dir", "$linked/$dir", @to_link);
	}
	debug("Backing out...\n\n");
}

sub usage {
	print "\nUsage:\n\n";
	print "[stop]\n";
	print "[-l] <path to lock file>\n\n";
}

sub main {
	if (!touch($lockfile) || !unlink $lockfile) {
		die "Error preparing lock file!\nExiting...\n";
	}

	while (!(-e $lockfile)) {
		iterate($real);
	}
	unlink $lockfile;
}

my $action = $ARGV[0];
my $stop;

if ($action eq "stop") {
	$stop = 1;

	if ($#ARGV > 1 && $ARGV[1] eq "-l") {
		$lockfile = $ARGV[2];
	}

	if (!touch($lockfile)) {
		die "Error creating lock file!\n";
	}

	exit;

} else {
	if ($#ARGV < 2) {
		usage;
		exit;
	}

	$real = abs_path($ARGV[0]);
	$linked = abs_path($ARGV[1]);

	debug("Real is $real\nLinked is $linked\n");

	if (-d $real) {
		print "Directory already exists, are you sure you want to continue?[y/n] ";
		exit 0 if !(<STDIN> =~ /^y$/);
	}
}

for my $argnum (2..$#ARGV) {
	if (substr($ARGV[$argnum], 0, 1) eq "-") {
		switch (substr($ARGV[$argnum], 1, 1)) {
			case "l" { $lockfile = $ARGV[$argnum+1];}
			else {usage; exit;}
		}
	}
}

if ($stop) {
	touch($lockfile);
}

#daemonize(\&main);
&main;
