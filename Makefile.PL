use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'MPX::RIF',
    AUTHOR              => q{Maurice Mengel <mauricemengel@gmail.com>},
    VERSION_FROM        => 'lib/MPX/RIF.pm',
    ABSTRACT_FROM       => 'lib/MPX/RIF.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'MPX-RIF-*' },
);
