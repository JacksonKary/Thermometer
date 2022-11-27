#include "thermo.h"
#include <stdbool.h>

// int set_temp_from_ports(temp_t *temp){

//     if((THERMO_SENSOR_PORT < 0 || THERMO_SENSOR_PORT > 28800) || ((THERMO_STATUS_PORT & (1 << 2)) >> 2)){ // if sensor value out of range or status port indicates error
//         temp->tenths_degrees = 0; 
//         temp->temp_mode = 3; // set mode to error
//         return 1; // return indicates error
//     }
//     // rounds to nearest tenth of a degree celsius and sets temp fields
//     // x >> 5 = x/32... x << 11 = remainder
//     if(THERMO_SENSOR_PORT % 32 >= 16){ // if remainder greater than or equal to 16 bits 
//         temp->tenths_degrees = THERMO_SENSOR_PORT >> 5; // sets the temp field to the tenth degree celsius
//         temp->tenths_degrees -= 449; // just combines rounding up by 1 (.1 degrees celsius) and subtracting 450 for -45 degrees celsius
//     }
//     else{ // if remainder less than 16 bits
//         temp->tenths_degrees = THERMO_SENSOR_PORT >> 5; 
//         temp->tenths_degrees -= 450; // no rounding needed, subtract 450 to adjust for -45 degree celsius starting point
//     }
//     if((THERMO_STATUS_PORT & (1 << 5)) >> 5){ // reads 5th bit of status port
//         temp->temp_mode = 2; // sets mode field to fahrenheit 
//         temp->tenths_degrees = ((temp->tenths_degrees * 9)/5) + 320; // converts to fahrenheit 
//     }
//     else {
//         temp->temp_mode = 1; // still in celsius
//     }
//     return 0; // no errors
// }

// int set_display_from_temp(temp_t temp, int *display){
//     // display number bit strings
//     int zero = 0b1111011;
//     int one = 0b1001000;
//     int two = 0b0111101;
//     int three = 0b1101101;
//     int four = 0b1001110;
//     int five = 0b1100111;
//     int six = 0b1110111;
//     int seven = 0b1001001;
//     int eight = 0b1111111;
//     int nine = 0b1101111;
//     int num_array[10] = {zero, one, two, three, four, five, six, seven, eight, nine};
//     int blank = 0b0000000;
//     int negative = 0b0000100;

//     *display <<= 31;

//     if(temp.temp_mode == 3 || (temp.temp_mode == 1 && (temp.tenths_degrees < -450 || temp.tenths_degrees > 450)) ){ // display error
//         *display = (0b00000110111101111110111110000000); // manually set all 32 bits to display error
//         return 1;
//     }
//     // could be included in the above if statement, but separated to fit 50 char limit
//     if((temp.temp_mode != 1 && temp.temp_mode != 2) || (temp.temp_mode == 2 && (temp.tenths_degrees < -490 || temp.tenths_degrees > 1130))){ 
//         *display = (0b00000110111101111110111110000000); // manually set all 32 bits to display error
//         return 1;
//     }
//     // mod_temp is set to the degrees in tenths  and is modified to find the place variables
//     int mod_temp = temp.tenths_degrees; // example: temp.tenths_degrees = 1121  in fahrenheit
//     if(mod_temp < 0){
//         mod_temp = -mod_temp; // if temp is negative, calculate mod with positive version
//     }
//     int temp_tenths = mod_temp % 10; // gets the tenths value. example: tenths_degrees = 1121... 1121 % 10 = 1, 1121 = 112.1 degrees, temp_tenths = 1
//     mod_temp -= temp_tenths; // 1121 - 1 = 1120  subtract tenths off to get clean modulus for next place
//     int temp_ones = (mod_temp % 100) / 10; // 1120 % 100 = 20 -> 20/10 = 2, temp_ones = 2
//     mod_temp -= temp_ones * 10; // 1120 - (2*10) = 1100  subtract ones off to get clean modulus for next place
//     int temp_tens = (mod_temp % 1000) / 100; // 1100 % 1000 = 100, 100/100 = 1, temp_tens = 1
//     mod_temp -= temp_tens * 100; // 1100 - (1*100) = 1000 subtract to get clean modulus for next place
//     int temp_hundreds = (mod_temp % 10000) / 1000; // 1000 % 10000 = 1000, 1000/1000 = 1, temp_hundreds = 1

//     if(temp_hundreds > 0 || temp_hundreds == 1){ // if degrees in the hundreds, print its place number
//         *display = (*display << 7 | (num_array[temp_hundreds])); // shifts display 7 over to the left, so ...(001 0)000 0000 then sets the temp_hundreds ...(001 0)100 1000
//     }
//     else if(temp.tenths_degrees < 0 && temp_tens != 0){ // put negative symbol if there's no hundreds place and if negative temp
//         *display  = (*display << 7 | negative); // places negative symbol
//     }
//     else{ // (temp_hundreds == 0)  if degrees not in hundreds and not negative, print blank space
//         *display = (*display << 7 & blank); // shifts display over by 7 and just fills in with 0s (& blank probably unnecessary)
//     }
//     // now the most significant 4 + 7 bits are set, time to set temp_tens bits 
//     if(temp_tens == 0 && temp_hundreds > 0){ // if tens place is 0 and hundreds place is greater than 0 then print a 0
//         *display = (*display << 7 | zero); // shifts display over and sets the 7 least significant bits to display 0
//     }
//     else if(temp.tenths_degrees < 0 && temp_tens == 0 && temp_hundreds == 0 && temp_ones != 0) { // if the number is negatives and in the ones place
//         *display = (*display << 7 | negative); // blank -> negative -> number -> number
//     }
//     else if(temp_tens == 0 && temp_hundreds == 0 && temp_ones == 0){ // if the number is negative but the number is 0 through the ones place
//         *display = (*display << 7 & blank); // blank -> blank -> negative or blank -> number
//     }
//     else if(temp_tens > 0){ // temp with tens place 
//         *display = (*display << 7 | num_array[temp_tens]); // blank -> number -> number -> number
//     }
//     if(temp_ones > 0){ // ones place is a number
//         *display = (*display << 7 | num_array[temp_ones]); 
//     }
//     else if(temp_ones == 0 && temp_tenths != 0 && temp_hundreds == 0 && temp_tens == 0){ // no ones number but there is a tenths number
//         *display = (*display << 7 | negative); // blank -> blank -> negative -> number
//     }
//     else if(temp_ones == 0 && temp_tenths == 0 && temp_tens == 0 && temp_hundreds == 0){ // all blank
//         *display = (*display << 7 & blank); // blank -> blank -> blank -> blank
//     }
//     else if(temp_tens == 0 && temp_hundreds > 0){
//         *display = (*display << 7 | zero);
//     }
//     else if(temp_ones == 0 && (temp_hundreds > 0 || temp_tens > 0)){ // if there is a placeholder in either hundreds or tenths spot, fill in ones spot with 0
//         *display = (*display << 7 | zero);
//     }
//     if(temp_tenths >= 0){ 
//         *display = (*display << 7 | num_array[temp_tenths]); 
//     }
//     if(temp.temp_mode == 1){ // celsius
//         *display = (*display | (1 << 28)); // sets 28th bit to be 1
//     }
//     if(temp.temp_mode == 2){ // fahrenheit
//         *display = (*display | (1 << 29)); // sets 29th bit to be 1
//     }
//     return 0;
// }


// int thermo_update(){
//     temp_t temp = {};
//     int return_val = set_temp_from_ports(&temp);
//     int display = 0;
//     bool failed = false; // true if one of the functions fails, return 1

//     if(return_val != 0){ // returned 1 which means error, or didn't return 0 which means error
//         THERMO_DISPLAY_PORT = 0b00000110111101111110111110000000; // set error
//         failed = true; // indicates error - doesn't return yet to ensure display is updated
//     }

//     return_val = set_display_from_temp(temp, &display);

//     if(return_val != 0){
//         THERMO_DISPLAY_PORT = 0b00000110111101111110111110000000;
//         failed = true; // indicates error
//     }
//     if(failed == true){ // one or both failed
//         return 1;
//     }
//     else{ // everything went well, failed == false
//         THERMO_DISPLAY_PORT = display;
//         return 0;
//     }
    
// }