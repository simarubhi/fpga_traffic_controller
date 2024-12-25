// Top module  
module traffic_controller(high_ud_sw, high_lr_sw, ud_ir, lr_ir, stop_sign_sw, clk, t_ones_ssd, t_tens_ssd, ud_ones_ssd, ud_tens_ssd, lr_ones_ssd, lr_tens_ssd, ud_led, lr_led, clk_led, high_ud_led, high_lr_led);  
	input high_ud_sw, high_lr_sw, ud_ir, lr_ir, stop_sign_sw, clk; // Switches for high traffic, buttons for traffic sensor input, switch to active stop sign mode, 50Mhz clock
	output [0:6] t_ones_ssd, t_tens_ssd, ud_ones_ssd, ud_tens_ssd, lr_ones_ssd, lr_tens_ssd; // Displays for timer and counters  
	output [0:5] ud_led, lr_led; // Traffic lights  
	output clk_led, high_ud_led, high_lr_led; // Clock led, high traffic flow leds  
   
	wire clk_1hz; // 1 second clock pulse  
  
	slow_clock(clk, clk_1hz); // Generates the 1 second clock pulse  
   
	light_controller(high_ud_sw, high_lr_sw, ud_ir, lr_ir, stop_sign_sw, clk_1hz, t_ones_ssd, t_tens_ssd, ud_ones_ssd, ud_tens_ssd, lr_ones_ssd, lr_tens_ssd, ud_led, lr_led, clk_led, high_ud_led, high_lr_led); // Controls traffic logic  
  
endmodule  
  
// Controls all traffic logic  
module light_controller(high_ud_sw, high_lr_sw, ud_ir, lr_ir, stop_sign_sw, clk_1hz, t_ones_ssd, t_tens_ssd, ud_ones_ssd, ud_tens_ssd, lr_ones_ssd, lr_tens_ssd, ud_led, lr_led, clk_led, high_ud_led, high_lr_led);  
   input high_ud_sw, high_lr_sw, ud_ir, lr_ir, stop_sign_sw, clk_1hz; // Switches for high traffic, buttons for traffic sensor input, switch to active stop sign mode, 1 second pulse clock  
	output [0:6] t_ones_ssd, t_tens_ssd, ud_ones_ssd, ud_tens_ssd, lr_ones_ssd, lr_tens_ssd; // Displays for timer and counters  
	output reg [0:5] ud_led, lr_led; // Traffic lights  
	output reg clk_led, high_ud_led, high_lr_led; // Clock led, high traffic flow leds  
   
	reg [5:0] timer, ud_count, lr_count; // Timer to count traffic light durations, counts for sensor input in each direction  
	reg [0:3] t_ones, t_tens, ud_ones, ud_tens, lr_ones, lr_tens; // Values for the timer and counts, passed into display modules  
   
	reg ud_auto_set, lr_auto_set; // Signal that hold value if certain direction should be automatically set high traffic flow  
   
	reg blink; // Signal to decide   
   
	reg flowing_ud; // Controls which direction is currently flowing
   
	// CONTROL VARIABLES ------------------------------------------------------------  
	reg [5:0] regular_flow = 15; // Duration when no high flow is set  
	reg [5:0] high_flow = 18; // High flow long duration  
	reg [5:0] low_flow = 10; // High flow short duration  
	reg [3:0] overflow_car_count_limit = 5; // Number of cars one direction should have more than the other to trigger high flow state  
      
	pos_display(t_ones, t_tens, t_ones_ssd, t_tens_ssd, clk_1hz); // Display timer synced with 1hz clock display(ud_ones, ud_tens, ud_ones_ssd, ud_tens_ssd, ud_count);
	display(ud_ones, ud_tens, ud_ones_ssd, ud_tens_ssd, ud_count); // Display up and down count synced with up-down ir sensor
	display(lr_ones, lr_tens, lr_ones_ssd, lr_tens_ssd, lr_count); // Display left and right count synced with left-right ir sensor  
    
	// Get individual values of timer  
	always@(timer)  
		begin  
			t_ones <= timer % 10;  
			t_tens <= timer / 10;  
		end  
   
	assign reset_counts = (stop_sign_sw || ud_count == 60 || lr_count == 60); // Reset both car counts when either reaches 60  
   
	// Count cars that pass in the UD direction  
	always@(negedge ud_ir or posedge reset_counts)  
		begin  
			if (reset_counts)  
				ud_count <= 0;  
			else  
				ud_count <= ud_count + 1;  
		end  
   
	// Count cars that pass in the LR direction   
	always@(negedge lr_ir or posedge reset_counts)  
		begin  
			if (reset_counts)  
				lr_count <= 0;  
			else  
				lr_count <= lr_count + 1;  
		end   
   
	// Get individual values of up-down count and increment or reset  
	always@(ud_count)  
		begin  
			ud_ones <= ud_count % 10;  
			ud_tens <= ud_count / 10;  
		end  
   
	// Get individual values of left-right count and increment or reset   
	always@(lr_count)  
		begin  
			lr_ones <= lr_count % 10;  
			lr_tens <= lr_count / 10;  
		end  
     
	// Blink clock led with 1hz clock  
	always@(clk_1hz)  
		clk_led <= clk_1hz;  
    
	// Controls the interval, timer, and light logic  
	// First run goes straight to timer == 0 condition  
	always@(posedge clk_1hz)  
		begin  
			if (stop_sign_sw) // Stop sign mode is activated (all 4 lights will blink red)  
				begin  
					// Reset all variables to initial conditions  
					blink <= ~blink;  
					timer <= 0;  
					ud_auto_set <= 0;  
					lr_auto_set <= 0;  
					high_ud_led <= 0;  
					high_lr_led <= 0;  
					flowing_ud <= 0;  
       
					if (blink) // Use toggled blink variable to blink red lights for both directions  
						begin
							ud_led <= 6'b000011;
							lr_led <= 6'b000011;
						end  
					else  
						begin  
							ud_led <= 6'b000000;
							lr_led <= 6'b000000;
						end  
				end  
			else // Stop sign mode is not active  
				begin  
					if (timer > 3) // Green light if more than 3 seconds remain  
						begin  
        
							if (flowing_ud) // Up down green light  
								begin  
									ud_led <= 6'b110000;  
									lr_led <= 6'b000011;  
								end  
							else // Right left green light  
								begin  
									lr_led <= 6'b110000;  
									ud_led <= 6'b000011;  
								end  
          
							timer <= timer - 1; // Count down timer  
						end  
       
					else if (timer <= 3 && timer > 0) // Yellow light if (0,3] seconds   
						begin  
         
							if (flowing_ud) // Up down yellow light  
								begin  
									ud_led <= 6'b001100;  
									lr_led <= 6'b000011;  
								end  
							else // Right left yellow light  
								begin  
									lr_led <= 6'b001100;  
									ud_led <= 6'b000011;  
								end  
          
							timer <= timer - 1;  
						end  
        
					else if (timer == 0) // Red light  
						begin  
         
							// Both directions red  
							ud_led <= 6'b000011;  
							lr_led <= 6'b000011;  
         
							flowing_ud <= ~flowing_ud; // Switch flow direction       
         
							if (~flowing_ud)  
								begin  
									// Logic to automatically set highflow state  
									if (ud_count >= lr_count + overflow_car_count_limit)  
										ud_auto_set = 1;  
									else  
										ud_auto_set = 0;  
									  
									if (lr_count >= ud_count + overflow_car_count_limit)  
										lr_auto_set = 1;  
									else  
										lr_auto_set = 0;  
								end  
              
							// Set timer according to if high flow state and direction  
							if (high_ud_sw) // UD switch active  
								begin  
									high_ud_led <= 1;  
									high_lr_led <= 0;  
           
									if (flowing_ud)  
										timer <= high_flow;  
									else  
										timer <= low_flow;  
          
								end  
							else if (high_lr_sw) // LR switch active (UD has priority if both up)  
								begin  
									high_ud_led <= 0;  
									high_lr_led <= 1;  
          
									if (flowing_ud)  
										timer <= low_flow;  
									else  
										timer <= high_flow;  
          
								end  
          
							else if (ud_auto_set) // If up-down has 5 or more cars than left-right set high flow state for up-down  
								begin  
									high_ud_led <= 1;  
									high_lr_led <= 0;  
         
									if (flowing_ud)  
										timer <= high_flow;  
									else  
										timer <= low_flow;  
          
								end  
							else if (lr_auto_set) // If left-right has 5 or more cars than up-down set high flow state for up-down  
								begin  
									high_ud_led <= 0;  
									high_lr_led <= 1;  
           
									if (flowing_ud)  
										timer <= low_flow;  
									else  
										timer <= high_flow;  
          
								end  
							else  
								begin  
									timer <= regular_flow; // Regular timer if no high flow state  
									high_ud_led <= 0;  
									high_lr_led <= 0;  
								end  
						end  
				end  
		end   
  
endmodule  
  
// Displays values to seven segment displays on positive edge of sync  
module pos_display(ones, tens, ones_ssd, tens_ssd, sync);  
	input [0:3] ones, tens; // Individual digits of integer  
	input sync; // Input to sync the display with  
	output reg [0:6] ones_ssd = 7'b0000001, tens_ssd = 7'b0000001; // Default display 0 for both ones and tens  
   
	// Displaying the timer  
	always@(posedge sync)  
		begin  
			begin  
				// Ones display  
				case(ones)  
					4'b0000:ones_ssd = 7'b0000001;  
					4'b0001:ones_ssd = 7'b1001111;  
					4'b0010:ones_ssd = 7'b0010010;  
					4'b0011:ones_ssd = 7'b0000110;  
					4'b0100:ones_ssd = 7'b1001100;  
					4'b0101:ones_ssd = 7'b0100100;  
					4'b0110:ones_ssd = 7'b0100000;  
					4'b0111:ones_ssd = 7'b0001111;  
					4'b1000:ones_ssd = 7'b0000000;  
					4'b1001:ones_ssd = 7'b0001100;  
				endcase  
			end  
    
			begin  
				// Tens display
				case(tens)  
					4'b0000:tens_ssd = 7'b0000001;  
					4'b0001:tens_ssd = 7'b1001111;  
					4'b0010:tens_ssd = 7'b0010010;  
					4'b0011:tens_ssd = 7'b0000110;  
					4'b0100:tens_ssd = 7'b1001100;  
					4'b0101:tens_ssd = 7'b0100100;  
					4'b0110:tens_ssd = 7'b0100000;  
					4'b0111:tens_ssd = 7'b0001111;  
					4'b1000:tens_ssd = 7'b0000000;  
					4'b1001:tens_ssd = 7'b0001100;  
				endcase  
			end  
		end  
    
endmodule  
  
// Displays values to seven segment displays  
module display(ones, tens, ones_ssd, tens_ssd, sync);  
	input [0:3] ones, tens; // Individual digits of integer  
	input sync; // Input to sync the display with  
	output reg [0:6] ones_ssd = 7'b0000001, tens_ssd = 7'b0000001; // Default display 0 for both ones and tens  
   
	// Displaying the timer  
	always@(sync)  
		begin  
			begin  
				// Ones display  
				case(ones)  
					4'b0000:ones_ssd = 7'b0000001;  
					4'b0001:ones_ssd = 7'b1001111;  
					4'b0010:ones_ssd = 7'b0010010;  
					4'b0011:ones_ssd = 7'b0000110;  
					4'b0100:ones_ssd = 7'b1001100;  
					4'b0101:ones_ssd = 7'b0100100;  
					4'b0110:ones_ssd = 7'b0100000;  
					4'b0111:ones_ssd = 7'b0001111;  
					4'b1000:ones_ssd = 7'b0000000;  
					4'b1001:ones_ssd = 7'b0001100;  
				endcase  
			end  
    
			begin  
				// Tens display
				case(tens)  
					4'b0000:tens_ssd = 7'b0000001;  
					4'b0001:tens_ssd = 7'b1001111;  
					4'b0010:tens_ssd = 7'b0010010;  
					4'b0011:tens_ssd = 7'b0000110;  
					4'b0100:tens_ssd = 7'b1001100;  
					4'b0101:tens_ssd = 7'b0100100;  
					4'b0110:tens_ssd = 7'b0100000;  
					4'b0111:tens_ssd = 7'b0001111;  
					4'b1000:tens_ssd = 7'b0000000;  
					4'b1001:tens_ssd = 7'b0001100;  
				endcase  
			end  
		end  
    
endmodule  
  
// 1 hz clock pulse  
module slow_clock(clk, clk_1hz);  
	input clk; // 50 Mhz input clock  
	output clk_1hz;  
  
	reg [27:0] counter;  
	reg clk_1hz = 0;  
   
	always@(posedge clk)  
		begin  
			counter <= counter + 1;  
     
			if (counter == 25_000_000)   
				begin  
					counter <= 0;  
					clk_1hz = ~clk_1hz;  
				end  
		end  
  
endmodule
