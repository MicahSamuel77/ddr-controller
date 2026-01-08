# DDR1 Memory Controller - ECE 337 Custom CDL Project
The aim of this project was to make a DDR1 Memory Controller that could interface with a SoC via the AMBA AXI4 Protocol. The following requirements were set for a successful implementation of the design:
- DDR Speed of 10 MHz
- Out of Order Interleaving Support
- Follows timing specifcations of DDR1
- Data is clocked on both rising and falling edge of clock
- Implements DDR Commands in correct order and refreshing

In addition to the memory controller, a DRAM and AXI "software" model also needed to be implemented for correct validation, the specifications for which can be seen below:

DRAM Model:
- 1 memory chip, 8 banks with depth of 8 memory arrays
- Each memory array is composed of 8 columns and 8 rows
- DRAM model responds correctly to commands being sent from DRAM controller
- Follows timings of generic DRAM cells
  
AXI Model:
- Supports queing and sending of transactions
- Supports reading the result of a transaction and if the response is what is expected

The first step of the development process was to make a Top Level RTL Diagram, which can be seen below:
<img width="791" height="653" alt="DDR-CDL-Diagrams-Top Level drawio (1)" src="https://github.com/user-attachments/assets/18317672-6fbc-4632-8a4a-7b599fc7f9dc" />

The work was then split up between the members of the team. Jash Pola worked on the AXI Subordinate, Micah Samuel worked on the commands and timing for the memory controller, and Richard Ye worked on the data handling and storage of the memory controller. Additionally, Jash worked on the AXI Model while Richard and Micah worked on the DRAM Model.





