use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'Curses::UI::Grid',
    AUTHOR             => q{Adrian Witas},
    VERSION_FROM       => 'lib/Curses/UI/Grid.pm',
    ABSTRACT_FROM      => 'lib/Curses/UI/Grid.pm',
    LICENSE            => 'artistic_2',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
        'Test::Pod'  => '1.51',
    },
    PREREQ_PM => {
        'Curses'     => '0.9609',
        'Curses::UI' => '1.36',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Curses-UI-Grid-*' },
);
