package Set::ConsistentHash;
use strict;
use Digest::SHA1 qw(sha1);
use vars qw($VERSION);
$VERSION = '1.00';

=head1 NAME

Set::ConsistentHash - library for doing consistent hashing

=head1 SYNOPSIS

  my $set = Set::ConsistentHash->new;

=head1 OVERVIEW

Description, shamelessly stolen from Wikipedia:

  Consistent hashing is a scheme that provides hash table
  functionality in a way that the addition or removal of one slot does
  not significantly change the mapping of keys to slots. In contrast,
  in most traditional hash tables, a change in the number of array
  slots causes nearly all keys to be remapped.

  Consistent hashing was introduced in 1997 as a way of distributing
  requests among a changing population of web servers. More recently,
  it and similar techniques have been employed in distributed hash
  tables.

You're encouraged to read the original paper, linked below.

=head1 CLASS METHODS

=head2 new

  $set = Set::ConsistentHash->new;

Takes no options.  Creates a new consistent hashing set with no
items.  You'll need to add items.

=cut

# creates a new consistent hashing set with no targets.  you'll need to add targets.
sub new {
    my ($class) = @_;
    return bless {
        weights => {},  # $target => integer $weight
        points  => {},  # 32-bit value points on 'circle' => \$target
        order   => [],  # 32-bit points, sorted
        buckets      => undef, # when requested, arrayref of 1024 buckets mapping to targets
        total_weight => undef, # when requested, total weight of all targets
    }, $class;
}

=head1 INSTANCE METHODS

=cut

# returns sorted list of all configured $targets
sub targets {
    my $self = shift;
    return sort keys %{$self->{weights}};
}


# returns sum of all target's weight
sub total_weight {
    my $self = shift;
    return $self->{total_weight} if defined $self->{total_weight};
    my $sum = 0;
    foreach my $val (values %{$self->{weights}}) {
        $sum += $val;
    }
    return $self->{total_weight} = $sum;
}

# returns the configured weight percentage [0,100] of a target.
sub weight_percentage {
    my ($self, $target) = @_;
    return 0 unless $self->{weights}{$target};
    return 100 * $self->{weights}{$target} / $self->total_weight;
}

# remove all targets
sub reset_targets {
    my $self = shift;
    $self->modify_targets(map { $_ => 0 } $self->targets);
}

# add/modify targets.  parameters are %weights:  $target -> $weight
sub modify_targets {
    my ($self, %weights) = @_;

    # uncache stuff:
    $self->{total_weight} = undef;
    $self->{buckets}      = undef;

    while (my ($target, $weight) = each %weights) {
        if ($weight) {
            $self->{weights}{$target} = $weight;
        } else {
            delete $self->{weight}{$target};
        }
    }
    $self->_redo_circle;
}
*modify_target = \&modify_targets;

sub _redo_circle {
    my $self = shift;

    my $pts = $self->{points} = {};
    while (my ($target, $weight) = each %{$self->{weights}}) {
        my $num_pts = $weight * 100;
        foreach my $ptn (1..$num_pts) {
            my $key = "$target-$ptn";
            my $val = unpack("L", substr(sha1($key), 0, 4));
            $pts->{$val} = \$target;
        }
    }

    $self->{order} = [ sort { $a <=> $b } keys %$pts ];
}

# returns arrayref of 1024 buckets.  each array element is the $target for that bucket index.
sub buckets {
    my $self = shift;
    return $self->{buckets} if $self->{buckets};
    my $buckets = $self->{buckets} = [];
    my $by = 2**22;  # 2**32 / 2**10 (1024)
    for my $n (0..1023) {
        my $pt = $n * $by;
        $buckets->[$n] = $self->target_of_point($pt);
    }

    return $buckets;
}

# returns hashref of $target -> $number of occurences in 1024 buckets
sub bucket_counts {
    my $self = shift;
    my $ct = {};
    foreach my $t (@{ $self->buckets }) {
        $ct->{$t}++;
    }
    return $ct;
}

# given an integer, returns $target (after modding on 1024 buckets)
sub target_of_bucket {
    my ($self, $bucketpos) = @_;
    return ($self->{buckets} || $self->buckets)->[$bucketpos % 1024];
}

# given a $point [0,2**32), returns the $target that's next going around the circle
sub target_of_point {
    my ($self, $pt) = @_;  # $pt is 32-bit unsigned integer

    my $order = $self->{order};
    my $circle_pt = $self->{points};

    my ($lo, $hi) = (0, scalar(@$order)-1);  # inclusive candidates

    while (1) {
        my $mid           = int(($lo + $hi) / 2);
        my $val_at_mid    = $order->[$mid];
        my $val_one_below = $mid ? $order->[$mid-1] : 0;

        # match
        return ${ $circle_pt->{$order->[$mid]} } if
            $pt <= $val_at_mid && $pt > $val_one_below;

        # wrap-around match
        return ${ $circle_pt->{$order->[0]} } if
            $lo == $hi;

        # too low, go up.
        if ($val_at_mid < $pt) {
            $lo = $mid + 1;
            $lo = $hi if $lo > $hi;
        }
        # too high
        else {
            $hi = $mid - 1;
            $hi = $lo if $hi < $lo;
        }

        next;
    }
};

=head1 REFERENCES

L<http://en.wikipedia.org/wiki/Consistent_hashing>

L<http://www8.org/w8-papers/2a-webserver/caching/paper2.html>

=head1 AUTHOR

Brad Fitzpatrick -- brad@danga.com

=head1 COPYRIGHT & LICENSE

Copyright 2007, Six Apart, Ltd.

You're granted permission to use this code under the same terms as Perl itself.

=head1 WARRANTY

This is free software.  It comes with no warranty of any kind.

=cut

1;
