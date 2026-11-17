
build :: () 
{
	w := compiler_create_workspace();

	if !w 
	{
		print("Workspace creation failed.\n");
		return;
	}

	targetOptions := get_build_options(w);
	targetOptions.output_executable_name = "program";
	targetOptions.output_path = ".exe";
	
	set_build_options(targetOptions, w);

	compiler_begin_intercept(w);
	add_build_file(tprint("%/src/main.jai", #filepath), w);

	while true
	{
		message := compiler_wait_for_message();
		if !message break;

		if message.kind == 
		{
			case .COMPLETE;
				break;
		}
	}
	compiler_end_intercept(w);
	set_build_options_dc(.{ do_output = false });
}

#run build();


#import "Basic";
#import "Compiler";
