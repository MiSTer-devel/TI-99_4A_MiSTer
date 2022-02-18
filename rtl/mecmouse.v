// Mechatronics Mouse via Joystick Port for TI-99/4A
// By Flandango

module mecmouse
(
	input	clk,
	input	reset,
	
	input j1_s,
	input j2_s,

	input [24:0] ps2_mouse,
	input mode,
	output reg [4:0] mecmouse_o
);

// |0|0|B3|B2|V|V|V|B1| { 0, 0 , 0, Up, Down, Right, Left, Fire }

reg         [4:0] mouse_r;        // Mouse Data Register
reg         [4:0] joystick_r;     // Mouse Data Register
reg  signed [7:0] mx, my, last_mx, last_my;
reg  signed [7:0] mx_buf, my_buf;
//reg  signed [7:0] last_jx, last_jy;
reg               last_select;    // Last Joystick selected
reg               read_y;
reg					dec_x, dec_y, reset_dec_x, reset_dec_y, set_dec_x, set_dec_y = 0;
reg         [31:0] js_idle_counter;
wire strobe = (old_stb != ps2_mouse[24]);
reg  old_stb = 0;

reg          [7:0] offset_n_x, offset_n_y /* synthesis keep */;

always @(posedge clk) begin
	old_stb <= ps2_mouse[24];
end

always@(posedge clk) begin
	if (mode) mecmouse_o <= joystick_r;
	else mecmouse_o <= mouse_r; 
	
	if(set_dec_x) dec_x <= 1;
	else if(reset_dec_x) dec_x <= 0;
	if(set_dec_y) dec_y <= 1;
	else if(reset_dec_y) dec_y <= 0;
end	

/* Capture button state */
always@(posedge clk) begin
		reg signed [7:0] data;
		data = read_y ? (my_buf - 8'd1) & 8'd7 : (mx_buf - 8'd1) & 8'd7;
		mouse_r[0] <= ~ps2_mouse[0]; //Left Button
		mouse_r[4] <= ~ps2_mouse[1]; //Right Button
		mouse_r[3:1] <= data[2:0];
		
		joystick_r[0] <= ~(ps2_mouse[0] || ps2_mouse[1] || ps2_mouse[2]);
end

// Joystick simulator
always@(posedge clk) begin
   if (js_idle_counter == 4463896) begin
		joystick_r[4:1] <= 4'b1111;
		js_idle_counter = 0;
	end
	else js_idle_counter = js_idle_counter + 8'd1;
	
	if (reset) begin
	end
	else if(strobe) begin
		if(ps2_mouse[15:8] != 0) begin // X Axis
			if(ps2_mouse[4]) begin
				offset_n_x <= (~ps2_mouse[15:8]) + 8'd1;
				joystick_r[2:1] <= (offset_n_x > 2) ? 2'b10 : joystick_r[2:1];       //Left
			end
			else joystick_r[2:1] <= ps2_mouse[15:8] > 2 ? 2'b01 : joystick_r[2:1];  //Right
		end
		else joystick_r[2:1] <= 2'b11;
		
		if(ps2_mouse[23:16] != 0) begin
			// High = Negative, Low = Positive
			if(ps2_mouse[5]) begin
				offset_n_y <= (~ps2_mouse[23:16]) + 8'd1;
				joystick_r[4:3] <=  (offset_n_y > 2) ? 2'b10 : joystick_r[4:3];      //Down
			end
			else joystick_r[4:3] <= ps2_mouse[23:16] > 2 ? 2'b01 : joystick_r[4:3]; //Up
		end
		else joystick_r[4:3] <= 2'b11;
		js_idle_counter = 0;
	end
	
end
	
//X Accumulator
always@(posedge clk) begin
//	reg signed [7:0] new_mx, delta_x;

	reset_dec_x  <= 0;
	if (reset) begin
		mx <= 0;
		last_mx <= 0;
	end
	else begin
		if(dec_x && reset_dec_x != 1) begin
			mx = mx - mx_buf;
			reset_dec_x <= 1;
		end
		else if(strobe) begin
			if (ps2_mouse[15:8] != last_mx) begin
				mx <= mx + $signed(ps2_mouse[15:8]);
				last_mx = ps2_mouse[15:8];
			end
		end
	end
end
		
//Y Accumulator
always@(posedge clk) begin
//	reg signed [7:0] new_my, delta_y;

	reset_dec_y <= 0;
	if (reset) begin
		my <= 0;
		last_my <= 0;
	end
	else begin
		if(dec_y && reset_dec_y != 1) begin
			my <= my - my_buf;
			reset_dec_y <= 1;
		end
		else if(strobe) begin
			if (ps2_mouse[23:16] != last_my) begin
				my <= my - $signed(ps2_mouse[23:16]);
				last_my = ps2_mouse[23:16];
			end
		end
		
	end
end
		

always@(posedge clk) begin
	reg last_j1_s, last_j2_s;

	set_dec_x = 0;
	set_dec_y = 0;
	if (reset) begin
		last_select <= 0;
		read_y <= 0;
		mx_buf <= 0;
		my_buf <= 0;
	end
	else begin
		last_j1_s <= j1_s;
		last_j2_s <= j2_s;

		if(~last_j2_s && j2_s) begin
			if(last_select == 0) begin
				if(~read_y) begin
					if(mx < $signed(-4)) mx_buf = -8'd4;
					else if(mx > $signed(3)) mx_buf = 3; 
					else mx_buf = mx;
					if(mx != 0) set_dec_x = 1;
				end
				else begin
					if(my < $signed(-4)) my_buf = -8'd4;
					else if(my > $signed(3)) my_buf = 3;
					else my_buf = my;
					if(my != 0) set_dec_y = 1;
				end
			end
			last_select <= 1;
		end
		else if(~last_j1_s && j1_s) begin
			if(last_select == 1) read_y <= ~read_y;
			last_select <= 0;
		end
		else if(j1_s == 0 && j2_s == 0) begin
			read_y <= 0;
			last_select <= 0;
		end
	end
end




endmodule
