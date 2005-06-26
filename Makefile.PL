use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Curses::UI::Grid',
    'VERSION_FROM'	=> 'lib/Curses/UI/Grid.pm', # finds $VERSION
    'PREREQ_PM'         => {Curses::UI => 0}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/Curses/UI/Grid.pm', # retrieve abstract from module
       AUTHOR     => 'Adrian Witas <adrian@wsi.edu.pl>') : ()),
);
