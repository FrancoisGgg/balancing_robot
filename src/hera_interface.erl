-module(hera_interface).

-behavior(hera_measure).

-export([init/1, measure/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

init(_Args) ->
	Spec = #{name=>kaltest, iter=>infinity, sync=>false, disable_com=>false},
	T0 = erlang:system_time()/1.0e6,
    Robot_Pid = spawn(robot, robot_init, [self()]),

	Names = "T,Freq,Gy,Acc,CtrlByte,AngleAccelerometer,AngleKalman,AngleComplem,Vref,Select",
	Len = 10,

	io:format("Pid of the Hera interface: ~p.~n", [self()]),
	io:format("Graphing enabled !~n"),
	grisp_led:color(1, {1, 1, 0}),
	grisp_led:color(2, {1, 1, 0}),

	{ok, {Robot_Pid, {Names, Len, 1}, T0, 0, 0, 200, T0}, Spec}.

measure({Robot_Pid, {Names, Len, File_Number}, StartTime, N, Freq, Mean_Freq, T0}) ->

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Interface with the robot Features %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	Robot_Pid ! {self(), get_all_data},
	receive {_, data, Robot_Data} -> ok end,

	T1 = erlang:system_time()/1.0e6,
	Dt = (T1- T0)/1000.0,
    if 
        N == 100 ->
			io:format("hera freq: ~.2f~n",[Freq]),
            N_New = 0,
            Freq_New = 0,
			Mean_Freq_New = Freq,

            %Reset LED color after some time
            grisp_led:color(1, {1, 1, 0}),
	        grisp_led:color(2, {1, 1, 0});
        true ->
            N_New = N+1,
            Freq_New = ((Freq*N)+(1/Dt))/(N+1),
			Mean_Freq_New = Mean_Freq
    end,

	%%%%%%%%%%%%%%%
    %%% Logging %%%
    %%%%%%%%%%%%%%%

	File_Name = "measures"++integer_to_list(File_Number)++".txt",

	%Retrieve start and end of logging sequence
	receive
		% {_, data, Robot_Data} -> 
		% 	Start_Log = false,
		% 	Stop_Log = false;
		{_, start_log} -> 
			Start_Log = true,
			Stop_Log = false;
		{_, stop_log} -> 
			Start_Log = false,
			Stop_Log = true
	after 0 ->
		Start_Log = false,
		Stop_Log = false
	end,

	%Start of logging sequence: create new file to write data in.
	if
		Start_Log ->
			log_init(Names, File_Name);
		true ->
			ok
	end,

	%End of logging sequence: retrieve data and write to file.
	if
		Stop_Log ->
			File_Number_New = File_Number+1,
			io:format("New log file with name: ~s~n",[File_Name]),
			log_init(Names, File_Name),
			Robot_Pid ! {self(), log_values},
			receive {_, log, Log_Values} -> ok end,
			io:format("received log vals ~p~n",[length(Log_Values)]),
			log(Log_Values, File_Name, Len);
		true ->
			File_Number_New = File_Number
	end,

	{ok, [0,1], {Robot_Pid, {Names, Len, File_Number_New}, StartTime, N_New, Freq_New, Mean_Freq_New, T1}}.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%
%Initialise the log file by writing the header
%
log_init(Names, File) ->
	file:write_file(File, io_lib:fwrite("~s\n", [Names])).

%
%Append the values to the log file
%
log([], _, _) -> ok;
log(Val_List, File, Len) ->
	Sub_Vals = lists:sublist(Val_List,1,Len),
	Vals = lists:map(fun(V) -> lists:flatten(io_lib:format("~p", [V])) end, Sub_Vals),
	S = string:join(Vals, ","),
	Bytes = io_lib:format("~s~n", [S]),
	% io:format("writing file~n"),
	ok = file:write_file(File, Bytes, [append]),
	log(lists:sublist(Val_List,Len+1,length(Val_List)),File,Len).
