# CSCI 2021 Project - Thermometer

## Description

This firmware program (written in C) could find itself onboard a digital thermometer. It reads temperature information from physical sensors and displays the temperature in Fahrenheit or Celsius on the digital screen. 

### The Program

`thermo_update.c` contains three functions:
<ul>
  <li><code>set_temp_from_ports</code> : Reads and validates <code>THERMO_SENSOR_PORT</code> and <code>THERMO_STATUS_PORT</code>, storing information in a <code>temp_t</code> struct.
    
Returns 1 on failure, 0 on success.

    
  <li><code>set_display_from_temp</code> : Encodes fields from the <code>temp_t</code> struct into a 32 bit integer, <code>display</code>. 
    
Returns 1 on failure, 0 on success.

    
  <li><code>thermo_update</code> : "Main" function that calls both previous functions and writes the int <code>display</code> to the screen's port <code>THERMO_DISPLAY_PORT</code>.
    Returns 1 on failure, 0 on success.
</ul>

 The thermo_update_asm file does the same thing as thermo_update, but is written entirely in assembly.

## What is in this directory?
<ul>
  <li>  <code>README.md</code>
  <li>  <code>.gitignore</code>
  <li>  <code>thermo_update</code> : This is the main C file I wrote which is responsible for reading the physical ports and sending the correct display signal to a screen
  <li>  <code>thermo_update_asm</code> : Has the same function as thermo_update, but is written from scratch entirely in assembly
  
  <li>  <code>test_thermo_update</code> : This is the main test file (I did not write this)
  <li>  <code>thermo_main</code> : This is the main file (I did not write this)
  <li>  <code>thermo_sim</code> : Support file for test simulation (I did not write this)
  <li>  <code>thermo</code> : Header file with fundamental attributes and functions of the thermometer (I did not write this)
</ul>

