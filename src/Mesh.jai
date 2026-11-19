
Mesh :: struct
{
	Vertices: [..] Vertex;
	Indices: [..] u32;
	Textures: [..] Texture;

	_vao: u32;
	_vbo: u32;
	_ebo: u32;
}

MeshInit :: (self: *Mesh, vertices: *[..] Vertex, indices: *[..] u32, textures: *[..] Texture)
{
	self.Vertices = vertices.*;
	self.Indices = indices.*;
	self.Textures = textures.*;

	_SetupMesh(self);
}

MeshDraw :: (self: *Mesh, shader: *Shader)
{
	hasDiffuse := false;
	hasSpecular := false;
	hasEmission := false;

	for self.Textures
	{
		glActiveTexture(cast(u32) (GL_TEXTURE0 + it_index));
		glBindTexture(GL_TEXTURE_2D, it.ID);

		if it.Type == "texture_diffuse"
		{
			ShaderSetInt(shader, "material.diffuseMap", xx it_index);
			hasDiffuse = true;
		}
		else if it.Type == "texture_specular"
		{
			ShaderSetInt(shader, "material.specularMap", xx it_index);
			hasSpecular = true;
		}
		else if it.Type == "texture_emission"
		{
			ShaderSetInt(shader, "material.emissionMap", xx it_index);
			hasEmission = true;
		}
	}

	ShaderSetBool(shader, "material.hasDiffuseMap", hasDiffuse);
	ShaderSetBool(shader, "material.hasSpecularMap", hasSpecular);
	ShaderSetBool(shader, "material.hasEmissionMap", hasEmission);

	glActiveTexture(GL_TEXTURE0);

	MeshDrawGeometry(self);
}

MeshDrawGeometry :: (self: *Mesh)
{
	glBindVertexArray(self._vao);
	glDrawElements(GL_TRIANGLES, xx self.Indices.count, GL_UNSIGNED_INT, xx 0);
	glBindVertexArray(0);
}

_SetupMesh :: (self: *Mesh)
{
	glGenVertexArrays(1, *self._vao);
	glGenBuffers(1, *self._vbo);
	glGenBuffers(1, *self._ebo);

	glBindVertexArray(self._vao);

	glBindBuffer(GL_ARRAY_BUFFER, self._vbo);
	glBufferData(GL_ARRAY_BUFFER, self.Vertices.count * size_of(Vertex), self.Vertices.data, GL_STATIC_DRAW);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self._ebo);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, self.Indices.count * size_of(u32), self.Indices.data, GL_STATIC_DRAW);

	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), xx 0);

	glEnableVertexAttribArray(1);
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), xx size_of(Vector3));
	
	glEnableVertexAttribArray(2);
	glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), xx (2 * size_of(Vector3)));

	glBindVertexArray(0);
}

Vertex :: struct
{
	Position: Vector3;
	Normal: Vector3;
	TexCoords: Vector2;
}

#import, file "Texture.jai";
#import, file "Shader.jai";

#import "Basic";
#import "Math";
#import "String";
#import "GL";
