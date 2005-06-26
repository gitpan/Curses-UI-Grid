###############################################################################
# subclass of Curses::UI::Cell is a widget that can be used to display
# and manipulate cell in grid model
#
# (c) 2004 by Adrian Witas. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as perl itself.
###############################################################################


package Curses::UI::Grid::Cell;


use strict;
use Curses;
use Curses::UI::Common;
use Curses::UI::Grid;

use vars qw(
    $VERSION 
    @ISA
);

$VERSION = '0.01';
@ISA = qw(
    Curses::UI::Grid
    );
    

sub new () {
    my $class = shift;

    my %userargs = @_;
    keys_to_lowercase(\%userargs);
    my %args = ( 
        # Parent info
        -parent          => undef       # the parent object
	,-row		 => undef	# row object
        # Position and size
        ,-x               => 0           # horizontal position (rel. to -window)
	,-w	 	  => undef
        ,-width           => undef       # default width 10
        ,-align       	  => "L"         # align L - left, R - right
	# Initial state
        ,-xpos             => 0           # cursor position

        # General options
        ,-maxlength       => 0           # the maximum length. 0 = infinite
        ,-overwrite       => 1           # immdiately overwrite cell unless function char 
	,-overwritetext	  => 1		 # contol overwrite and function char (internally set)

	# Grid model 
	,-text	   	  => ''	# text
	,-fldname	  => '' # field name for data bididngs
    	,-frozen	  => 0  # field name for data bididngs	        
	,-focusable	  => 1  # internally set 
	,-readonly	  => 0  # readonly ?
        ,%userargs
	# Init values
        ,-focus           => 0
        ,-bg_            => undef        # user defined background color
        ,-fg_            => undef        # user defined font color
    );
    

    # Create the Widget.
    my $this = {%args};
    bless $this;

    $this->{-xoffset}  = 0; #
    $this->{-xpos}     = 0; # X position for cursor in the document
    $this->parent->layout_content;
    return $this;
}

# set layout
sub set_layout ($$$) {
    my $this = shift;
    my $x=shift;
    my $w=shift;
    $this->x($x);
    $this->w($w);
     if($w > 0) { $this->show
     } else { $this->hide; }

return $w;
}	


sub layout_text($) {
   my $this = shift;

   my $r= $this->row;
   my $p=$this->parent;
   my ($width,$w,$a,$t)=($this->width,$this->w,$this->align, $this->text );
   if($r->type ne 'head') {
	my $ret= $p->run_event('-oncelllayout',$this,$t);
	$t=$ret if(defined $ret && !ref($ret));
    }

	return '' unless defined $w;
	
	if($a eq "R" && length($t) > $w ) {
	    $t=substr($t, (length($t)-$w-$this->xoffset) ,$w);
	} 
	if($a eq "L" && abs($this->xoffset) ) {
	    $t=substr($t,-$this->xoffset,$w);
	}


       $t=sprintf("%".($a eq "L"  ? "-":"").$width."s" ,$t);
       $t= $a eq "L" ? substr($t,0,$w) : substr($t, (length($t)-$w),$w);
       $t.=" " if(ref($this->row) && $this->row->type ne "data");

  return $t;
}


sub draw($;) {
    my $this = shift;
    my $no_doupdate = shift || 0;

    # Return immediately if this object is hidden.
    return $this if $this->hidden;
    return $this if $Curses::UI::screen_too_small; 
     my $p=$this->parent;
     my $r=$this->row(1);

   if( $#{$p->{_rows}} > 1 ) {
        $this->{-nocursor}=0;
    } else {
        $this->{-nocursor}=1;
    }

     $r->{-canvasscr}->attron(A_BOLD) if($r->{-focus});
     $this->draw_cell(1,$r);
     $r->{-canvasscr}->attroff(A_BOLD) if($r->{-focus});
     doupdate() unless $no_doupdate;
     $r->{-canvasscr}->move($r->y,$this->xabs_pos);
     $r->{-canvasscr}->noutrefresh;


    return $this;
}    


sub draw_cell($$$) {
    my $this = shift;
    my $no_doupdate = shift || 0;
    my $r = shift;
    $r=$this->row($r);
    # Return immediately if this object is hidden.
    return $this if $this->hidden;
    my $p=$this->parent;
    $p->run_event('-oncelldraw',$this)  if($r->type ne 'head');
    # Let there be color
    my $fg=$r->type ne 'head' ? $this->fg : $p->{-fg};
    my $bg=$r->type ne 'head' ? $this->bg : $p->{-bg};
    my $pair=$p->set_color($fg,$bg,$r->{-canvasscr});
    my ($x,$t)=($this->x,$this->layout_text);
    $t=substr($t,0,$p->canvaswidth-$x) if(length($t)+$x >= $p->canvaswidth);
    $r->{-canvasscr}->addstr($r->y,$x,$t);
    $p->color_off($pair,$r->{-canvasscr});
    return $this;
}

sub text($$) {
    my $this = shift;
    my $text = shift;
    my $result='';
    my $r=$this->row;
    my $p=$this->parent;
    my $type= $r->type || '';
    my $id=$this->id;
    #if row type is head return or set label attribute otherwise cell value
    if(defined $text) {
	if($type eq 'head') { 
	   $this->{-label}=$text; 
	} else {  
	   $r->{-cells}{$id}=$text; 
	}
    }
    
    $result = $type eq 'head' ? $this->{-label} : exists $r->{-cells}{$id} ? $r->{-cells}{$id} :'' if($type) ;
    return $result;
}

sub cursor_right($) {
    my $this = shift;
    $this->overwriteoff;
    $this->xoffset($this->xoffset-1) if($this->xpos()   == ($this->w-1) );
    $this->xpos($this->xpos+1);
    $this->draw(1);
    
    return $this;																	        return $this;	    
}

sub cursor_left($) {
    my $this = shift;
    $this->overwriteoff;
    $this->xoffset($this->xoffset+1) unless($this->xpos($this->xpos));
    $this->xpos($this->xpos-1);
    $this->draw(1);
    return $this;	    
}

sub cursor_to_home($) {
    my $this = shift;
    $this->overwriteoff;
    my ($t,$w,$a)=($this->text,$this->w,$this->align);
    $this->xoffset($a eq "L" ?  $w : (length($t)-$w > 0 ? length($t)-$w: 0 ) );
    $this->xpos( $a eq "L" ? 0 : $w-length($t) );
    $this->draw(1);
}

sub cursor_to_end($) {
    my $this = shift;
    $this->overwriteoff;
    my ($t,$w,$a)=($this->text,$this->w,$this->align);
    $w=$w > length($t) && $a eq "L" ? length($t)+1 : $w;
    $this->xoffset( $a eq "R" ? 0:  $w-1-length($t) ) if( length($t) >= $w) ;
    $this->xpos( $a eq "L" ? $w-1 : $w-1 );
    $this->draw(1);
}

sub delete_character($) {
    my $this = shift;
    my $ch= shift;
    my $p=$this->parent;
    return if $this->readonly;
    my $ret= $p->run_event('-oncellkeypress',$this,$ch);
    return if(defined $ret && !$ret);

    $this->overwriteoff;

    my $text=$this->text;
    my ($xo,$pos,$len,$a,$w)= ($this->xoffset ,$this->text_xpos,$this->w+abs($this->xoffset),$this->align,$this->w);

    return if($a eq "R" && $pos <= 0);  
    $this->xoffset($this->xoffset-1) if($a eq "R" &&  $xo && length($text) - $xo >= $w);
    $this->xoffset($this->xoffset-1) if($a eq "L" && length($text) > $len);
    $pos-- if($a eq "R");
    substr($text, $pos, 1, '') if(abs($pos) <= length($text));
    $this->text($text);
    $this->draw(1);
}

sub backspace($) {
    my $this = shift;
    my $ch= shift;
    return if $this->readonly;
    my $p=$this->parent;
    my $ret= $p->run_event('-oncellkeypress',$this,$ch);
    return if(defined $ret && !$ret);
    $this->overwriteoff;
    my ($a,$xo)=($this->align,$this->xoffset);
    $this->cursor_left;
    $this->delete_character();
    $this->cursor_right  if($a eq "R" );
}

sub add_string($$;) {
    my $this = shift;
    my $ch = shift;
    return if $this->readonly;
    my $p = $this->parent;

    my $ret= $p->run_event('-oncellkeypress',$this,$ch);
    return if(defined $ret && !$ret);

    my @ch = split //, $ch;
    $ch = '';
    foreach (@ch) {
        $ch .= $this->key_to_ascii($_);
    }


    $this->text('') if( $this->overwritetext );

    my ($xo,$pos,$len,$a)= ($this->xoffset ,$this->text_xpos,  length($this->text),$this->align);
    my $text=$this->text;

    substr($text, abs($pos) , 0) = $ch  if($pos <= $len );
    $this->text($text);
    $this->cursor_right if($a eq "L");
    $this->draw();
    $p->run_event('-onaftercellkeypress',$this,$ch);
}



# x of cell
sub x($;) {
    my $this=shift;
    my $x=shift;
    $this->{-x}=$x if(defined $x);
    return $this->{-x};
}

# absolute x position to row
sub xabs_pos($;) {
    my $this=shift;
    my $result="";
    my $xpos=( $this->xpos > ($this->w-1) ? $this->w-1 : $this->xpos );
    $xpos =0 if($xpos < 0);
    return $this->{-x} + $xpos;
}


# cursor relative x pos
sub xpos($;) {
    my $this=shift;
    my $x=shift;
    if(defined $x){ 
	$x = 0 if($x < 0);
	$x= $this->width-1 if($x > $this->width-1 );
        $this->{-xpos}=$x;
    }
    return $this->{-xpos};
}


# cursor position in text
sub text_xpos($;) {
    my $this=shift;
    my ($w,$x,$xo,$a,$l)=($this->w-1,$this->xpos,$this->xoffset,$this->align,length($this->text));    
    return  $a eq "R" ? $l-($w-$x+abs($xo)) : $x-$xo;
}


# offset to x pos
sub xoffset($;) {
    my $this=shift;
    my $xo=shift;
    my ($a,$l,$w)=($this->align,length($this->text),$this->w);

    if( defined($xo) ) {
	if($a eq "L" ) {
        $xo=0 if($xo > 0);
        #$xo=$this->w-1 if($xo < 0);
	} else {
	    $xo=$l-$w if($xo > ($l-$w) && $xo);
	    $xo=0 if($xo < 0);
	}


	$this->{-xoffset}=$xo;
    }
    return $this->{-xoffset};
}


# event of focus
sub event_onfocus()
{
    my $this = shift;
    my $p=$this->parent;
    $this->overwriteon;
    $p->{-cell_idx}=$p->{-cellid2idx}{ $this->{-id} };

    # Store value of cell in case of data change
    if(ref($this->row) && $this->row->type ne 'head' ) {
	$this->row->set_undo_value($this->id,$this->text);
    }
    # Let the parent find another cell to focus
    # if this widget is not focusable.
    $this->{-focus} = 1;
    if( $this->width ne $this->w || $this->hidden ) {
	my $vs=$p->get_vscroll_to_obj($this);
	   $p->vscroll($vs);
    }

    $this->xpos( $this->align eq "L" ? 0 : $this->w-1 );
    $this->xoffset(0);
    $p->run_event('-oncellfocus',$this);
    $this->draw(1);
    return $this;
}


sub event_onblur() {
    my $this = shift;
    my  $p=$this->parent;
    $this->xpos( $this->align eq "L" ? 0 : $this->w-1 );
    $this->xoffset(0);
    my $res= $p->run_event('-oncellblur',$this);

    #if event return values and it's equal 0 then cancell onblur event
    if(defined $res) {
	if($res eq "0") {
	    return '';
	}
    }

    # test cellchange trigger
    if(ref($this->row) && $this->row->type ne 'head' ) {
	my ($undo,$text)=($this->row->get_undo_value($this->id) ,$this->text);
	
	# if data was changed
	if($undo ne $text) {
	    $res= $p->run_event('-oncellchange',$this);
	    #if event return values and it's equal 0 then cancell onblur event
	    if(defined $res) {
		    if($res eq "0") {
			return '';
		    }
	    }
	}
    }
    $p->{-cell_idx_prev}=$p->{-cellid2idx}{ $this->{-id} };
    $this->{-focus} = 0;

    $this->draw;
    return $this;
}

sub overwriteoff() { shift()->{-overwritetext}=0 }
sub overwriteon() { shift()->{-overwritetext}=1 }


sub overwritetext($;) {
    my $this=shift;
    my $result=!$this->{-overwrite} ? $this->{-overwrite}  : $this->{-overwritetext};
    $this->overwriteoff();
    return $result;
}

sub has_focus() {
    my $this=shift;
    my $p=$this->parent;
    my $result=0;
    $result=1 if($this->{-focus});
return $result;
}


sub focus($;) {
    my $this=shift;
    # Let the parent focus this object.
    my $parent = $this->parent;
    $parent->focus($this) if defined $parent;
    $this->draw(1);
    return $this;
}


sub bg() {
    my $this = shift;
    my $bg=shift;
    $this->{-bg_}=$bg if(defined $bg);
    return  $this->{-bg_} ? $this->{-bg_} : exists( $this->{-bg} ) && $this->{-bg} ? $this->{-bg} : $this->row->bg;
}

sub fg() {
    my $this = shift;
    my $fg=shift;
    $this->{-fg_}=$fg if(defined $fg);
    return  $this->{-fg_} ? $this->{-fg_} : exists( $this->{-fg} ) && $this->{-bg} ? $this->{-fg} : $this->row->fg;
}

sub row() {
    my $this = shift;
    my $row= shift;
    $this->{-row} = $row if defined $row;
    $this->{-row}=$this->parent->getactiverow 
	    if(!ref($this->{-row}) ||  ref($this->{-row}) ne 'Curses::UI::Grid::Row');
    return $this->{-row};
}



sub align()  { uc(shift()->{-align})    }
sub frozen() { shift->{-frozen}         }
# defined width
sub width()  { shift->{-width}          }

#current width
sub w($;) {
    my $this=shift;
    my $w=shift;
    $this->{-w}=$w if(defined $w);
    return $this->{-w};
}

sub DESTROY {
    my $this=shift;
    foreach my $k (qw(-canvasscr -parent -row)) {
        delete $this->{$k} if ( $this->{$k}='' );
    }
    foreach my $k( keys %{$this} ) {
        delete $this->{$k};
    }
}

__END__

=pod

=head1 NAME

Curses::UI::Grid::Cell -  Create and manipulate cell in grid model.

=head1 CLASS HIERARCHY

 Curses::UI::Grid
    |
    +----Curses::UI::Cell


=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');
    my $grid =$win->add('mygrid','Grid');

    my $row1=$grid->add_cell( -id=>'cell1'
		             ,-fg=>'blue'
			     ,-bg->'red'
			     ,-frozen=>1
			     ,-align => 'R'
			   );



=head1 DESCRIPTION


       Curses::UI::Grid::Cell is a widget that can be 
       used to manipulate cell in grid model


      See exampes/grid-demo.pl in the distribution for a short demo.



=head1 STANDARD OPTIONS

       -parent,-fg,-bg,-focusable,-width


For an explanation of these standard options, see
L<Curses::UI::Widget|Curses::UI::Widget>.


=head1 WIDGET-SPECIFIC OPTIONS


=over 4


=item * B<-id> ( ID )

This option will be contain the cell id.


=item * B<-frozen> < BOOLEAN >

This option will  make the cell visible on the same place
even if vertical scroll occurs.

<B>Note Only first X column (from right) could be frozen.


=item * B<-align> < ALIGN >

This option will make apropriate align for the data cell.
ALIGN could be either R or L.
R - rigth align;
L - left align;


=item * B<-overwrite> < BOOLEAN >

If BOOLEAN is true, and when add_string  method is called first time
after the cell becomes focused the old value will be cleared 
unless the function key will be pressed earlier. (cursor_left,cursor_to_end,etc.)


=head1 METHODS

=over 4


=item * B<new> ( OPTIONS )

Constructs a new grid object using options in the hash OPTIONS.


=item * B<layout> ( )

Lays out the cell, makes sure it fits
on the available screen.


=item * B<draw> ( BOOLEAN )

Draws the cell object. If BOOLEAN
is true, the screen is not updated after drawing.

By default, BOOLEAN is true so the screen is updated.



=head1 WIDGET-SPECIFIC METHODS

=over 4


=item * B<layout_cell> ( )

Lays out the cell, makes sure it fits
on the available screen.


=item * B<draw_cell> ( BOOLEAN )

Draws the cell object. If BOOLEAN
is true, the screen is not updated after drawing.

By default, BOOLEAN is true so the screen is updated.


=item * B<fg> ( COLOR )

Thid routine could set or get foreground color using -fg_ option .
If -fg_  is NULL then -fg or parent fg color is return.


=item * B<bg> ( COLOR )

Thid routine could set or get background color using -bg_ option.
If -bg_  is NULL then -bg or parent bg color is return.


=item * B<text> ( TEXT )

Thid routine could set or get text value for given cell and active row.

=back

=head1 SEE ALSO
       Curses::UI::Grid::Row Curses::UI::Grid


=head1 AUTHOR

       Copyright (c) 2004 by Adrian Witas. All rights reserved.


=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=pod SCRIPT CATEGORIES

User Interfaces


1;