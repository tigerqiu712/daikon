#!/usr/bin/env perl
# java-cpp -- C preprocessor specialized for Java
# Michael Ernst and Josh Kataoka
# Time-stamp: <2002-07-10 09:09:12 mernst>

# This acts like the C preprocessor, but
#  * it does not remove comments
#  * it cleans up spacing in the processed file

# If last argument is a file, it is used as input.  Otherwise, input comes
# from standard in.  Output goes to standard out.

# Problem:  single quote marks (') in comment can cause "unterminated
# character constant" warnings.
# The workaround is not to use single quotes in comments; for instance,
# avoid contractions and possessives such as "can't", "won't", "Mike's",
# "Josh's".
# (Implementation note:  I do want substitution to occur in comments.
# Therefore, I do not use the -C (leave comments in) flag to cpp, or make
# JAVACPP_DOUBLESLASHCOMMENT put the rest of the line in a string, both
# of which would also avoid the problem but would prevent substitution.)

# I'm not calling this jpp because someone else has probably already taken
# that name.
# This is a script rather than a shell alias so it's sure to work in
# Makefiles, scripts, etc.




# Original csh script:
#
# if (-e $1) then
#   # Last argument is a file
#   set filearg = $1
#   shift
# else
#   set filearg =
# endif
#
# # echo filearg $filearg
# # echo argv $argv
#
# perl -p -w -e 's/\/\//DOUBLESLASHCOMMENT/g;' -e 's/\/\*/SLASHSTARCOMMENT/g;' $filearg > /tmp/java-cpp-$$-input
# cpp $argv java-cpp-$$-input > java-cpp-$$-output
# cat /tmp/java-cpp-$$-output | perl -p -w -e 's/DOUBLESLASHCOMMENT/\/\//g;' -e 's/SLASHSTARCOMMENT/\/\*/g;' -e 's/"  ?\+ "//g;' -e 's/^(package .*\.) ([^ ]*) ?;/$1$2;/;' -e 's/^# [0-9]+ ".*$//;' | perl -p -w -e 'use English; $INPUT_RECORD_SEPARATOR = "";' | lines-from "package"
# # Problem:  doesn't propagate error codes correctly
# rm java-cpp-$$-input java-cpp-$$-output



use English;
use strict;
$WARNING = 1;			# "-w" command-line switch

my $system_temp_dir = -d '/tmp' ? '/tmp' : $ENV{TMP} || $ENV{TEMP} ||
    die "Cannot determine system temporary directory, stopped";
my $tmpfile = "$system_temp_dir/java-cpp-$$";

my $file_handle_nonce = 'fh00';

{
  my $filename;
  if ((scalar(@ARGV) > 0) && (-r $ARGV[$#ARGV])) {
    $filename = pop @ARGV;	# remove last (filename) element
  } else {
    $filename = "-";
  }

  open(TMPFILE, ">$tmpfile") || die "Cannot open $tmpfile: $!\n";
  escape_comments($filename);
  close(TMPFILE);

  run_cpp();
  unlink($tmpfile);
}

exit();

###########################################################################
### Subroutines
###

# Also processes #include directives.
# Perhaps I should instead do this; the advantage would be correct
# "#line" information.
# ## Use of cpp for #include only:
# cpp -C -nostdinc -undef

sub escape_comments ( $ ) {
  my ($filename) = @_;

  # Indirect through this filehandle name in order to make this routine
  # (escape_comments) re-entrant.
  my $inhandle = $file_handle_nonce++;   # this is a string increment

  # print STDERR "Opening $filename\n";

  no strict 'refs';
  open($inhandle, $filename) || die "Can't open $filename: $!\n";

  while (<$inhandle>) {

    if (/^\#include "(.*)"/) {
      escape_comments($1);
      next;
    }
    s|//|JAVACPP_DOUBLESLASHCOMMENT|g;
    s|/\*|JAVACPP_SLASHSTARCOMMENT|g;
    s/\'/JAVACPP_SINGLEQUOTE/g;
    print TMPFILE;
  }
  close($inhandle);

}


sub run_cpp {
  # This causes strings to potentially have many trailing blanks.
  $INPUT_RECORD_SEPARATOR = "";

  my $argv = join(' ', @ARGV);
  open(CPPFILE, "cpp $argv $tmpfile |") || die "Cannot open $tmpfile: $!\n";

  my $post_return_space = "";
  my $next_post_return_space = "";
  while (<CPPFILE>) {
    s|JAVACPP_DOUBLESLASHCOMMENT|//|g;
    s|JAVACPP_SLASHSTARCOMMENT|/\*|g;
    s/JAVACPP_SINGLEQUOTE/\'/g;

    # Convert string concatenation ("a" + "b") single string ("ab").
    s/"  ?\+ "//g;
    # Remove "# 22" lines.
    s/(^|\n)\# [0-9]+ ".*"($|\n)/$1$2/;

    ## Remove extra horizontal space
    # Remove all trailing space
    s/[ \t]+\n/\n/g;
    # Remove space after package name
    s/((?:^|\n)package .*\.) ([^ ]*) ?;/$1$2;/;
    # convert "(Foo )" to "(Foo)"
    s/\((\b[A-Za-z]\w*) \)/($1)/g;
    # convert "a .b" to "a.b".
    s/(\b[A-Za-z]\w*) \.([A-Za-z]\w*\b)/$1.$2/g;
    # convert "a. foo (" to "a.foo("
    # (Note single spaces, lowercase first letter.)
    s/(\b[A-Za-z]\w*)\. ([a-z]\w*) \(/$1.$2\(/g;
    # convert " instanceof long [])" to " instanceof long[])"
    s/( instanceof \w+) ((\[\])*\))/$1$2/g;

    ## Remove extra vertical space
    # compress out duplicate blank lines
    s/\n\n\n+/\n\n/g;
    # This does not work:  it applies to *every* paragraph.
    # # compress out blank lines at end (due to the above, this can be simpler)
    # s/\n\n\z/\n/;
    # Remove newline after "if" statement
    # if no open curly brace or semicolon but 2 newlines.
    if (/^[ \t]*if[ \t]*\([^\n\{;]*\n\n\z/) {
      # not "chomp":  it removes all of the trailing newlines rather than one
      s/\n\z//;
    }
    # Remove newline after "return" statement if followed by 2 nelines and
    # open curly brace.  But I have no way of knowing that open curly follows.
    # Thus, the post_return_space hack.
    if (/\breturn [^\n]*;\n\n\z/) {
      s/\n\z//;
      $next_post_return_space = "\n";
    }

    # Skip if nothing to print (eg, if this paragraph was just a "# 22" line)
    if (! /[^\n]/) { next; }

    if (/^[ \t]*\}/) {
      $post_return_space = "";
    }
    print $post_return_space;
    $post_return_space = $next_post_return_space;
    $next_post_return_space = "";

    print;
  }

  close(CPPFILE);
}
