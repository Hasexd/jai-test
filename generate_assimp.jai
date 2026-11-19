
LIB_DIR :: "libs/assimp";
DLL_PATH :: "libs/assimp/assimp-vc145-mt.dll";
INCLUDE :: "libs/assimp/include";

GenerateDef :: (dll: string, defPath: string) -> bool
{
    result, output := run_command("dumpbin", "/exports", dll, capture_and_return_output = true);

    if result.exit_code != 0
    {
        print("dumpbin didnt work\n");
        return false;
    }

    builder: String_Builder;
    append(*builder, tprint("LIBRARY %\nEXPORTS\n", path_strip_extension(path_filename(dll))));

    count := 0;

    for line: split(output, "\n")
    {
        fields: [..] string;
        fields.allocator = temp;

        for p: split(trim(line), " ")
        {
            if p.count
                array_add(*fields, p);
        }

        if fields.count >= 4 &&
           fields[0][0] >= #char "0" &&
           fields[0][0] <= #char "9" &&
           begins_with(fields[3], "ai")
        {
            append(*builder, tprint("    %\n", fields[3]));
            count += 1;
        }
    }

    print("Found % exports (ai*)\n", count);

    if count == 0
        return false;

    return write_entire_file(defPath, builder_to_string(*builder));
}

BuildImportLib :: (defPath: string, libPath: string) -> bool
{
    result := run_command(
        "lib",
        tprint("/def:%", defPath),
        "/machine:x64",
        tprint("/out:%", libPath),
        print_captured_output = true
    );

    return result.exit_code == 0;
}

GenerateAssimpBindings :: () -> bool
{
    opts: Generate_Bindings_Options;
    opts.generate_library_declarations = true;

    array_add(*opts.libpaths, LIB_DIR);
    array_add(*opts.libnames, "assimp");
    array_add(*opts.include_paths, INCLUDE);

    array_add(*opts.source_files,
        tprint("%/assimp/cimport.h", INCLUDE),
        tprint("%/assimp/scene.h", INCLUDE),
        tprint("%/assimp/postprocess.h", INCLUDE));

    array_add(*opts.extra_clang_arguments, tprint("-I%", INCLUDE));

    return generate_bindings(opts, tprint("%/assimp.jai", LIB_DIR));
}

#run
{
    set_build_options_dc(.{do_output = false});

    defPath := tprint("%/assimp.def", LIB_DIR);
    libPath := tprint("%/assimp.lib", LIB_DIR);

    if !GenerateDef(DLL_PATH, defPath) exit(1);

    if !BuildImportLib(defPath, libPath)
    {
        print("lib.exe didnt work\n");
        exit(1);
    }

    if !GenerateAssimpBindings()
    {
        print("Failed to generate assimp bindings\n");
        exit(1);
    }

    print("Successfully generated assimp bindings\n");
}

#import "Basic";
#import "Process";
#import "String";
#import "File";
#import "Bindings_Generator";
#import "Compiler";
