#!/usr/bin/perl

use strict;
use Lingua::Stem;

while(<>) {
    my $sent = $_;
    $sent =~ s/\d//g;
    $sent =~ s/[;,.]//g;
    $sent =~ s/\(\s*?\)//g;
    $sent =~ s/[^!-~\s]//g;
    $sent =~ s,\c[A-Z],,g;
    $sent =~ s/\W/ /g;
    $sent =~ s/\s+/ /g;
    $sent = lc($sent);
    $sent = stem($sent);
    print $sent;
}

sub stem {
    my $line = shift;

    my $stemmer = Lingua::Stem->new(-locale => 'EN-US');
    $stemmer->stem_caching({ -level => 2 });
    my @words = split(/\s+/, $line);

    my @stemmed = @{$stemmer->stem(@words)};
    my $stem = join(" ",@stemmed);
    return $stem;
}
