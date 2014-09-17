use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Benchmark::CSV;

our $VERSION = '0.001000';

use Path::Tiny;
use Carp qw( croak );
use Time::HiRes qw( gettimeofday tv_interval );
use IO::Handle;
use List::Util qw( shuffle );

# ABSTRACT: Report raw timing results in CSV-style format for advanced processing.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

sub new {
  my ( $self, @rest ) = @_;
  return bless { ref $rest[0] ? %{ $rest[0] } : @rest }, $self;
}

sub output_fh {
  my $nargs = ( my ( $self, $value ) = @_ );
  if ( $nargs >= 2 ) {
    croak 'Cant set output_fh after finalization' if $self->{finalized};
    return ( $self->{output_fh} = $value );
  }
  return $self->{output_fh} if $self->{output_fh};
  if ( not $self->{output} ) {
    return ( $self->{output_fh} = \*STDOUT );
  }
  return ( $self->{output_fh} = Path::Tiny::path( $self->{output} )->openw );
}

sub sample_size {
  my $nargs = ( my ( $self, $value ) = @_ );
  if ( $nargs >= 2 ) {
    croak 'Cant set sample_size after finalization' if $self->{finalized};
    return ( $self->{sample_size} = $value );
  }
  return $self->{sample_size} if defined $self->{sample_size};
  return ( $self->{sample_size} = 1 );
}

sub add_instance {
  my $nargs = ( my ( $self, $name, $method ) = @_ );
  croak 'Too few arguments to ->add_instance( name => sub { })' if $nargs < 3;
  croak 'Cant add instances after execution/finalization' if $self->{finalized};
  $self->{instances} ||= {};
  croak "Cant add instance $name more than once" if exists $self->{instances}->{$name};
  $self->{instances}->{$name} = $method;
  return;
}

sub _compile_timer {
  ## no critic (Variables::ProhibitUnusedVarsStricter)
  my ( undef, $name, $code, $sample_size ) = @_;
  ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars);
  my $run_one = q[ $code->(); ];
  my $run_batch = join qq[\n], map { $run_one } 1 .. $sample_size;
  my $sub;
  my $build_sub = <<"EOF";
  \$sub = sub {
    my \$start = [ gettimeofday ];
    $run_batch;
    return ( \$name, sprintf '%f', tv_interval( \$start, [ gettimeofday ]) );
  };
  1
EOF
  local $@ = undef;
  ## no critic (BuiltinFunctions::ProhibitStringyEval, Lax::ProhibitStringyEval::ExceptForRequire)
  croak $@ unless eval $build_sub;
  return $sub;
}

sub _write_header {
  my ($self) = @_;
  return if $self->{headers_written};
  $self->output_fh->printf( "%s\n", join q[,], sort keys %{ $self->{instances} } );
  $self->{headers_written} = 1;
  $self->{finalized}       = 1;
  return;
}

sub _write_result {
  my ( $self, $result ) = @_;
  $self->output_fh->printf( "%s\n", join q[,], map { $result->{$_} } sort keys %{$result} );
  return;
}

sub run_iterations {
  my $nargs = ( my ( $self, $count ) = @_ );
  croak 'Arguments missing to ->run_iterations( num )' if $nargs < 2;
  $self->_write_header;
  my $sample_size = $self->sample_size;
  my $timers      = {};
  for my $instance ( keys %{ $self->{instances} } ) {
    $timers->{$instance} = $self->_compile_timer( $instance, $self->{instances}->{$instance}, $sample_size );
  }
  my @timer_names = keys %{$timers};
  for ( 1 .. ( $count / $sample_size ) ) {
    $self->_write_result( { map { $timers->{$_}->() } shuffle @timer_names } );
  }
  $self->output_fh->flush;
  return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Benchmark::CSV - Report raw timing results in CSV-style format for advanced processing.

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

  use Benchmark::CSV;

  my $benchmark = Benchmark::CSV->new(
    output => './test.csv',
    sample_size => 10,
  );

  $benchmark->add_instance( 'method_a' => sub {});
  $benchmark->add_instance( 'method_b' => sub {});

  $benchmark->run_iterations(100_000);

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
