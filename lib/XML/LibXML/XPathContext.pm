# $Id: XPathContext.pm 422 2002-11-08 17:10:30Z phish $
#
# This is free software, you may use it and distribute it under the same terms as
# Perl itself.
#
# Copyright 2001-2003 AxKit.com Ltd., 2002-2006 Christian Glahn, 2006-2009 Petr Pajas
#
#

package XML::LibXML::XPathContext;

use strict;
use warnings;
use vars qw($VERSION @ISA $USE_LIBXML_DATA_TYPES);

use Carp;
use XML::LibXML;
use XML::LibXML::NodeList;

$VERSION = "2.0208"; # VERSION TEMPLATE: DO NOT CHANGE

# should LibXML XPath data types be used for simple objects
# when passing parameters to extension functions (default: no)
$USE_LIBXML_DATA_TYPES = 0;

sub CLONE_SKIP { 1 }

sub findnodes {
    my ($self, $xpath, $node) = @_;

    my @nodes = $self->_guarded_find_call('_findnodes', $node, $xpath);

    if (wantarray) {
        return @nodes;
    }
    else {
        return XML::LibXML::NodeList->new(@nodes);
    }
}

sub find {
    my ($self, $xpath, $node) = @_;

    my ($type, @params) = $self->_guarded_find_call('_find', $node, $xpath,0);

    if ($type) {
        return $type->new(@params);
    }
    return undef;
}

sub exists {
    my ($self, $xpath, $node) = @_;
    my (undef, $value) = $self->_guarded_find_call('_find', $node, $xpath,1);
    return $value;
}

sub findvalue {
    my $self = shift;
    return $self->find(@_)->to_literal->value;
}

sub _guarded_find_call {
    my ($self, $method, $node)=(shift,shift,shift);

    my $prev_node;
    if (ref($node)) {
        $prev_node = $self->getContextNode();
        $self->setContextNode($node);
    }
    my @ret;
    eval {
        @ret = $self->$method(@_);
    };
    $self->_free_node_pool;
    $self->setContextNode($prev_node) if ref($node);

    if ($@) {
      my $err = $@;
      chomp $err;
      croak $err;
    }

    return @ret;
}

sub registerFunction {
    my ($self, $name, $sub) = @_;
    $self->registerFunctionNS($name, undef, $sub);
    return;
}

sub unregisterNs {
    my ($self, $prefix) = @_;
    $self->registerNs($prefix, undef);
    return;
}

sub unregisterFunction {
    my ($self, $name) = @_;
    $self->registerFunctionNS($name, undef, undef);
    return;
}

sub unregisterFunctionNS {
    my ($self, $name, $ns) = @_;
    $self->registerFunctionNS($name, $ns, undef);
    return;
}

sub unregisterVarLookupFunc {
    my ($self) = @_;
    $self->registerVarLookupFunc(undef, undef);
    return;
}

# extension function perl dispatcher
# borrowed from XML::LibXSLT

sub _perl_dispatcher {
    my $func = shift;
    my @params = @_;
    my @perlParams;

    my $i = 0;
    while (@params) {
        my $type = shift(@params);
        if ($type eq 'XML::LibXML::Literal' or
            $type eq 'XML::LibXML::Number' or
            $type eq 'XML::LibXML::Boolean')
        {
            my $val = shift(@params);
            unshift(@perlParams, $USE_LIBXML_DATA_TYPES ? $type->new($val) : $val);
        }
        elsif ($type eq 'XML::LibXML::NodeList') {
            my $node_count = shift(@params);
            unshift(@perlParams, $type->new(splice(@params, 0, $node_count)));
        }
    }

    $func = "main::$func" unless ref($func) || $func =~ /(.+)::/;
    no strict 'refs';
    my $res = $func->(@perlParams);
    return $res;
}

1;
