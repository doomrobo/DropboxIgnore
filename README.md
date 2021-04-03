# Dropbox Ignore

## THIS PROJECT IS UNMAINTAINED

If you are on Mac or Linux and are looking for an alternative, check out https://github.com/sp1thas/dropboxignore

## Description

A perl script that allows you to use perl regex to omit certain files from your dropbox. For now, you need three things to use this:

0. A local store of data that you will be linking to Dropbox
0. An empty Dropbox folder
0. Perl

## Usage:
To specify the type of files within a directory you'd like to omit, simply insert the corresponding perl regex on its own line in a file called ".dropboxignore"
Then, to run the script, the command-line syntax is simply:

	perl dropboxignore.pl <path/to/local/store> <path/to/Dropbox>

Now let the magic* do it's work.
Additionally, a "lock" file can be specified. All this does is act as an indicator to the running program that, when the file exists, it needs to stop immediately. The file is specified with the command line parameter -l &lt;lock/file/path&gt;.

To stop, you must type in

	perl dropboxignore.pl stop

Where &lt;pid&gt; is the number from the line "Child is &lt;number&gt;" that printed when you ran the command to start the script. Again, you may use the -l parameter with this command.

<br>
<br>
*This is by no means magic, nor does it work as such. For clear proof of this fact, please refer to the TODO.mkd.
