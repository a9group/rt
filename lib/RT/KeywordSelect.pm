#$Header$

package RT::KeywordSelect;

use strict;
use vars qw(@ISA);
use RT::Record;
use RT::Keyword;

@ISA = qw(RT::Record);

# {{{ POD
=head1 NAME

 RT::KeywordSelect - Manipulate an RT::KeywordSelect record

=head1 SYNOPSIS

  use RT::KeywordSelect;

  my $keyword_select = RT::KeywordSelect->new($CurrentUser);
  $keyword_select->Create(
    Keyword     => 20,
    ObjectType => 'Ticket',
    Name       => 'Choices'
  );

  my $keyword_select = RT::KeywordSelect->new($CurrentUser);
  $keyword_select->Create(
    Name        => 'Choices',			  
    Keyword     => 20,
    ObjectType  => 'Ticket',
    ObjectField => 'Queue',
    ObjectValue => 1,
    Single      => 1,
    Depth => 4,
  );

=head1 DESCRIPTION

An B<RT::KeywordSelect> object is a link between a Keyword and a object
type (one of: Ticket), titled by the I<Name> field of the B<RT::Keyword> such
that:

=over 4

=item Object display will contain a field, titled with the I<Name> field and
  showing any descendent keywords which are related to this object via the
  B<RT::ObjectKeywords> table.

=item Object creation for this object will contain a field titled with the
  I<Name> field and containing the descendents of the B<RT::Keyword> as
  choices.  If the I<Single> field of this B<RT::KeywordSelect> is true, each
  object must be associated (via an B<RT::ObjectKeywords> record) to a single
  descendent.  If the I<Single> field is false, each object may be connect to
  zero, one, or many descendents.

=item Searches for this object type will contain a selection field titled with
  the I<Name> field and containing the descendents of the B<RT::Keyword> as
  choices.

=item If I<ObjectField> is defined (one of: Queue), all of the above apply only
  when the value of I<ObjectField> (Queue) in B<ObjectType> (Ticket) matches
  I<ObjectValue>.

=back

=head1 METHODS

=over 4

=item new CURRENT_USER

Takes a single argument, an RT::CurrentUser object.  Instantiates a new
(uncreated) RT::KeywordSelect object.

=cut
# }}}

# {{{ sub _Init
sub _Init {
    my $self = shift;
    $self->{'table'} = "KeywordSelects";
    $self->SUPER::_Init(@_);
}
# }}}

# {{{ sub _Accessible
sub _Accessible {
    my $self = shift;
    my %Cols = (
		Name => 'read/write',
		Keyword => 'read/write', # link to Keywords.  Can be specified by id
		Single => 'read/write', # bool (described below)

		Depth => 'read/write', #- If non-zero, limits the descendents to this number of levels deep.
		ObjectType  => 'read/write', # currently only C<Ticket>
		ObjectField => 'read/write', #optional, currently only C<Queue>
		ObjectValue => 'read/write', #constrains KeywordSelect function to when B<ObjectType>.I<ObjectField> equals I<ObjectValue>
		Disabled => 'read/write'
	       );
    return($self->SUPER::_Accessible(@_, %Cols));  
}
# }}}


# {{{ sub LoadByName

=head2 LoadByName( Name => [NAME], Queue => [QUEUE_ID])
.  Takes a queue id and a keyword select name. 
    tries to load the keyword select for that queue. if that fails, it tries to load it
    without a queue specified.

=cut


sub LoadByName {
    my $self = shift;
    my %args = ( Name => undef,
		 Queue => undef,
		 @_
	       );
    if ($args{'Queue'}) {
	#Try to get the keyword select for this queue
	$self->LoadByCols( Name => $args{'Name'}, 
			   ObjectType => 'Ticket', 
			   ObjectField => 'Queue', 
			   ObjectValue => $args{'Queue'});
    }	
    unless ($self->Id) { #if that failed to load an object
	#Try to get the keyword select of that name that's global
	$self->LoadByCols( Name => $args{'Name'}, 
			   ObjectType => 'Ticket', 
			   ObjectField => 'Queue', 
			   ObjectValue => '0');
    }
    
    return($self->Id);
    
}

# }}}

# {{{ sub Create
=item Create KEY => VALUE, ...

Takes a list of key/value pairs and creates a the object.  Returns the id of
the newly created record, or false if there was an error.

Keys are:

Keyword - link to Keywords.  Can be specified by id.
Name - A name for this KeywordSelect
Single - bool (described above)
Depth - If non-zero, limits the descendents to this number of levels deep.
ObjectType - currently only C<Ticket>
ObjectField - optional, currently only C<Queue>
ObjectValue - constrains KeywordSelect function to when B<ObjectType>.I<ObjectField> equals I<ObjectValue>

=cut

sub Create {
    my $self = shift;
    my %args = ( Keyword => undef,
		 Single => 1,
		 Depth => 0,
		 Name => undef,
		 ObjectType => undef,
		 ObjectField => undef,
		 ObjectValue => undef,
		 @_);
# TODO +++ ACL
#    unless ($self->CurrentUserHasRight('ModifyKeywordSelects')) {
#        $RT::Logger->debug("CurrentUser can't modify KeywordSelects for ".$self->Queue."\n");
#	return (undef, 'Permission denied');
#    }

    my $Keyword = new RT::Keyword($self->CurrentUser);
    
    if ( $args{'Keyword'} && $args{'Keyword'} !~ /^\d+$/ ) {
	$Keyword->LoadByPath($args{'Keyword'});
    }	
    else {
	$Keyword->Load($args{'Keyword'});
    }

    unless ($Keyword->Id) {
	$RT::Logger->debug("Keyword ".$args{'Keyword'} ." not found\n");
	return(undef, 'Keyword not found');
    }
    
    $args{'Name'} = $Keyword->Name if  (!$args{'Name'});
    
    return($self->SUPER::Create( Name => $args{'Name'},
				 Keyword => $Keyword->Id,
				 Single => $args{'Single'},
				 Depth => $args{'Depth'},
				 ObjectType => $args{'ObjectType'},
				 ObjectField => $args{'ObjectField'},
				 ObjectValue => $args{'ObjectValue'}));
    
    
}
# }}}

# {{{ sub KeywordObj

=item KeywordObj

Returns the B<RT::Keyword> referenced by the I<Keyword> field.

=cut

sub KeywordObj {
    my $self = shift;

    my $Keyword = new RT::Keyword($self->CurrentUser);
    $Keyword->Load( $self->Keyword ); #or ?
    return($Keyword);
} 
# }}}

# {{{ sub Object

=item Object

Returns the object (currently only RT::Queue) specified by ObjectField and ObjectValue.

=cut

sub Object {
    my $self = shift;
    if ( $self->ObjectField eq 'Queue' ) {
	my $Queue = new RT::Queue($self->CurrentUser);
	$Queue->Load( $self->ObjectValue );
	return ($Queue);
    } else {
	return (undef);
    }
}

# }}}

# {{{ sub _Set

# does an acl check, then passes off the call
sub _Set {
    my $self = shift;

    unless ($self->CurrentUserHasRight('ModifyKeywordSelects')) {
        $RT::Logger->debug("CurrentUser can't modify KeywordSelects for ".$self->Queue."\n");
	return (undef);
    }

    return $self->SUPER::_Set(@_);

}
# }}}

# {{{ sub CurrentUserHasRight

=item CurrentUserHasRight

Helper menthod for HasRight. Presets Principal to CurrentUser then 
calls HasRight.

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;
    return ($self->HasRight( Principal => $self->CurrentUser->UserObj,
                             Right => $right ));
    
}

# }}}

# {{{ sub HasRight

=item HasRight

Takes a param-hash consisting of "Right" and "Principal"  Principal is 
an RT::User object or an RT::CurrentUser object. "Right" is a textual
Right string that applies to KeywordSelects

=cut

sub HasRight {
    my $self = shift;
    my %args = ( Right => undef,
                 Principal => undef,
                 @_ );

    if (($self->__Value('ObjectField') eq 'Queue') and
	($self->__Value('ObjectValue') >0 )) {
        return ( $args{'Principal'}->HasQueueRight( 
						   Right => $args{'Right'},
						   Queue => $self->SUPER::_Value('Queue') )); 
    }
    else {
        return( $args{'Principal'}->HasSystemRight( $args{'Right'} ));
    }
}
# }}}

=back

=head1 AUTHORS

Ivan Kohler <ivan-rt@420.am>, Jesse Vincent <jesse@fsck.com>

=head1 BUGS

Yes.

=head1 SEE ALSO

L<RT::KeywordSelects>, L<RT::Keyword>, L<RT::Keywords>, L<RT::ObjectKeyword>,
L<RT::ObjectKeywords>, L<RT::Record>

=cut

1;

