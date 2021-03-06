
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "build cheap mpx from filenames etc.",
  "AUTHOR" => "Maurice Mengel <mauricemengel\@gmail.com>",
  "BUILD_REQUIRES" => {
    "Test::More" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "MPX-RIF",
  "EXE_FILES" => [
    "bin/MIMO-resmvr.pl",
    "bin/mpx-rif.pl",
    "bin/newmulId.pl",
    "bin/rename-images.pl",
    "bin/saxon.pl",
    "bin/testXpath.pl",
    "bin/xpath.pl"
  ],
  "LICENSE" => "perl",
  "NAME" => "MPX::RIF",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Cwd" => 0,
    "Data::Dumper" => 0,
    "Date::Manip" => 0,
    "Encode" => 0,
    "Exporter" => 0,
    "File::Copy" => 0,
    "File::Find" => 0,
    "File::Find::Rule" => 0,
    "File::Spec" => 0,
    "FindBin" => 0,
    "Getopt::Std" => 0,
    "HTTP::OAI" => 0,
    "Image::Magick" => 0,
    "Log::Handler" => 0,
    "Pod::Usage" => 0,
    "SOAP::DateTime" => 0,
    "Time::HiRes" => 0,
    "XML::LibXML" => 0,
    "XML::LibXSLT" => 0,
    "XML::Writer" => 0,
    "YAML::Syck" => 0,
    "YAML::XS" => 0,
    "strict" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.027",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



