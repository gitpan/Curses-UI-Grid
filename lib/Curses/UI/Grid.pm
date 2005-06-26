package Curses::UI::Grid;

###############################################################################
# subclass of Curses::UI::Grid is a widget that can be used to display 
# and manipulate data in grid model 
#
# (c) 2004 by Adrian Witas. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as perl itself.
###############################################################################

use 5.008;
use strict;
use warnings;


use Curses;
use Curses::UI::Widget;
use Curses::UI::Common;

use vars qw(
    $VERSION 
    @ISA
);

$VERSION = '0.10';


@ISA = qw(
    Curses::UI::Common
    Curses::UI::Widget
    );

    
# Configuration: routine name to subroutine mapping.
my %routines = (
    'loose-focus'            => \&loose_focus,
    'cursor-right'           => \&cursor_right,
    'cursor-left'            => \&cursor_left,
    'add-string'             => \&add_string,
    'grid-pageup'            => \&grid_pageup,
    'grid-pagedown'          => \&grid_pagedown,
    'cursor-home'            => \&cursor_to_home,
    'cursor-end'             => \&cursor_to_end,
    'next-cell'		     => \&next_cell,
    'prev-cell'		     => \&prev_cell,
    'next-row'		     => \&next_row,
    'prev-row'		     => \&prev_row,
    'insert-row'	     => \&insert_row,
    'delete-row'	     => \&delete_row,
    'delete-character'	     => \&delete_character,
    'backspace'              => \&backspace,
);

# Configuration: binding to routine name mapping.
my %basebindings = (
    CUI_TAB()                => 'next-cell',
    KEY_ENTER()              => 'next-cell',
    KEY_BTAB()               => 'prev-cell',
    KEY_UP()                 => 'prev-row',
    KEY_DOWN()               => 'next-row',
    KEY_RIGHT()              => 'cursor-right',
    KEY_LEFT()               => 'cursor-left',
    KEY_HOME()              =>  'cursor-home',
    KEY_END()               =>  'cursor-end',

    KEY_PPAGE()              => 'grid-pageup',
    KEY_NPAGE()              => 'grid-pagedown',
);

my %editbindings = (

    ''                       => 'add-string',
    KEY_IC()   		     => 'insert-row',
    KEY_SDC()                => 'delete-row',
    KEY_DC()                 => 'delete-character',
    KEY_BACKSPACE()          => 'backspace',
);


#debug model likes in Curses::UI::Notebook
sub debug_msg(;$) {
    return unless ($Curses::UI::debug);

    my $caller = (caller(1))[3];
    my $msg = shift || '';
    my $indent = ($msg =~ /^(\s+)/ ? $1 : '');
    $msg =~ s/\n/\nDEBUG: $indent/mg;

    warn 'DEBUG: ' .
        ($msg ?
            "$msg in $caller" :
            "$caller() called by " . ((caller(2))[3] || 'main')
        ) .
        "().\n";
}


sub new ()
{

    my $class = shift;
    my %userargs = @_;
    keys_to_lowercase(\%userargs);
    
    # support only arguments listed in @valid_args;
    my @valid_args = (
        'x', 'y', 'width', 'height'
        ,'pad', 'padleft', 'padright', 'padtop', 'padbottom'
        ,'ipad', 'ipadleft', 'ipadright', 'ipadtop', 'ipadbottom'
        ,'border','bg', 'fg' ,'bfg' ,'bbg','titlereverse'
        ,'intellidraw'
        ,'onrowchange'
	,'onfocus','onblur','onnextpage','onprevpage'
	,'onrowdraw','onrowfocus','onrowblur','onrowchange'
	,'onbeforerowinsert','onrowinsert','onrowdelete','onafterrowdelete'
	,'oncelldraw','oncellfocus','oncellblur','oncellchange','oncelllayout','oncellkeypress'
	,'routines', 'basebindings','editbindings'
	,'parent'
	,'rows','columns','editable'
    );
    
    foreach my $arg (keys %userargs) {
        unless (grep($arg eq "-$_", @valid_args)) {
            debug_msg ("  deleting invalid arg '$arg'");
            delete $userargs{$arg};
        }
    }

    my %args = ( 
        # Parent info
        -parent          => undef       # the parent object

        # Position and size
        ,-x               => 0           # horizontal position (rel. to -window)
        ,-y               => 0           # vertical position (rel. to -window)
        ,-width           => undef       # horizontal editsize, undef = stretch
        ,-height          => undef       # vertical editsize, undef = stretch


        # Initial state
        ,-xpos             => 0           # cursor position
        ,-ypos             => 0           # cursor position

        # General options
        ,-border          => undef       # use border?

        ,-vscrollbar      => 0           # show vertical scrollbar
        ,-hscrollbar      => 0           # show horizontal scrollbar
        ,-vscroll      	  => 0           # vertical offset
        ,-hscroll      	  => 0           # horizontal offset
        ,-editable        => 1           # 0 - only used as viewer
	,-focus		  => 1

        # Events
	# grid event
	,-onfocus	 => undef
	,-onblur	 => undef
	,-onnextpage	 => undef
	,-onprevpage	 => undef

	# row event
	,-onrowblur	    => undef
	,-onrowfocus	    => undef
	,-onrowchange	    => undef
	,-onrowdraw	    => undef 
	,-onbeforerowinsert => undef 
	,-onrowinsert       => undef 
	,-onrowdelete       => undef 
	,-onafterrowdelete  => undef
	# cell event
	,-oncellblur	      => undef
	,-oncellfocus	      => undef
	,-oncellchange	      => undef
	,-oncelldraw	      => undef
	,-oncellkeypress      => undef
	,-oncelllayout	      => undef


	# Grid model 
	,-columns 	 => 0	# number of coluns
	,-rows		 => 0	# number of rows
	,-page_size	 => 0   # max number rows in grid = canvasheight - 2
	,-row_idx_prev	 => 0	# previous row idx
	,-row_idx 	 => 0	# current index idx
	,-cell_idx_prev	 => 0 	# current cell idx
	,-cell_idx	 => 0 	# current cell idx
	,-count		 => 0	# numbers of all rows from data source
	,-page		 => 0   # current page
	,_cells		 => []  # collection of cells id
	,_rows		 => []  # collection of rows id
	,-focusable      => 1
        ,%userargs
        ,-routines        => {%routines}     # binding routines

	# Init values
        ,-focus           => 0
    );


    #overwrite base bindings
    %basebindings=( %{$args{-basebindings}} ) if exists($args{-basebindings});
    #overwrite base editbindings
    %editbindings=( %{$args{-editbindings}} ) if exists($args{-editbindings});
    
    # Create the Widget.
    my $this = $class->Curses::UI::Widget::new( %args );
    $this->{-page_size} = $this->canvasheight-2;
    $this->add_row('header',%args,-type=>'head');
    $this->set_cells(); 	#if column is not FALSE add empty cells to grid
    $this->set_rows(); 		#if rows is not FALSE add empty rows to grid
    $this->{-xpos}     = 0; 	# X position for cursor in the document
    $this->{-ypos}     = 0; 	# Y position for cursor in the document

    $this->layout_content;		 #layout content
    $this->editable( $args{-editable} ); #set binding as viewer or editable grid
    return $this;
}


#set apptopriate bindings model
sub editable($;) {
    my $this = shift;
    my $editable = shift;

    $this->{-editable} = $editable;
    my %mybindings = ();

    if ($editable) {
        %mybindings = (%basebindings
		     , %editbindings);
    } else {
        %mybindings = (%basebindings);
    }

    $this->{-bindings} = \%mybindings;

    return $this;
}

##############################################################
# Grid model functions
##############################################################

#add empty rows defined as -rows arguments
sub set_rows($;) {

    my $this = shift;
    my %userargs = @_;
    keys_to_lowercase(\%userargs);
    my $rows= exists $userargs{-rows} ? $userargs{-rows} : $this->{-rows};
    for my $i (1  ..  $rows ) {
        $this->add_row("row".$i
		    ,-type=>'data'
	            ,-fg=>-1
    		    ,-bg=>-1
		    ,-cells=>{}
		    );

    }
}


#add empty cells defined as -columns arguments
sub set_cells($;) {

    my $this = shift;
    my %userargs = @_;
    keys_to_lowercase(\%userargs);

    my $cols= $this->{-columns};
    my %args =(-width=>10,%userargs,-align=>"L");
        for my $id(1 .. $cols) {
            $this->add_cell("cell".$id,%args) ;
        }
}


# add new row
sub add_row() {
    my $this=shift;
    my $id=shift;
    my %args=@_;
    my $idx;
    
    if(exists($args{-type}) && $args{-type} eq 'head' ) {
        $idx=0;
	$args{-focusable}=0;
    } else {
	$args{-type}='data';
        $idx=$#{$this->{_rows}}+1;
	$args{-focusable}=1;
	    
	    unless( defined $id ) {
		$id="row".$idx;
    	    }
    }

    return if(exists($this->{-id2row}{$id}));
    return if($idx > $this->{-page_size});
    $this->{-rows}++ if( $args{-type} eq 'data');


    my $obj=$this->add($id,'Curses::UI::Grid::Row',%args,-x=>0,-id=>$id,-y=>$idx );
    $this->{_rows}[ $idx ]=$id;
    $this->{-rowid2idx}{$id}=$idx;
    $this->{-id2row}{$id}=$obj;
    return $obj;
}

# insert data row 
sub delete_row($$;) {
    my $this=shift;
    my $rows=\@{ $this->{_rows} };
    my $row=$this->getfocusrow;

    # trigger ondeleterow event
    my $ret=$this->run_event('-onrowdelete',$row);
    # cancel action delete row if ret is FALSE
    return 0 if(defined $ret && !$ret);
    my $position = $this->{-rowid2idx}{ $row->{-id} };
    $this->shift_row($position,-1); 	
    
    # trigger onafterdeleterow event
    $ret=$this->run_event('-onafterrowdelete',$row);
    $this->del_row;
    $row=$this->getfocusrow;
    $row->event_onfocus if ref($row);
    $this->draw;
    return 1;
}


# insert data row 
sub insert_row($$;) {
    my $this=shift;
    my $pos=shift || 0;
    my $rows=\@{ $this->{_rows} };
    
    my $ps=$this->{-page_size};
    my $row=$this->getfocusrow;


    # test blur event
    my $ret=1;
    $ret=$row->event_onblur if(ref($row));
    # cancel action row insert if ret is FALSE
    return undef if(defined $ret && !$ret);

    # test event onbeforeinsertrow
    $ret=$this->run_event('-onbeforerowinsert',$this);
    # cancel action row insert if ret is FALSE
    return undef if(defined $ret && !$ret);

    # add row obj to end
    $row=$this->{-id2row}{ $$rows[ $#{$rows} ] } if($pos == -1);

    my $position = exists($this->{-rowid2idx}{ $row->{-id} } ) ? $this->{-rowid2idx}{ $row->{-id} }: 0;

    if($position <= $ps) {
	$this->add_row();
	$row=$this->id2row( $$rows[$#{$rows}] ) if($position == 0);
    }
    
    # adding row to end not requires shift rows
    if($pos == -1) {
       $row=$this->{-id2row}{ $$rows[ $#{$rows} ] };
    } else {
	$this->shift_row($position,1) if($position);
    }

    # trigger event oninsertrow
    $ret=$this->run_event('-onrowinsert',$row);

    # make row focused
    $this->draw;
    $row->event_onfocus();


    return $row;
}

sub shift_row($;) {
    my $this=shift;
    my $pos=shift;
    my $dir=shift ||-1;
    my $rows=\@{ $this->{_rows} };

    if($dir == 1 && $#{$rows} > 1) {
    for (my $i=$#{$rows};$i>=$pos+1;$i--) {
	my ($dst,$src)=( \%{ $this->{-id2row} {$$rows[$i]} }
			, \%{ $this->{-id2row} {$$rows[$i-1]} } );
	$$dst{-cells}={ %{$$src{-cells}} };

        foreach my $k (qw(-fg_ -bg_ -fg -bg)) {
    		$$dst{$k}=$$src{$k};
    	    }
    }

    my $dst=\%{$this->{-id2row} {$$rows[$pos]}};
    foreach my $k (qw(-fg_ -bg_)) {$$dst{$k}='';}
    $$dst{-cells}={};
    } elsif($dir == -1) {
	for my $i($pos .. $#{$rows}-1) {

	my ($dst,$src)=( \%{ $this->{-id2row} {$$rows[$i]} }
			, \%{ $this->{-id2row} {$$rows[$i+1]} } );
	$$dst{-cells}={ %{$$src{-cells}} };

        foreach my $k (qw(-fg_ -bg_ -fg -bg)) {
    		$$dst{$k}=$$src{$k} if($$src{$k});
    	    }
	}
	    my $dst=\%{ $this->{-id2row}{ $$rows[ $#{$rows} ] } };
	    foreach my $k (qw(-fg_ -bg_)) {$$dst{$k}='';}
	    $$dst{-cells}={};
    }
}




# delete last row from grid
sub del_row() {
    my $this=shift;
    my $redraw=shift || 0;
    return 0 unless $#{$this->{_rows}};
    # check current row
    my $id= $this->{_rows}[$#{$this->{_rows}}];
    my $r=$this->getfocusrow;
    $this->focus_row($r,1,-1) if($id eq $r->id);
    my $row=$this->id2row($id);

    return 0 if(ref($row) ne 'Curses::UI::Grid::Row');
    pop @{$this->{_rows}};

    #$row->{-canvasscr}='';
    #foreach my $k (qw(-cells -cells_undo)) {
    #	delete $row->{$k} if ( defined $row->{$k} );
    #}
    
    undef $row;
    delete $this->{-rowid2idx}{$id};
    delete $this->{-id2row}{$id};
    $this->{-rows}--;
    $this->draw(1) if($redraw);

return 1;
}

#add new cell
sub add_cell() {
    my $this=shift;
    my $id=shift;
    my $idx=$#{$this->{_cells} }+1;
    my %args=@_;
    my $obj=$this->add($id,'Curses::UI::Grid::Cell',%args,-x=>0,-focusable=>1,-id=>$id);
    $this->{_cells}[$idx]=$id;
    $this->{-cellid2idx}{$id}=$idx;
    $this->{-id2cell}{$id}=$obj;
    $this->{-columns}++;
}


sub del_cell() {
    my $this=shift;
    my $id=shift;
    my $obj=$this->id2cell($id);
    return 0 unless defined $obj;

    my $idx=$this->id2idx($id);
    splice(@{$this->{_cells}}, $idx, 1);
    delete $this->{-cellid2idx}{$id};
    delete $this->{-id2cell}{$id};
    undef $obj;
    $this->{-columns}--;
    $this->layout_content;
    return 1;
}


#add object
sub add() {
    my $this=shift;
    my $id=shift;
    my $class=shift;
    my %args=@_;

    $this->root->usemodule($class);
    my $object = $class->new(
        %args,
        -parent => $this
    );

    # begin by AGX: inherith parent background color!
    if (defined( $object->{-bg} )) {
        if ($object->{-bg} eq "-1" ) {
                if (defined( $this->{-bg} )) {
                        $object->{-bg} = $this->{-bg};
                }
        }
    }
    # end by AGX
    # begin by AGX: inherith parent foreground color!
    if (defined( $object->{-fg} )) {
        if ($object->{-fg} eq "-1" ) {
                if (defined( $this->{-fg} )) {
                        $object->{-fg} = $this->{-fg};
                }
        }
    }

return $object;
}

# get cell by id
sub get_cell($;) {
    my $this = shift;
    my $id = shift;
    return $this->id2cell($id);
}
# get row by id
sub get_row($;) {
    my $this = shift;
    my $id = shift;
    return $this->id2row($id);
}



# set head value
sub set_label(;;$) {
    my $this = shift;
    my $cell = shift;
    my $label= shift;

    my $cell_obj=ref($cell) ? $cell : $this->id2cell($cell);
    $cell_obj->{-label}=$label;
}


sub getfocusrow() {
    my $this = shift;
    my $row='';
    return undef if( $#{$this->{_rows}} < $this->{-row_idx} );
    $row=$this->id2row( $this->{_rows}[$this->{-row_idx}] );
    $row=$this->get_last_row if($row->hidden);
    return $row;
}

sub getactiverow() {
    my $this = shift;
    my $row=$this->getfocusrow;
    $row=$this->id2row( $this->{_rows}[0] ) unless defined $row;
    return $row;	
}

sub getfocuscell() {
    my $this = shift;
    my $c = $this->id2cell( $this->{_cells}[$this->{-cell_idx}] );
    return undef unless  defined $c;
    $c->row($this->getfocusrow);
    return $this->id2cell( $this->{_cells}[$this->{-cell_idx}] );
}


sub get_last_row($;) {
    my $this = shift;
    my $row;
    for (my $i=$#{$this->{_rows}};$i>1; $i--) {
	$row=$this->get_row($this->{_rows}[$i ] );
	last if($row->{-focusable} && !$this->hidden );
    }
    return $row;	    
}

sub get_first_row($;) {
    my $this = shift;
    my $row=$this->get_row($this->{_rows}[1]);
    return $row;	    
}


sub page($;) 	{ 
    my $this=shift;
    my $page=shift;
    $this->{-page}=$page if(defined $page);
    return $this->{-page};
}

sub page_size($;)  { 
    my $this=shift;
    my $page_size=shift;
    $this->{-page_size}=$page_size if(defined $page_size);
    return $this->{-page_size};
}





##############################################################
# Layout  functions
##############################################################


sub layout() {

    my $this = shift;
    $this->SUPER::layout() or return;
    $this->layout_content();
    return $this;
}

# layout cells
sub layout_content {

   my $this = shift;
   return $this if $Curses::UI::screen_too_small;

    # ----------------------------------------------------------------------
    # Horizontal cells layout of the screen
    # ----------------------------------------------------------------------

   $this->clear_vline();
   my ($w,$vs,$x,$fx,$ncells)=($this->canvaswidth,$this->vscroll,0,0,0);
   my $c=\@{ $this->{_cells} };
    for my $i( 0 ..$#{$c} ) {
        my $o= $this->id2cell($$c[$i]);
	$o->hide;

        my ($o_w,$f)=($o->width,$o->frozen);
	$ncells+=$o_w;

        if($f) {
             $o->set_layout($x++,$o_w,1);
             $fx+=$o_w+1;
        }
        elsif( ($vs+$fx) < $x ) {
            if( $w >=  int($x + $o_w) ) {
                $o_w=$o->set_layout($x++,$o_w,1);
            } elsif(  $w > ($x) ) {
                $o_w=$o->set_layout( $x++, $w - $x, 1);
            }

        } elsif( $vs  <  $o_w  ) {
            $o_w=$o->set_layout($x++, $o_w - $vs,0);
            $vs=0;
        }
        else {
              $vs-=$o_w;
              $o_w=0;
       }

        $x+=$o_w;
        $this->add_vline( $x - 1 ) if( $x > 0 &&  ($x-1) < $w && !$o->hidden);
    }


    # ----------------------------------------------------------------------
    # Layout horizontal scrollbar.
    # ----------------------------------------------------------------------

    if ($this->{-hscrollbar}) {
        my $longest_line = $ncells;
        $this->{-hscrolllen} = $longest_line + 1;
        $this->{-hscrollpos} = $this->{-xpos} + $this->vscroll;
    } else {
        $this->{-hscrolllen} = 0;
        $this->{-hscrollpos} = 0;
    }


    # ----------------------------------------------------------------------
    # Layout vertical scrollbar
    # ----------------------------------------------------------------------

    if ($this->{-vscrollbar}) {
        $this->{-vscrolllen} = $this->{-pages} * $this->{-rows};
        $this->{-vscrollpos} = $this->{-pages} + $this->{-y} -1;
    } else {
        $this->{-vscrolllen} = 0;
        $this->{-vscrollpos} = 0;
    }

   return $this;
}



# get vscroll to given object
sub get_vscroll_to_obj($;) {

    my $this = shift;
    my $cell = shift;

    my $lidx=$this->{-prev_cell_idx};
    my $idx= $this->{-cell_idx};
    my ($k,$x,$w,$h,$d,$o)=(0,0,$this->canvaswidth,0,1,undef);

    my $c=\@{ $this->{_cells} };

    for  my $i ( 0 .. $#{$c} ) {
        $k++;
    	    $o=$this->id2cell( $$c[$i] );

            if($o->frozen) {
                $w-=($o->w+1);
                next;
            }
        $x+=$o->width;
        last if($o eq $cell);
    }

    if( $lidx > $idx ) {
        $w=$o->width;
    }

    if( $x > $w ) {
        for (my $j=$k; $j>0 ; $j--) {
                next unless defined ($$c[$j] );
		$o= $this->id2cell($$c[$j]);

                if( $w > $o->width ) {
                   $w-=$o->width;
                   $x-=$o->width;
                } elsif ($w) {
                    $x-=$w ;
                    last;
                }
                $x++;
                last unless $w;
        }
    } else { $x=0; }
return $x;
}


sub add_vline() {
    my $this=shift;
    my $x=shift;
    $this->{-vlines}[$#{ $this->{-vlines} } +1]=$x;
}

sub clear_vline() {
my $this=shift;
$this->{-vlines}=[];
}




##############################################################
# Draw  functions
##############################################################

sub draw(;$) {

    my $this = shift;
    my $no_doupdate = shift || 0;
    $this->SUPER::draw(1) or return $this;


    $this->draw_grid(1);

    if( $#{$this->{_rows}} > 0 ) {
	$this->{-nocursor}=0;
    } else {
	$this->{-nocursor}=1;
    }

    doupdate() unless $no_doupdate;
    return $this;
}    


sub draw_grid(;$) {

    my $this = shift;
    my $no_doupdate = shift || 0;


    $this->draw_header_vline;
    my $pair=$this->set_color($this->{-fg},$this->{-bg},$this->{-canvasscr});
    my $r=\@{$this->{_rows}};
        for (my $i=$#{$r};$i>=0;$i--) {$this->id2row( $$r[$i] )->draw_row;}
    $this->color_off($pair,$this->{-canvasscr});

    my $c=$this->getfocuscell;
       $r=$this->getfocusrow;
    my ($y,$x)=( ref($r) ? $r->y : 0 , ref($c) ? $c->xabs_pos : 0 );
    $this->{-ypos}=$y;
    $this->{-xpos}=$x;
    $this->{-canvasscr}->move($this->{-ypos},$this->{-xpos});
    $this->{-canvasscr}->noutrefresh if $no_doupdate;

}


sub draw_header_vline(;$) {

    my $this = shift;
    my $pair=$this->set_color($this->{-fg},$this->{-bg},$this->{-canvasscr});
    $this->{-canvasscr}->addstr(0,0,sprintf("%-".($this->canvaswidth *($this->canvasheight) )."s", ' ') );
    $this->color_off($pair,$this->{-canvasscr});

    my ($fg,$bg,$cn)=($this->{-bfg} ne "-1" ? $this->{-bfg} : $this->{-fg}
		, $this->{-bbg} ne "-1" ? $this->{-bbg} : $this->{-bg} 
		, 0);
    $this->{-canvasscr}->move(1,0);
    $pair=$this->set_color( $fg,$bg, $this->{-canvasscr} );

    $this->{-canvasscr}->hline(ACS_HLINE,$this->canvaswidth);

    if($#{$this->{_rows}} > 0 )  {
        foreach my $x (@{ $this->{-vlines} } ) {
		    $cn++;
		    if($this->canvaswidth-1 == $x && $cn eq $this->{-columns} ) {
		        $this->{-canvasscr}->move(1,$x) ;
			$this->{-canvasscr}->vline(ACS_URCORNER,1);
    		        next;
		    }

		        $this->{-canvasscr}->move(1,$x) ;
	                $this->{-canvasscr}->vline(ACS_TTEE,1);

                }
    }
    $this->color_off($pair,$this->{-canvasscr});
    return $this;
}

# x offet 
sub vscroll() { 
    my $this=shift;
    my $vs=shift;
    if(defined $vs) {
     $this->{-vscroll}=$vs;
     $this->layout_content();
     $this->draw(1);
    }
    return $this->{-vscroll};
}



##############################################################
# Color  functions
##############################################################

sub set_color($;) {
    my $this = shift;
    my $bg= shift || -1;
    my $fg= shift || -1;
    my $canvas=shift;
    return unless ref($canvas);
    my $pair = '';
	
        return if($fg eq "-1" || $bg eq "-1");

        if($Curses::UI::color_support && $bg && $fg) {
                my $co = $Curses::UI::color_object;
		 $canvas->attron(A_REVERSE);
                 $pair = $co->get_color_pair($fg,$bg);
		 $canvas->attron(COLOR_PAIR($pair));
		 $this->{-canvasscr}->attron(COLOR_PAIR($pair));
        }

return $pair;
}

sub color_off($;) {
    my $this = shift;
    my $pair= shift;
    my $canvas=shift;
    my $co = $Curses::UI::color_object;
    
        if($Curses::UI::color_support && $pair) {
                $canvas->attroff(A_REVERSE);
                $canvas->attroff(COLOR_PAIR($pair));
	}
}


##############################################################
# Event  functions
##############################################################

#overwrite run_event: pass row or cell or grid object as caller
sub run_event($;)
{

    my $this = shift;
    my $event = shift;
    my $obj = shift;
    my $callback = $this->{$event};
    if (defined $callback) {
        if (ref $callback eq 'CODE') {
            return $callback->( ref($obj)?$obj:$this);
        } else {
            $this->root->fatalerror(
                "$event callback for $this "
              . "($callback) is no CODE reference"
            );
        }
    }
    return;
}

sub focus_row(;$$$) {
    my $this      = shift;
    return $this->focus_obj('row'
		    ,shift || undef
		    ,shift
		    ,shift );

}

sub focus_cell(;$$$) {
    my $this      = shift;
    return $this->focus_obj('cell'
		    ,shift || undef
		    ,shift
		    ,shift );

}

sub focus_obj(;$$$$)
{

    my $this      = shift;
    my $type	  = shift;
    my $focus_to  = shift;
    my $forced	  = shift;
    my $direction = shift;

    $direction=1 unless defined($direction);
    my $idx;

    my $index="-".$type."_idx";
    my $index_prev="-".$type."_idx_prev";
    my $collection="_".$type."s";
    my $map2idx="-".$type."id2idx";
    my $map2id="-id2".$type;
    my $onnextpage=0;
    my $onprevpage=0;

    my $cur_id  = $this->{$collection}[ $this->{$index} ];
    my $cur_obj = $this->{$map2id}{$cur_id};

    $focus_to=$cur_id if( !defined $focus_to || !$focus_to);

    $direction = ($direction < 0 ? -1 : $direction );

   # Find the id for a object if the argument
   # is an object.
    my $new_id = ref $focus_to
               ? $focus_to->{-id}
               : $focus_to;


    my $new_obj = $this->{$map2id}{$new_id};

    if(defined $new_id && $direction != 0) {
        # Find the new focused object.
	my $idx =   $this->{$map2idx}{$new_id};
	my $start_idx = $idx;

            undef $new_obj;
            undef $new_id;

            OBJECT: for(;;)
            {
                $idx += $direction;
                 if($idx > @{ $this->{$collection} }-1){

		    if($type eq 'row') {
			 # if curent position is less than page size and grid is editable
			 # and cursor down then add new row
			 return $this->insert_row(-1) 
				    if($idx <= $this->{-page_size} && $this->{-editable});
			 
			 $onnextpage=1;  #set trigger flag to next_page
			 }
    		         
	    
		    $idx = 0;
		}


		if($idx < 0) {
            	    $idx = @{$this->{$collection}}-1 ;
		    $onprevpage=1 if($type eq 'row');  #set trigger flag to prev_page
		}

                last if $idx == $start_idx;

                my $test_obj  = $this->{$map2id}{ $this->{$collection}->[$idx] };
                my $test_id = $test_obj->{-id};

                if($test_obj->focusable)
                {
                    $new_id  = $test_id;
                    $new_obj = $test_obj;
                    last OBJECT
                }
		
            }
        }


        # Change the focus if a focusable objects was found and tiggers not return FALSE.
        if($forced or defined $new_obj and $new_obj ne $cur_obj) {
		 my $ret=1;

 		 # trigger focus to new object if ret isn't FALSE  and any page trigger is set
		 $ret=$this->grid_pageup(1)   if($ret && $onprevpage);
		 $ret=$this->grid_pagedown(1) if($ret && $onnextpage);

		 $ret=$cur_obj->event_onblur if($ret && $cur_obj);
		 $new_obj->event_onfocus if($ret && ref($new_obj));
        }

 return $this;
}

sub event_onfocus($;) {
    my $this = shift;
    my $row=$this->getactiverow;
    $this->focus_row(undef,1,1) if(!ref($row) || $row->type eq 'head');
    return $this->SUPER::event_onfocus(@_);
}




##############################################################
# Data maipulation functions
##############################################################

# data manipulation
sub set_value(;;$) {
    my $this = shift;
    my $row = shift;
    my $cell = shift;
    my $data= shift;

    my $row_id=ref($row)  ? $row->{-id}   : $row;
    my $cell_id=ref($cell) ? $cell->{-id} : $cell;
    my $r=$this->get_row($row_id);
    $r->set_value($cell_id,$data) if(ref($r));
}


sub set_values($$;) {
    my $this = shift;
    my $row = shift;
    my %data= @_;
    my $row_id=ref($row)  ? $row->{-id}   : $row;
    my $r=$this->get_row($row_id);
    $r->set_values(%data) if(ref($r));
}

sub get_value($$$) {
    my $this = shift;
    my $row = shift;
    my $cell = shift;
    my $row_id=ref($row)  ? $row->{-id}   : $row;
    my $cell_id=ref($cell) ? $cell->{-id} : $cell;
    my $r=$this->get_row($row_id);
    return $r->get_value($cell_id) if(ref($r));
}


sub get_values($$;) {
    my $this = shift;
    my $row = shift;
    my %data= @_;
    my $row_id=ref($row)  ? $row->{-id}   : $row;
    my $r=$this->get_row($row_id);
    return $r->get_values() if(ref($r));
}

sub get_values_ref($$$) {
    my $this = shift;
    my $row = shift;
    my $ref = shift;
    my $row_id=ref($row)  ? $row->{-id}   : $row;
    my $r=$this->get_row($row_id);
    return \%{ $r->get_values_ref() } if(ref($r));
}


##############################################################
# Data navigation functions
##############################################################

sub next_row($;) {
    my $this = shift;
    my $row=$this->getfocusrow;
    $this->focus_row($this->getfocusrow,undef,1);
    return $this;	    
}

sub prev_row($;) {
    my $this = shift;
    $this->focus_row($this->getfocusrow,undef,-1);
    return $this;	    
}

sub first_row($;) {
    my $this = shift;
    my $row=$this->get_first_row;
    $this->focus_row($row,1,0);
    return $this;	    
}

sub last_row($;) {
    my $this = shift;
    my $row=$this->get_last_row;
    $this->focus_row($row,1,0);
    return $this;	    
}



sub grid_pageup($;) {
    my $this=shift;
    my $do_draw= shift || 0;
    my $ret=$this->run_event('-onprevpage',$this);
    return 0 if(defined $ret && !$ret);
    $this->draw(1) if $do_draw;
    $this->focus_row($this->getfocusrow,1,0) if($do_draw && $do_draw != 1 );
    return $this;
}

sub grid_pagedown($;) {
    my $this=shift;
    my $do_draw= shift || 0;
    my $ret=$this->run_event('-onnextpage',$this);
    return 0 if(defined $ret && !$ret);
    $this->draw(1) if $do_draw;
    $this->focus_row($this->getfocusrow,1,0) if($do_draw && $do_draw != 1 );
    return $this;
}


# row's functions

sub first_cell($;) {
    my $this = shift;
    my $cell=$this->get_cell($this->{_cells}[0] );
    $this->focus_cell($cell,1,0);
    return $this;	    
}

sub last_cell($;) {
    my $this = shift;
    my $cell=$this->get_cell($this->{_cells}[ $#{$this->{_cells}} ] );
    $this->focus_cell($cell,1,0);
    return $this;	    
}


sub prev_cell($;) {
    my $this = shift;
    $this->focus_cell($this->getfocuscell,undef,-1);
    return $this;	    
}

sub next_cell($;) {
    my $this = shift;
    my $r=$this->getactiverow;
    $this->focus_cell($this->getfocuscell,undef,1);
    return $this;	    
}


##############################################################
# Cell's functions
##############################################################


sub cursor_left($;) {
    my $this = shift;
    my $c=$this->getfocuscell;
    $c->cursor_left;
    return $this;	    
}


sub cursor_right($;) {
    my $this = shift;
    my $c=$this->getfocuscell;
    $c->cursor_right;
    return $this;																	        return $this;	    
}

sub cursor_to_home($;) {
    my $this = shift;
    my $c=$this->getfocuscell;
    $c->cursor_to_home;
}

sub cursor_to_end($;) {
    my $this = shift;
    my $c=$this->getfocuscell;
    $c->cursor_to_end;
}

sub delete_character($;) {
    my $this = shift;
    my $row=$this->getfocusrow;
    return if $row->{-type} eq 'head';
    my $c=$this->getfocuscell;
    $c->delete_character(shift);
}

sub backspace($;) {
    my $this = shift;
    my $row=$this->getfocusrow;
    return if($row->{-type} eq 'head');
    my $c=$this->getfocuscell;
    $c->backspace(shift);
}

sub add_string($;) {
    my $this = shift;
    my $row=$this->getfocusrow;
    return if $row->{-type} eq 'head';
    my $c=$this->getfocuscell;
    $c->add_string( shift );
}




##############################################################
# Cell's functions
##############################################################

# map function
sub id2cell(){ 
    my $this=shift;
    my $id=shift;
    return $this->{-id2cell}{$id}
}

sub id2row(){ 
    my $this=shift;
    my $id=shift;
    return $this->{-id2row}{$id}
}

sub idx2rowid(){ 
    my $this=shift;
    my $idx=shift;
    return $this->{-ixd2rowid}{$idx}
}









sub id() 	{ shift()->{-id} }
sub readonly()  { shift()->{-readonly} }





1;

__END__

=pod

=head1 NAME

Curses::UI::Grid - Create and manipulate data in grid model

=head1 CLASS HIERARCHY

 Curses::UI::Widget
    |
    +----Curses::UI::Grid


=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');
    my $grid =$win->add(
	'mygrid','Grid'
        ,-rows=>3
        ,-columns=>5
    );

    # set header desc 
    for my $i(1 .. 5) {$g->set_label("cell$i","Head ".$i);}
    # add some data
    for my $i(1 .. 5) {$g->set_cell_value("row1","cell".$i,"value $i");}
    my $val=$g->get_value("row1","cell2");


=head1 DESCRIPTION


       Curses::UI::Grid is a widget that can be used to
       browsing or manipulate data in grid model


      See exampes/grid-demo.pl in the distribution for a short demo.


=head1 STANDARD OPTIONS
       -parent, -x, -y, -width, -height, -pad, -padleft,
       -padright, -padtop, -padbottom, -ipad, -ipadleft,
       -ipadright, -ipadtop, -ipadbottom, -title,
       -titlefull-width, -titlereverse, -onfocus, -onblur,
       -fg,-bg,-bfg,-bbg


=head1 WIDGET-SPECIFIC OPTIONS

=over 4


=item * B<-basebindings> < HASHREF >

Basebindings is assigned to bindings with editbindings  
if editable option is set.

The keys in bindings hash reference are keystrokes and the values are
routines to which they should be bound.  In the event a key is empty,
the corresponding routine will become the default routine that


B<process_bindings> applies to unmatched keystrokes it receives.

By default, the following mappings are used for basebindings:

    KEY                 ROUTINE
    ------------------  ----------
    CUI_TAB             next_cell
    KEY_ENTER()         next_cell
    KEY_BTAB()          prev-cell
    KEY_UP()            prev_row
    KEY_DOWN()          next_row
    KEY_RIGHT()         cursor_right
    KEY_LEFT()          cursor_left
    KEY_HOME()          cursor_home
    KEY_END()           cursor_end

    KEY_PPAGE()         grid_pageup
    KEY_NPAGE()         grid_pagedown


=item * B<-editindings> < HASHREF >

By default, the following mappings are used for basebindings:

    
    KEY                 ROUTINE
    ------------------  ----------
    any			add_string
    KEY_DC()            delete_character
    KEY_BACKSPACE()     backspace
    KEY_IC()   		insert_row
    KEY_SDC()           delete_row



=item * B<-routines> < HASHREF >

    ROUTINE          ACTION
    ----------       -------------------------
    loose_focus      loose grid focus
    first_row        make first row active
    last_row         make last  row active
    grid-pageup      trigger event -onnextpage
    grid-pagedown    trigger event -onprevpage

    next_row	     make next row active
    prev_row	     make prev row active


    next_cell	     make next cell active
    prev_cell	     make prev cell active
    first_cell       make first row active
    last_cell        make last  row active

    cursor_home      move cursor into home pos in focused cell
    cursor_end       move cursor into end pos in focused cell
    cursor_righ      move cursor right in focused cell
    cursor_left      move cursor left in focused cell
    add_string       add string to focused cell
    delete_row	     delete active row from grid, shift rows upstairs
    insert_row       insert row in current position

    delete_character delete_character from focused cell
    backspace        delete_character from focused cell


=item * B<-editable> 	< BOOLEAN >	

The grid widget will be created as a editable grid.
Otherwise it will be able only view data (data viewer) if
BOOLEAN is false. By default BOOLEAN is true.


=item * B<-columns> 	< COLUMNS >	

This option control how many cell objects should be kept
in memory for the grid widget. By default is 0
If this value is set to non FALSE, construtor creates empty cells.


=item * B<-rows> 	< ROWS >	

This option control how many row objects should be kept
in memory for the grid widget. By default is 0
If this value is set to non FALSE, construtor creates empty rows.


=item * B<-count> 	< COUNT >

This option store logical number of all rows.
It could be used for calculating vertical scroll.


=item * B<-page> 	< NUMBER >	

This option store logical number of current page.
It could be used for calculating vertical scroll.

=back

=head2 GRID EVENTS

=over 6

=item * B<-onnextpage>  < CODEREF >

This sets the onnextpage event handler for the widget.
If the widget trigger event nextpage, the code in CODEREF will
be executed. It will get the widget reference as its
argument.

=item * B<-onprevpage>  < CODEREF >

This sets the onnextpage event handler for the widget.
If the widget trigger event previouspage, the code in CODEREF will
be executed. It will get the widget reference as its
argument.


=head2 GRID-ROW-SPECIFIC OPTIONS

=over 6

=item * B<-onrowdraw> < CODEREF >

This sets the onrowdraw event handler for the widget.
If the widget trigger event rowdraw, the code in CODEREF will
be executed. It will get the widget reference as its
argument. This could be useful for dynamically setting colors
appropriate to some conditions.

    my $grid=$w->add('grid'
        ,'Grid'
        ,-rows=>3
        ,-columns=>4
        ,-onrowdraw => sub{
               my $row=shift;
		#check conditions and set color for row
               my $v=$row->get_value('cell0');
		....
		if( .... ) {
            	    $row->bg('black');
            	    $row->fg('yellow');
                } else { 
		# return back to origin color
		    $row->bg(''); 
		    $row->fg(''); 
		}
        },
    );


=item * B<-onrowfocus> < CODEREF >

This sets the onrowfocus event handler for the widget.
If the widget trigger event rowfocus, the code in CODEREF will
be executed. It will get the row widget reference as its
argument.

=item * B<-onrowblur> 	< CODEREF >

This sets the onrowblur event handler for the widget.
If the widget trigger event rowblur, the code in CODEREF will
be executed. It will get the row widget reference as its
argument. The CODEREF could return FALSE to cancel rowblur 
action and current row will not lose the focus.

=item * B<-onrowchange> < CODEREF >

This sets the onrowchange event handler for the widget.
If the widget trigger event rowchange, the code in CODEREF will
be executed. It will get the row widget reference as its
argument. The CODEREF could return FALSE to cancel onrowblur 
action and current row will not lose the focus.


=item * B<-onrowchange> < CODEREF >

This sets the onrowchange event handler for the widget.
If the widget trigger event rowchange, the code in CODEREF will
be executed. It will get the row widget reference as its
argument. The CODEREF could return FALSE to cancel onrowblur 
action and current row will not lose the focus.


=item * B<-onbeforerowinsert> < CODEREF >

This sets the onbeforerowinsert event handler for the widget.
If the widget trigger event onbeforerowinsert, the code in CODEREF will
be executed. It will get the grid widget reference as its
argument. The CODEREF could return FALSE to cancel insert_row action
See more about insert_row method.

=item * B<-onrowinsert> < CODEREF >

This sets the oninsert event handler for the widget.
If the row widget trigger event onrowinsert, the code in CODEREF will
be executed. It will get the row widget reference as its
argument. 
See more about insert_row method.


=item * B<-onrowdelete> < CODEREF >

This sets the onrowdelete event handler for the widget.
If the widget trigger event onrowdelete, the code in CODEREF will
be executed. It will get the row widget reference as its
argument. The CODEREF could return FALSE to cancel delete_row action
See more about delete_row method.

=item * B<-onfterrowdelete> < CODEREF >
This sets the onrowdelete event handler for the widget.
If the widget trigger event onrowdelete, the code in CODEREF will
be executed. It will get the row widget reference as its
argument. 
See more about delete_row method

back

=head2 GRID-CELL-SPECIFIC OPTIONS

=over 6

=item * B<-oncelldraw>   < CODEREF >

This sets the oncelldraw event handler for the widget.
If the widget trigger event celldraw, the code in CODEREF will
be executed. It will get the cell widget reference as its
argument. 


=item * B<-oncellfocus>  < CODEREF >

This sets the oncellfocus event handler for the widget.
If the widget trigger event cellfocus, the code in CODEREF will
be executed. It will get the cell  widget reference as its
argument. 


=item * B<-oncellblur>   < CODEREF >

This sets the oncellblur event handler for the widget.
If the widget trigger event cellblur, the code in CODEREF will
be executed. It will get the cell  widget reference as its
argument. The CODEREF could return FALSE to cancel oncellblur 
action and current cell will not lose the focus.

    my $grid=$w->add('grid'
        ,'Grid'
        ,-rows=>3
        ,-columns=>4
        ,-oncellblur => sub {
            my $cell=shift;
	    # some validation 
            if(... ) {

                return 0; # cancel oncellblur event
            }
            return $cell;
        }
    );

=item * B<-oncellchange> < CODEREF >

This sets the oncellchange event handler for the widget.
If the widget trigger event cellchange, the code in CODEREF will
be executed. It will get the cell  widget reference as its
argument. The CODEREF could return FALSE to cancel oncellblur 
action and current cell will not lose the focus.


    my $grid=$w->add('grid'
        ,'Grid'
        ,-rows=>3
        ,-columns=>4
        ,-oncellblur => sub {
            my $cell=shift;
	    my $old_value=$cell->text_undo;
	    my $value=$cell->text;
	    # some validation 
            if(... ) {

                return 0; # cancell oncellchange and oncellblur event 
            }
            return $cell;
        }
    );


=item * B<-oncellkeypress> < CODEREF >

This sets the oncellkeypress event handler for the widget.
If the widget trigger event cellkeypress, the code in CODEREF will
be executed. It will get the cell  widget reference and added string as its
argument. Actually the cellkeypress event is called by method add_string 
in cell obejct. The CODEREF could return FALSE to cancel add_string action.


=item * B<-oncelllayout> < CODEREF >

This sets the oncelllayout event handler for the widget.
If the widget trigger event cellkeypress, the code in CODEREF will
be executed. It will get the cell widget  reference and value as its
argument. The CODEREF could return any text which will be proceeded
insted of the orgin value.

    my $grid=$w->add('grid'
        ,'Grid'
        ,-rows=>3
        ,-columns=>4
        ,-oncelllayout => sub {
            my $cell=shift;
	    my $value=$cell->text;
	    # mask your value
		....
            return $value;
        }
    );



=back

=head1 METHODS

=over 4

=item * B<new> ( OPTIONS )
Constructs a new grid object using options in the hash OPTIONS.


=item * B<layout> ( )

Lays out the grid object with rows and cells, makes sure it fits 
on the available screen.


=item * B<draw> ( BOOLEAN )

Draws the grid object along with the rows and cells. If BOOLEAN
is true, the screen is not updated after drawing.

By default, BOOLEAN is true so the screen is updated.


=item * B<focus> ( )


=item * B<onFocus> ( CODEREF )


=item * B<onBlur> ( CODEREF )


See L<Curses::UI::Widget|Curses::UI::Widget> for explanations of these
methods.

=back

=head2 GRID-MODEL FUNCTIONS

=over 6

=item * B<insert_row>

This routine will add empty row data to grid at cureent position.
All row data below curent row will be shifted down. 
Then function will call event onbeforerowinsert with grid obj as parameter.
Otherwise
add_row method will be called if rows number is less than page size.
Then onrowinsert event is called with row object as parameter.
Returns the row object or undef on failure.

=item * B<delelete_row>  ( )

This routine will delete row data from current position. 
The function calls event onrowdelete,shifts others row up
and runs event onafterrowdelete and remove last row if onafterrowdelete 
CODEREF doesn't return FALSE.

Note. If onrowdelete CODEREF returns FALSE then  
the delete_row routine will be cancelled. 
Returns TRUE or FALSE on failure.

=item * B<add_row> ( OPTIONS )

This routine will add row to grid using options in the hash OPTIONS.
For available options see Curses::UI::Grid::Row. 
Returns the row object or undef on failure.

=item * B<del_row>  ( )

This routine will delete last row. 
Returns TRUE or FALSE on failure.

=item * B<add_cell> ( OPTIONS )

This routine will add cell to grid using options in the hash OPTIONS.
For available options see Curses::UI::Grid::Cell. 
Returns the cell object or undef on failure.

=item * B<del_cell> ( ID  )

This routine will delete given cell. 
Returns TRUE or FALSE on failure.

=item * B<get_cell> ( ID  )

This routine will return given cell object. 


=item * B<get_row>  ( ID  )

This routine will return given row object. 


=item * B<set_label> ( ID , VALUE )

This routine will set header title for cell object


=item * B<getfocusrow>

This routine will return focused row object. 


=item * B<getfocuscell>

This routine will return focused cell object. 


=item * B<page_size>

This routine will return page_size attribute (canvasheight - 2). 


=item * B<page>

This routine will return page attribute.

=back

=head2 DATA-MANIPULATION FUNCTIONS

=over 6

=item * B<set_value>  ( ROW , CELL , VALUE  )

This routine will set value for given row and cell.
CELL could by either cell object or id cell.
ROW  could by either row object or id row.


=item * B<set_values> ( ROW , HASH  )
This routine will set values for given row. 
HASH should contain cells id as keys.
ROW  could by either row object or id row.

    $grid->set_values('row1',cell1=>'cell 1',cell4=>'cell 4');

    $grid->set_values('row1',cell2=>'cell 2',cell3=>'cell 3');

This method will not affect cells which are not given in HASH.


=item * B<get_value>  ( ROW , CELL )

This routine will return value for given row and cell. 
CELL could by either cell object or id cell.
ROW  could by either row object or id row.


=item * B<get_values> ( ROW )
This routine will return  HASH values for given row. 
HASH will be contain cell id as key.
ROW  could by either row object or id row.


=item * B<get_values_ref> ( ROW )

This routine will return  HASH reference  for given row values. 
ROW  could by either row object or id row.
  my $ref=$grid->get_values_ref('row1');
    $$ref{cell1}='cell 1 ';
    $$ref{cell2}='cell 2 ';
    $$ref{cell3}='cell 3 ';
    $grid->draw();

Note. After seting values by reference you should call draw method.

=back

=head2 GRID-NAWIGATION FUNCTIONS

=over 6

=item * B<grid_pageup>


=item * B<grid_pagedown>


=item * B<focus_row>


=item * B<first_row>


=item * B<last_row>


=item * B<next_row>


=item * B<prev_row>


=item * B<focus_cell>


=item * B<next_cell>


=item * B<prev_cell>


=item * B<first_cell>


=item * B<last_cell>


=item * B<get_first_row>


=item * B<get_last_row>


=back

=head1 SEE ALSO

       Curses::UI::Grid::Row Curses::UI::Grid::Cell


=head1 AUTHOR
       Copyright (c) 2004 by Adrian Witas. All rights reserved.


=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 


=pod SCRIPT CATEGORIES

User Interfaces


=cut
