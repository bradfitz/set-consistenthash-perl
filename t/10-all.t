#!/usr/bin/perl

use Test::More tests => 1;

use Set::ConsistentHash;
use Digest::SHA1 qw(sha1);
use String::CRC32 qw(crc32);;
use Data::Dumper;

my $set = Set::ConsistentHash->new;
$set->modify_targets(
                     A => 1,
                     B => 1,
                     C => 2,
                     );

my $set2 = Set::ConsistentHash->new;
$set2->modify_targets(
                      A => 1,
                      B => 1,
                      C => 1,
                      );

print Dumper($set->bucket_counts);
print Dumper($set2->bucket_counts);


if (0) {
    my %matched;
    my $total_trials = 100_000;
    for my $n (1..$total_trials) {
        my $rand = crc32("trial$n");
        my $server = $set->target_of_point($rand);
        #print "matched $rand = $server\n";
        $matched{$server}++;
    }

    foreach my $s ($set->targets) {
        printf("$s: expected=%0.02f%%  actual=%0.02f%%\n", #  space=%0.02f%%\n",
               $set->weight_percentage($s),
               100 * $matched{$s} / $total_trials,
               #($space{$s} / 2**32) * 100,
               );
    }
}

if (1) {
    my $total_trials = 100_000;
    my %tran;
    for my $n (1..$total_trials) {
        my $rand = crc32("trial$n");
        #my $s1 = $set->target_of_point($rand);
        #my $s2 = $set2->target_of_point($rand);

        my $s1 = $set->target_of_bucket($rand);
        my $s2 = $set2->target_of_bucket($rand);
        $tran{"$s1-$s2"}++;
        $tran{"$s1-"}++;
        $tran{"-$s2"}++;
    }

    print Dumper(\%tran);
}

pass("dummy test");
