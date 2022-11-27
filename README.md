# CSCI 2021 Project - Thermometer

This program could find itself onboard a digital thermometer. The thermo_update file contains functions that read values from ports (physical sensors) and then display a temperature in F or C on a physical screen. The thermo_update_asm file does the same thing as thermo_update, but is written entirely in assembly.

#### What is in this directory?
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

