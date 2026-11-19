
Shader :: struct
{
	ID: u32;
}

ShaderInit :: (self: *Shader, vertexFile: string, fragmentFile: string)
{
	vertex := _CompileShader(vertexFile, GL_VERTEX_SHADER);
	fragment := _CompileShader(fragmentFile, GL_FRAGMENT_SHADER);
	
	self.ID = glCreateProgram();
	glAttachShader(self.ID, vertex);
	glAttachShader(self.ID, fragment);
	glLinkProgram(self.ID);

	infoLog: [512] u8;
	length: u32 = 0;
	success: s32 = 0;
	glGetProgramiv(self.ID, GL_LINK_STATUS, *success);

	if !success
	{
		glGetProgramInfoLog(self.ID, 512, *length, *infoLog[0]);
		_PrintShaderError(infoLog, length);
	}

	glDeleteShader(vertex);
	glDeleteShader(fragment);
}

ShaderUse :: (self: *Shader)
{
	glUseProgram(self.ID);
}

ShaderSetBool :: (self: *Shader, name: string, value: bool)
{
	glUniform1i(_glGetUniformLocation(self.ID, name), cast(s32) value);
}

ShaderSetInt :: (self: *Shader, name: string, value: u32)
{
	glUniform1i(_glGetUniformLocation(self.ID, name), xx value);
}

ShaderSetFloat :: (self: *Shader, name: string, value: float32)
{
	glUniform1f(_glGetUniformLocation(self.ID, name), value);
}

ShaderSetVec3 :: (self: *Shader, name: string, value: Vector3)
{
	glUniform3f(_glGetUniformLocation(self.ID, name), value.x, value.y, value.z);
}

ShaderSetMat4 :: (self: *Shader, name: string, value: Matrix4)
{
	m := value;
	glUniformMatrix4fv(_glGetUniformLocation(self.ID, name), 1, GL_TRUE, *m.coef[0][0]);
}


_CompileShader :: (shaderFile: string, stage: u32) -> u32
{
	shaderStr, tf := read_entire_file(tprint("%/../shaders/%", #filepath, shaderFile));
	
	if !tf
	{
		print("Failed to open a shader file (%).\n", shaderFile);
		return 0;
	}

	shader := glCreateShader(stage);
	_glShaderSource(shader, shaderStr);
	glCompileShader(shader);
	
	infoLog: [512] u8;
	length: u32 = 0;
	success: s32 = 0;
	glGetShaderiv(shader, GL_COMPILE_STATUS, *success);

	if !success
	{
		glGetShaderInfoLog(shader, 512, *length, *infoLog[0]);
		_PrintShaderError(infoLog, length);
	}
	
	return shader;
}

_PrintShaderError :: (error: [512] u8, length: u32)
{
	builder: String_Builder;
	init_string_builder(*builder);

	for index:0..length
	{
		append(*builder, error[index]);
	}
	print("%", builder_to_string(*builder));
}

#import "Basic";
#import "String";
#import "File";
#import "GL";
#import "Math";
