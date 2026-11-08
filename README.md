# Elevator-in-Assembly
Project from Class - Elevator control system written in C then actualized with STM32 and other components.  Please dont ask too specifically how things work, this was very long ago and it was the last time i wrote assembly XD.


STM32 Elevator Controller

ECE 0202 Final Project | Spring 2026

A three-floor elevator control system developed in ARM assembly for the STM32L476 microcontroller. The project uses two stepper motors to simulate elevator movement and door operation, with a matrix keypad for user input, a seven-segment floor display, LED status indicators, and UART serial communication.

Features

* Three-Floor Control: Processes elevator requests for floors 1–3.
* Floor Request Queue: Stores multiple floor requests using a bitmask and prioritizes the nearest requested floor.
* Stepper Motor Control: Controls separate motors for elevator movement and door operation.
* Speed Control: Implements acceleration and deceleration timing during elevator movement.
* Keypad Interface: Scans a 4×3 matrix keypad with software debouncing.
* Emergency Stop: De-energizes motors and pauses operation while the emergency key is held.
* Manual Override: Allows manual cycling through floor requests.
* Maintenance Mode: Requests a return to the first floor.
* Floor Display: Outputs floor information to a seven-segment display through a BCD decoder.
* Status Indicators: Uses LEDs and UART messages to indicate elevator activity.

Hardware

* STM32L476 microcontroller
* Two stepper motors with ULN2003 drivers
* 4×3 matrix keypad
* Seven-segment display with 74LS247 BCD decoder
* Three status LEDs
* UART serial interface

Software

* ARM assembly (ARMASM syntax)
* STM32 GPIO register configuration
* Software-based motor sequencing and timing
* Keil-compatible assembly source

Project Structure

Elevator_Controller.s — Main assembly source containing initialization, elevator control logic, keypad handling, motor control, and peripheral interfaces.

The original project also references STM32 device constants and external clock/UART initialization routines, which are not included in this repository.

Notes

This repository archives an academic embedded systems project developed in Spring 2026. It is intended to demonstrate low-level microcontroller programming, peripheral interfacing, and embedded control logic rather than provide a standalone, currently verified build.

The emergency-stop behavior is a software demonstration, not a safety-rated emergency-stop implementation.