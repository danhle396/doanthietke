# jtag_uart.tcl - host side of the JTAG console (fpga/board/jtag_uart_bridge.sv).
# Run by fpga/tools/jtag_uart.py as:  quartus_stp -t jtag_uart.tcl
# Talks to the bridge through the sld_virtual_jtag instance (virtual IR = 1,
# 24-bit DR, see the bridge header) and to Python through pipes:
#   stdin  (from Python): "S <hex bytes>"  send bytes to the SoC UART
#                         "R 1" / "R 0"    hold / release the SoC reset
#                         "Q"              quit
#   stderr (to Python)  : "OK <hardware> | <device>"   connected
#                         "D <hex bytes>"  bytes received from the SoC UART
#                         "O"              bridge FIFO overflowed (bytes lost)
#                         "E <message>"    fatal error
# stderr is used because quartus_stp buffers stdout until it exits.

proc emit {msg} { puts stderr $msg; flush stderr }

set hw ""
if {[catch {get_hardware_names} hws]} {
  emit "E no JTAG cable found (USB-Blaster plugged in, board powered on?)"; exit 1
}
foreach h $hws {
  if {[string match "*USB-Blaster*" $h]} { set hw $h; break }
}
if {$hw eq ""} { emit "E no USB-Blaster found (cable plugged in, driver installed?)"; exit 1 }
set dev ""
foreach d [get_device_names -hardware_name $hw] {
  if {[string match "*EP2C35*" $d]} { set dev $d; break }
}
if {$dev eq ""} { emit "E no EP2C35 on $hw (board powered on?)"; exit 1 }

if {[catch {open_device -hardware_name $hw -device_name $dev} err]} { emit "E open_device: $err"; exit 1 }
if {[catch {device_lock -timeout 10000} err]} { emit "E device_lock: $err"; close_device; exit 1 }
if {[catch {device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value} err]} {
  emit "E no virtual JTAG instance (is de2_soc.sof with the JTAG console loaded?): $err"
  device_unlock; close_device; exit 1
}

fconfigure stdin -blocking 0 -buffering line

set rst 0
set seq 0
set data 0
set txq {}
set ovf 0
set checked 0

proc scan_once {} {
  global rst seq data
  set v [expr {($rst << 9) | ($seq << 8) | $data}]
  set r [device_virtual_dr_shift -instance_index 0 -length 24 -dr_value [format %06X $v] -value_in_hex]
  scan $r %x o
  return $o
}

emit "OK $hw | $dev"

set running 1
while {$running} {
  while {[gets stdin line] >= 0} {
    set cmd [string index $line 0]
    set arg [string trim [string range $line 1 end]]
    switch -- $cmd {
      S {
        for {set i 0} {$i + 1 < [string length $arg]} {incr i 2} {
          lappend txq [scan [string range $arg $i [expr {$i + 1}]] %x]
        }
      }
      R { set rst [expr {$arg eq "1" ? 1 : 0}] }
      Q { set running 0 }
    }
  }
  if {[eof stdin]} { set running 0 }
  if {!$running} break

  # scan until nothing moves (or 64 scans), then report what arrived
  set got {}
  for {set k 0} {$k < 64} {incr k} {
    set o [scan_once]
    if {!$checked} {
      if {(($o >> 16) & 0xFF) != 0xA5} {
        emit [format "E bridge not answering (DR = %06X): wrong .sof loaded?" $o]
        device_unlock; close_device; exit 1
      }
      set checked 1
    }
    set more 0
    if {(($o >> 8) & 1) != (($o >> 9) & 1)} {
      lappend got [format %02x [expr {$o & 0xFF}]]
      set more 1
    }
    if {(($o >> 11) & 1) && !$ovf} { set ovf 1; emit "O" } elseif {!(($o >> 11) & 1)} { set ovf 0 }
    set ack [expr {($o >> 10) & 1}]
    if {$ack == $seq && [llength $txq] > 0} {
      set data [lindex $txq 0]
      set txq [lrange $txq 1 end]
      set seq [expr {1 - $seq}]
      set more 1
    } elseif {$ack != $seq} {
      set more 1                       ;# last byte not taken yet: scan again
    }
    if {!$more} break
  }
  if {[llength $got] > 0} { emit "D [join $got {}]" }
  if {[llength $got] == 0 && [llength $txq] == 0} { after 5 }
}

# leave the SoC running
set rst 0
catch {scan_once}
catch {device_unlock}
catch {close_device}
exit 0
