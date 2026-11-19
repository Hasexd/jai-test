
Model :: struct
{
	_meshes: [..] Mesh;
	_loaded: [..] LoadedTexture;
}

LoadedTexture :: struct
{
	Name: string;
	ID: u32;
}

ModelDraw :: (self: *Model, shader: *Shader)
{
	for self._meshes
		MeshDraw(*it, shader);
}

ModelInit :: (self: *Model, fileName: string)
{
	path := tprint("%/../models/%", #filepath, fileName);

	flags := aiPostProcessSteps.Triangulate
		| aiPostProcessSteps.GenNormals
		| aiPostProcessSteps.FlipUVs
		| aiPostProcessSteps.JoinIdenticalVertices;

	scene := aiImportFile(temp_c_string(path), cast(u32) flags);

	if !scene || (scene.mFlags & AI_SCENE_FLAGS_INCOMPLETE) != 0 || !scene.mRootNode
	{
		print("Assimp error: %\n", to_string(aiGetErrorString()));
		return;
	}

	_ProcessNode(self, scene.mRootNode, scene);

	aiReleaseImport(scene);
}

_ProcessNode :: (self: *Model, node: *aiNode, scene: *aiScene)
{
	for i: 0..cast(s64) node.mNumMeshes - 1
	{
		mesh := scene.mMeshes[node.mMeshes[i]];
		array_add(*self._meshes, _ProcessMesh(self, mesh, scene));
	}

	for i: 0..cast(s64) node.mNumChildren - 1
	{
		_ProcessNode(self, node.mChildren[i], scene);
	}
}

_ProcessMesh :: (self: *Model, mesh: *aiMesh, scene: *aiScene) -> Mesh
{
	vertices: [..] Vertex;
	indices: [..] u32;
	textures: [..] Texture;

	for i: 0..cast(s64) mesh.mNumVertices - 1
	{
		vertex: Vertex;
		vertex.Position = .{ mesh.mVertices[i].x, mesh.mVertices[i].y, mesh.mVertices[i].z };
		vertex.Normal = .{ mesh.mNormals[i].x, mesh.mNormals[i].y, mesh.mNormals[i].z };

		if mesh.mTextureCoords[0]
			vertex.TexCoords = .{ mesh.mTextureCoords[0][i].x, mesh.mTextureCoords[0][i].y };
		else
			vertex.TexCoords = .{ 0.0, 0.0 };

		array_add(*vertices, vertex);
	}

	for i: 0..cast(s64) mesh.mNumFaces - 1
	{
		face := mesh.mFaces[i];
		for j: 0..cast(s64) face.mNumIndices - 1
			array_add(*indices, face.mIndices[j]);
	}

	if mesh.mMaterialIndex < scene.mNumMaterials
	{
		material := scene.mMaterials[mesh.mMaterialIndex];

		_AddMaterialTexture(self, *textures, material, aiTextureType.DIFFUSE, "texture_diffuse");
		_AddMaterialTexture(self, *textures, material, aiTextureType.SPECULAR, "texture_specular");
		_AddMaterialTexture(self, *textures, material, aiTextureType.EMISSIVE, "texture_emission");
	}

	result: Mesh;
	MeshInit(*result, *vertices, *indices, *textures);

	return result;
}

_AddMaterialTexture :: (self: *Model, textures: *[..] Texture, material: *aiMaterial, type: aiTextureType, typeName: string)
{
	if aiGetMaterialTextureCount(material, type) == 0 return;

	str: aiString;
	aiGetMaterialTexture(material, type, 0, *str, null, null, null, null, null, null);

	path: string;
	path.count = str.length;
	path.data = *str.data[0];

	fileName := _FileNameOnly(path);

	for self._loaded
	{
		if it.Name == fileName
		{
			cached: Texture;
			cached.ID = it.ID;
			cached.Type = typeName;
			array_add(textures, cached);
			return;
		}
	}

	texture, ok := TextureLoad(fileName, typeName);
	if !ok return;

	entry: LoadedTexture;
	entry.Name = copy_string(fileName);
	entry.ID = texture.ID;
	array_add(*self._loaded, entry);

	array_add(textures, texture);
}

_FileNameOnly :: (path: string) -> string
{
	i := path.count - 1;
	while i >= 0
	{
		if path[i] == #char "/" || path[i] == #char "\\" break;
		i -= 1;
	}

	result: string;
	result.data = path.data + i + 1;
	result.count = path.count - i - 1;

	return result;
}

#import, file "Mesh.jai";
#import, file "Shader.jai";
#import, file "Assimp.jai";
#import, file "Texture.jai";

#import "Basic";
#import "String";
