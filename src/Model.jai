
Model :: struct
{
	_meshes: [..] Mesh;
	_loaded: [..] LoadedTexture;

	_axisX: Vector3 = .{ 1.0, 0.0, 0.0 };
	_axisY: Vector3 = .{ 0.0, 1.0, 0.0 };
	_axisZ: Vector3 = .{ 0.0, 0.0, 1.0 };

	_center: Vector3;
	_scale: float32 = 1.0;
}

LoadedTexture :: struct
{
	Name: string;
	ID: u32;
}

ModelDraw :: (self: *Model, shader: *Shader)
{
	model := MakeScale(Vector3.{ self._scale, self._scale, self._scale }) * MakeTranslation(self._center * -1.0);
	ShaderSetMat4(shader, "model", model);

	for self._meshes
		MeshDraw(*it, shader);
}

ModelInit :: (self: *Model, fileName: string, flipUVs := false)
{
	path := tprint("%/../models/%", #filepath, fileName);

	flags := aiPostProcessSteps.Triangulate
		| aiPostProcessSteps.GenNormals
		| aiPostProcessSteps.JoinIdenticalVertices
		| aiPostProcessSteps.PreTransformVertices;

	if flipUVs flags |= aiPostProcessSteps.FlipUVs;

	scene := aiImportFile(temp_c_string(path), cast(u32) flags);

	if !scene || (scene.mFlags & AI_SCENE_FLAGS_INCOMPLETE) != 0 || !scene.mRootNode
	{
		print("Assimp error: %\n", to_string(aiGetErrorString()));
		return;
	}

	_ReadAxes(self, scene.mMetaData);

	_ProcessNode(self, scene.mRootNode, scene);

	_FitToView(self);

	aiReleaseImport(scene);
}

_ReadAxes :: (self: *Model, meta: *aiMetadata)
{
	coord := _AxisVector(_MetaInt(meta, "CoordAxis", 0), _MetaInt(meta, "CoordAxisSign", 1));
	up    := _AxisVector(_MetaInt(meta, "UpAxis", 1),    _MetaInt(meta, "UpAxisSign", 1));
	front := _AxisVector(_MetaInt(meta, "FrontAxis", 2), _MetaInt(meta, "FrontAxisSign", 1));

	// print("Model axes (right, up, front): % % %\n", coord, up, front); // debug only

	if abs(dot(coord, up)) > 0.01 || abs(dot(coord, front)) > 0.01 || abs(dot(up, front)) > 0.01 return;

	self._axisX = coord;
	self._axisY = up;
	self._axisZ = front;
}

_MetaInt :: (meta: *aiMetadata, key: string, fallback: s32) -> s32
{
	if !meta return fallback;

	for i: 0..cast(s64) meta.mNumProperties - 1
	{
		name: string;
		name.count = meta.mKeys[i].length;
		name.data = *meta.mKeys[i].data[0];

		if name == key && meta.mValues[i].mType == .AI_INT32
			return << cast(*s32) meta.mValues[i].mData;
	}

	return fallback;
}

_AxisVector :: (axis: s32, sign: s32) -> Vector3
{
	v: Vector3;
	s := cast(float32) sign;

	if axis == 0 v.x = s;
	else if axis == 1 v.y = s;
	else v.z = s;

	return v;
}

_ToSceneAxes :: (self: *Model, v: Vector3) -> Vector3
{
	return Vector3.{ dot(self._axisX, v), dot(self._axisY, v), dot(self._axisZ, v) };
}

_FitToView :: (self: *Model)
{
	lo := Vector3.{  1.0e30,  1.0e30,  1.0e30 };
	hi := Vector3.{ -1.0e30, -1.0e30, -1.0e30 };

	for mesh: self._meshes
	{
		for vertex: mesh.Vertices
		{
			p := vertex.Position;
			lo = Vector3.{ min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z) };
			hi = Vector3.{ max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z) };
		}
	}

	// print("Model bounds: min % max %\n", lo, hi); // debug only

	size := hi - lo;
	largest := max(size.x, max(size.y, size.z));
	if largest <= 0.0 return;

	self._center = (lo + hi) * 0.5;
	self._scale = 2.0 / largest;
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

		vertex.Position = _ToSceneAxes(self, vertex.Position);
		vertex.Normal = _ToSceneAxes(self, vertex.Normal);

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

		if !_AddMaterialTexture(self, *textures, material, aiTextureType.DIFFUSE, "texture_diffuse")
		{
			if !_AddMaterialTexture(self, *textures, material, aiTextureType.BASE_COLOR, "texture_diffuse")
				print("No diffuse texture for material % (mesh uses Material colors)\n", mesh.mMaterialIndex);
		}

		_AddMaterialTexture(self, *textures, material, aiTextureType.SPECULAR, "texture_specular");

		if !_AddMaterialTexture(self, *textures, material, aiTextureType.EMISSIVE, "texture_emission")
			_AddMaterialTexture(self, *textures, material, aiTextureType.EMISSION_COLOR, "texture_emission");
	}

	result: Mesh;
	MeshInit(*result, *vertices, *indices, *textures);

	return result;
}

_AddMaterialTexture :: (self: *Model, textures: *[..] Texture, material: *aiMaterial, type: aiTextureType, typeName: string) -> bool
{
	if aiGetMaterialTextureCount(material, type) == 0 return false;

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
			return true;
		}
	}

	texture, ok := TextureLoad(fileName, typeName);
	if !ok return false;

	entry: LoadedTexture;
	entry.Name = copy_string(fileName);
	entry.ID = texture.ID;
	array_add(*self._loaded, entry);

	array_add(textures, texture);

	return true;
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
#import, file "Transform.jai";

#import "Basic";
#import "Math";
#import "String";
