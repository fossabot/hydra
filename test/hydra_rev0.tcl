#---------------------------------------------
# tclftdi GUI for the efabless Hydra project
#---------------------------------------------
# Written by Tim Edwards
# Revision 0: September 20, 2013
#    Initial version for evaluation	
#	
#-----------------------------------------
# Copyright (c) 2013 Tim Edwards
# Open Circuit Design/eFabless
#-----------------------------------------

#-----------------------------------------
# Define the register and core dictionaries.
# The register bank (SPI) is a dictionary,
# and each register is a sub-dictionary of
# the register bank.  The core values are in
# a single, non-hierarchical dictionary.
#-----------------------------------------

global core
global registers
global device
global update_level

set registers [dict create]

# Define all the SPI registers, with the correct lengths

set reg0 [dict create]
dict set reg0 number 0
dict set reg0 mode readonly
dict set reg0 values {0 0 0}
dict set registers reg0 $reg0

set reg1 [dict create]
dict set reg1 number 1
dict set reg1 mode readonly
dict set reg1 values {0 0 0}
dict set registers reg1 $reg1

set reg2 [dict create]
dict set reg2 number 2
dict set reg2 mode readwrite
dict set reg2 values {0 0 0 0}
dict set registers reg2 $reg2

set reg3 [dict create]
dict set reg3 number 3
dict set reg3 mode readwrite
dict set reg3 values {0 0 0 0 0 0}
dict set registers reg3 $reg3

set reg4 [dict create]
dict set reg4 number 4
dict set reg4 mode readwrite
dict set reg4 values {0 0}
dict set registers reg4 $reg4

set reg5 [dict create]
dict set reg5 number 5
dict set reg5 mode readwrite
dict set reg5 values {0 0}
dict set registers reg5 $reg5

set reg6 [dict create]
dict set reg6 number 6
dict set reg6 mode readwrite
dict set reg6 values {0 0}
dict set registers reg6 $reg6

set reg7 [dict create]
dict set reg7 number 7
dict set reg7 mode readwrite
dict set reg7 values {0 0}
dict set registers reg7 $reg7

set reg8 [dict create]
dict set reg8 number 8
dict set reg8 mode readwrite
dict set reg8 values {0 0}
dict set registers reg8 $reg8

set reg9 [dict create]
dict set reg9 number 9
dict set reg9 mode readwrite
dict set reg9 values {0 0}
dict set registers reg9 $reg9

set reg10 [dict create]
dict set reg10 number 10
dict set reg10 mode readwrite
dict set reg10 values {0 0}
dict set registers reg10 $reg10

#----------------------------------------------------------
# Special Procedures for specific signals
#
# These procecures make changes to the chip without
# affecting the current configuration.
#----------------------------------------------------------

# (none defined at present)

#-----------------------------------------
# Standard procedures
#-----------------------------------------

#---------------------------------------------
# Quit GUI with exit code
#---------------------------------------------

proc ftdi::quit {{code 0}} {
   global device
   global tclftdi_emulation

   if {$tclftdi_emulation == 0} {
      ftdi::closedev $device
   }
   exit $code
}

#-----------------------------------------
# Write the register values to the chip
# by writing via the SPI
#-----------------------------------------

proc ftdi::setconfig {{all 0}} {
   global registers
   global saved_registers
   global device
   
   set regorder {reg0 reg1 reg2 reg3 reg4 reg5 reg6 reg7 \
		reg8 reg9 reg10}

   foreach regname $regorder {
      set reg [dict get $registers $regname]
      set mode [dict get $reg mode]
      set number [dict get $reg number]
      if {$mode == "readwrite"} {
	 if {$all == 1} {
	    set oldrvals -1
	 } else {
            set oldrvals [dict get $saved_registers $regname values]
	 }
         set rvals [dict get $reg values]
	 if {$rvals != $oldrvals} {
            spi_write $device $number $rvals
	    # Validate.
            set newrvals [spi_read $device $number [llength $rvals]]
	    if {$newrvals != $rvals} {
               dict set registers $regname values $newrvals
	    }
	 }
      }
   }
   set saved_registers $registers
}

#--------------------------------------------------------------
# Convert a decimal list to hexidecimal
#--------------------------------------------------------------

proc ftdi::dec2hex {dlist} {
   set hlist {}
   foreach d $dlist {
      lappend hlist [format "0x%02x" $d]
   }
   return $hlist
}

#--------------------------------------------------------------
# Convert a hexidecimal list to decimal
#--------------------------------------------------------------

proc ftdi::hex2dec {hlist} {
   set dlist {}
   foreach h $hlist {
      lappend dlist [format "%d" $h]
   }
   return $dlist
}

#--------------------------------------------------------------
# Wrapper functions for writereg used by special entry bind
#--------------------------------------------------------------

proc ftdi::write_raw_reg {value regname idx} {
   global registers

   set rvalues [dict get $registers $regname values]
   set decval [ftdi::ibconvert $value]
   set rvalues [lreplace $rvalues $idx $idx $decval]
   dict set registers $regname values $rvalues
   ftdi::update_core
   ftdi::update_raw
   ftdi::update_gui
}

#--------------------------------------------------------------
# File functions
#
# Since the GUI describes everything in detail, all we need to
# save and load are the register values.
#--------------------------------------------------------------

proc ftdi::saveconfig {} {
   global tclopto_emulation
   global core
   global registers
   global ref_freq
   global xtal_freq
   global xtal2_freq
   global appframe

   set savefile [tk_getSaveFile -defaultextension .config -filetypes {{"Config" {.config}}} \
	-initialdir configurations]
   set fs [open $savefile w]
   set prodid [dict get $core prodid]
   puts $fs hydra

   dict for {regname reg} $registers {
      puts $fs [ftdi::dec2hex [dict get $reg values]]
   }

   # Any other signal values needed for a complete description
   # of the chip environment go here.

   # Last line is the description entered into the GUI form
   puts $fs [${appframe}.config.info get]

   close $fs
}

#--------------------------------------------------------------

proc ftdi::loadconfig {} {
   global registers
   global core
   global ref_freq
   global xtal_freq
   global xtal2_freq
   global appframe

   set regorder {reg0 reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 reg9 reg10}

   if {[catch {set loadfile [tk_getOpenFile -filetypes {{"Config" {.config}}} \
		-initialdir configurations]}]} {
      puts stderr "Failure to run file load procedure"
      return
   }
   if {$loadfile == {}} return
   set fl [open $loadfile r]
   set line [gets $fl]
   if {$line == "hydra"} {
      dict for {regname reg} $registers {
         set line [gets $fl]
         dict set registers $regname values [ftdi::hex2dec $line]
      }
   } else {
      puts stderr "Configuration file is for project $line, not project hydra"
      return
   }

   ${appframe}.config.file config -text [file rootname [file tail $loadfile]]
   ${appframe}.config.info delete 0 end
   ${appframe}.config.info insert 0 $line

   close $fl

   ftdi::update_raw
   ftdi::update_core
   ftdi::update_gui
}

#-----------------------------------------
# Fill the register values from the chip
# by reading via the SPI
#-----------------------------------------

proc ftdi::getconfig {} {
   global registers
   global saved_registers
   global device
   
   dict for {regname reg} $registers {
      set number [dict get $reg number]
      set nbytes [llength [dict get $reg values]]
      set rvals [spi_read $device $number $nbytes]
      dict set registers $regname values $rvals
   }
   set saved_registers $registers
}

#--------------------------------------------------------------------
# If the focus window is an entry window, it is possible to update
# its contents and then attempt to configure or program the chip
# before its contents have been written back to the core.  This
# routine, to be run from the "Config" and "Program" button
# callback procedures, automatically generates a "return" key
# event in the focus window, thus forcing an update.
#--------------------------------------------------------------------

proc ftdi::setentry {} {
   set fwindow [focus]
   set class [winfo class $fwindow]
   if {"$class" == "Entry"} {
      event generate $fwindow <Return>
   }
}

#---------------------------------------------------------------------
# Generate a standard text entry field, with a label on the left
#---------------------------------------------------------------------

proc ftdi::stdentry {parent widget name size {color black}} {
   frame ${parent}.${widget}
   label ${parent}.${widget}.label -text $name -foreground $color
   entry ${parent}.${widget}.field -width $size
   pack ${parent}.${widget}.label -side left -padx 5
   pack ${parent}.${widget}.field -side left
}

#---------------------------------------------------------------------
# Set an entry field in a standard label/entry field frame
#---------------------------------------------------------------------

proc ftdi::set_std_entry {winname value} {
   ${winname}.field delete 0 end
   ${winname}.field insert 0 $value
}

#---------------------------------------------------------------------
# Similar to stdentry, but puts the label on top and the entry field
# underneath.  Associated routines std_entry_bind and set_std_entry
# are the same as for stdentry.
#---------------------------------------------------------------------

proc ftdi::topentry {parent widget name size {color black}} {
   frame ${parent}.${widget}
   label ${parent}.${widget}.label -text $name -foreground $color
   entry ${parent}.${widget}.field -width $size
   pack ${parent}.${widget}.label -side top -pady 3
   pack ${parent}.${widget}.field -side top
}

#--------------------------------------------------------------------
# Bind a callback procedure to an entry widget, so that changing the
# entry updates the core and raw entries, when the return key is
# pressed or when the entry widget loses focus.
#--------------------------------------------------------------------

proc ftdi::entry_bind {winname signame {minval 0} {maxval 255}} {
   bind $winname <Return> [subst { \
	catch { \
	set value \[$winname get\]; \
	if {\$value > $maxval} {set value $maxval}; \
	if {\$value < $minval} {set value $minval}; \
	dict set core $signame \$value; \
	ftdi::writeback_core; ftdi::update_raw; ftdi::update_gui}}]
   bind $winname <Leave> [subst { \
	catch { \
	if {"\[focus\]" == "$winname"} { \
	set value \[$winname get\]; \
	if {\$value > $maxval} {set value $maxval}; \
	if {\$value < $minval} {set value $minval}; \
	dict set core $signame \$value; \
	ftdi::writeback_core; ftdi::update_raw; ftdi::update_gui}}}]
   bind $winname <FocusOut> [subst { \
	catch { \
	set value \[$winname get\]; \
	if {\$value > $maxval} {set value $maxval}; \
	if {\$value < $minval} {set value $minval}; \
	dict set core $signame \$value; \
	ftdi::writeback_core; ftdi::update_raw; ftdi::update_gui}}]
}

#---------------------------------------------------------------------
# Bind a callback function to a standard text entry field
#---------------------------------------------------------------------

proc ftdi::std_entry_bind {winname signame {minval 0} {maxval 255}} {
   set fieldname ${winname}.field
   bind $fieldname <Return> [subst { \
	catch { \
	set value \[$fieldname get\]; \
	if {\$value > $maxval} {set value $maxval}; \
	if {\$value < $minval} {set value $minval}; \
	dict set core $signame \$value; \
	ftdi::writeback_core; ftdi::update_raw; \
	ftdi::update_gui}}]
   bind $fieldname <Leave> [subst { \
	catch { \
	if {"\[focus\]" == "$fieldname"} { \
	set value \[$fieldname get\]; \
	if {\$value > $maxval} {set value $maxval}; \
	if {\$value < $minval} {set value $minval}; \
	dict set core $signame \$value; \
	ftdi::writeback_core; ftdi::update_raw; \
	ftdi::update_gui}}}]
   bind $fieldname <FocusOut> [subst { \
	catch { \
	set value \[$fieldname get\]; \
	if {\$value > $maxval} {set value $maxval}; \
	if {\$value < $minval} {set value $minval}; \
	dict set core $signame \$value; \
	ftdi::writeback_core; ftdi::update_raw; \
	ftdi::update_gui}}]
}

#--------------------------------------------------------------------
# Bind a callback procedure to a dropdown menu widget with choices
#--------------------------------------------------------------------

proc ftdi::choice_bind {winname signame menulist} {
   global core
   foreach entry $menulist {
      set mlab [lindex $entry 0]
      set mval [lindex $entry 1]
      ${winname}.button.menu add radiobutton -value $mval -label $mlab \
	   -variable choices_$signame \
	   -command "dict set core $signame $mval; \
	   ${winname}.button config -text $mlab; \
	   ftdi::writeback_core; ftdi::update_raw; ftdi::update_gui"
   }
}

#--------------------------------------------------------------------
# Bind a checkbox button to a change in a core value
#--------------------------------------------------------------------

proc ftdi::checkbox_bind {winname signame onv offv} {
   global core
   ${winname}.button config -variable choices_$signame
   ${winname}.button config -onvalue $onv
   ${winname}.button config -offvalue $offv
   ${winname}.button config -command \
	[subst {dict set core $signame \$choices_$signame; \
	 ftdi::writeback_core; ftdi::update_raw; ftdi::update_gui}]
}

#--------------------------------------------------------------------
# Bind callback procedures for a signal & override pair
# This assumes that for {winname} there is a widget called {winname}_label,
# and for signale {signame} there is a signal called override{signame}.
#--------------------------------------------------------------------

proc ftdi::override_bind {framename signame} {
   global core
   set winname ${framename}.button
   ${winname}.menu add command -label "Default" -command " \
	   dict set core override$signame 0; \
	   ${framename}.label config -text ? -foreground black; \
	   ftdi::writeback_core; ftdi::update_raw; ftdi::update_gui"
   ${winname}.menu add command -label "High (1)" -command " \
	   dict set core override$signame 1; \
	   dict set core $signame 1; \
	   ${framename}.label config -text 1 -foreground blue; \
	   ftdi::writeback_core; ftdi::update_raw; ftdi::update_gui"
   ${winname}.menu add command -label "Low (0)" -command " \
	   dict set core override$signame 1; \
	   dict set core $signame 0; \
	   ${framename}.label config -text 0 -foreground blue; \
	   ftdi::writeback_core; ftdi::update_raw; ftdi::update_gui"
}

#--------------------------------------------------------------------
# Bind a callback procedure to an entry widget, calling procedure
# "procname" to translate between the value in the entry window
# and the value in the core.  Procedure "procname" should take
# one value (the window entry value) and produce one value as a
# result (the core value).
#--------------------------------------------------------------------

proc ftdi::special_bind {winname procname args} {
   bind $winname <Return> [subst {$procname \[$winname get\] $args}]
   bind $winname <Leave> [subst {$procname \[$winname get\] $args}]
}

#---------------------------------------------------------------------
# Special entry binding --- rather than call back to change a core
# value, the procedure "procname" is called, with args.
#---------------------------------------------------------------------

proc ftdi::special_entry_bind {winname procname args} {
   set fieldname ${winname}.field
   bind $fieldname <Return> [subst {$procname \[$fieldname get\] $args}]
   bind $fieldname <Leave> [subst {$procname \[$fieldname get\] $args}]
   bind $fieldname <FocusOut> [subst {$procname \[$fieldname get\] $args}]
}

proc ftdi::simple_entry_bind {winname procname args} {
   set fieldname ${winname}.field
   bind $fieldname <Return> [subst {$procname \[$fieldname get\] $args}]
   bind $fieldname <FocusOut> [subst {$procname \[$fieldname get\] $args}]
}

#------------------------------------------------------------------------
# Set an override button configuration based on file or chip input
#------------------------------------------------------------------------

proc ftdi::get_override {framename override value} {
   if {$override == 0} {
      ${framename}.button.menu invoke 0
   } else {
      if {$value == 1} {
         ${framename}.button.menu invoke 1
      } else {
         ${framename}.button.menu invoke 2
      }
   }
}

#------------------------------------------------------------------------
# Search a dropdown menu and select the choice corresponding to the value
#------------------------------------------------------------------------

proc ftdi::get_choice {winname value} {
   set nentries [+ 1 [${winname}.button.menu index end]]
   for {set i 0} {$i < $nentries} {incr i} {
      set val [${winname}.button.menu entrycget $i -value]
      if {$val == $value} {
         ${winname}.button.menu invoke $i
	 break
      }
   }
}

#------------------------------------------------------------------------

proc ftdi::get_checkbox {winname value} {
   set val_on [${winname}.button cget -onvalue]
   set val_off [${winname}.button cget -offvalue]
   if {$value == $val_on} {
      ${winname}.button select
   } else {
      ${winname}.button deselect
   }
}

#---------------------------------------------------------------------
# Generate a button:label pair for signals with override bits
#---------------------------------------------------------------------

proc ftdi::overridebutton {parent widget name} {
   frame ${parent}.${widget}
   menubutton ${parent}.${widget}.button -text $name -menu ${parent}.${widget}.button.menu
   label ${parent}.${widget}.label -text ?
   menu ${parent}.${widget}.button.menu -tearoff 0
   pack ${parent}.${widget}.button -side left
   pack ${parent}.${widget}.label -side left -padx 5
}

#---------------------------------------------------------------------
# Generate a menu button for a drop-down list of choices
#---------------------------------------------------------------------

proc ftdi::choicebutton {parent widget name} {
   frame ${parent}.${widget}
   label ${parent}.${widget}.label -text $name
   menubutton ${parent}.${widget}.button -text ? \
	-menu ${parent}.${widget}.button.menu -foreground brown
   menu ${parent}.${widget}.button.menu -tearoff 0
   pack ${parent}.${widget}.label -side left -padx 5
   pack ${parent}.${widget}.button -side left
}

#---------------------------------------------------------------------
# Generate a checkbox entry
#---------------------------------------------------------------------

proc ftdi::checkbox {parent widget name} {
   frame ${parent}.${widget}
   label ${parent}.${widget}.label -text $name
   checkbutton ${parent}.${widget}.button
   pack ${parent}.${widget}.label -side left -padx 5
   pack ${parent}.${widget}.button -side left
}

#---------------------------------------------------------------------
# Generate a button
#---------------------------------------------------------------------

proc ftdi::procbutton {widget name proc args} {
   button ${widget} -text $name -command "$proc $args"
}

#---------------------------------------------------------------------
# Generate a standard text entry with a label in front 
#---------------------------------------------------------------------

proc ftdi::textentry {parent widget name width} {
   label ${parent}.${widget}_label -text $name
   entry ${parent}.${widget} -width $width
}

#--------------------------------------------------
# Generate a text dump of the registers
#--------------------------------------------------

proc ftdi::register_dump {} {
   global registers

   dict for {regname reg} $registers {
      puts -nonewline stdout "[dict get $reg number]: "
      set values [dict get $reg values]
      foreach j $values {
	 puts -nonewline stdout "[format "0x%02x" $j] "
      }
      puts stdout ""
   }
}

#-----------------------------------------
# Update the "raw" values window with the
# register byte values (raw data)
#-----------------------------------------

proc ftdi::update_raw {} {
   global registers
   global regframe

   set rstr ""

   dict for {regname reg} $registers {
      set values [dict get $reg values]
      set d 0
      foreach dval $values {
         set bval [ftdi::bconvert $dval 8]
	 ftdi::set_std_entry ${regframe}.reglist.${regname}${d} $bval
	 incr d
      }
   }
}

#--------------------------------------------------
# Update the "core" dictionary from the registers.
# The core dictionary holds the human-readable
# values, rather than the binary dump of the
# register bytes.
#--------------------------------------------------

proc ftdi::update_core {} {
   global registers
   global core

   # First read all the values of interest

   set values [dict get $registers reg0 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   set byte2 [lindex $values 2]
   dict set core mfgrid [+ [* 256 [& $byte1 0x0f]] $byte0]
   dict set core revision [>> [& $byte1 0xf0] 4]
   dict set core prodid $byte0

   set values [dict get $registers reg1 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   set byte2 [lindex $values 2]
   dict set core timer1_ringosc_freq [>> [& $byte0 0xc0] 6]
   dict set core timer0_ringosc_freq [>> [& $byte0 0x30] 4]
   dict set core poweron_status [& $byte0 0x0f]
   dict set core timer0_count [>> [& $byte1 0xfe] 1]
   dict set core timer0_enable [& $byte1 0x01]
   dict set core timer1_count [>> [& $byte2 0xfe] 1]
   dict set core timer1_enable [& $byte2 0x01]

   set values [dict get $registers reg2 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   set byte2 [lindex $values 2]
   set byte3 [lindex $values 3]
   dict set core DAC0_value [+ [* 256 [& $byte1 0x0f]] $byte0]
   dict set core DAC0_enable [>> [& $byte1 0x10] 4]
   dict set core DAC1_value [+ [* 256 [& $byte3 0x0f]] $byte2]
   dict set core DAC1_enable [>> [& $byte3 0x10] 4]

   set values [dict get $registers reg3 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   set byte2 [lindex $values 2]
   set byte3 [lindex $values 3]
   set byte4 [lindex $values 4]
   set byte5 [lindex $values 5]
   dict set core ADC0_value [+ [* 256 [& $byte1 0x0f]] $byte0]
   dict set core ADC0_input_select [>> [& $byte1 0xf0] 4]
   dict set core ADC0_vref_select [>> [& $byte2 0x0c] 2]
   dict set core ADC0_run [>> [& $byte2 0x02] 1]
   dict set core ADC0_enable [& $byte2 0x01]
   dict set core ADC1_value [+ [* 256 [& $byte4 0x0f]] $byte3]
   dict set core ADC1_input_select [>> [& $byte4 0xf0] 4]
   dict set core ADC1_vref_select [>> [& $byte5 0x0c] 2]
   dict set core ADC1_run [>> [& $byte5 0x02] 1]
   dict set core ADC1_enable [& $byte5 0x01]

   set values [dict get $registers reg4 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   dict set core bandgap_trim [>> [& $byte0 0xf0] 4]
   dict set core Vref0_value [>> [& $byte0 0x0e] 1]
   dict set core Vref0_enable [& $byte0 0x01]
   dict set core Vref1_value [>> [& $byte1 0x0e] 1]
   dict set core Vref1_enable [& $byte1 0x01]

   set values [dict get $registers reg5 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   dict set core LDO0_value [>> [& $byte0 0x0e] 1]
   dict set core LDO0_enable [& $byte0 0x01]
   dict set core LDO1_value [>> [& $byte1 0x0e] 1]
   dict set core LDO1_enable [& $byte1 0x01]

   set values [dict get $registers reg6 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   dict set core Iref0_value [>> [& $byte0 0x0e] 1]
   dict set core Iref0_enable [& $byte0 0x01]
   dict set core Iref1_value [>> [& $byte1 0x0e] 1]
   dict set core Iref1_enable [& $byte1 0x01]

   set values [dict get $registers reg7 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   dict set core PWM0_input_source [>> [& $byte0 0x0e] 1]
   dict set core PWM0_enable [& $byte0 0x01]
   dict set core PWM1_input_source [>> [& $byte1 0x0e] 1]
   dict set core PWM1_enable [& $byte1 0x01]

   set values [dict get $registers reg8 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   dict set core Buf0_mode [>> [& $byte0 0x06] 1]
   dict set core Buf0_enable [& $byte0 0x01]
   dict set core Buf1_mode [>> [& $byte1 0x06] 1]
   dict set core Buf1_enable [& $byte1 0x01]

   set values [dict get $registers reg9 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   dict set core OpAmp0_input_source [>> [& $byte0 0x0e] 1]
   dict set core OpAmp0_enable [& $byte0 0x01]
   dict set core Comp0_out [>> [& $byte0 0x10] 4]
   dict set core OpAmp1_input_source [>> [& $byte1 0x0e] 1]
   dict set core OpAmp1_enable [& $byte1 0x01]
   dict set core Comp1_out [>> [& $byte1 0x10] 4]

   set values [dict get $registers reg10 values]
   set byte0 [lindex $values 0]
   set byte1 [lindex $values 1]
   dict set core TempSens0_enable [& $byte0 0x01]
   dict set core TempSens1_enable [& $byte1 0x01]
}

#---------------------------------------------------------------
# Writeback:  Copy core values back into the registers
#---------------------------------------------------------------

proc ftdi::writeback_core {} {
   global registers
   global core

   # Derived values: (none)

   # NOTE:  All read-only values are ignored, as they cannot be
   # written back.  Values are pulled from the register instead
   # of the core signal value, and written directly back to the
   # register

   # Register 0 is all read-only and can be ignored.

   set values [dict get $registers reg1 values]
   set byte0 [& [lindex $values 0] 0x0f]
   set byte0 [& [<< [dict get $core timer0_ringosc_freq] 4] 0x30]
   set byte0 [| $byte0 [ & [<< [dict get $core timer1_ringosc_freq] 6] 0xc0]]
   set byte1 [& [<< [dict get $core timer0_count] 1] 0xfe]
   set byte1 [| $byte1 [dict get $core timer0_enable]]
   set byte2 [& [<< [dict get $core timer1_count] 1] 0xfe]
   set byte2 [| $byte2 [dict get $core timer1_enable]]
   dict set registers reg1 values [list $byte0 $byte1 $byte2]

   set byte0 [& [dict get $core DAC0_value] 0xff]
   set byte1 [& [>> [dict get $core DAC0_value] 8] 0x0f]
   set byte1 [| $byte1 [& [<< [dict get $core DAC0_enable] 4] 0x01]]
   set byte2 [& [dict get $core DAC1_value] 0xff]
   set byte3 [& [>> [dict get $core DAC1_value] 8] 0x0f]
   set byte3 [| $byte3 [& [<< [dict get $core DAC1_enable] 4] 0x01]]
   dict set registers reg2 values [list $byte0 $byte1 $byte2 $byte3]

   # ADC values are read-only
   set values [dict get $registers reg3 values]
   set byte0 [lindex $values 0]
   set byte1 [& [lindex $values 1] 0x0f]
   set byte1 [| $byte1 [& [<< [dict get $core ADC0_input_select] 4] 0xf0]]
   set byte2 [& [<< [dict get $core ADC0_vref_select] 2] 0x0c]
   set byte2 [| $byte2 [& [<< [dict get $core ADC0_run] 1] 0x02]]
   set byte2 [| $byte2 [& [dict get $core ADC0_enable] 0x01]]
   set byte3 [lindex $values 3]
   set byte4 [& [lindex $values 4] 0x0f]
   set byte4 [| $byte4 [& [<< [dict get $core ADC1_input_select] 4] 0xf0]]
   set byte5 [& [<< [dict get $core ADC1_vref_select] 2] 0x0c]
   set byte5 [| $byte5 [& [<< [dict get $core ADC1_run] 1] 0x02]]
   set byte5 [| $byte5 [& [dict get $core ADC0_enable] 0x01]]
   dict set registers reg3 values [list $byte0 $byte1 $byte2 $byte3 $byte4 $byte5]

   set byte0 [& [<< [dict get $core bandgap_trim] 4] 0xf0]
   set byte0 [| $byte0 [& [<< [dict get $core Vref0_value] 1] 0x0e]]
   set byte0 [| $byte0 [& [dict get $core Vref0_enable] 0x01]]
   set byte1 [& [<< [dict get $core Vref1_value] 1] 0x0e]
   set byte1 [| $byte1 [& [dict get $core Vref1_enable] 0x01]]
   dict set registers reg4 values [list $byte0 $byte1]

   set byte0 [& [<< [dict get $core LDO0_value] 1] 0x0e]
   set byte0 [| $byte0 [& [dict get $core LDO0_enable] 0x01]]
   set byte1 [& [<< [dict get $core LDO1_value] 1] 0x0e]
   set byte1 [| $byte1 [& [dict get $core LDO1_enable] 0x01]]
   dict set registers reg5 values [list $byte0 $byte1]

   set byte0 [& [<< [dict get $core Iref0_value] 1] 0x0e]
   set byte0 [| $byte0 [& [dict get $core Iref0_enable] 0x01]]
   set byte1 [& [<< [dict get $core Iref1_value] 1] 0x0e]
   set byte1 [| $byte1 [& [dict get $core Iref1_enable] 0x01]]
   dict set registers reg6 values [list $byte0 $byte1]

   set byte0 [& [<< [dict get $core PWM0_input_source] 1] 0x1e]
   set byte0 [| $byte0 [& [dict get $core PWM0_enable] 0x01]]
   set byte1 [& [<< [dict get $core PWM1_input_source] 1] 0x1e]
   set byte1 [| $byte1 [& [dict get $core PWM1_enable] 0x01]]
   dict set registers reg7 values [list $byte0 $byte1]

   set byte0 [& [<< [dict get $core Buf0_mode] 1] 0x06]
   set byte0 [| $byte0 [& [dict get $core Buf0_enable] 0x01]]
   set byte1 [& [<< [dict get $core Buf1_mode] 1] 0x06]
   set byte1 [| $byte1 [& [dict get $core Buf1_enable] 0x01]]
   dict set registers reg8 values [list $byte0 $byte1]

   # Comp0_out and Comp1_out are read-only
   set values [dict get $registers reg9 values]
   set byte0 [& [lindex $values 0] 0x10]
   set byte1 [& [lindex $values 1] 0x10]

   set byte0 [| $byte0 [& [<< [dict get $core OpAmp0_input_source] 1] 0x0e]]
   set byte0 [| $byte0 [& [dict get $core OpAmp0_enable] 0x01]]
   set byte1 [| $byte1 [& [<< [dict get $core OpAmp1_input_source] 1] 0x0e]]
   set byte1 [| $byte1 [& [dict get $core OpAmp1_enable] 0x01]]
   dict set registers reg9 values [list $byte0 $byte1]

   set byte0 [& [dict get $core TempSens0_enable] 0x01]
   set byte1 [& [dict get $core TempSens1_enable] 0x01]
   dict set registers reg10 values [list $byte0 $byte1]
}

#---------------------------------------------------------------
# Update the GUI windows (except "raw"; see above)
#---------------------------------------------------------------

proc ftdi::update_gui {} {
   global registers
   global core
   global update_level
   global appframe

   if {$update_level > 0} {return}
   incr update_level

   # Reconfigure the product/manufacturer title bar

   set mfgr_id [dict get $core mfgrid]
   if {$mfgr_id == 0x00} {
      ${appframe}.id.mfgrid config -text "eFabless"
   } else {
      set mfgr_id [format "0x%03x" [dict get $core mfgrid]]
      ${appframe}.id.mfgrid config -text "Unknown ID $mfgr_id"
   }
   set pid [dict get $core prodid]
   if {$pid == 0x00} {
      set rev [dict get $core revision]
      ${appframe}.id.prodid config -text "Hydra rev $rev (emulated)"
   } else {
      set pid [format "0x%02x" [dict get $core prodid]]
      ${appframe}.id.prodid config -text "Unknown ID $pid"
   }

   # Reconfigure all core widgets

   set coreframe ${appframe}.pic.n.c1
   ftdi::get_choice ${coreframe}.timer0_ringosc_freq [dict get $core timer0_ringosc_freq]
   ftdi::set_std_entry ${coreframe}.timer0_count [dict get $core timer0_count]
   ftdi::get_checkbox ${coreframe}.timer0_enable [dict get $core timer0_enable]

   ftdi::get_choice ${coreframe}.timer1_ringosc_freq [dict get $core timer1_ringosc_freq]
   ftdi::set_std_entry ${coreframe}.timer1_count [dict get $core timer1_count]
   ftdi::get_checkbox ${coreframe}.timer1_enable [dict get $core timer1_enable]

   ftdi::get_checkbox ${coreframe}.dac0_enable [dict get $core DAC0_enable]
   ftdi::set_std_entry ${coreframe}.dac0_value [dict get $core DAC0_value]

   ftdi::get_checkbox ${coreframe}.dac1_enable [dict get $core DAC1_enable]
   ftdi::set_std_entry ${coreframe}.dac1_value [dict get $core DAC1_value]

   ftdi::get_checkbox ${coreframe}.adc0_enable [dict get $core ADC0_enable]
   ${coreframe}.adc0_value config -text [dict get $core ADC0_value]
   ftdi::get_choice ${coreframe}.adc0_input_select [dict get $core ADC0_input_select]

   ftdi::get_checkbox ${coreframe}.adc1_enable [dict get $core ADC1_enable]
   ${coreframe}.adc1_value config -text [dict get $core ADC1_value]
   ftdi::get_choice ${coreframe}.adc1_input_select [dict get $core ADC1_input_select]

   ftdi::get_checkbox ${coreframe}.vref0_enable [dict get $core Vref0_enable]
   ftdi::get_choice ${coreframe}.vref0_value [dict get $core Vref0_value]

   ftdi::get_checkbox ${coreframe}.vref1_enable [dict get $core Vref1_enable]
   ftdi::get_choice ${coreframe}.vref1_value [dict get $core Vref1_value]

   ftdi::get_checkbox ${coreframe}.ldo0_enable [dict get $core LDO0_enable]
   ftdi::get_choice ${coreframe}.ldo0_value [dict get $core LDO0_value]

   ftdi::get_checkbox ${coreframe}.ldo1_enable [dict get $core LDO1_enable]
   ftdi::get_choice ${coreframe}.ldo1_value [dict get $core LDO1_value]

   ftdi::get_checkbox ${coreframe}.iref0_enable [dict get $core Iref0_enable]
   ftdi::get_choice ${coreframe}.iref0_value [dict get $core Iref0_value]

   ftdi::get_checkbox ${coreframe}.iref1_enable [dict get $core Iref1_enable]
   ftdi::get_choice ${coreframe}.iref1_value [dict get $core Iref1_value]

   ftdi::get_checkbox ${coreframe}.pwm0_enable [dict get $core PWM0_enable]
   ftdi::get_choice ${coreframe}.pwm0_input_source [dict get $core PWM0_input_source]

   ftdi::get_checkbox ${coreframe}.pwm1_enable [dict get $core PWM1_enable]
   ftdi::get_choice ${coreframe}.pwm1_input_source [dict get $core PWM1_input_source]

   ftdi::get_checkbox ${coreframe}.buf0_enable [dict get $core Buf0_enable]

   ftdi::get_checkbox ${coreframe}.buf1_enable [dict get $core Buf1_enable]

   ftdi::get_checkbox ${coreframe}.opamp0_enable [dict get $core OpAmp0_enable]
   ftdi::get_choice ${coreframe}.opamp0_input_source [dict get $core OpAmp0_input_source]

   ftdi::get_checkbox ${coreframe}.opamp1_enable [dict get $core OpAmp1_enable]
   ftdi::get_choice ${coreframe}.opamp1_input_source [dict get $core OpAmp1_input_source]

   ftdi::get_checkbox ${coreframe}.tempsens0_enable [dict get $core TempSens0_enable]

   ftdi::get_checkbox ${coreframe}.tempsens1_enable [dict get $core TempSens1_enable]

   incr update_level -1
}

#---------------------------------------------------------------
# Window resize callbacks:
# (1) canvas_resize ensures that the entire canvas is
#	displayable, and
# (2) window_limit ensures that the window size is not higher
#	than the screen size.
#---------------------------------------------------------------

proc ftdi::canvas_resize {} {
   global appframe appcanvas

   set cwidth [winfo width $appframe]
   set cheight [winfo height $appframe]
   $appcanvas configure -scrollregion [list 0 0 $cwidth $cheight]
}

proc ftdi::window_limit {} {
   global appframe appname appshell

   set cheight [winfo height $appframe]
   set cheight1 [+ $cheight [winfo height ${appshell}.menu]]
   set cheight2 [- [winfo screenheight ${appname}] 50]
}

#---------------------------------------------------------------
# Generate the main core diagram and widgets
#---------------------------------------------------------------

proc ftdi::make_core {corename} {
   canvas $corename -width 1200 -height 700 -background white
   set coreframe [winfo parent $corename]
   ${coreframe} add $corename -text "Hydra"

   if {![catch {image create photo backgnd -file hydra_block_bkgnd.gif}]} {
      $corename create image 580 350 -image backgnd -anchor center
   }

   if {![catch {image create photo elogo -file efabless_logo.png}]} {
      $corename create image 780 830 -image elogo -anchor center
   }

   #--------Timer0-------------
   ftdi::choicebutton $corename timer0_ringosc_freq "Ring Osc Freq.:" 
   ftdi::choice_bind ${corename}.timer0_ringosc_freq timer0_ringosc_freq \
		{{5MHz 0} {10MHz 1} {20MHz 2} {40MHz 3}}
   ${corename} create window 440 270 -window ${corename}.timer0_ringosc_freq \
        -anchor center

   ftdi::topentry $corename timer0_count "Timer 0 value:" 8
   ftdi::std_entry_bind ${corename}.timer0_count timer0_count 0 127
   ${corename} create window 390 310 -window ${corename}.timer0_count -anchor center

   ftdi::checkbox $corename timer0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.timer0_enable timer0_enable 1 0
   ${corename} create window 490 310 -window ${corename}.timer0_enable -anchor center

   #--------Timer1-------------
   ftdi::choicebutton $corename timer1_ringosc_freq "Ring Osc Freq.:" 
   ftdi::choice_bind ${corename}.timer1_ringosc_freq timer1_ringosc_freq \
		{{5MHz 0} {10MHz 1} {20MHz 2} {40MHz 3}}
   ${corename} create window 440 350 -window ${corename}.timer1_ringosc_freq \
        -anchor center

   ftdi::topentry $corename timer1_count "Timer 1 value:" 8
   ftdi::std_entry_bind ${corename}.timer1_count timer1_count 0 127
   ${corename} create window 390 390 -window ${corename}.timer1_count -anchor center

   ftdi::checkbox $corename timer1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.timer1_enable timer1_enable 1 0
   ${corename} create window 490 390 -window ${corename}.timer1_enable -anchor center

   #--------DAC0-------------

   ftdi::checkbox $corename dac0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.dac0_enable DAC0_enable 1 0
   ${corename} create window 100 60 -window ${corename}.dac0_enable -anchor center

   ftdi::topentry $corename dac0_value "DAC 0 value:" 8
   ftdi::std_entry_bind ${corename}.dac0_value dac0_value 0 4095
   ${corename} create window 100 100 -window ${corename}.dac0_value -anchor center

   #--------DAC1-------------

   ftdi::checkbox $corename dac1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.dac1_enable DAC1_enable 1 0
   ${corename} create window 100 140 -window ${corename}.dac1_enable -anchor center

   ftdi::topentry $corename dac1_value "DAC 1 value:" 8
   ftdi::std_entry_bind ${corename}.dac1_value dac1_value 0 4095
   ${corename} create window 100 180 -window ${corename}.dac1_value -anchor center

   #--------ADC0-------------

   ftdi::checkbox $corename adc0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.adc0_enable ADC0_enable 1 0
   ${corename} create window 380 60 -window ${corename}.adc0_enable -anchor center

   label ${corename}.adc0_value_label -text "Value:"
   ${corename} create window 380 100 -window ${corename}.adc0_value_label -anchor center
   label ${corename}.adc0_value -text "----"
   ${corename} create window 440 100 -window ${corename}.adc0_value -anchor center

   ftdi::choicebutton $corename adc0_input_select "Input:" 
   ftdi::choice_bind ${corename}.adc0_input_select ADC0_input_select \
		{{Vref0 0} {Vref1 1} {TempSens0 2} {TempSens1 3} {Buf0 4}\
		 {Buf1 5} {OpAmp0 6} {OpAmp1 7}}
   ${corename} create window 490 60 -window ${corename}.adc0_input_select \
        -anchor center

   #--------ADC1-------------

   ftdi::checkbox $corename adc1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.adc1_enable ADC1_enable 1 0
   ${corename} create window 380 140 -window ${corename}.adc1_enable -anchor center

   label ${corename}.adc1_value_label -text "Value:"
   ${corename} create window 380 180 -window ${corename}.adc1_value_label -anchor center
   label ${corename}.adc1_value -text "----"
   ${corename} create window 440 180 -window ${corename}.adc1_value -anchor center

   ftdi::choicebutton $corename adc1_input_select "Input:" 
   ftdi::choice_bind ${corename}.adc1_input_select ADC1_input_select \
		{{Vref0 0} {Vref1 1} {TempSens0 2} {TempSens1 3} {Buf0 4}\
		 {Buf1 5} {OpAmp0 6} {OpAmp1 7}}
   ${corename} create window 490 140 -window ${corename}.adc1_input_select \
        -anchor center

   #--------Vref0-------------

   ftdi::checkbox $corename vref0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.vref0_enable Vref0_enable 1 0
   ${corename} create window 660 60 -window ${corename}.vref0_enable -anchor center

   ftdi::choicebutton $corename vref0_value "Value:" 
   ftdi::choice_bind ${corename}.vref0_value Vref0_value \
		{{0.8V 0} {1.0V 1} {1.2V 2} {1.5V 3} {1.8V 4} {2.0V 5} \
		 {2.8V 6} {3.0V 7}}
   ${corename} create window 660 100 -window ${corename}.vref0_value -anchor center

   #--------Vref1-------------

   ftdi::checkbox $corename vref1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.vref1_enable Vref1_enable 1 0
   ${corename} create window 660 140 -window ${corename}.vref1_enable -anchor center

   ftdi::choicebutton $corename vref1_value "Value:" 
   ftdi::choice_bind ${corename}.vref1_value Vref1_value \
		{{0.8V 0} {1.0V 1} {1.2V 2} {1.5V 3} {1.8V 4} {2.0V 5} \
		 {2.8V 6} {3.0V 7}}
   ${corename} create window 660 180 -window ${corename}.vref1_value -anchor center

   #--------LDO0-------------

   ftdi::checkbox $corename ldo0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.ldo0_enable LDO0_enable 1 0
   ${corename} create window 940 60 -window ${corename}.ldo0_enable -anchor center

   ftdi::choicebutton $corename ldo0_value "Value:" 
   ftdi::choice_bind ${corename}.ldo0_value LDO0_value \
		{{0.8V 0} {1.0V 1} {1.2V 2} {1.5V 3} {1.8V 4} {2.0V 5} \
		 {2.8V 6} {3.0V 7}}
   ${corename} create window 940 100 -window ${corename}.ldo0_value -anchor center

   #--------LDO1-------------

   ftdi::checkbox $corename ldo1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.ldo1_enable LDO1_enable 1 0
   ${corename} create window 940 140 -window ${corename}.ldo1_enable -anchor center

   ftdi::choicebutton $corename ldo1_value "Value:" 
   ftdi::choice_bind ${corename}.ldo1_value LDO1_value \
		{{0.8V 0} {1.0V 1} {1.2V 2} {1.5V 3} {1.8V 4} {2.0V 5} \
		 {2.8V 6} {3.0V 7}}
   ${corename} create window 940 180 -window ${corename}.ldo1_value -anchor center

   #--------Iref0-------------

   ftdi::checkbox $corename iref0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.iref0_enable Iref0_enable 1 0
   ${corename} create window 940 290 -window ${corename}.iref0_enable -anchor center

   ftdi::choicebutton $corename iref0_value "Value:" 
   ftdi::choice_bind ${corename}.iref0_value Iref0_value \
		{{100uA 0} {200uA 1} {500uA 2} {1mA 3} {2mA 4} {5mA 5} \
		 {10mA 6} {20mA 7}}
   ${corename} create window 940 330 -window ${corename}.iref0_value -anchor center

   #--------Iref1-------------

   ftdi::checkbox $corename iref1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.iref1_enable Iref1_enable 1 0
   ${corename} create window 940 360 -window ${corename}.iref1_enable -anchor center

   ftdi::choicebutton $corename iref1_value "Value:" 
   ftdi::choice_bind ${corename}.iref1_value Iref1_value \
		{{100uA 0} {200uA 1} {500uA 2} {1mA 3} {2mA 4} {5mA 5} \
		 {10mA 6} {20mA 7}}
   ${corename} create window 940 400 -window ${corename}.iref1_value -anchor center

   #--------PWM0-------------

   ftdi::checkbox $corename pwm0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.pwm0_enable PWM0_enable 1 0
   ${corename} create window 940 500 -window ${corename}.pwm0_enable -anchor center

   ftdi::choicebutton $corename pwm0_input_source "Input:" 
   ftdi::choice_bind ${corename}.pwm0_input_source PWM0_input_source \
		{{Vref0 0} {Vref1 1} {TempSens0 2} {TempSens1 3} {Buf0 4}\
		 {Buf1 5} {OpAmp0 6} {OpAmp1 7}}
   ${corename} create window 940 540 -window ${corename}.pwm0_input_source \
        -anchor center

   #--------PWM1-------------

   ftdi::checkbox $corename pwm1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.pwm1_enable PWM1_enable 1 0
   ${corename} create window 940 570 -window ${corename}.pwm1_enable -anchor center

   ftdi::choicebutton $corename pwm1_input_source "Input:" 
   ftdi::choice_bind ${corename}.pwm1_input_source PWM1_input_source \
		{{Vref0 0} {Vref1 1} {TempSens0 2} {TempSens1 3} {Buf0 4}\
		 {Buf1 5} {OpAmp0 6} {OpAmp1 7}}
   ${corename} create window 940 610 -window ${corename}.pwm1_input_source \
        -anchor center

   #--------Buf0-------------

   ftdi::checkbox $corename buf0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.buf0_enable Buf0_enable 1 0
   ${corename} create window 660 500 -window ${corename}.buf0_enable -anchor center

   #--------Buf1-------------

   ftdi::checkbox $corename buf1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.buf1_enable Buf1_enable 1 0
   ${corename} create window 660 570 -window ${corename}.buf1_enable -anchor center

   #--------OpAmp0-------------

   ftdi::checkbox $corename opamp0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.opamp0_enable OpAmp0_enable 1 0
   ${corename} create window 380 500 -window ${corename}.opamp0_enable -anchor center

   ftdi::choicebutton $corename opamp0_input_source "Input:" 
   ftdi::choice_bind ${corename}.opamp0_input_source OpAmp0_input_source \
		{{Vref0 0} {Vref1 1} {TempSens0 2} {TempSens1 3} {Buf0 4}\
		 {Buf1 5} {OpAmp0 6} {OpAmp1 7}}
   ${corename} create window 380 540 -window ${corename}.opamp0_input_source \
        -anchor center

   #--------OpAmp1-------------

   ftdi::checkbox $corename opamp1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.opamp1_enable OpAmp1_enable 1 0
   ${corename} create window 380 570 -window ${corename}.opamp1_enable -anchor center

   ftdi::choicebutton $corename opamp1_input_source "Input:" 
   ftdi::choice_bind ${corename}.opamp1_input_source OpAmp1_input_source \
		{{Vref0 0} {Vref1 1} {TempSens0 2} {TempSens1 3} {Buf0 4}\
		 {Buf1 5} {OpAmp0 6} {OpAmp1 7}}
   ${corename} create window 380 610 -window ${corename}.opamp1_input_source \
        -anchor center

   #--------TempSens0-------------

   ftdi::checkbox $corename tempsens0_enable "Enable:"
   ftdi::checkbox_bind ${corename}.tempsens0_enable TempSens0_enable 1 0
   ${corename} create window 100 500 -window ${corename}.tempsens0_enable -anchor center

   #--------TempSens1-------------

   ftdi::checkbox $corename tempsens1_enable "Enable:"
   ftdi::checkbox_bind ${corename}.tempsens1_enable TempSens1_enable 1 0
   ${corename} create window 100 570 -window ${corename}.tempsens1_enable -anchor center

}

#---------------------------------------------------------------
# Generate the GUI window and callbacks
#---------------------------------------------------------------

set appname .hydra
toplevel $appname
wm title $appname tclftdi
wm group $appname .
wm protocol $appname WM_DELETE_WINDOW "ftdi::quit"

set appshell ${appname}.sh
set appcanvas ${appshell}.c
set appframe ${appcanvas}.f

frame  ${appname}.sh
frame  ${appshell}.menu
canvas ${appcanvas} -yscrollcommand "${appshell}.sb set" \
		-xscrollcommand "${appshell}.xsb set"
scrollbar ${appshell}.sb -command "${appcanvas} yview"
scrollbar ${appshell}.xsb -orient horizontal -command "${appcanvas} xview"
frame  ${appframe}

pack ${appshell} -side left -expand true -fill both

grid ${appshell}.menu -row 0 -column 0 -columnspan 2 -sticky news
grid ${appcanvas} -row 1 -column 0 -sticky news
grid ${appshell}.sb -row 1 -column 1 -sticky news
grid ${appshell}.xsb -row 2 -column 0 -sticky news
grid columnconfigure ${appshell} 0 -weight 1
grid rowconfigure ${appshell} 1 -weight 1

${appcanvas} create window 0 0 -window ${appframe} -anchor nw
${appcanvas} configure -scrollregion {0 0 1000 1200}

bind ${appframe} <Configure> ftdi::canvas_resize
bind ${appname} <Configure> ftdi::window_limit

frame ${appframe}.config -relief ridge -borderwidth 2
frame ${appframe}.id -relief ridge -borderwidth 2
frame ${appframe}.pic -relief ridge -borderwidth 2

grid ${appframe}.config -row 1 -column 0 -columnspan 2 -sticky news -padx 10
grid ${appframe}.id -row 2 -column 0 -columnspan 2 -sticky news -padx 10
grid ${appframe}.pic -row 3 -column 0 -columnspan 2 -sticky news -padx 10

grid columnconfigure ${appframe} 0 -weight 1
grid columnconfigure ${appframe} 1 -weight 1
grid rowconfigure ${appframe} 8 -weight 1

label ${appframe}.config.label -text "Configuration file:"
label ${appframe}.config.file -text "(none)" -foreground blue
entry ${appframe}.config.info -width 80 -foreground brown

pack ${appframe}.config.label -side left -padx 10
pack ${appframe}.config.file -side left -padx 10
pack ${appframe}.config.info -side left -padx 10

label ${appframe}.id.mfgrid_label -text "Manufacturer:" -foreground blue
label ${appframe}.id.mfgrid -text "???"
label ${appframe}.id.prodid_label -text "Product:" -foreground blue
label ${appframe}.id.prodid -text "???"

pack ${appframe}.id.prodid_label -side left -padx 10
pack ${appframe}.id.prodid -side left -padx 10
pack ${appframe}.id.mfgrid_label -side left -padx 10
pack ${appframe}.id.mfgrid -side left -padx 10

ttk::notebook ${appframe}.pic.n
pack ${appframe}.pic.n -side top

# Make the main GUI window in the first tab

ftdi::make_core ${appframe}.pic.n.c1

# Make second tab for raw register content

set regframe ${appframe}.pic.n.c2
frame ${regframe} -relief ridge -borderwidth 2
${appframe}.pic.n add $regframe -text "Registers"

label ${regframe}.title -text "Hydra Registers" -justify left
frame ${regframe}.reglist

grid ${regframe}.title -row 0 -column 0 -sticky nwe -padx 10
grid ${regframe}.reglist -row 1 -column 0 -sticky nwe -padx 10

ftdi::stdentry ${regframe}.reglist reg00 "Reg  0 0" 12
ftdi::stdentry ${regframe}.reglist reg01 "       1" 12
ftdi::stdentry ${regframe}.reglist reg02 "       2" 12
ftdi::stdentry ${regframe}.reglist reg10 "Reg  1 0" 12
ftdi::stdentry ${regframe}.reglist reg11 "       1" 12
ftdi::stdentry ${regframe}.reglist reg12 "       2" 12
ftdi::stdentry ${regframe}.reglist reg20 "Reg  2 0" 12
ftdi::stdentry ${regframe}.reglist reg21 "       1" 12
ftdi::stdentry ${regframe}.reglist reg22 "       2" 12
ftdi::stdentry ${regframe}.reglist reg23 "       3" 12
ftdi::stdentry ${regframe}.reglist reg30 "Reg  3 0" 12
ftdi::stdentry ${regframe}.reglist reg31 "       1" 12
ftdi::stdentry ${regframe}.reglist reg32 "       2" 12
ftdi::stdentry ${regframe}.reglist reg33 "       3" 12
ftdi::stdentry ${regframe}.reglist reg34 "       4" 12
ftdi::stdentry ${regframe}.reglist reg35 "       5" 12
ftdi::stdentry ${regframe}.reglist reg40 "Reg  4 0" 12
ftdi::stdentry ${regframe}.reglist reg41 "       1" 12
ftdi::stdentry ${regframe}.reglist reg50 "Reg  5 0" 12
ftdi::stdentry ${regframe}.reglist reg51 "       1" 12
ftdi::stdentry ${regframe}.reglist reg60 "Reg  6 0" 12
ftdi::stdentry ${regframe}.reglist reg61 "       1" 12
ftdi::stdentry ${regframe}.reglist reg70 "Reg  7 0" 12
ftdi::stdentry ${regframe}.reglist reg71 "       1" 12
ftdi::stdentry ${regframe}.reglist reg80 "Reg  8 0" 12
ftdi::stdentry ${regframe}.reglist reg81 "       1" 12
ftdi::stdentry ${regframe}.reglist reg90 "Reg  9 0" 12
ftdi::stdentry ${regframe}.reglist reg91 "       1" 12
ftdi::stdentry ${regframe}.reglist reg100 "Reg 10 0" 12
ftdi::stdentry ${regframe}.reglist reg101 "       1" 12

ftdi::simple_entry_bind ${regframe}.reglist.reg00 ftdi::write_raw_reg reg0 0
ftdi::simple_entry_bind ${regframe}.reglist.reg01 ftdi::write_raw_reg reg0 1
ftdi::simple_entry_bind ${regframe}.reglist.reg02 ftdi::write_raw_reg reg0 2
ftdi::simple_entry_bind ${regframe}.reglist.reg10 ftdi::write_raw_reg reg1 0
ftdi::simple_entry_bind ${regframe}.reglist.reg11 ftdi::write_raw_reg reg1 1
ftdi::simple_entry_bind ${regframe}.reglist.reg12 ftdi::write_raw_reg reg1 2
ftdi::simple_entry_bind ${regframe}.reglist.reg20 ftdi::write_raw_reg reg2 0
ftdi::simple_entry_bind ${regframe}.reglist.reg21 ftdi::write_raw_reg reg2 1
ftdi::simple_entry_bind ${regframe}.reglist.reg22 ftdi::write_raw_reg reg2 2
ftdi::simple_entry_bind ${regframe}.reglist.reg23 ftdi::write_raw_reg reg2 3
ftdi::simple_entry_bind ${regframe}.reglist.reg30 ftdi::write_raw_reg reg3 0
ftdi::simple_entry_bind ${regframe}.reglist.reg31 ftdi::write_raw_reg reg3 1
ftdi::simple_entry_bind ${regframe}.reglist.reg32 ftdi::write_raw_reg reg3 2
ftdi::simple_entry_bind ${regframe}.reglist.reg33 ftdi::write_raw_reg reg3 3
ftdi::simple_entry_bind ${regframe}.reglist.reg34 ftdi::write_raw_reg reg3 4
ftdi::simple_entry_bind ${regframe}.reglist.reg35 ftdi::write_raw_reg reg3 5
ftdi::simple_entry_bind ${regframe}.reglist.reg40 ftdi::write_raw_reg reg4 0
ftdi::simple_entry_bind ${regframe}.reglist.reg41 ftdi::write_raw_reg reg4 1
ftdi::simple_entry_bind ${regframe}.reglist.reg50 ftdi::write_raw_reg reg5 0
ftdi::simple_entry_bind ${regframe}.reglist.reg51 ftdi::write_raw_reg reg5 1
ftdi::simple_entry_bind ${regframe}.reglist.reg60 ftdi::write_raw_reg reg6 0
ftdi::simple_entry_bind ${regframe}.reglist.reg61 ftdi::write_raw_reg reg6 1
ftdi::simple_entry_bind ${regframe}.reglist.reg70 ftdi::write_raw_reg reg7 0
ftdi::simple_entry_bind ${regframe}.reglist.reg71 ftdi::write_raw_reg reg7 1
ftdi::simple_entry_bind ${regframe}.reglist.reg80 ftdi::write_raw_reg reg8 0
ftdi::simple_entry_bind ${regframe}.reglist.reg81 ftdi::write_raw_reg reg8 1
ftdi::simple_entry_bind ${regframe}.reglist.reg90 ftdi::write_raw_reg reg9 0
ftdi::simple_entry_bind ${regframe}.reglist.reg91 ftdi::write_raw_reg reg9 1
ftdi::simple_entry_bind ${regframe}.reglist.reg100 ftdi::write_raw_reg reg10 0
ftdi::simple_entry_bind ${regframe}.reglist.reg101 ftdi::write_raw_reg reg11 1

grid ${regframe}.reglist.reg00 -column 0 -row 0
grid ${regframe}.reglist.reg01 -column 0 -row 1
grid ${regframe}.reglist.reg02 -column 0 -row 2
grid ${regframe}.reglist.reg10 -column 0 -row 3
grid ${regframe}.reglist.reg11 -column 0 -row 4
grid ${regframe}.reglist.reg12 -column 0 -row 5
grid ${regframe}.reglist.reg20 -column 0 -row 6
grid ${regframe}.reglist.reg21 -column 0 -row 7
grid ${regframe}.reglist.reg22 -column 0 -row 8
grid ${regframe}.reglist.reg23 -column 0 -row 9

grid ${regframe}.reglist.reg30 -column 1 -row 0
grid ${regframe}.reglist.reg31 -column 1 -row 1
grid ${regframe}.reglist.reg32 -column 1 -row 2
grid ${regframe}.reglist.reg33 -column 1 -row 3
grid ${regframe}.reglist.reg34 -column 1 -row 4
grid ${regframe}.reglist.reg35 -column 1 -row 5

grid ${regframe}.reglist.reg40 -column 2 -row 0
grid ${regframe}.reglist.reg41 -column 2 -row 1
grid ${regframe}.reglist.reg50 -column 2 -row 2
grid ${regframe}.reglist.reg51 -column 2 -row 3
grid ${regframe}.reglist.reg60 -column 2 -row 4
grid ${regframe}.reglist.reg61 -column 2 -row 5

grid ${regframe}.reglist.reg70 -column 3 -row 0
grid ${regframe}.reglist.reg71 -column 3 -row 1
grid ${regframe}.reglist.reg80 -column 3 -row 2
grid ${regframe}.reglist.reg81 -column 3 -row 3
grid ${regframe}.reglist.reg90 -column 3 -row 4
grid ${regframe}.reglist.reg91 -column 3 -row 5
grid ${regframe}.reglist.reg100 -column 3 -row 6
grid ${regframe}.reglist.reg101 -column 3 -row 7


button ${appshell}.menu.quit -text Quit -command {ftdi::quit}
button ${appshell}.menu.config -text Config -command \
	{ftdi::setentry; ftdi::setconfig}
button ${appshell}.menu.save -text Save -command {ftdi::saveconfig}
button ${appshell}.menu.load -text Load -command {ftdi::loadconfig}
button ${appshell}.menu.console -text Console -command {ftdi::consoleup}
button ${appshell}.menu.configall -text "Config All" \
	-command {ftdi::setentry; ftdi::setconfig 1 ; \
	ftdi::getconfig; ftdi::update_raw; ftdi::update_core; \
	ftdi::update_gui}
button ${appshell}.menu.refresh -text "Refresh" \
	-command {ftdi::getconfig; ftdi::update_raw; ftdi::update_core; \
	ftdi::update_gui}

grid ${appshell}.menu.quit -row 0 -column 0 -sticky news -padx 10
grid ${appshell}.menu.config -row 0 -column 1 -sticky news -padx 10
grid ${appshell}.menu.save -row 0 -column 2 -sticky news -padx 10
grid ${appshell}.menu.load -row 0 -column 3 -sticky news -padx 10
grid ${appshell}.menu.console -row 0 -column 4 -sticky news -padx 10
grid ${appshell}.menu.configall -row 0 -column 5 -sticky news -padx 10
grid ${appshell}.menu.refresh -row 0 -column 6 -sticky news -padx 10

#-----------------------------------------
# Initialization
#-----------------------------------------

set tclopto_emulation 0
if {$argc > 1} {
   set device [lindex $argv 1]
   if {"$device" == "emulate"} {
      puts stdout "Running in hydra emulation mode"
      set tclftdi_emulation 1
   } elseif {[catch {ftdi::opendev $device}]} {
      ftdi::consoleontop
      puts stderr "Unable to open device $device"
      return
   }
} else {
   set devicelist [opendev]
   if {[llength $devicelist] > 1} {
      ftdi::consoleontop
      puts stderr "Multiple devices ($devicelist) open.  Please specify one to use."
      return
   } else {
      set device [lindex $devicelist 0]
   }
}

puts stdout "How about here?"   

set update_level 0

if {$tclftdi_emulation == 1} {
   set regemu $registers

   proc ftdi::spi_read {device addr nbytes} {
      global regemu
      return [dict get $regemu reg$addr values]
   }

   proc ftdi::spi_write {device addr bytes} {
      global regemu
      if {($addr > 1) && ($addr < 15)} {
         dict set regemu reg$addr values $bytes
      }
   }

   namespace import ftdi::spi_read ftdi::spi_write

   # Initial register values for emulation

   dict set regemu reg0 values {0 0 0}
   dict set regemu reg1 values {0 0 0}
   dict set regemu reg2 values {0 0 0 0}
   dict set regemu reg3 values {0 0 0 0 0 0}
   dict set regemu reg4 values {0 0}
   dict set regemu reg5 values {0 0}
   dict set regemu reg6 values {0 0}
   dict set regemu reg7 values {0 0}
   dict set regemu reg8 values {0 0}
   dict set regemu reg9 values {0 0}
   dict set regemu reg10 values {0 0}
}

set errors 0
if {[catch {ftdi::getconfig} errMsg]} {puts stderr $errMsg; incr errors}
if {[catch {ftdi::update_raw} errMsg]} {puts stderr $errMsg; incr errors}
if {[catch {ftdi::update_core} errMsg]} {puts stderr $errMsg; incr errors}
if {[catch {ftdi::update_gui} errMsg]} {puts stderr $errMsg; incr errors}
if {$errors == 0} {ftdi::consoledown}
